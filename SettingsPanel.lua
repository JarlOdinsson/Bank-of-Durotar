local addonName, BOD = ...

BOD.SettingsPanel = {
    panel = nil,
    registered = false,
}

local function createFontString(parent, template)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

local function createCheck(parent, label, anchor, x, y, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -8)
    check:SetSize(24, 24)
    check:SetScript("OnClick", function(button)
        setter(button:GetChecked() and true or false)
        if BOD.Sidecar then
            BOD.Sidecar:ApplyLayout()
            BOD.Sidecar:Refresh()
        end
        if BOD.MinimapButton then
            BOD.MinimapButton:ApplySettings()
        end
    end)

    local text = createFontString(parent, "GameFontNormalSmall")
    text:SetPoint("LEFT", check, "RIGHT", 0, 0)
    text:SetText(label)

    check.refresh = function()
        check:SetChecked(getter() and true or false)
    end
    check:refresh()
    return check, text
end

local function createButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 120, height or 24)
    button:SetText(label)
    return button
end

function BOD.SettingsPanel:EnsureCreated()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame", "BankOfDurotarOptionsPanel")
    self.panel = panel
    panel.name = "Bank of Durotar"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Bank of Durotar")

    local general = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    general:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    general:SetText("General")

    local openCheck = createCheck(panel, "Open with Auction House", general, 0, -8, function()
        return BOD.db.settings.openWithAuctionHouse
    end, function(value)
        BOD.db.settings.openWithAuctionHouse = value
    end)

    local minimapCheck = createCheck(panel, "Show minimap button", openCheck, 0, -5, function()
        return BOD.db.settings.showMinimapButton
    end, function(value)
        BOD.db.settings.showMinimapButton = value
        if BOD.db.settings.minimap then
            BOD.db.settings.minimap.hidden = not value
        end
    end)

    local dockCheck = createCheck(panel, "Dock sidecar to Auction House", minimapCheck, 0, -5, function()
        return BOD.db.settings.dockToAuctionHouse
    end, function(value)
        BOD.db.settings.dockToAuctionHouse = value
    end)

    local widthLabel = createFontString(panel, "GameFontNormalSmall")
    widthLabel:SetPoint("TOPLEFT", dockCheck, "BOTTOMLEFT", 4, -10)
    widthLabel:SetText("Sidecar width")

    local widthBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    self.widthBox = widthBox
    widthBox:SetSize(58, 22)
    widthBox:SetPoint("LEFT", widthLabel, "RIGHT", 12, 0)
    widthBox:SetAutoFocus(false)
    widthBox:SetNumeric(true)
    widthBox:SetText(tostring(BOD.db.settings.sidecarWidth or 390))
    widthBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
    end)
    widthBox:SetScript("OnEditFocusLost", function(box)
        local width = tonumber(box:GetText()) or 390
        BOD.db.settings.sidecarWidth = math.max(360, math.min(420, width))
        box:SetText(tostring(BOD.db.settings.sidecarWidth))
        if BOD.Sidecar then
            BOD.Sidecar:ApplyLayout()
        end
    end)

    local resetButton = createButton(panel, "Reset UI Position", 140, 24)
    resetButton:SetPoint("LEFT", widthBox, "RIGHT", 12, 0)
    resetButton:SetScript("OnClick", function()
        if BOD.Sidecar then
            BOD.Sidecar:ResetPosition()
        end
        if BOD.UI then
            BOD.db.settings.window = {
                point = "CENTER",
                relativePoint = "CENTER",
                x = 0,
                y = 0,
            }
            BOD.UI:RestorePosition()
        end
    end)

    local diagnostics = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    diagnostics:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", -4, -28)
    diagnostics:SetText("Diagnostics")

    local info = createFontString(panel, "GameFontHighlightSmall")
    self.infoText = info
    info:SetPoint("TOPLEFT", diagnostics, "BOTTOMLEFT", 0, -8)
    info:SetSize(560, 135)

    local redactCheck = createCheck(panel, "Redact character and realm in reports", info, 0, -8, function()
        return BOD.db.settings.redactIdentity
    end, function(value)
        BOD.db.settings.redactIdentity = value
        if BOD.UI then
            BOD.UI:Refresh()
        end
    end)

    local debugCheck = createCheck(panel, "Debug mode", redactCheck, 0, -5, function()
        return BOD.db.settings.debug
    end, function(value)
        BOD.db.settings.debug = value
    end)

    local exportButton = createButton(panel, "Export Report", 120, 24)
    exportButton:SetPoint("TOPLEFT", debugCheck, "BOTTOMLEFT", 4, -10)
    exportButton:SetScript("OnClick", function()
        if BOD.UI then
            BOD.UI:Show()
            BOD.UI:RefreshReport()
            BOD.UI.reportBox:SetFocus()
            BOD.UI.reportBox:HighlightText()
        end
    end)

    local clearButton = createButton(panel, "Clear Diagnostics", 130, 24)
    clearButton:SetPoint("LEFT", exportButton, "RIGHT", 10, 0)
    clearButton:SetScript("OnClick", function()
        BOD:ClearDiagnostics()
        self:Refresh()
    end)

    panel:SetScript("OnShow", function()
        self:Refresh()
    end)
end

function BOD.SettingsPanel:Register()
    if self.registered then
        return
    end

    self:EnsureCreated()

    if Settings and type(Settings.RegisterCanvasLayoutCategory) == "function" and type(Settings.RegisterAddOnCategory) == "function" then
        local category = Settings.RegisterCanvasLayoutCategory(self.panel, "Bank of Durotar")
        Settings.RegisterAddOnCategory(category)
        self.category = category
        self.registered = true
    elseif type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(self.panel)
        self.registered = true
    else
        BOD:Log("WARN", "Settings", "No supported addon settings registration API detected.")
    end
end

function BOD.SettingsPanel:Refresh()
    if not self.panel or not self.infoText then
        return
    end

    local client = BOD.Diagnostics:GetClientInfo()
    local canQuery, queryDetail = BOD.AuctionAPI:CanQuery()
    local latestProbe = BOD.db and BOD.db.diagnostics.latestSession or nil
    local capabilities = BOD.AuctionAPI:GetCapabilities()
    local lines = {
        "Client: " .. tostring(client.wowVersion) .. " build " .. tostring(client.build) .. " interface " .. tostring(client.tocVersion),
        "Project ID: " .. tostring(client.projectID),
        "API family: " .. tostring(capabilities.family),
        "Query readiness: " .. tostring(canQuery) .. " (" .. tostring(queryDetail) .. ")",
        "Latest probe: " .. tostring(latestProbe and latestProbe.state or "none"),
        "Events recorded: " .. tostring(BOD.db and #BOD.db.diagnostics.events or 0),
        "Capability list: legacyQuery=" .. tostring(capabilities.legacyQuery)
            .. ", legacyResults=" .. tostring(capabilities.legacyResults)
            .. ", modernAH=" .. tostring(capabilities.modernAuctionHouse),
    }
    self.infoText:SetText(table.concat(lines, "\n"))

    if self.widthBox then
        self.widthBox:SetText(tostring(BOD.db.settings.sidecarWidth or 390))
    end
end

function BOD.SettingsPanel:OnEvent(event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        self:Register()
    elseif self.panel and self.panel:IsShown() then
        self:Refresh()
    end
end
