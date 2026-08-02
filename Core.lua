local addonName, BOD = ...

BOD.addonName = addonName
BOD.version = "0.5.0-beta.1"
BOD.db = nil
BOD.lastError = nil

local DEFAULT_DB = {
    schemaVersion = 12,
    marketData = {
        schemaVersion = 3,
        latestSnapshotID = nil,
        currentSnapshot = nil,
    },
    scan = {
        schemaVersion = 1,
        lastFullScanQueryAt = 0,
        lastCompletedScanAt = 0,
        lastScanState = "READY",
    },
    history = {
        schemaVersion = 3,
        realmKey = nil,
        items = {},
        scanDays = {},
        totalScans = 0,
        latestScanId = nil,
        latestObservedAt = nil,
        lastCleanupAt = 0,
        lastCleanup = nil,
    },
    crafting = {
        schemaVersion = 1,
        professions = {},
    },
    salesHistory = {
        schemaVersion = 1,
        items = {},
        mailboxCounts = {},
    },
    trading = {
        schemaVersion = 1,
        nextTradeId = 1,
        openTrades = {},
        closedTrades = {},
        settings = {
            enabled = true,
            riskMode = "BALANCED",
            emergencyReserveCopper = 0,
            maximumCapitalPerTradeCopper = 0,
            maximumTotalCapitalCommittedCopper = 0,
            maxOpenTrades = 5,
            minimumAbsoluteProfitCopper = 5000,
            minimumDiscountPercent = 15,
            minimumDemand = "ACTIVE",
            minimumConfidence = "FAIR",
            minimumObservationCount = 5,
            showSpeculativeTrades = false,
            tradeHistoryRetention = 50,
        },
    },
    settings = {
        minimap = {
            hidden = false,
            angle = 225,
        },
        showMinimapButton = true,
        openWithAuctionHouse = true,
        dockToAuctionHouse = true,
        sidecarView = "PLAN",
        guidedMode = false,
        guidedStep = 1,
        goldBudgetCopper = 1000000,
        minimumExpectedProfitCopper = 1000,
        sidecarPosition = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
    },
}

