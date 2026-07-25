local addonName, BOD = ...

BOD.addonName = addonName
BOD.version = "0.1.0-alpha.2"
BOD.db = nil
BOD.events = {}
BOD.maxLogEntries = 100
BOD.maxEvents = 100
BOD.clearRequestedAt = nil

local DEFAULT_DB = {
    schemaVersion = 3,
    diagnostics = {
        logs = {},
        events = {},
        latestSession = nil,
        transactionProbe = {
            latestReport = nil,
            lastProtectedAttempt = nil,
            lastTerminalFailure = nil,
        },
    },
    settings = {
        debug = false,
        redactIdentity = false,
        searchText = "Netherweave Cloth",
        window = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
        minimap = {
            hidden = false,
            angle = 225,
        },
        openWithAuctionHouse = true,
        showMinimapButton = true,
        dockToAuctionHouse = true,
        sidecarWidth = 390,
        sidecarCollapsed = false,
        sidecarPosition = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
        lastSearchText = "Netherweave Cloth",
        selectedSort = "unitBuyout",
        filters = {
            buyoutOnly = false,
            minStackSize = 0,
            maxUnitPrice = nil,
        },
    },
}

local function copyDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end

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
    if type(BankOfDurotarDB) ~= "table" then
        BankOfDurotarDB = {}
    end

    local previousSchemaVersion = tonumber(BankOfDurotarDB.schemaVersion) or 0
    BankOfDurotarDB = copyDefaults(BankOfDurotarDB, DEFAULT_DB)
    BankOfDurotarDB.schemaVersion = 3

    if type(BankOfDurotarDB.diagnostics.logs) ~= "table" then
        BankOfDurotarDB.diagnostics.logs = {}
    end
    if type(BankOfDurotarDB.diagnostics.events) ~= "table" then
        BankOfDurotarDB.diagnostics.events = {}
    end
    if type(BankOfDurotarDB.diagnostics.transactionProbe) ~= "table" then
        BankOfDurotarDB.diagnostics.transactionProbe = copyDefaults({}, DEFAULT_DB.diagnostics.transactionProbe)
    end

    while #BankOfDurotarDB.diagnostics.logs > self.maxLogEntries do
        table.remove(BankOfDurotarDB.diagnostics.logs, 1)
    end
    while #BankOfDurotarDB.diagnostics.events > self.maxEvents do
        table.remove(BankOfDurotarDB.diagnostics.events, 1)
    end

    if previousSchemaVersion < 2 then
        if BankOfDurotarDB.settings.minimap and BankOfDurotarDB.settings.minimap.hidden ~= nil then
            BankOfDurotarDB.settings.showMinimapButton = not BankOfDurotarDB.settings.minimap.hidden
        end
    end

    BankOfDurotarDB.settings.sidecarWidth = math.max(360, math.min(420, tonumber(BankOfDurotarDB.settings.sidecarWidth) or 390))
    if type(BankOfDurotarDB.settings.filters) ~= "table" then
        BankOfDurotarDB.settings.filters = copyDefaults({}, DEFAULT_DB.settings.filters)
    end
    if type(BankOfDurotarDB.settings.sidecarPosition) ~= "table" then
        BankOfDurotarDB.settings.sidecarPosition = copyDefaults({}, DEFAULT_DB.settings.sidecarPosition)
    end

    self.db = BankOfDurotarDB
end

function BOD:FormatTimestamp(timestamp)
    timestamp = tonumber(timestamp) or time()
    return date("%Y-%m-%d %H:%M:%S", timestamp)
end

