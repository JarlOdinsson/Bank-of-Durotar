local addonName, BOD = ...

BOD.MinimapButton = {
    button = nil,
    menu = nil,
    isDragging = false,
}

local BUTTON_SIZE = 32
local DEFAULT_ANGLE = 225
local MINIMAP_RADIUS = 80

local function getSettings()
    if not BOD.db then
        BOD:InitializeDatabase()
    end
    BOD.db.settings.minimap = BOD.db.settings.minimap or {}
    if BOD.db.settings.minimap.hidden == nil then
        BOD.db.settings.minimap.hidden = false
    end
    if type(BOD.db.settings.minimap.angle) ~= "number" then
        BOD.db.settings.minimap.angle = DEFAULT_ANGLE
    end
    return BOD.db.settings.minimap
end

local function normalizeAngle(angle)
    angle = tonumber(angle) or DEFAULT_ANGLE
    angle = angle % 360
    if angle < 0 then
        angle = angle + 360
    end
    return angle
end

local function getAngleDegrees(deltaY, deltaX)
    if math.atan2 then
        return math.deg(math.atan2(deltaY, deltaX))
    end

    if deltaX == 0 then
        return deltaY >= 0 and 90 or 270
    end

    local angle = math.deg(math.atan(deltaY / deltaX))
    if deltaX < 0 then
        angle = angle + 180
    elseif deltaY < 0 then
        angle = angle + 360
    end
    return angle
end

local function createMenuButton(parent, label, yOffset, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(118, 22)
    button:SetPoint("TOPLEFT", 8, yOffset)
    button:SetText(label)
    button:SetScript("OnClick", function()
        parent:Hide()
        onClick()
    end)
    return button
end

local function setBackdrop(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.95)
    end
end

function BOD.MinimapButton:EnsureCreated()
    if self.button then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local button = CreateFrame("Button", "BankOfDurotarMinimapButton", Minimap, template)
    self.button = button
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetSize(54, 54)
    overlay:SetPoint("TOPLEFT")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    button.icon = icon

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            BOD.UI:Toggle()
        elseif mouseButton == "RightButton" then
            self:ToggleMenu()
        end
    end)

    button:SetScript("OnDragStart", function()
        self.isDragging = true
        self:HideMenu()
    end)

    button:SetScript("OnDragStop", function()
        self.isDragging = false
    end)

    button:SetScript("OnUpdate", function()
        if self.isDragging then
            self:UpdatePositionFromCursor()
        end
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Bank of Durotar")
        GameTooltip:AddLine("Left-click: Open", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Options", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self:CreateMenu()
    self:ApplySettings()
end

function BOD.MinimapButton:CreateMenu()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local menu = CreateFrame("Frame", "BankOfDurotarMinimapMenu", UIParent, template)
    self.menu = menu
    menu:SetSize(134, 92)
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)
    setBackdrop(menu)
    menu:Hide()

    createMenuButton(menu, "Show/Hide", -8, function()
        BOD.UI:Toggle()
    end)
    createMenuButton(menu, "Run Probe", -34, function()
        BOD.Probe:Start(BOD:GetSearchText())
    end)
    createMenuButton(menu, "Toggle Debug", -60, function()
        BOD.db.settings.debug = not BOD.db.settings.debug
        BOD:Print("Debug logging " .. (BOD.db.settings.debug and "enabled." or "disabled."))
        BOD.UI:Refresh()
    end)
end

function BOD.MinimapButton:UpdatePosition()
    if not self.button then
        return
    end

    local settings = getSettings()
    local angle = math.rad(normalizeAngle(settings.angle))
    local x = math.cos(angle) * MINIMAP_RADIUS
    local y = math.sin(angle) * MINIMAP_RADIUS

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function BOD.MinimapButton:UpdatePositionFromCursor()
    if not self.button or not Minimap then
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale() or 1
    local centerX, centerY = Minimap:GetCenter()
    if not cursorX or not cursorY or not centerX or not centerY then
        return
    end

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local angle = getAngleDegrees(cursorY - centerY, cursorX - centerX)
    getSettings().angle = normalizeAngle(angle)
    self:UpdatePosition()
end

function BOD.MinimapButton:ApplySettings()
    self:UpdatePosition()
    if getSettings().hidden then
        self.button:Hide()
    else
        self.button:Show()
    end
end

function BOD.MinimapButton:SetShown(shouldShow)
    self:EnsureCreated()
    getSettings().hidden = not shouldShow
    self:ApplySettings()
    BOD:Print("Minimap button " .. (shouldShow and "shown." or "hidden."))
end

function BOD.MinimapButton:ToggleShown()
    self:SetShown(getSettings().hidden)
end

function BOD.MinimapButton:ResetPosition()
    self:EnsureCreated()
    local settings = getSettings()
    settings.angle = DEFAULT_ANGLE
    settings.hidden = false
    self:ApplySettings()
    BOD:Print("Minimap button reset.")
end

function BOD.MinimapButton:ToggleMenu()
    self:EnsureCreated()
    if self.menu:IsShown() then
        self.menu:Hide()
        return
    end

    self.menu:ClearAllPoints()
    self.menu:SetPoint("TOPRIGHT", self.button, "BOTTOMLEFT", -4, -4)
    self.menu:Show()
end

function BOD.MinimapButton:HideMenu()
    if self.menu then
        self.menu:Hide()
    end
end

function BOD.MinimapButton:OnEvent(event)
    if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
        self:EnsureCreated()
        self:ApplySettings()
    end
end