local function copyDefaults(target, defaults)
    target = type(target) == "table" and target or {}
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = copyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function BOD:InitializeDatabase()
    BankOfDurotarDB = copyDefaults(type(BankOfDurotarDB) == "table" and BankOfDurotarDB or {}, DEFAULT_DB)
    BankOfDurotarDB.schemaVersion = 12

    -- Remove data used only by the retired developer probes.
    BankOfDurotarDB.diagnostics = nil

    local marketData = BankOfDurotarDB.marketData
    local oldMarketSchema = tonumber(marketData.schemaVersion) or 0
    marketData.schemaVersion = 3
    if oldMarketSchema ~= 3 then
        -- Alpha snapshots duplicated large records. Start clean with the compact release schema.
        marketData.currentSnapshot = nil
        marketData.latestSnapshotID = nil
    end
    if type(marketData.currentSnapshot) ~= "table" then
        marketData.currentSnapshot = nil
        marketData.latestSnapshotID = nil
    end
    marketData.currentByRealm = nil
    marketData.realmOrder = nil
    marketData.snapshots = nil
    marketData.maxSnapshots = nil

    local scan = BankOfDurotarDB.scan
    scan.schemaVersion = 1
    scan.lastFullScanQueryAt = math.max(0, tonumber(scan.lastFullScanQueryAt) or 0)
    scan.lastCompletedScanAt = math.max(0, tonumber(scan.lastCompletedScanAt) or 0)
    scan.lastScanState = type(scan.lastScanState) == "string" and scan.lastScanState or "READY"

    local history = BankOfDurotarDB.history
    local oldHistorySchema = tonumber(history.schemaVersion) or 0
    history.schemaVersion = 3
    if oldHistorySchema ~= 3 then
        history.items = {}
        history.scanDays = {}
        history.totalScans = 0
        history.realmKey = nil
        history.firstObservedAt = nil
        history.latestObservedAt = nil
        history.latestScanId = nil
    end
    history.items = type(history.items) == "table" and history.items or {}
    history.scanDays = type(history.scanDays) == "table" and history.scanDays or {}
    history.scanIds = nil
    history.lastCleanupAt = math.max(0, tonumber(history.lastCleanupAt) or 0)

    local crafting = BankOfDurotarDB.crafting
    crafting.schemaVersion = 1
    crafting.professions = type(crafting.professions) == "table" and crafting.professions or {}

    local salesHistory = BankOfDurotarDB.salesHistory
    salesHistory.schemaVersion = 1
    salesHistory.items = type(salesHistory.items) == "table" and salesHistory.items or {}
    salesHistory.mailboxCounts = type(salesHistory.mailboxCounts) == "table" and salesHistory.mailboxCounts or {}

    local trading = BankOfDurotarDB.trading
    trading.schemaVersion = 1
    trading.nextTradeId = math.max(1, math.floor(tonumber(trading.nextTradeId) or 1))
    trading.openTrades = type(trading.openTrades) == "table" and trading.openTrades or {}
    trading.closedTrades = type(trading.closedTrades) == "table" and trading.closedTrades or {}
    trading.settings = copyDefaults(type(trading.settings) == "table" and trading.settings or {}, DEFAULT_DB.trading.settings)
    local tradeSettings = trading.settings
    local validModes = { CONSERVATIVE = true, BALANCED = true, AGGRESSIVE = true }
    local validDemand = { UNKNOWN = true, SLOW = true, ACTIVE = true, HOT = true }
    local validConfidence = { SPECULATIVE = true, FAIR = true, STRONG = true }
    tradeSettings.riskMode = validModes[tostring(tradeSettings.riskMode):upper()] and tostring(tradeSettings.riskMode):upper() or "BALANCED"
    tradeSettings.minimumDemand = validDemand[tostring(tradeSettings.minimumDemand):upper()] and tostring(tradeSettings.minimumDemand):upper() or "ACTIVE"
    tradeSettings.minimumConfidence = validConfidence[tostring(tradeSettings.minimumConfidence):upper()] and tostring(tradeSettings.minimumConfidence):upper() or "FAIR"
    tradeSettings.enabled = tradeSettings.enabled ~= false
    tradeSettings.showSpeculativeTrades = tradeSettings.showSpeculativeTrades == true
    for _, key in ipairs({ "emergencyReserveCopper", "maximumCapitalPerTradeCopper", "maximumTotalCapitalCommittedCopper", "minimumAbsoluteProfitCopper" }) do
        tradeSettings[key] = math.max(0, math.min(2147483647, math.floor(tonumber(tradeSettings[key]) or 0)))
    end
    tradeSettings.maxOpenTrades = math.max(1, math.min(5, math.floor(tonumber(tradeSettings.maxOpenTrades) or 5)))
    tradeSettings.minimumDiscountPercent = math.max(0, math.min(90, math.floor(tonumber(tradeSettings.minimumDiscountPercent) or 15)))
    tradeSettings.minimumObservationCount = math.max(1, math.min(30, math.floor(tonumber(tradeSettings.minimumObservationCount) or 5)))
    tradeSettings.tradeHistoryRetention = math.max(1, math.min(500, math.floor(tonumber(tradeSettings.tradeHistoryRetention) or 50)))

    local settings = BankOfDurotarDB.settings
    settings.sidecarPosition = type(settings.sidecarPosition) == "table" and settings.sidecarPosition or copyDefaults({}, DEFAULT_DB.settings.sidecarPosition)
    if BOD.PlanMoney then
        -- These fields have always been stored as copper, even when the old UI displayed only gold or silver.
        settings.goldBudgetCopper = BOD.PlanMoney:MigrateStoredCopper(settings.goldBudgetCopper, 1000000)
        settings.minimumExpectedProfitCopper = BOD.PlanMoney:MigrateStoredCopper(settings.minimumExpectedProfitCopper, 1000)
    else
        settings.goldBudgetCopper = math.max(0, math.min(2147483647, math.floor(tonumber(settings.goldBudgetCopper) or 1000000)))
        settings.minimumExpectedProfitCopper = math.max(0, math.min(2147483647, math.floor(tonumber(settings.minimumExpectedProfitCopper) or 1000)))
    end
    settings.searchText = nil
    settings.lastSearchText = nil
    settings.selectedSort = nil
    settings.filters = nil
    settings.sidecarCollapsed = nil
    settings.opportunityMinimumConfidence = nil
    settings.opportunityMinimumUpsideText = nil
    settings.opportunityIncludeLowSample = nil

    self.db = BankOfDurotarDB
