local addonName, BOD = ...

BOD.FullScanProbe = {
    state = "IDLE",
    token = 0,
    active = false,
    startedAt = nil,
    endedAt = nil,
    lastError = nil,
    querySignature = nil,
    resultCount = 0,
    uniqueItemCount = 0,
    resultEvents = 0,
    lastResultEventAt = nil,
    completionCondition = nil,
    marketSnapshotID = nil,
    cooldownPollActive = false,
    cooldownPollToken = 0,
    cooldownPollStarts = 0,
    cooldownPollTicks = 0,
}

local QUERY_PERMISSION_TIMEOUT = 20
local QUERY_PERMISSION_INTERVAL = 0.5
local RESULT_TIMEOUT = 120
local QUIET_WINDOW_SECONDS = 2
local PROCESS_CHUNK_SIZE = 500
local FULL_SCAN_COOLDOWN_ESTIMATE_SECONDS = 900
local COOLDOWN_POLL_INTERVAL_SECONDS = 1

local TERMINAL_STATES = {
    COMPLETED = true,
    FAILED = true,
    CANCELLED = true,
    TIMED_OUT = true,
}

local AVAILABILITY_STATES = {
    READY = true,
    SCANNING = true,
    PROCESSING = true,
    COOLDOWN = true,
    WAITING_FOR_SERVER = true,
    FAILED = true,
    CANCELLED = true,
}

