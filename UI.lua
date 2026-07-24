local addonName, BOD = ...

BOD.UI = {
    frame = nil,
    statusText = nil,
    resultsText = nil,
    logText = nil,
    reportBox = nil,
    searchBox = nil,
}

local function createFontString(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    if size == "small" then
        text:SetFontObject(GameFontHighlightSmall)
    else
        text:SetFontObject(GameFontHighlight)
    end
    return text
end

local function setBackdrop(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.92)
    end
end

local function createButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 90, height or 24)
    button:SetText(label)
    return button
end

function BOD.UI:EnsureCreated()
    if self.frame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", nil, UIParent, template)
    self.frame = frame
    frame:SetSize(760, 620)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)
    frame:SetScript("OnShow", function()
        self:Refresh()
    end)
    setBackdrop(frame)

    self:RestorePosition()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("Bank of Durotar 0.0.1 - AH API Probe")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    searchLabel:SetText("Search")

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.searchBox = searchBox
    searchBox:SetSize(220, 24)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetText(BOD:GetSearchText())
    searchBox:SetScript("OnEditFocusLost", function(box)
        BOD:SetSearchText(box:GetText())
    end)
    searchBox:SetScript("OnEnterPressed", function(box)
        BOD:SetSearchText(box:GetText())
        box:ClearFocus()
    end)

    local probeButton = createButton(frame, "Probe", 82, 24)
    probeButton:SetPoint("LEFT", searchBox, "RIGHT", 14, 0)
    probeButton:SetScript("OnClick", function()
        BOD:SetSearchText(searchBox:GetText())
        BOD.Probe:Start(BOD:GetSearchText())
    end)

    local refreshButton = createButton(frame, "Refresh Status", 118, 24)
    refreshButton:SetPoint("LEFT", probeButton, "RIGHT", 8, 0)
    refreshButton:SetScript("OnClick", function()
        self:Refresh()
    end)

    local reportButton = createButton(frame, "Export Report", 112, 24)
    reportButton:SetPoint("LEFT", refreshButton, "RIGHT", 8, 0)
    reportButton:SetScript("OnClick", function()
        self:RefreshReport()
        self.reportBox:SetFocus()
        self.reportBox:HighlightText()
    end)

    local redactCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.redactCheck = redactCheck
    redactCheck:SetSize(24, 24)
    redactCheck:SetPoint("LEFT", reportButton, "RIGHT", 8, 0)
    redactCheck:SetChecked(BOD.db and BOD.db.settings.redactIdentity)
    redactCheck:SetScript("OnClick", function(check)
        if BOD.db and BOD.db.settings then
            BOD.db.settings.redactIdentity = check:GetChecked() and true or false
            self:Refresh()
        end
    end)

    local redactLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    redactLabel:SetPoint("LEFT", redactCheck, "RIGHT", 0, 1)
    redactLabel:SetText("Redact")

    local clientHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clientHeader:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -18)
    clientHeader:SetText("Status and API Detection")

    local statusScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    statusScroll:SetPoint("TOPLEFT", clientHeader, "BOTTOMLEFT", 0, -6)
    statusScroll:SetSize(340, 205)

    local statusChild = CreateFrame("Frame", nil, statusScroll)
    statusChild:SetSize(320, 205)
    statusScroll:SetScrollChild(statusChild)
    self.statusText = createFontString(statusChild, "small")
    self.statusText:SetPoint("TOPLEFT", 0, 0)
    self.statusText:SetWidth(320)

    local resultsHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultsHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 395, -82)
    resultsHeader:SetText("Sample Results")

    local resultsScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    resultsScroll:SetPoint("TOPLEFT", resultsHeader, "BOTTOMLEFT", 0, -6)
    resultsScroll:SetSize(320, 205)

    local resultsChild = CreateFrame("Frame", nil, resultsScroll)
    resultsChild:SetSize(300, 205)
    resultsScroll:SetScrollChild(resultsChild)
    self.resultsText = createFontString(resultsChild, "small")
    self.resultsText:SetPoint("TOPLEFT", 0, 0)
    self.resultsText:SetWidth(300)

    local logHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -320)
    logHeader:SetText("Log")

    local logScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    logScroll:SetPoint("TOPLEFT", logHeader, "BOTTOMLEFT", 0, -6)
    logScroll:SetSize(330, 230)

    local logChild = CreateFrame("Frame", nil, logScroll)
    logChild:SetSize(310, 230)
    logScroll:SetScrollChild(logChild)
    self.logText = createFontString(logChild, "small")
    self.logText:SetPoint("TOPLEFT", 0, 0)
    self.logText:SetWidth(310)

    local reportHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reportHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 395, -320)
    reportHeader:SetText("Copyable Report")

    local reportScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    reportScroll:SetPoint("TOPLEFT", reportHeader, "BOTTOMLEFT", 0, -6)
    reportScroll:SetSize(320, 230)

    local reportBox = CreateFrame("EditBox", nil, reportScroll)
    self.reportBox = reportBox
    reportBox:SetMultiLine(true)
    reportBox:SetAutoFocus(false)
    reportBox:SetFontObject(ChatFontNormal)
    reportBox:SetWidth(300)
    reportBox:SetTextInsets(0, 0, 0, 0)
    reportScroll:SetScrollChild(reportBox)
    reportBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
    end)

    frame:Hide()