function BOD:FormatMoney(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100
    return string.format("%dg %02ds %02dc", gold, silver, copperOnly)
end

function BOD:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd18b00Bank of Durotar|r: " .. tostring(message))
end

function BOD:Log(level, source, message)
    if not self.db then
        return
    end

    level = level or "INFO"
    source = source or "Core"
    message = tostring(message or "")

    local entry = {
        timestamp = time(),
        level = level,
        source = source,
        message = message,
    }

    local logs = self.db.diagnostics.logs
    logs[#logs + 1] = entry
    while #logs > self.maxLogEntries do
        table.remove(logs, 1)
    end

    if level == "ERROR" or (self.db.settings.debug and level ~= "DEBUG") then
        self:Print(string.format("[%s] %s: %s", level, source, message))
    elseif self.db.settings.debug and level == "DEBUG" then
        self:Print(string.format("[DEBUG] %s: %s", source, message))
    end

    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

function BOD:Debug(source, message)
    self:Log("DEBUG", source, message)
end

function BOD:SetError(source, message)
    if self.Probe then
        self.Probe.lastError = tostring(message or "")
    end
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

function BOD:GetSearchText()
    local text = self.db and self.db.settings and self.db.settings.searchText
    text = trim(text)
    if text == "" then
        text = "Netherweave Cloth"
    end
    return text
end

function BOD:SetSearchText(text)
    if self.db and self.db.settings then
        self.db.settings.searchText = trim(text)
    end
end

function BOD:ClearDiagnostics()
    if not self.db then
        return
    end
    self.db.diagnostics.logs = {}
    self.db.diagnostics.events = {}
    self.db.diagnostics.latestSession = nil
    self.db.diagnostics.transactionProbe = copyDefaults({}, DEFAULT_DB.diagnostics.transactionProbe)
    self.clearRequestedAt = nil
    self:Log("INFO", "Core", "Diagnostic results cleared.")
end

function BOD:HandleSlashCommand(input)
    local command = trim(input):lower()

    if command == "" then
        self.UI:Toggle()
    elseif command == "help" then
        self:Print("/bod - toggle diagnostics")
        self:Print("/bod show - show diagnostics")
        self:Print("/bod hide - hide diagnostics")
        self:Print("/bod probe - run one targeted AH probe")
        self:Print("/bod status - print current probe status")
        self:Print("/bod debug - toggle debug logging")
        self:Print("/bod clear - run twice within 10 seconds to clear diagnostics")
        self:Print("/bod minimap - toggle minimap button")
        self:Print("/bod minimap show|hide|reset - manage minimap button")
        self:Print("/bod market - show player-facing Auction House sidecar")
        self:Print("/bod txprobe - open developer transaction probe")
    elseif command == "show" then
        self.UI:Show()
    elseif command == "hide" then
        self.UI:Hide()
    elseif command == "probe" then
        self.Probe:Start(self:GetSearchText())
    elseif command == "status" then
        local canQuery, detail = self.AuctionAPI:CanQuery()
        self:Print(string.format("State: %s. AH open: %s. Query: %s (%s).",
            self.Probe:GetState(),
            tostring(self.AuctionAPI:IsAuctionHouseOpen()),
            tostring(canQuery),
            tostring(detail or "unknown")))
    elseif command == "debug" then
        self.db.settings.debug = not self.db.settings.debug
        self:Print("Debug logging " .. (self.db.settings.debug and "enabled." or "disabled."))
        self.UI:Refresh()
    elseif command == "clear" then
        local now = time()
        if self.clearRequestedAt and now - self.clearRequestedAt <= 10 then
            self:ClearDiagnostics()
        else
            self.clearRequestedAt = now
            self:Print("Run /bod clear again within 10 seconds to clear stored diagnostics.")
        end
    elseif command == "minimap" then
        self.MinimapButton:ToggleShown()
    elseif command == "minimap show" then
        self.MinimapButton:SetShown(true)
    elseif command == "minimap hide" then
        self.MinimapButton:SetShown(false)
    elseif command == "minimap reset" then
        self.MinimapButton:ResetPosition()
    elseif command == "market" or command == "sidecar" then
        self.Sidecar:Show()
    elseif command == "txprobe" or command == "transaction probe" then
        self.TransactionProbe:Show()
    else
        self:Print("Unknown command. Use /bod help.")
    end
end

local eventFrame = CreateFrame("Frame")
BOD.eventFrame = eventFrame

function BOD:RegisterEvent(eventName)
    local ok, errorMessage = pcall(eventFrame.RegisterEvent, eventFrame, eventName)
    if not ok then
        self:Log("WARN", "Core", "Could not register event " .. tostring(eventName) .. ": " .. tostring(errorMessage))
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... ~= addonName then
        return
    end

    if event == "ADDON_LOADED" then
        BOD:InitializeDatabase()
    end

    if BOD.Diagnostics and BOD.Diagnostics.OnEvent then
        BOD.Diagnostics:OnEvent(event, ...)
    end
    if BOD.AuctionAPI and BOD.AuctionAPI.OnEvent then
        BOD.AuctionAPI:OnEvent(event, ...)
    end
    if BOD.Probe and BOD.Probe.OnEvent then
        BOD.Probe:OnEvent(event, ...)
    end
    if BOD.UI and BOD.UI.OnEvent then
        BOD.UI:OnEvent(event, ...)
    end
    if BOD.MinimapButton and BOD.MinimapButton.OnEvent then
        BOD.MinimapButton:OnEvent(event, ...)
    end
    if BOD.SearchController and BOD.SearchController.OnEvent then
        BOD.SearchController:OnEvent(event, ...)
    end
    if BOD.Sidecar and BOD.Sidecar.OnEvent then
        BOD.Sidecar:OnEvent(event, ...)
    end
    if BOD.TransactionProbe and BOD.TransactionProbe.OnEvent then
        BOD.TransactionProbe:OnEvent(event, ...)
    end
    if BOD.SettingsPanel and BOD.SettingsPanel.OnEvent then
        BOD.SettingsPanel:OnEvent(event, ...)
    end

    if event == "ADDON_LOADED" then
        BOD:Log("INFO", "Core", "Loaded version " .. BOD.version .. ".")
    elseif event == "PLAYER_LOGIN" then
        BOD:Log("INFO", "Core", "Player login complete.")
    end
end)

BOD:RegisterEvent("ADDON_LOADED")
BOD:RegisterEvent("PLAYER_LOGIN")
BOD:RegisterEvent("PLAYER_LOGOUT")
BOD:RegisterEvent("AUCTION_HOUSE_SHOW")
BOD:RegisterEvent("AUCTION_HOUSE_CLOSED")
BOD:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
BOD:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
BOD:RegisterEvent("AUCTION_BIDDER_LIST_UPDATE")
BOD:RegisterEvent("AUCTION_MULTISELL_START")
BOD:RegisterEvent("AUCTION_MULTISELL_UPDATE")
BOD:RegisterEvent("AUCTION_MULTISELL_FAILURE")
BOD:RegisterEvent("CHAT_MSG_SYSTEM")
BOD:RegisterEvent("UI_ERROR_MESSAGE")
BOD:RegisterEvent("BAG_UPDATE")
BOD:RegisterEvent("BAG_UPDATE_DELAYED")
BOD:RegisterEvent("ITEM_LOCK_CHANGED")
BOD:RegisterEvent("PLAYER_MONEY")
BOD:RegisterEvent("ADDON_ACTION_BLOCKED")
BOD:RegisterEvent("ADDON_ACTION_FORBIDDEN")

SLASH_BANKOFDUROTAR1 = "/bod"
SlashCmdList.BANKOFDUROTAR = function(input)
    if not BOD.db then
        BOD:InitializeDatabase()
    end
    BOD:HandleSlashCommand(input)
end