local function countKeys(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    local secondsOnly = seconds % 60
    return string.format("%02d:%02d", minutes, secondsOnly)
end

local function normalizeTimestamp(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number == math.huge then
        return 0
    end
    return math.floor(number)
end

local function getScanDB()
    if not BOD.db then
        BOD:InitializeDatabase()
    end
    BOD.db.scan = BOD.db.scan or {}
    BOD.db.scan.schemaVersion = 1
    BOD.db.scan.lastFullScanQueryAt = normalizeTimestamp(BOD.db.scan.lastFullScanQueryAt)
    BOD.db.scan.lastCompletedScanAt = normalizeTimestamp(BOD.db.scan.lastCompletedScanAt)
    if not AVAILABILITY_STATES[BOD.db.scan.lastScanState] then
        BOD.db.scan.lastScanState = "READY"
    end
    return BOD.db.scan
end

function BOD.FullScanProbe.CalculateCooldownStatus(canQuery, canQueryAll, lastQueryAt, nowValue)
    local currentTime = normalizeTimestamp(nowValue)
    local queryAt = normalizeTimestamp(lastQueryAt)
    local elapsed = queryAt > 0 and math.max(0, currentTime - queryAt) or FULL_SCAN_COOLDOWN_ESTIMATE_SECONDS
    local estimatedRemaining = math.max(0, FULL_SCAN_COOLDOWN_ESTIMATE_SECONDS - elapsed)

    if canQueryAll == true then
        return {
            state = "READY",
            canQuery = canQuery and true or false,
            canQueryAll = true,
            estimatedRemaining = 0,
            estimatedRemainingText = "00:00",
            waitingForServer = false,
        }
    end

    if estimatedRemaining > 0 then
        return {
            state = "COOLDOWN",
            canQuery = canQuery and true or false,
            canQueryAll = false,
            estimatedRemaining = estimatedRemaining,
            estimatedRemainingText = formatDuration(estimatedRemaining),
            waitingForServer = false,
        }
    end

    return {
        state = "WAITING_FOR_SERVER",
        canQuery = canQuery and true or false,
        canQueryAll = false,
        estimatedRemaining = 0,
        estimatedRemainingText = "Waiting for Blizzard...",
        waitingForServer = true,
    }
end

function BOD.FullScanProbe:GetCooldownStatus()
    if self.active and (self.state == "PROCESSING_RESULTS" or self.state == "PROCESSING") then
        return {
            state = "PROCESSING",
            canQuery = false,
            canQueryAll = false,
            estimatedRemaining = 0,
            estimatedRemainingText = "00:00",
            waitingForServer = false,
        }
    elseif self.active then
        return {
            state = "SCANNING",
            canQuery = false,
            canQueryAll = false,
            estimatedRemaining = 0,
            estimatedRemainingText = "00:00",
            waitingForServer = false,
        }
    end

    local scanDB = getScanDB()
    local canQuery, canQueryAll, detail = BOD.AuctionAPI:GetQueryReadiness()
    local status = self.CalculateCooldownStatus(canQuery, canQueryAll, scanDB.lastFullScanQueryAt, time())
    status.detail = detail
    status.lastFullScanQueryAt = scanDB.lastFullScanQueryAt
    status.lastCompletedScanAt = scanDB.lastCompletedScanAt
    status.cooldownPollActive = self.cooldownPollActive and true or false
    status.cooldownPollStarts = self.cooldownPollStarts or 0
    status.cooldownPollTicks = self.cooldownPollTicks or 0
    return status
end

function BOD.FullScanProbe:GetCooldownStatusLines()
    local status = self:GetCooldownStatus()
    local lines = {}
    if status.state == "READY" then
        lines[#lines + 1] = "Full scan ready"
        if status.lastCompletedScanAt and status.lastCompletedScanAt > 0 then
            lines[#lines + 1] = "Last completed: " .. tostring(BOD:FormatTimestamp(status.lastCompletedScanAt))
        end
    elseif status.state == "COOLDOWN" then
        lines[#lines + 1] = "Full scan unavailable"
        lines[#lines + 1] = "Estimated remaining: " .. tostring(status.estimatedRemainingText)
        if status.lastFullScanQueryAt and status.lastFullScanQueryAt > 0 then
            lines[#lines + 1] = "Last scan: " .. tostring(BOD:FormatTimestamp(status.lastFullScanQueryAt))
        end
        lines[#lines + 1] = "Waiting for Blizzard availability"
    elseif status.state == "WAITING_FOR_SERVER" then
        lines[#lines + 1] = "Full scan unavailable"
        lines[#lines + 1] = "Estimated timer elapsed"
        lines[#lines + 1] = "Waiting for Blizzard..."
        lines[#lines + 1] = "The button will unlock when the server allows another full scan."
    elseif status.state == "PROCESSING" then
        lines[#lines + 1] = "Processing results"
        lines[#lines + 1] = self:GetProgressLine()
    elseif status.state == "SCANNING" then
        lines[#lines + 1] = "Scanning"
        lines[#lines + 1] = self:GetProgressLine()
    else
        lines[#lines + 1] = tostring(status.state)
    end
    return lines, status
end

function BOD.FullScanProbe:GetPrimaryButtonText()
    if self.active then
        return "CANCEL SCAN"
    end
    local status = self:GetCooldownStatus()
    return status.state == "READY" and "SCAN MARKET" or "FULL SCAN COOLDOWN"
end

function BOD.FullScanProbe:CanStartFullScan()
    local status = self:GetCooldownStatus()
    return status.state == "READY" and status.canQueryAll == true
end

function BOD.FullScanProbe:RecordQuerySent()
    local scanDB = getScanDB()
    scanDB.lastFullScanQueryAt = time()
    scanDB.lastScanState = "SCANNING"
end

function BOD.FullScanProbe:RefreshAvailability()
    if not BOD.AuctionAPI:IsAuctionHouseOpen() then
        self:StopCooldownPolling()
        return self:GetCooldownStatus()
    end

    local status = self:GetCooldownStatus()
    getScanDB().lastScanState = status.state
    if status.state == "READY" then
        self:StopCooldownPolling()
    elseif not self.active then
        self:StartCooldownPolling()
    end

    if BOD.Sidecar and BOD.Sidecar.frame and BOD.Sidecar.frame:IsShown() then
        BOD.Sidecar:Refresh()
    end
    return status
end

function BOD.FullScanProbe:StartCooldownPolling()
    if self.cooldownPollActive then
        return
    end
    if not C_Timer or type(C_Timer.After) ~= "function" or not BOD.AuctionAPI:IsAuctionHouseOpen() then
        return
    end

    self.cooldownPollActive = true
    self.cooldownPollToken = (self.cooldownPollToken or 0) + 1
    self.cooldownPollStarts = (self.cooldownPollStarts or 0) + 1
    local token = self.cooldownPollToken

    local function tick()
        if token ~= self.cooldownPollToken or not self.cooldownPollActive then
            return
        end
        if not BOD.AuctionAPI:IsAuctionHouseOpen() then
            self:StopCooldownPolling()
            return
        end
        self.cooldownPollTicks = (self.cooldownPollTicks or 0) + 1
        local status = self:GetCooldownStatus()
        if BOD.Sidecar and BOD.Sidecar.frame and BOD.Sidecar.frame:IsShown() then
            BOD.Sidecar:Refresh()
        end
        if status.state == "READY" then
            self:StopCooldownPolling()
            return
        end
        C_Timer.After(COOLDOWN_POLL_INTERVAL_SECONDS, tick)
    end

    C_Timer.After(COOLDOWN_POLL_INTERVAL_SECONDS, tick)
end

function BOD.FullScanProbe:StopCooldownPolling()
    if not self.cooldownPollActive then
        return
    end
    self.cooldownPollActive = false
    self.cooldownPollToken = (self.cooldownPollToken or 0) + 1
end

function BOD.FullScanProbe:GetActiveCooldownTickerCount()
    return self.cooldownPollActive and 1 or 0
end

function BOD.FullScanProbe:GetState()
    return self.state or "IDLE"
end

function BOD.FullScanProbe:IsTerminal()
    return TERMINAL_STATES[self:GetState()] == true
end

function BOD.FullScanProbe:SetState(state, detail)
    local previousState = self.state
    self.state = state
    if previousState ~= state or detail then
        BOD:Log("INFO", "FullScan", "State changed to " .. state .. (detail and (": " .. detail) or "."))
    end
    if BOD.Sidecar then
        BOD.Sidecar:Refresh()
    end
end

function BOD.FullScanProbe:ResetForStart()
    self.token = self.token + 1
    self.active = true
    self.startedAt = time()
    self.endedAt = nil
    self.lastError = nil
    self.querySignature = nil
    self.queryAccepted = false
    self.resultCount = 0
    self.uniqueItemCount = 0
    self.resultEvents = 0
    self.processedRecords = 0
    self.lastResultEventAt = nil
    self.completionCondition = nil
    self.marketSnapshotID = nil
end

function BOD.FullScanProbe:StartFromPlayerClick()
    if self.active then
        self:Cancel("Scan probe cancelled by player.")
        return false
    end

    if not BOD.AuctionAPI:IsAuctionHouseOpen() then
        self:SetState("FAILED", "Open the Auction House before running the full-scan probe.")
        return false
    end

    if BOD.AuctionAPI:GetFamily() ~= "legacy" then
        self:SetState("FAILED", "Legacy Auction House API is required for the full-scan probe.")
        return false
    end

    if not C_Timer or type(C_Timer.After) ~= "function" then
        self:SetState("FAILED", "C_Timer.After is unavailable; cannot run bounded full-scan probe.")
        return false
    end

    if not self:CanStartFullScan() then
        local status = self:RefreshAvailability()
        self:SetState(status.state, "Full scan unavailable; " .. tostring(status.detail or "waiting for Blizzard availability"))
        return false
    end

    self:ResetForStart()
    BOD:Log("INFO", "FullScan", "Starting one player-initiated full-market scan probe.")
    self:WaitForQueryPermission(self.token, time())
    return true
end

function BOD.FullScanProbe:WaitForQueryPermission(token, startedWaitingAt)
    if token ~= self.token or not self.active then
        return
    end

    self:SetState("WAITING_FOR_QUERY_PERMISSION")
    local canScan, detail = BOD.AuctionAPI:CanFullScan()
    if canScan then
        self:SendQuery(token)
        return
    end

    if time() - startedWaitingAt >= QUERY_PERMISSION_TIMEOUT then
        self:Timeout("Full-scan query permission timed out: " .. tostring(detail))
        return
    end

    C_Timer.After(QUERY_PERMISSION_INTERVAL, function()
        self:WaitForQueryPermission(token, startedWaitingAt)
    end)
end

function BOD.FullScanProbe:SendQuery(token)
    if token ~= self.token or not self.active then
        return
    end

    -- Listen before sending: the client may deliver AUCTION_ITEM_LIST_UPDATE
    -- synchronously, and a zero-delay timer is not guaranteed to run first.
    self:SetState("WAITING_FOR_RESULTS")
    local ok, detail, signature = BOD.AuctionAPI:SendFullScanProbe()
    self.querySignature = signature
    if not ok then
        self.queryAccepted = false
        self:Fail("Full-scan probe query failed: " .. tostring(detail))
        return
    end

    self.queryAccepted = true
    self:RecordQuerySent()
    BOD:Log("INFO", "FullScan", detail)
    C_Timer.After(RESULT_TIMEOUT, function()
        if token == self.token and self.active and self.state == "WAITING_FOR_RESULTS" then
            self:Timeout("Full-scan result wait timed out.")
        end
    end)
end

function BOD.FullScanProbe:ScheduleQuietCompletion(token, eventTime)
    C_Timer.After(QUIET_WINDOW_SECONDS, function()
        if token ~= self.token or not self.active or self.state ~= "WAITING_FOR_RESULTS" then
            return
        end
        if self.lastResultEventAt ~= eventTime then
            return
        end
        self.completionCondition = "No AUCTION_ITEM_LIST_UPDATE for " .. tostring(QUIET_WINDOW_SECONDS) .. " seconds after latest result event."
        self:CompleteFromResults()
    end)
end

function BOD.FullScanProbe:CompleteFromResults()
    if not self.active or self.state ~= "WAITING_FOR_RESULTS" then
        return
    end

    self:SetState("PROCESSING_RESULTS")
    self.resultCount = BOD.AuctionAPI:GetResultCount()
    self.uniqueItemCount = 0
    self.processedRecords = 0
    self.processingIndex = 1
    self.processingUniqueItems = {}
    self.pendingResultIndexes = {}
    if BOD.MarketData then
        BOD.MarketData:StartSnapshot({
            querySignature = self.querySignature,
            startedAt = self.startedAt,
            completionCondition = self.completionCondition,
        })
    end
    self:ProcessResultChunk(self.token)
end

function BOD.FullScanProbe:ProcessResultChunk(token)
    if token ~= self.token or not self.active or self.state ~= "PROCESSING_RESULTS" then
        return
    end

    local lastIndex = math.min(self.resultCount, (self.processingIndex or 1) + PROCESS_CHUNK_SIZE - 1)
    for index = self.processingIndex or 1, lastIndex do
        local result = BOD.AuctionAPI:GetResult(index)
        if result then
            local identityReady = result.itemLink or (tonumber(result.maxStack) and tonumber(result.maxStack) > 1)
            if BOD.MarketData and identityReady then
                BOD.MarketData:ObserveListing(result)
            elseif not identityReady then
                self.pendingResultIndexes[#self.pendingResultIndexes + 1] = index
            end
            local key = tostring(result.itemID or result.itemLink or result.name or "unknown")
            self.processingUniqueItems[key] = true
        end
    end

    self.processedRecords = lastIndex
    self.uniqueItemCount = countKeys(self.processingUniqueItems)
    if BOD.Sidecar then
        BOD.Sidecar:Refresh()
    end

    if lastIndex < self.resultCount then
        self.processingIndex = lastIndex + 1
        C_Timer.After(0, function()
            self:ProcessResultChunk(token)
        end)
        return
    end

    self.processingIndex = nil
    self.processingUniqueItems = nil
    if #self.pendingResultIndexes > 0 then
        C_Timer.After(1, function() self:ResolvePendingResults(token) end)
    else
        self.pendingResultIndexes = nil
        self:Finish("COMPLETED")
    end
end

function BOD.FullScanProbe:ResolvePendingResults(token)
    if token ~= self.token or not self.active or self.state ~= "PROCESSING_RESULTS" then return end
    for _, index in ipairs(self.pendingResultIndexes or {}) do
        local result = BOD.AuctionAPI:GetResult(index)
        if result and BOD.MarketData then BOD.MarketData:ObserveListing(result) end
    end
    self.pendingResultIndexes = nil
    self:Finish("COMPLETED")
end

function BOD.FullScanProbe:Cancel(message)
    if self.active then
        self:Finish("CANCELLED", message or "Full-scan probe cancelled.")
    end
end

function BOD.FullScanProbe:Timeout(message)
    self:Finish("TIMED_OUT", message)
end

function BOD.FullScanProbe:Fail(message)
    self:Finish("FAILED", message)
end

function BOD.FullScanProbe:Finish(state, errorMessage)
    self.active = false
    self.token = self.token + 1
    self.endedAt = time()
    self.lastError = errorMessage
    local scanDB = getScanDB()
    scanDB.lastScanState = state
    if state == "COMPLETED" and BOD.MarketData then
        scanDB.lastCompletedScanAt = self.endedAt
        local snapshot = BOD.MarketData:FinalizeSnapshot(self:GetScanSummary(state))
        self.marketSnapshotID = snapshot and snapshot.id or nil
        if snapshot and BOD.MarketHistory and BOD.MarketHistory.RecordSnapshot then
            BOD.MarketHistory:RecordSnapshot(snapshot)
        end
        if snapshot and BOD.TradeService then
            BOD.TradeService:Invalidate()
            BOD.TradeService:Build()
        end
    elseif BOD.MarketData then
        BOD.MarketData:AbortSnapshot(errorMessage or state)
    end
    if errorMessage then
        BOD:Log(state == "TIMED_OUT" and "WARN" or "ERROR", "FullScan", errorMessage)
    end
    self:SetState(state, errorMessage)
    self:RefreshAvailability()
    if BOD.RefreshOwnedUI then
        BOD:RefreshOwnedUI()
    end
    if state == "COMPLETED"
        and self.marketSnapshotID
        and BOD.Sidecar
        and BOD.Sidecar.frame
        and BOD.Sidecar.frame:IsShown()
    then
        BOD.Sidecar:SetView("PLAN")
    end
end

function BOD.FullScanProbe:GetElapsedSeconds()
    local startedAt = tonumber(self.startedAt)
    if not startedAt then
        return 0
    end
    return (tonumber(self.endedAt) or time()) - startedAt
end

function BOD.FullScanProbe:GetScanSummary(state)
    return {
        state = state or self.state,
        startedAt = self.startedAt,
        endedAt = self.endedAt,
        elapsedSeconds = self:GetElapsedSeconds(),
        querySignature = self.querySignature,
        queryAccepted = self.queryAccepted,
        completionCondition = self.completionCondition,
        processedRecords = self.processedRecords,
        resultCount = self.resultCount,
        uniqueItemCount = self.uniqueItemCount,
    }
end

function BOD.FullScanProbe:GetProgressLine()
    local lifecycleState = self:GetState()
    local cooldownStatus = self:GetCooldownStatus()
    local state = cooldownStatus.state
    if lifecycleState == "WAITING_FOR_RESULTS" then
        return "Events: " .. tostring(self.resultEvents or 0)
    elseif lifecycleState == "PROCESSING_RESULTS" then
        return "Processed: " .. tostring(self.processedRecords or 0) .. " / " .. tostring(self.resultCount or "unknown")
    elseif lifecycleState == "COMPLETED" then
        return "Auctions: " .. tostring(self.processedRecords or 0) .. ", Items: " .. tostring(self.uniqueItemCount or 0)
    elseif lifecycleState == "FAILED" or lifecycleState == "TIMED_OUT" then
        return tostring(self.lastError or "Scan failed")
    elseif lifecycleState == "CANCELLED" then
        return "Cancelled"
    elseif state == "COOLDOWN" then
        return "Estimated remaining: " .. tostring(cooldownStatus.estimatedRemainingText)
    elseif state == "WAITING_FOR_SERVER" then
        return "Waiting for Blizzard..."
    end
    return "Click Scan Market"
end

function BOD.FullScanProbe:OnEvent(event)
    if event == "AUCTION_ITEM_LIST_UPDATE" and self.active and self.state == "WAITING_FOR_RESULTS" then
        self.resultEvents = self.resultEvents + 1
        self.lastResultEventAt = time()
        self:ScheduleQuietCompletion(self.token, self.lastResultEventAt)
        if BOD.Sidecar then
            BOD.Sidecar:Refresh()
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        self:Cancel("Auction House closed during full-scan probe.")
        self:StopCooldownPolling()
    elseif event == "AUCTION_HOUSE_SHOW" then
        self:RefreshAvailability()
    end
end
