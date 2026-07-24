local addonName, BOD = ...

BOD.Diagnostics = {
    lastEvent = nil,
}

local API_NAMES = {
    "CanSendAuctionQuery",
    "QueryAuctionItems",
    "GetNumAuctionItems",
    "GetAuctionItemInfo",
    "GetAuctionItemLink",
    "GetAuctionItemTimeLeft",
    "PlaceAuctionBid",
    "StartAuction",
    "CancelAuction",
}

local PROJECT_CONSTANTS = {
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
    "WOW_PROJECT_WRATH_CLASSIC",
    "WOW_PROJECT_CATACLYSM_CLASSIC",
}

local function valueType(value)
    if value == nil then
        return "nil"
    end
    return type(value)
end

function BOD.Diagnostics:GetClientInfo()
    local version, build, buildDate, tocVersion = GetBuildInfo()
    local realm = GetRealmName and GetRealmName() or "unknown"
    local character = UnitName and UnitName("player") or "unknown"
    local locale = GetLocale and GetLocale() or "unknown"

    if BOD.db and BOD.db.settings.redactIdentity then
        realm = "[redacted]"
        character = "[redacted]"
    end

    return {
        addonVersion = BOD.version,
        wowVersion = version or "unknown",
        build = build or "unknown",
        buildDate = buildDate or "unknown",
        tocVersion = tocVersion or "unknown",
        projectID = WOW_PROJECT_ID or "unknown",
        locale = locale,
        realm = realm,
        character = character,
    }
end

function BOD.Diagnostics:GetProjectConstants()
    local constants = {}
    for _, name in ipairs(PROJECT_CONSTANTS) do
        constants[#constants + 1] = {
            name = name,
            value = _G[name],
            valueType = valueType(_G[name]),
        }
    end
    return constants
end

function BOD.Diagnostics:GetAPIDetection()
    local detected = {}
    for _, name in ipairs(API_NAMES) do
        detected[#detected + 1] = {
            name = name,
            available = type(_G[name]) == "function",
            valueType = valueType(_G[name]),
        }
    end

    local auctionHouse = _G.C_AuctionHouse
    detected[#detected + 1] = {
        name = "C_AuctionHouse",
        available = type(auctionHouse) == "table",
        valueType = valueType(auctionHouse),
    }
    detected[#detected + 1] = {
        name = "C_AuctionHouse.SendSearchQuery",
        available = type(auctionHouse) == "table" and type(auctionHouse.SendSearchQuery) == "function",
        valueType = type(auctionHouse) == "table" and valueType(auctionHouse.SendSearchQuery) or "nil",
    }
    detected[#detected + 1] = {
        name = "C_AuctionHouse.ReplicateItems",
        available = type(auctionHouse) == "table" and type(auctionHouse.ReplicateItems) == "function",
        valueType = type(auctionHouse) == "table" and valueType(auctionHouse.ReplicateItems) or "nil",
    }

    return detected
end

