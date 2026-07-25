local addonName, BOD = ...

BOD.SearchController = {
    state = "IDLE",
    token = 0,
    active = false,
    searchText = "",
    startedAt = nil,
    endedAt = nil,
    lastQueryTime = nil,
    lastError = nil,
    resultCount = 0,
    rawResults = {},
    visibleResults = {},
    selectedResult = nil,
}

local QUERY_PERMISSION_TIMEOUT = 10
local RESULT_TIMEOUT = 15
local QUERY_PERMISSION_INTERVAL = 0.5

local TERMINAL_STATES = {
    RESULTS_RECEIVED = true,
    EMPTY_RESULTS = true,
    TIMED_OUT = true,
    FAILED = true,
    CANCELLED = true,
}

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function BOD.SearchController:GetState()
    return self.state or "IDLE"
end

function BOD.SearchController:IsTerminal()
    return TERMINAL_STATES[self:GetState()] == true
end

function BOD.SearchController:SetState(state, detail)
    local previousState = self.state
    self.state = state
    if previousState ~= state or detail then
        BOD:Log("INFO", "Search", "State changed to " .. state .. (detail and (": " .. detail) or "."))
    end
    if BOD.Sidecar then
        BOD.Sidecar:Refresh()
    end
end

function BOD.SearchController:ResetForStart(searchText)
    self.token = self.token + 1
    self.active = true
    self.searchText = searchText
    self.startedAt = time()
    self.endedAt = nil
    self.lastError = nil
    self.resultCount = 0
    self.rawResults = {}
    self.visibleResults = {}
    self.selectedResult = nil
end

function BOD.SearchController:StartSearch(searchText)
    searchText = trim(searchText)
    if searchText == "" then
        self:Fail("Enter an item name before searching.")
        return false
    end

    if self.active then
        BOD:Log("WARN", "Search", "Search already active; repeated click ignored.")
        return false
    end

    if BOD.db and BOD.db.settings then
        BOD.db.settings.lastSearchText = searchText
    end

    self:ResetForStart(searchText)

    if not BOD.AuctionAPI:IsAuctionHouseOpen() then
        self:SetState("WAITING_FOR_AH", "Auction House is not open")
        self:Fail("Open the Auction House before searching.")
        return false
    end

    if BOD.AuctionAPI:GetFamily() ~= "legacy" then
        self:Fail("Legacy Auction House API is required for this milestone.")
        return false
    end

    if not C_Timer or type(C_Timer.After) ~= "function" then
        self:Fail("C_Timer.After is unavailable; cannot run bounded search.")
        return false
    end

    BOD:Log("INFO", "Search", "Starting one targeted search for '" .. searchText .. "'.")
    self:WaitForQueryPermission(self.token, time())
    return true
end

function BOD.SearchController:WaitForQueryPermission(token, startedWaitingAt)
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

function BOD.SearchController:SendQuery(token)
    if token ~= self.token or not self.active then
        return
    end

    self:SetState("QUERY_SENT")
    local ok, detail = BOD.AuctionAPI:SendTargetedSearch(self.searchText)
    if not ok then
        self:Fail("Search failed: " .. tostring(detail))
        return
    end

    self.lastQueryTime = time()
    BOD:Log("INFO", "Search", detail)

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

function BOD.SearchController:CompleteFromResults()
    if not self.active or self.state ~= "WAITING_FOR_RESULTS" then
        return
    end

    self.resultCount = BOD.AuctionAPI:GetResultCount()
    self.rawResults = {}
    self.visibleResults = {}
    self.selectedResult = nil

    for index = 1, self.resultCount do
        local result = BOD.AuctionAPI:GetResult(index)
        if result then
            self.rawResults[#self.rawResults + 1] = result
        end
    end

    self:RefreshVisibleResults()

    if self.resultCount == 0 then
        self:Finish("EMPTY_RESULTS")
    else
        self:Finish("RESULTS_RECEIVED")
    end
end

function BOD.SearchController:RefreshVisibleResults()
    local settings = BOD.db and BOD.db.settings or {}
    local filters = settings.filters or {}
    local sortKey = settings.selectedSort or "unitBuyout"
    self.visibleResults = BOD.SearchResults:ApplyFiltersAndSort(self.rawResults, filters, sortKey)
end

function BOD.SearchController:SelectResult(result)
    self.selectedResult = result
    if BOD.Sidecar then
        BOD.Sidecar:RefreshResultRows()
        BOD.Sidecar:RefreshSelection()
    end
end

function BOD.SearchController:Timeout(message)
    self:Finish("TIMED_OUT", message)
end

function BOD.SearchController:Fail(message)
    self:Finish("FAILED", message)
end

function BOD.SearchController:Cancel(message)
    if self.active then
        self:Finish("CANCELLED", message or "Search cancelled.")
    end
end

function BOD.SearchController:Finish(state, errorMessage)
    self.active = false
    self.token = self.token + 1
    self.endedAt = time()
    self.lastError = errorMessage

    if errorMessage then
        BOD:Log(state == "TIMED_OUT" and "WARN" or "ERROR", "Search", errorMessage)
    end

    self:SetState(state, errorMessage)
end

function BOD.SearchController:OnEvent(event)
    if event == "AUCTION_ITEM_LIST_UPDATE" then
        self:CompleteFromResults()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        self:Cancel("Auction House closed during search.")
    end
end
