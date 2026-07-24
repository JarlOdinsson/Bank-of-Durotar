local addonName, BOD = ...

BOD.Probe = {
    state = "IDLE",
    token = 0,
    active = false,
    searchText = "Netherweave Cloth",
    startedAt = nil,
    endedAt = nil,
    lastQueryTime = nil,
    lastError = nil,
    resultCount = 0,
    results = {},
}

local QUERY_PERMISSION_TIMEOUT = 10
local RESULT_TIMEOUT = 15
local QUERY_PERMISSION_INTERVAL = 0.5
local SAMPLE_LIMIT = 20

function BOD.Probe:GetState()
    return self.state or "IDLE"
end

function BOD.Probe:SetState(state, detail)
    local previousState = self.state
    self.state = state
    if previousState ~= state or detail then
        BOD:Log("INFO", "Probe", "State changed to " .. state .. (detail and (": " .. detail) or "."))
    end
    if BOD.UI then
        BOD.UI:Refresh()
    end
end

function BOD.Probe:ResetForStart(searchText)
    self.token = self.token + 1
    self.active = true
    self.searchText = searchText
    self.startedAt = time()
    self.endedAt = nil
    self.lastError = nil
    self.resultCount = 0
    self.results = {}
end

function BOD.Probe:Start(searchText)
    searchText = searchText or BOD:GetSearchText()
    BOD:SetSearchText(searchText)

    if self.active then
        BOD:Log("WARN", "Probe", "Probe already active; second request ignored.")
        return false
    end

    self:ResetForStart(searchText)

    if not BOD.AuctionAPI:IsAuctionHouseOpen() then
        self:SetState("WAITING_FOR_AH", "Auction House is not open")
        self:Fail("Open the Auction House before running the probe.")
        return false
    end

    if not C_Timer or type(C_Timer.After) ~= "function" then
        self:Fail("C_Timer.After is unavailable; cannot run controlled probe.")
        return false
    end

    BOD:Log("INFO", "Probe", "Starting one targeted search for '" .. searchText .. "'.")
    self:WaitForQueryPermission(self.token, time())
    return true
end

function BOD.Probe:WaitForQueryPermission(token, startedWaitingAt)
    if token ~= self.token or not self.active then
        return
    end

    self:SetState("WAITING_FOR_QUERY_PERMISSION")

    local canQuery, detail = BOD.AuctionAPI:CanQuery()
    if canQuery then
        self:SendQuery(token)
        return
    end

    if time() - startedWaitingAt >= QUERY_PERMISSION_TIMEOUT then
        self:Timeout("Query permission timed out: " .. tostring(detail))
        return
    end

    C_Timer.After(QUERY_PERMISSION_INTERVAL, function()
        self:WaitForQueryPermission(token, startedWaitingAt)
    end)
end

function BOD.Probe:SendQuery(token)
    if token ~= self.token or not self.active then
        return
    end

    self:SetState("QUERY_SENT")
    local ok, detail = BOD.AuctionAPI:SendTargetedSearch(self.searchText)
    if not ok then
        self:Fail("Query failed: " .. tostring(detail))
        return
    end

    self.lastQueryTime = time()
    BOD:Log("INFO", "Probe", detail)

    C_Timer.After(0, function()
        if token ~= self.token or not self.active or self.state ~= "QUERY_SENT" then
            return
        end

        self:SetState("WAITING_FOR_RESULTS")

        C_Timer.After(RESULT_TIMEOUT, function()
            if token == self.token and self.active and self.state == "WAITING_FOR_RESULTS" then
                self:Timeout("Result wait timed out.")
            end
        end)
    end)
end

function BOD.Probe:CompleteFromResults()
    if not self.active or self.state ~= "WAITING_FOR_RESULTS" then
        return
    end

    self.resultCount = BOD.AuctionAPI:GetResultCount()
    self.results = {}

    local sampleCount = math.min(self.resultCount, SAMPLE_LIMIT)
    for index = 1, sampleCount do
        local result = BOD.AuctionAPI:GetResult(index)
        if result then
            self.results[#self.results + 1] = result
        end
    end

    self:Finish("RESULTS_RECEIVED", nil)
end

function BOD.Probe:Timeout(message)
    self:Finish("TIMED_OUT", message)
end

function BOD.Probe:Fail(message)
    self:Finish("FAILED", message)
end

function BOD.Probe:Finish(state, errorMessage)
    self.active = false
    self.token = self.token + 1
    self.endedAt = time()
    self.lastError = errorMessage

    if errorMessage then
        BOD:Log(state == "TIMED_OUT" and "WARN" or "ERROR", "Probe", errorMessage)
    end

    self:SetState(state, errorMessage)
    self:PersistLatestSession()
end

function BOD.Probe:PersistLatestSession()
    if not BOD.db then
        return
    end

    local canQuery, queryDetail = BOD.AuctionAPI:CanQuery()

    BOD.db.diagnostics.latestSession = {
        schemaVersion = 1,
        searchText = self.searchText,
        startedAt = self.startedAt,
        endedAt = self.endedAt,
        state = self.state,
        error = self.lastError,
        resultCount = self.resultCount,
        sampleCount = #self.results,
        results = self.results,
        apiFamily = BOD.AuctionAPI:GetFamily(),
        canQueryAtPersist = canQuery,
        queryDetailAtPersist = queryDetail,
    }
end

function BOD.Probe:OnEvent(event)
    if event == "AUCTION_ITEM_LIST_UPDATE" then
        self:CompleteFromResults()
    elseif event == "AUCTION_HOUSE_CLOSED" and self.active then
        self:Fail("Auction House closed during probe.")
    elseif event == "UI_ERROR_MESSAGE" and self.active then
        BOD:Log("WARN", "Probe", "UI error observed during probe.")
    end
end