end

function BOD:FormatTimestamp(timestamp)
    return date("%Y-%m-%d %H:%M:%S", tonumber(timestamp) or time())
end

function BOD:FormatMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    return string.format("%dg %02ds %02dc", math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100)
end

function BOD:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd18b00Bank of Durotar|r: " .. tostring(message))
end

function BOD:Log(level, source, message)
    if level == "ERROR" then
        self.lastError = tostring(message or "")
        self:Print(tostring(source or "Error") .. ": " .. self.lastError)
    end
end

function BOD:Debug()
end

function BOD:SetError(source, message)
    self:Log("ERROR", source, message)
end

function BOD:SafeCall(source, fn, ...)
    if type(fn) ~= "function" then
        return false, "missing function"
    end
    local results = { pcall(fn, ...) }
    local ok = table.remove(results, 1)
    if not ok then
        self:SetError(source, results[1])
        return false, results[1]
    end
    return true, unpack(results)
end

function BOD:RefreshOwnedUI()
    if self.Sidecar then
        self.Sidecar:EnsureCreated()
        self.Sidecar:ApplyLayout()
        self.Sidecar:Refresh()
    end
    if self.MinimapButton then
        self.MinimapButton:ApplySettings()
    end
end

function BOD:HandleSlashCommand(input)
    local command = trim(input):lower()
    if command == "" or command == "show" or command == "market" then
        self.Sidecar:Show()
        self.Sidecar:SetView("PLAN")
    elseif command == "hide" then
        self.Sidecar:Hide()
    elseif command == "scan" then
        self.Sidecar:Show()
        self.FullScanProbe:StartFromPlayerClick()
    elseif command == "buy" or command == "opportunities" then
        self.Sidecar:Show()
        self.Sidecar:SetView("PLAN")
    elseif command == "trades" or command == "trade" then
        self.Sidecar:Show()
        self.Sidecar:SetView("TRADES")
    elseif command == "sell" or command == "sellprice" then
        self.Sidecar:Show()
        self.Sidecar:SetView("SELL")
    elseif command == "craft" or command == "crafting" then
        self.Sidecar:Show()
        self.Sidecar:SetView("CRAFT")
    elseif command == "minimap show" then
        self.MinimapButton:SetShown(true)
    elseif command == "minimap hide" then
        self.MinimapButton:SetShown(false)
    elseif command == "minimap reset" then
        self.MinimapButton:ResetPosition()
    elseif command == "help" then
        self:Print("/bod - open | /bod scan | /bod buy | /bod trades | /bod sell | /bod craft")
        self:Print("/bod minimap show|hide|reset")
    else
        self:Print("Unknown command. Use /bod help.")
    end
end

local eventFrame = CreateFrame("Frame")
BOD.eventFrame = eventFrame

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... ~= addonName then
        return
    end
    if event == "ADDON_LOADED" then
        BOD:InitializeDatabase()
    end
    if BOD.AuctionAPI then BOD.AuctionAPI:OnEvent(event, ...) end
    if BOD.MinimapButton then BOD.MinimapButton:OnEvent(event, ...) end
    if BOD.CraftingService then BOD.CraftingService:OnEvent(event, ...) end
    if BOD.SalesHistory then BOD.SalesHistory:OnEvent(event, ...) end
    if BOD.Sidecar then BOD.Sidecar:OnEvent(event, ...) end
    if BOD.FullScanProbe then BOD.FullScanProbe:OnEvent(event, ...) end
end)

for _, eventName in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED",
    "AUCTION_ITEM_LIST_UPDATE",
    "BAG_UPDATE_DELAYED",
    "PLAYER_MONEY",
    "GET_ITEM_INFO_RECEIVED",
    "TRADE_SKILL_SHOW",
    "TRADE_SKILL_UPDATE",
    "MAIL_SHOW",
    "MAIL_INBOX_UPDATE",
}) do
    eventFrame:RegisterEvent(eventName)
end

SLASH_BANKOFDUROTAR1 = "/bod"
SlashCmdList.BANKOFDUROTAR = function(input)
    if not BOD.db then BOD:InitializeDatabase() end
    BOD:HandleSlashCommand(input)
end
