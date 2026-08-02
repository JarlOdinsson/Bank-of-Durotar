local BOD = {
    db = {
        scan = {
            schemaVersion = 1,
            lastFullScanQueryAt = 1000,
            lastCompletedScanAt = 0,
            lastScanState = "READY",
        },
    },
    AuctionAPI = {
        auctionHouseOpen = true,
        canQuery = true,
        canQueryAll = false,
    },
}

local currentTime = 1600

function time()
    return currentTime
end

function BOD:InitializeDatabase()
    self.db = self.db or {}
    self.db.scan = self.db.scan or {}
end

function BOD:Log()
end

function BOD:Print()
end

function BOD:FormatTimestamp(value)
    return tostring(value)
end

function BOD.AuctionAPI:GetQueryReadiness()
    return self.canQuery, self.canQueryAll, "test"
end

function BOD.AuctionAPI:IsAuctionHouseOpen()
    return self.auctionHouseOpen
end

function BOD.AuctionAPI:CanQuery()
    return self.canQuery, "test query"
end

function BOD.AuctionAPI:CanFullScan()
    return self.canQuery and self.canQueryAll, "test full scan"
end

function BOD.AuctionAPI:GetFamily()
    return "legacy"
end

local scheduledCallbacks = {}
C_Timer = {
    After = function(_, callback)
        scheduledCallbacks[#scheduledCallbacks + 1] = callback
    end,
}

local chunk = assert(loadfile("FullScanProbe.lua"))
chunk("BankOfDurotar", BOD)

local function assertEquals(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, label)
    if not value then
        error(label .. ": expected truthy value", 2)
    end
end

local status = BOD.FullScanProbe.CalculateCooldownStatus(true, true, 1000, 1600)
assertEquals(status.state, "READY", "canQueryAll true is ready")
assertEquals(status.estimatedRemainingText, "00:00", "ready estimate")

status = BOD.FullScanProbe.CalculateCooldownStatus(true, false, 1000, 1600)
assertEquals(status.state, "COOLDOWN", "600 elapsed is cooldown")
assertEquals(status.estimatedRemainingText, "05:00", "600 elapsed estimate")

status = BOD.FullScanProbe.CalculateCooldownStatus(true, false, 1000, 1900)
assertEquals(status.state, "WAITING_FOR_SERVER", "900 elapsed waits for server")
assertEquals(status.estimatedRemainingText, "Waiting for Blizzard...", "expired estimate text")

status = BOD.FullScanProbe.CalculateCooldownStatus(true, false, 1000, 1301)
assertEquals(status.estimatedRemainingText, "09:59", "09:59 formatting")
status = BOD.FullScanProbe.CalculateCooldownStatus(true, false, 1000, 1840)
assertEquals(status.estimatedRemainingText, "01:00", "01:00 formatting")
status = BOD.FullScanProbe.CalculateCooldownStatus(true, false, 1000, 1899)
assertEquals(status.estimatedRemainingText, "00:01", "00:01 formatting")

BOD.AuctionAPI.canQuery = true
BOD.AuctionAPI.canQueryAll = false
BOD.db.scan.lastFullScanQueryAt = 1000
currentTime = 1600
status = BOD.FullScanProbe:GetCooldownStatus()
assertEquals(status.state, "COOLDOWN", "live cooldown status")
assertEquals(status.canQuery, true, "targeted query remains available")
assertEquals(BOD.FullScanProbe:CanStartFullScan(), false, "full scan disabled during cooldown")

BOD.FullScanProbe:StartCooldownPolling()
BOD.FullScanProbe:StartCooldownPolling()
assertEquals(BOD.FullScanProbe:GetActiveCooldownTickerCount(), 1, "cooldown watcher starts once")
assertEquals(BOD.FullScanProbe.cooldownPollStarts, 1, "duplicate watcher not counted")

BOD.AuctionAPI.auctionHouseOpen = false
scheduledCallbacks[1]()
assertEquals(BOD.FullScanProbe:GetActiveCooldownTickerCount(), 0, "cooldown watcher stops when AH closes")

BOD.AuctionAPI.auctionHouseOpen = true
BOD.FullScanProbe:StartCooldownPolling()
BOD.AuctionAPI.canQueryAll = true
scheduledCallbacks[#scheduledCallbacks]()
assertEquals(BOD.FullScanProbe:GetActiveCooldownTickerCount(), 0, "cooldown watcher stops when ready")
assertEquals(BOD.FullScanProbe:GetCooldownStatus().state, "READY", "canQueryAll true early is ready")

BOD.db.scan.lastFullScanQueryAt = "bad"
BOD.db.scan.lastCompletedScanAt = -10
BOD.db.scan.lastScanState = "bogus"
BOD.AuctionAPI.canQueryAll = false
currentTime = 1900
status = BOD.FullScanProbe:GetCooldownStatus()
assertEquals(status.lastFullScanQueryAt, 0, "malformed query timestamp rejected")
assertEquals(status.lastCompletedScanAt, 0, "malformed completed timestamp rejected")
assertEquals(BOD.db.scan.lastScanState, "READY", "malformed persisted state reset")

BOD.db.scan.lastFullScanQueryAt = 1000
assertTruthy(#scheduledCallbacks >= 1, "callbacks scheduled")
print("full_scan_cooldown_test.lua: PASS")