function BOD.Diagnostics:RecordEvent(event, ...)
    if not BOD.db then
        return
    end

    local args = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        args[index] = tostring(value)
    end

    local entry = {
        timestamp = time(),
        event = event,
        args = args,
    }

    self.lastEvent = entry
    local events = BOD.db.diagnostics.events
    events[#events + 1] = entry
    while #events > BOD.maxEvents do
        table.remove(events, 1)
    end
end

function BOD.Diagnostics:OnEvent(event, ...)
    self:RecordEvent(event, ...)
end

function BOD.Diagnostics:BuildReport()
    local lines = {}
    local client = self:GetClientInfo()
    local capabilities = BOD.AuctionAPI:GetCapabilities()
    local latestSession = BOD.db and BOD.db.diagnostics.latestSession or nil
    local canQuery, queryDetail = BOD.AuctionAPI:CanQuery()

    lines[#lines + 1] = "Bank of Durotar Diagnostic Report"
    lines[#lines + 1] = "Generated: " .. BOD:FormatTimestamp(time())
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Client"
    lines[#lines + 1] = "Addon version: " .. tostring(client.addonVersion)
    lines[#lines + 1] = "WoW version: " .. tostring(client.wowVersion)
    lines[#lines + 1] = "Build: " .. tostring(client.build)
    lines[#lines + 1] = "Build date: " .. tostring(client.buildDate)
    lines[#lines + 1] = "TOC/interface: " .. tostring(client.tocVersion)
    lines[#lines + 1] = "Project ID: " .. tostring(client.projectID)
    lines[#lines + 1] = "Locale: " .. tostring(client.locale)
    lines[#lines + 1] = "Realm: " .. tostring(client.realm)
    lines[#lines + 1] = "Character: " .. tostring(client.character)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Project constants"
    for _, constant in ipairs(self:GetProjectConstants()) do
        lines[#lines + 1] = string.format("%s: %s (%s)", constant.name, tostring(constant.value), constant.valueType)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Auction House"
    lines[#lines + 1] = "AH open: " .. tostring(BOD.AuctionAPI:IsAuctionHouseOpen())
    lines[#lines + 1] = "Detected API family: " .. tostring(BOD.AuctionAPI:GetFamily())
    lines[#lines + 1] = "Can query: " .. tostring(canQuery) .. " (" .. tostring(queryDetail) .. ")"
    lines[#lines + 1] = "Full scan available: " .. tostring(capabilities.fullScanAvailable)
    lines[#lines + 1] = "Probe state: " .. tostring(BOD.Probe:GetState())
    lines[#lines + 1] = "Last query time: " .. tostring(BOD.Probe.lastQueryTime and BOD:FormatTimestamp(BOD.Probe.lastQueryTime) or "none")
    lines[#lines + 1] = "Last event: " .. tostring(self.lastEvent and self.lastEvent.event or "none")
    lines[#lines + 1] = "Last error: " .. tostring(BOD.Probe.lastError or "none")
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Available auction functions"
    for _, api in ipairs(self:GetAPIDetection()) do
        lines[#lines + 1] = string.format("%s: %s (%s)", api.name, tostring(api.available), api.valueType)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Events received"
    local events = BOD.db and BOD.db.diagnostics.events or {}
    for _, entry in ipairs(events) do
        lines[#lines + 1] = string.format("%s %s", BOD:FormatTimestamp(entry.timestamp), entry.event)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Latest probe"
    if latestSession then
        lines[#lines + 1] = "Search text: " .. tostring(latestSession.searchText)
        lines[#lines + 1] = "Started: " .. tostring(latestSession.startedAt and BOD:FormatTimestamp(latestSession.startedAt) or "unknown")
        lines[#lines + 1] = "Ended: " .. tostring(latestSession.endedAt and BOD:FormatTimestamp(latestSession.endedAt) or "unknown")
        lines[#lines + 1] = "State: " .. tostring(latestSession.state)
        lines[#lines + 1] = "Result count: " .. tostring(latestSession.resultCount)
        lines[#lines + 1] = "Sample count: " .. tostring(latestSession.sampleCount or 0)
        lines[#lines + 1] = "API family at persist: " .. tostring(latestSession.apiFamily)
        lines[#lines + 1] = "Query ready at persist: " .. tostring(latestSession.canQueryAtPersist)
        lines[#lines + 1] = "Query detail at persist: " .. tostring(latestSession.queryDetailAtPersist)
        lines[#lines + 1] = "Error: " .. tostring(latestSession.error or "none")
        lines[#lines + 1] = "Sample field names and value types:"
        if latestSession.results and latestSession.results[1] then
            for key, value in pairs(latestSession.results[1]) do
                lines[#lines + 1] = string.format("%s: %s", key, type(value))
            end
        else
            lines[#lines + 1] = "No sampled result fields."
        end
    else
        lines[#lines + 1] = "No probe session stored."
    end

    return table.concat(lines, "\n")
end