end

function BOD.UI:RestorePosition()
    local frame = self.frame
    local window = BOD.db and BOD.db.settings.window or nil
    frame:ClearAllPoints()
    if window then
        frame:SetPoint(window.point or "CENTER", UIParent, window.relativePoint or "CENTER", window.x or 0, window.y or 0)
    else
        frame:SetPoint("CENTER")
    end
end

function BOD.UI:SavePosition()
    if not BOD.db or not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    BOD.db.settings.window = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = math.floor((x or 0) + 0.5),
        y = math.floor((y or 0) + 0.5),
    }
end

function BOD.UI:Show()
    self:EnsureCreated()
    self.frame:Show()
    self:Refresh()
end

function BOD.UI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function BOD.UI:Toggle()
    self:EnsureCreated()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BOD.UI:Refresh()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    local client = BOD.Diagnostics:GetClientInfo()
    local capabilities = BOD.AuctionAPI:GetCapabilities()
    local canQuery, queryDetail = BOD.AuctionAPI:CanQuery()
    local latestEvent = BOD.Diagnostics.lastEvent

    local statusLines = {
        "Addon: " .. tostring(client.addonVersion),
        "WoW: " .. tostring(client.wowVersion),
        "Build: " .. tostring(client.build),
        "Build date: " .. tostring(client.buildDate),
        "TOC/interface: " .. tostring(client.tocVersion),
        "Project ID: " .. tostring(client.projectID),
        "Locale: " .. tostring(client.locale),
        "Realm: " .. tostring(client.realm),
        "Character: " .. tostring(client.character),
        "",
        "AH open: " .. tostring(capabilities.ahOpen),
        "API family: " .. tostring(capabilities.family),
        "Can query: " .. tostring(canQuery),
        "Query detail: " .. tostring(queryDetail),
        "Full scan available: " .. tostring(capabilities.fullScanAvailable),
        "Probe state: " .. tostring(BOD.Probe:GetState()),
        "Last query: " .. tostring(BOD.Probe.lastQueryTime and BOD:FormatTimestamp(BOD.Probe.lastQueryTime) or "none"),
        "Last event: " .. tostring(latestEvent and latestEvent.event or "none"),
        "Last error: " .. tostring(BOD.Probe.lastError or "none"),
        "",
        "APIs",
    }

    for _, api in ipairs(BOD.Diagnostics:GetAPIDetection()) do
        statusLines[#statusLines + 1] = string.format("%s: %s", api.name, tostring(api.available))
    end

    if self.redactCheck and BOD.db and BOD.db.settings then
        self.redactCheck:SetChecked(BOD.db.settings.redactIdentity)
    end

    self.statusText:SetText(table.concat(statusLines, "\n"))

    self:RefreshResults()
    self:RefreshLog()
    self:RefreshReport()
end

function BOD.UI:RefreshResults()
    if not self.resultsText then
        return
    end

    local lines = {
        "Count: " .. tostring(BOD.Probe.resultCount or 0),
    }

    local results = BOD.Probe.results or {}
    if #results == 0 and BOD.db and BOD.db.diagnostics.latestSession and BOD.db.diagnostics.latestSession.results then
        results = BOD.db.diagnostics.latestSession.results
        lines[1] = "Stored count: " .. tostring(BOD.db.diagnostics.latestSession.resultCount or 0)
    end

    for _, result in ipairs(results) do
        local buyout = result.buyoutTotal and BOD:FormatMoney(result.buyoutTotal) or "none"
        local perUnit = result.buyoutPerUnit and BOD:FormatMoney(result.buyoutPerUnit) or "none"
        lines[#lines + 1] = string.format("%d. %s x%s", result.index or 0, tostring(result.name or "unknown"), tostring(result.stackCount or "?"))
        lines[#lines + 1] = "   Buyout: " .. buyout .. "  Each: " .. perUnit
        lines[#lines + 1] = "   Owner: " .. tostring(result.ownerFullName or result.owner or "unknown")
    end

    if #results == 0 then
        lines[#lines + 1] = "No sampled results."
    end

    self.resultsText:SetText(table.concat(lines, "\n"))
end

function BOD.UI:RefreshLog()
    if not self.logText or not BOD.db then
        return
    end

    local lines = {}
    for _, entry in ipairs(BOD.db.diagnostics.logs or {}) do
        lines[#lines + 1] = string.format("%s [%s] %s: %s",
            date("%H:%M:%S", entry.timestamp or time()),
            tostring(entry.level),
            tostring(entry.source),
            tostring(entry.message))
    end
    self.logText:SetText(table.concat(lines, "\n"))
end

function BOD.UI:RefreshReport()
    if self.reportBox and BOD.Diagnostics then
        self.reportBox:SetText(BOD.Diagnostics:BuildReport())
    end
end

function BOD.UI:OnEvent(event)
    if event == "ADDON_LOADED" then
        self:EnsureCreated()
    elseif self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end
