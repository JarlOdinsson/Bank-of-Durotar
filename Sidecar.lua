local addonName, BOD = ...

BOD.Sidecar = {
    frame = nil,
    activeView = "PLAN",
    viewButtons = {},
    panels = {},
    buyRows = {},
    bagRows = {},
    craftRows = {},
    selectedItemKey = nil,
    selectedItemLink = nil,
}

local WIDTH, HEIGHT = 520, 640
local BUY_ROWS, SELL_ROWS, CRAFT_ROWS = 10, 3, 3
local GUIDED_HEIGHT = 716
local COPPER_PER_GOLD = 10000
local MAX_SAFE_INTEGER = 2147483647
local GUIDE_STEPS = {
    { view = "PLAN", title = "WELCOME", text = "This guide will show you exactly what to click. Use Back and Next whenever you need them." },
    { view = "PLAN", title = "SET YOUR BUDGET", text = "Type how much gold you can spend in the Budget box, then click Apply." },
    { view = "PLAN", title = "SCAN THE MARKET", text = "Open the Auction House and click Scan Market. Wait while Bank of Durotar learns the prices." },
    { view = "PLAN", title = "BUY", text = "Under Items to Buy, search the exact item name in Blizzard's Auction House. Never pay more than the shown limit." },
    { view = "PLAN", title = "SELL FROM YOUR BAGS", text = "Under Items to Sell, use the shown stack size and price. Put those numbers into Blizzard's sell window." },
    { view = "SELL", title = "PRICE ANY ITEM", text = "Drag an item from your bags into the big box. Type how many you are selling, then copy the price in step 3." },
    { view = "CRAFT", title = "CRAFT FOR PROFIT", text = "Open each profession once. After a market scan, this tab shows crafts that may make gold." },
    { view = "PLAN", title = "YOU ARE READY", text = "That is the whole loop: set a budget, scan, follow the safe suggestions, and always buy and sell manually." },
}

local function settings()
    if not BOD.db then BOD:InitializeDatabase() end
    return BOD.db.settings
end

local function font(parent, template)
    local value = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    value:SetJustifyH("LEFT")
    value:SetJustifyV("TOP")
    return value
end

local function button(parent, label, width, height)
    local value = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    value:SetSize(width or 100, height or 24)
    value:SetText(label)
    return value
end

local function sectionLabel(parent, label)
    local value = font(parent, "GameFontNormalSmall")
    value:SetText(label)
    value:SetTextColor(0.85, 0.68, 0.32)
    return value
end

local function recommendationRow(parent, height, width)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local container = CreateFrame("Frame", nil, parent, template)
    container:SetSize(width or 475, height)
    if container.SetBackdrop then
        container:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        container:SetBackdropColor(0.10, 0.075, 0.045, 0.72)
    end

    local value = font(container, "GameFontHighlightSmall")
    value:SetPoint("TOPLEFT", 10, -7)
    value:SetPoint("BOTTOMRIGHT", -8, 5)
    value.container = container
    return value
end

local function setRow(row, text)
    text = tostring(text or "")
    row:SetText(text)
    if text == "" then row.container:Hide() else row.container:Show() end
end

local function cursorItemLink()
    if type(GetCursorInfo) ~= "function" then return nil end
    local cursorType, itemID, itemLink = GetCursorInfo()
    if cursorType ~= "item" then return nil end
    if type(itemLink) == "string" and itemLink ~= "" then return itemLink end
    if itemID and type(GetItemInfo) == "function" then
        local _, link = GetItemInfo(itemID)
        return link
    end
end

local function setBackdrop(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        frame:SetBackdropColor(0.04, 0.025, 0.015, 0.96)
    end
end

local function getAuctionFrame()
    if AuctionFrame and AuctionFrame.IsShown then return AuctionFrame end
    if AuctionHouseFrame and AuctionHouseFrame.IsShown then return AuctionHouseFrame end
end

local function canDock(frame)
    if not frame or not frame.GetRight or not UIParent or not UIParent.GetWidth then return false end
    local right, screen = frame:GetRight(), UIParent:GetWidth()
    return right and screen and right + WIDTH + 8 <= screen
end

local function ageLabel(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds < 60 then return tostring(seconds) .. "s" end
    if seconds < 3600 then return tostring(math.floor(seconds / 60)) .. "m" end
    if seconds < 86400 then return tostring(math.floor(seconds / 3600)) .. "h" end
    return tostring(math.floor(seconds / 86400)) .. "d"
end

local function marketMemoryLabel()
    local memory = BOD.MarketHistory and BOD.MarketHistory.GetLearningStatus and BOD.MarketHistory:GetLearningStatus() or {}
    local sales = BOD.SalesHistory and BOD.SalesHistory.GetLearningStatus and BOD.SalesHistory:GetLearningStatus() or {}
    local stage = memory.mature and "Established" or (memory.ready and "Building" or "Learning")
    return string.format("Market memory: %s · %d scans · %d days · %d items · Mail: %d sold, %d expired", stage, tonumber(memory.totalScans) or 0, tonumber(memory.daysObserved) or 0, tonumber(memory.trackedItems) or 0, tonumber(sales.soldCount) or 0, tonumber(sales.expiredCount) or 0)
end

function BOD.Sidecar:CreatePlanPanel(frame, anchor)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    panel:SetSize(488, 460)
    self.panels.PLAN = panel

    local heading = font(panel, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 4, -4)
    heading:SetText("Gold Plan")

    local budgetLabel = font(panel, "GameFontNormalSmall")
    budgetLabel:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
    budgetLabel:SetText("Budget")

    self.budgetBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    self.budgetBox:SetSize(80, 24)
    self.budgetBox:SetPoint("LEFT", budgetLabel, "RIGHT", 10, 0)
    self.budgetBox:SetAutoFocus(false)
    self.budgetBox:SetNumeric(true)
    self.budgetBox:SetText(tostring(math.floor((settings().goldBudgetCopper or 1000000) / COPPER_PER_GOLD)))
    self.budgetBox:SetScript("OnEnterPressed", function(box) self:SaveBudget(); box:ClearFocus() end)

    local goldLabel = font(panel, "GameFontNormalSmall")
    goldLabel:SetPoint("LEFT", self.budgetBox, "RIGHT", 5, 0)
    goldLabel:SetText("gold")

    local apply = button(panel, "Apply", 72, 24)
    apply:SetPoint("LEFT", goldLabel, "RIGHT", 12, 0)
    apply:SetScript("OnClick", function() self:SaveBudget() end)

    self.planSummary = font(panel, "GameFontHighlightSmall")
    self.planSummary:SetPoint("TOPLEFT", budgetLabel, "BOTTOMLEFT", 0, -12)
    self.planSummary:SetSize(475, 30)

    local buyHeader = sectionLabel(panel, "BUY These Auction Items — Top Flips (scroll for up to 10)")
    buyHeader:SetPoint("TOPLEFT", self.planSummary, "BOTTOMLEFT", 0, -8)
    local buyScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    self.buyScroll = buyScroll
    buyScroll:SetPoint("TOPLEFT", buyHeader, "BOTTOMLEFT", 0, -7)
    buyScroll:SetSize(462, 144)
    buyScroll:EnableMouseWheel(true)
    local buyScrollChild = CreateFrame("Frame", nil, buyScroll)
    self.buyScrollChild = buyScrollChild
    buyScrollChild:SetSize(438, BUY_ROWS * 52)
    buyScroll:SetScrollChild(buyScrollChild)
    buyScroll:SetScript("OnMouseWheel", function(scroll, delta)
        local maximum = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or math.max(0, (BUY_ROWS * 52) - 144)
        local nextValue = math.max(0, math.min(maximum, (scroll:GetVerticalScroll() or 0) - (delta * 52)))
        scroll:SetVerticalScroll(nextValue)
        local scrollBar = scroll.ScrollBar or scroll.scrollBar
        if scrollBar and scrollBar.SetValue then scrollBar:SetValue(nextValue) end
    end)
    for index = 1, BUY_ROWS do
        local row = recommendationRow(buyScrollChild, 48, 432)
        row.container:SetPoint("TOPLEFT", 0, -((index - 1) * 52))
        self.buyRows[index] = row
    end

    local bagHeader = sectionLabel(panel, "SELL These Items From Your Bags")
    bagHeader:SetPoint("TOPLEFT", buyScroll, "BOTTOMLEFT", 0, -10)
    for index = 1, SELL_ROWS do
        local row = recommendationRow(panel, 38)
        row.container:SetPoint("TOPLEFT", bagHeader, "BOTTOMLEFT", 0, -7 - ((index - 1) * 42))
        self.bagRows[index] = row
    end

    self.planNote = font(panel, "GameFontDisableSmall")
    self.planNote:SetPoint("TOPLEFT", self.bagRows[SELL_ROWS].container, "BOTTOMLEFT", 0, -7)
    self.planNote:SetSize(475, 24)
    self.planNote:SetText("Flip score estimates resale ease; demand is never guaranteed. Buy and post manually.")
end

function BOD.Sidecar:CreateCraftPanel(frame, anchor)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    panel:SetSize(488, 460)
    self.panels.CRAFT = panel

    local heading = font(panel, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 4, -4)
    heading:SetText("Craft for Profit")

    local help = font(panel, "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -12)
    help:SetSize(475, 42)
    help:SetText("Open each profession window once so Bank of Durotar learns your recipes.\nThen scan the Auction House to price the materials and finished items.")

    self.craftSummary = font(panel, "GameFontNormalSmall")
    self.craftSummary:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
    self.craftSummary:SetSize(475, 30)

    local header = sectionLabel(panel, "CRAFT These Items")
    header:SetPoint("TOPLEFT", self.craftSummary, "BOTTOMLEFT", 0, -8)
    for index = 1, CRAFT_ROWS do
        local row = recommendationRow(panel, 70)
        row.container:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -9 - ((index - 1) * 76))
        self.craftRows[index] = row
    end

    local note = font(panel, "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", self.craftRows[CRAFT_ROWS].container, "BOTTOMLEFT", 0, -8)
    note:SetSize(475, 32)
    note:SetText("Profit includes the 5% Auction House cut, but not deposits, cooldowns, or unsold items.")
end

function BOD.Sidecar:CreateSellPanel(frame, anchor)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    panel:SetSize(488, 460)
    self.panels.SELL = panel

    local heading = font(panel, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 4, -4)
    heading:SetText("Sell an Item")

    local intro = font(panel, "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    intro:SetText("Follow these three steps. Bank of Durotar does the math.")

    local itemLabel = sectionLabel(panel, "1. CHOOSE THE ITEM")
    itemLabel:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    self.sellDropTarget = CreateFrame("Button", nil, panel, template)
    self.sellDropTarget:SetSize(475, 66)
    self.sellDropTarget:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", 0, -7)
    self.sellDropTarget:RegisterForClicks("LeftButtonUp")
    self.sellDropTarget:RegisterForDrag("LeftButton")
    if self.sellDropTarget.SetBackdrop then
        self.sellDropTarget:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        self.sellDropTarget:SetBackdropColor(0.12, 0.085, 0.04, 0.94)
        self.sellDropTarget:SetBackdropBorderColor(0.85, 0.58, 0.16, 1)
    end
    self.sellDropIcon = self.sellDropTarget:CreateTexture(nil, "ARTWORK")
    self.sellDropIcon:SetSize(42, 42)
    self.sellDropIcon:SetPoint("LEFT", 12, 0)
    self.sellDropIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.sellDropName = font(self.sellDropTarget, "GameFontNormal")
    self.sellDropName:SetPoint("TOPLEFT", self.sellDropIcon, "TOPRIGHT", 12, -2)
    self.sellDropName:SetText("DRAG AN ITEM HERE")
    self.sellDropHelp = font(self.sellDropTarget, "GameFontHighlightSmall")
    self.sellDropHelp:SetPoint("TOPLEFT", self.sellDropName, "BOTTOMLEFT", 0, -6)
    self.sellDropHelp:SetText("Open your bags, then drag one item into this big box.")
    local function useCursorItem()
        local link = cursorItemLink()
        if link then
            self:SelectSellItem(link)
            if type(ClearCursor) == "function" then ClearCursor() end
        end
    end
    self.sellDropTarget:SetScript("OnReceiveDrag", useCursorItem)
    self.sellDropTarget:SetScript("OnClick", useCursorItem)

    local manualLabel = font(panel, "GameFontDisableSmall")
    manualLabel:SetPoint("TOPLEFT", self.sellDropTarget, "BOTTOMLEFT", 2, -10)
    manualLabel:SetText("Or type the item's name:")
    self.sellItemBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    self.sellItemBox:SetSize(300, 24)
    self.sellItemBox:SetPoint("TOPLEFT", manualLabel, "BOTTOMLEFT", 3, -5)
    self.sellItemBox:SetAutoFocus(false)
    self.sellItemBox:SetScript("OnEnterPressed", function(box) self:SelectSellItem(box:GetText()); box:ClearFocus() end)
    local use = button(panel, "Find", 68, 24)
    use:SetPoint("LEFT", self.sellItemBox, "RIGHT", 8, 0)
    use:SetScript("OnClick", function() self:SelectSellItem(self.sellItemBox:GetText()) end)

    local stackLabel = sectionLabel(panel, "2. HOW MANY ARE YOU SELLING?")
    stackLabel:SetPoint("TOPLEFT", self.sellItemBox, "BOTTOMLEFT", -3, -18)
    self.sellStackBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    self.sellStackBox:SetSize(70, 24)
    self.sellStackBox:SetPoint("TOPLEFT", stackLabel, "BOTTOMLEFT", 3, -6)
    self.sellStackBox:SetAutoFocus(false)
    self.sellStackBox:SetNumeric(true)
    self.sellStackBox:SetText("1")
    self.sellStackBox:SetScript("OnTextChanged", function() self:RefreshSell() end)

    local stackHelp = font(panel, "GameFontHighlightSmall")
    stackHelp:SetPoint("LEFT", self.sellStackBox, "RIGHT", 10, 0)
    stackHelp:SetText("Type the number in the stack.")

    local resultLabel = sectionLabel(panel, "3. USE THIS PRICE")
    resultLabel:SetPoint("TOPLEFT", self.sellStackBox, "BOTTOMLEFT", -3, -18)

    self.sellText = font(panel, "GameFontHighlight")
    self.sellText:SetPoint("TOPLEFT", resultLabel, "BOTTOMLEFT", 0, -8)
    self.sellText:SetSize(475, 180)
end

function BOD.Sidecar:InstallItemClickHook()
    if self.itemClickHooked or type(hooksecurefunc) ~= "function" or type(HandleModifiedItemClick) ~= "function" then return end
    self.itemClickHooked = true
    hooksecurefunc("HandleModifiedItemClick", function(itemLink)
        if self.frame and self.frame:IsShown() and self.activeView == "SELL" and type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then
            self:SelectSellItem(itemLink)
        end
    end)
end

function BOD.Sidecar:CreateGuidePanel(frame, anchor)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local panel = CreateFrame("Frame", nil, frame, template)
    self.guidePanel = panel
    panel:SetSize(488, 64)
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        panel:SetBackdropColor(0.09, 0.07, 0.035, 0.97)
        panel:SetBackdropBorderColor(0.85, 0.58, 0.16, 1)
    end

    self.guideTitle = font(panel, "GameFontNormalSmall")
    self.guideTitle:SetPoint("TOPLEFT", 10, -9)
    self.guideTitle:SetSize(320, 14)
    self.guideText = font(panel, "GameFontHighlightSmall")
    self.guideText:SetPoint("TOPLEFT", self.guideTitle, "BOTTOMLEFT", 0, -4)
    self.guideText:SetSize(326, 36)

    self.guideBack = button(panel, "Back", 62, 24)
    self.guideBack:SetPoint("BOTTOMRIGHT", -76, 8)
    self.guideBack:SetScript("OnClick", function() self:SetGuideStep((settings().guidedStep or 1) - 1) end)
    self.guideNext = button(panel, "Next", 62, 24)
    self.guideNext:SetPoint("LEFT", self.guideBack, "RIGHT", 6, 0)
    self.guideNext:SetScript("OnClick", function()
        local step = tonumber(settings().guidedStep) or 1
        if step >= #GUIDE_STEPS then self:SetGuided(false) else self:SetGuideStep(step + 1) end
    end)
end

function BOD.Sidecar:ApplyGuidedLayout()
    if not self.frame or not self.guidePanel then return end
    local guided = settings().guidedMode == true
    self.frame:SetHeight(guided and GUIDED_HEIGHT or HEIGHT)
    if guided then self.guidePanel:Show() else self.guidePanel:Hide() end
    for _, panel in pairs(self.panels) do
        panel:ClearAllPoints()
        if guided then panel:SetPoint("TOPLEFT", self.guidePanel, "BOTTOMLEFT", 0, -10)
        else panel:SetPoint("TOPLEFT", self.viewButtons.PLAN, "BOTTOMLEFT", 0, -12) end
    end
    if self.guideToggle then
        self.guideToggle:SetText(guided and "Guided: ON" or "Guided: OFF")
        if guided then self.guideToggle:LockHighlight() else self.guideToggle:UnlockHighlight() end
    end
end

function BOD.Sidecar:RefreshGuide()
    if not self.guidePanel or settings().guidedMode ~= true then return end
    local stepNumber = math.max(1, math.min(#GUIDE_STEPS, math.floor(tonumber(settings().guidedStep) or 1)))
    local step = GUIDE_STEPS[stepNumber]
    self.guideTitle:SetText(string.format("GUIDED · STEP %d OF %d · %s", stepNumber, #GUIDE_STEPS, step.title))
    self.guideText:SetText(step.text)
    self.guideBack:SetEnabled(stepNumber > 1)
    self.guideNext:SetText(stepNumber == #GUIDE_STEPS and "Finish" or "Next")
end

function BOD.Sidecar:SetGuideStep(stepNumber)
    stepNumber = math.max(1, math.min(#GUIDE_STEPS, math.floor(tonumber(stepNumber) or 1)))
    settings().guidedStep = stepNumber
    local view = GUIDE_STEPS[stepNumber].view
    if view and self.panels[view] then
        self.activeView = view
        settings().sidecarView = view
    end
    self:Refresh()
end

function BOD.Sidecar:SetGuided(enabled)
    settings().guidedMode = enabled and true or false
    if enabled then settings().guidedStep = 1 end
    self:ApplyGuidedLayout()
    self:ApplyLayout()
    if enabled then self:SetGuideStep(settings().guidedStep) else self:Refresh() end
end

function BOD.Sidecar:EnsureCreated()
    if self.frame then return end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "BankOfDurotarSidecar", UIParent, template)
    self.frame = frame
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() if not self.docked then frame:StartMoving() end end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); self:SavePosition() end)
    setBackdrop(frame)

    local title = font(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -15)
    title:SetText("Bank of Durotar")
    local subtitle = font(frame, "GameFontDisableSmall")
    subtitle:SetPoint("LEFT", title, "RIGHT", 10, -1)
    subtitle:SetText("Auction House advisor")
    self.guideToggle = button(frame, "Guided: OFF", 102, 22)
    self.guideToggle:SetPoint("TOPRIGHT", -48, -12)
    self.guideToggle:SetScript("OnClick", function() self:SetGuided(settings().guidedMode ~= true) end)
    local close = button(frame, "X", 28, 22)
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetScript("OnClick", function() self:Hide() end)

    self.scanButton = button(frame, "SCAN MARKET", 170, 34)
    self.scanButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    self.scanButton:SetScript("OnClick", function() self:SaveBudget(false); BOD.FullScanProbe:StartFromPlayerClick() end)
    self.status = font(frame, "GameFontHighlightSmall")
    self.status:SetPoint("TOPLEFT", self.scanButton, "TOPRIGHT", 14, -2)
    self.status:SetSize(290, 48)

    local tabs = { { "PLAN", "Plan" }, { "CRAFT", "Craft" }, { "SELL", "Sell Price" } }
    local previous
    for index, tab in ipairs(tabs) do
        local tabButton = button(frame, tab[2], 152, 28)
        self.viewButtons[tab[1]] = tabButton
        if index == 1 then tabButton:SetPoint("TOPLEFT", self.scanButton, "BOTTOMLEFT", 0, -12)
        else tabButton:SetPoint("LEFT", previous, "RIGHT", 8, 0) end
        tabButton:SetScript("OnClick", function() self:SetView(tab[1]) end)
        previous = tabButton
    end

    self:CreatePlanPanel(frame, self.viewButtons.PLAN)
    self:CreateCraftPanel(frame, self.viewButtons.PLAN)
    self:CreateSellPanel(frame, self.viewButtons.PLAN)
    self:CreateGuidePanel(frame, self.viewButtons.PLAN)
    self:InstallItemClickHook()
    frame:Hide()
    self:ApplyGuidedLayout()
    self:ApplyLayout()
end

function BOD.Sidecar:ApplyLayout()
    if not self.frame then return end
    local ah = getAuctionFrame()
    self.frame:ClearAllPoints()
    self.frame:SetParent(UIParent)
    self.docked = settings().dockToAuctionHouse and ah and ah:IsShown() and canDock(ah)
    if self.docked then
        self.frame:SetParent(ah)
        self.frame:SetPoint("TOPLEFT", ah, "TOPRIGHT", 4, -12)
    else
        local position = settings().sidecarPosition or {}
        self.frame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER", position.x or 0, position.y or 0)
    end
end

function BOD.Sidecar:SavePosition()
    if not self.frame or self.docked then return end
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    settings().sidecarPosition = { point = point or "CENTER", relativePoint = relativePoint or "CENTER", x = math.floor((x or 0) + 0.5), y = math.floor((y or 0) + 0.5) }
end

function BOD.Sidecar:SetView(view)
    if not self.panels[view] then view = "PLAN" end
    self.activeView = view
    settings().sidecarView = view
    self:Refresh()
end

function BOD.Sidecar:ShowView()
    for key, panel in pairs(self.panels) do if key == self.activeView then panel:Show() else panel:Hide() end end
    for key, tab in pairs(self.viewButtons) do
        if key == self.activeView then
            tab:LockHighlight()
            if tab:GetFontString() then tab:GetFontString():SetTextColor(1, 0.82, 0) end
        else
            tab:UnlockHighlight()
            if tab:GetFontString() then tab:GetFontString():SetTextColor(1, 1, 1) end
        end
    end
end

function BOD.Sidecar:Show()
    self:EnsureCreated(); self:ApplyLayout(); self.frame:Show(); self:SetView(settings().sidecarView)
end
function BOD.Sidecar:Hide() if self.frame then self.frame:Hide() end end
function BOD.Sidecar:Toggle() self:EnsureCreated(); if self.frame:IsShown() then self:Hide() else self:Show() end end

function BOD.Sidecar:SaveBudget(refresh)
    if not self.budgetBox then return end
    local gold = math.max(1, math.floor(tonumber(self.budgetBox:GetText()) or 0))
    local copper = math.min(MAX_SAFE_INTEGER, gold * COPPER_PER_GOLD)
    settings().goldBudgetCopper = copper
    self.budgetBox:SetText(tostring(math.floor(copper / COPPER_PER_GOLD)))
    if refresh ~= false then self:RefreshPlan() end
end

function BOD.Sidecar:RefreshPlan()
    if self.activeView ~= "PLAN" then return end
    local plan = BOD.GoldPlan:Build(settings().goldBudgetCopper)
    if plan.status == "INVALID_BUDGET" then
        self.planSummary:SetText("Enter a gold budget of 1 or more.")
    elseif plan.status == "NO_DATA" then
        self.planSummary:SetText("Budget: " .. BOD:FormatMoney(plan.budgetCopper) .. "  |  Scan the market first.\n" .. marketMemoryLabel())
    else
        self.planSummary:SetText("Budget: " .. BOD:FormatMoney(plan.budgetCopper) .. "  |  Planned: " .. BOD:FormatMoney(plan.investedCopper) .. "  |  Left: " .. BOD:FormatMoney(plan.remainingCopper) .. "\n" .. marketMemoryLabel())
    end

    for index, row in ipairs(self.buyRows) do
        local buy = plan.buys[index]
        if buy then
            local outcomes = tonumber(buy.personalOutcomeCount) or 0
            local historyText = outcomes >= 3 and string.format("sold %d/%d for you", tonumber(buy.personalSoldCount) or 0, outcomes) or (tostring(buy.confidence):lower() .. " confidence")
            setRow(row, string.format("|cffffd100%d  %s × %d|r  ·  Flip score %d/100\nBuy stack for %s or less  ·  Sell near %s each  ·  Profit ~%s\n%d%% return  ·  %d listings now  ·  %d scans  ·  %s", index, tostring(buy.itemName or buy.itemKey), tonumber(buy.currentQuantity) or 0, tonumber(buy.flipScore) or 0, BOD:FormatMoney(buy.capitalRequired), BOD:FormatMoney(buy.resaleTargetUnitPrice), BOD:FormatMoney(buy.estimatedTotalUpside), math.floor((tonumber(buy.profitRate) or 0) * 100), tonumber(buy.listingCount) or 0, tonumber(buy.historyObservationCount) or 0, historyText))
        else
            setRow(row, index == 1 and "No safe buys found. It is better to wait than force a purchase." or "")
        end
    end
    if self.buyScrollChild then
        self.buyScrollChild:SetHeight(math.max(144, math.max(1, #plan.buys) * 52))
        local maximum = math.max(0, (math.max(1, #plan.buys) * 52) - 144)
        if (self.buyScroll:GetVerticalScroll() or 0) > maximum then self.buyScroll:SetVerticalScroll(maximum) end
    end

    for index, row in ipairs(self.bagRows) do
        local sell = plan.sells[index]
        if sell then
            if sell.saleMethod == "VENDOR" then
                setRow(row, string.format("|cffffd100%d  Vendor %s × %d|r\nReceive %s  ·  Better than the expected Auction House return", index, tostring(sell.itemName), tonumber(sell.stackCount) or 0, BOD:FormatMoney(sell.stackPrice)))
            else
                setRow(row, string.format("|cffffd100%d  Sell %s × %d|r\nList at %s  ·  %s each  ·  %s confidence", index, tostring(sell.itemName), tonumber(sell.stackCount) or 0, BOD:FormatMoney(sell.stackPrice), BOD:FormatMoney(sell.unitPrice), tostring(sell.confidence):lower()))
            end
        else
            setRow(row, index == 1 and "No bag items have enough reliable market data yet." or "")
        end
    end
end

function BOD.Sidecar:RefreshCraft()
    if self.activeView ~= "CRAFT" then return end
    local result = BOD.CraftingService:GetRecommendations(CRAFT_ROWS, settings().goldBudgetCopper)
    if result.status == "NO_RECIPES" then
        self.craftSummary:SetText("No recipes learned yet. Open each profession window once.\n" .. marketMemoryLabel())
    elseif result.status == "NO_DATA" then
        self.craftSummary:SetText("Recipes learned. Scan the market to calculate profit.\n" .. marketMemoryLabel())
    elseif result.status == "EMPTY" then
        self.craftSummary:SetText(string.format("Checked %d recipes. None currently clears a 15%% margin.\n%s", result.recipeCount or 0, marketMemoryLabel()))
    else
        self.craftSummary:SetText(string.format("Found profitable crafts from %d learned profession lists.\n%s", result.professionCount or 0, marketMemoryLabel()))
    end

    for index, row in ipairs(self.craftRows) do
        local craft = result.recommendations[index]
        if craft then
            setRow(row, string.format("|cffffd100%d  %s × %d|r  ·  %s\nMaterials: %s  ·  Sell: %s\nProfit ~%s  ·  %d%% margin  ·  %s confidence", index, tostring(craft.outputName), tonumber(craft.outputCount) or 1, tostring(craft.profession), BOD:FormatMoney(craft.reagentCost), BOD:FormatMoney(craft.sellPrice), BOD:FormatMoney(craft.estimatedProfit), math.floor((tonumber(craft.marginRate) or 0) * 100), tostring(craft.confidence):lower()))
        else
            setRow(row, "")
        end
    end
end

function BOD.Sidecar:SelectSellItem(text)
    local item = BOD.MarketData:FindItemByText(text)
    self.selectedItemKey = item and item.itemKey or nil
    self.selectedItemLink = item and text or nil
    if item then
        local name, canonicalLink, texture
        if type(GetItemInfo) == "function" then
            local itemInfo = { GetItemInfo(text) }
            name, canonicalLink, texture = itemInfo[1], itemInfo[2], itemInfo[10]
            if not name and item.itemID then
                itemInfo = { GetItemInfo(item.itemID) }
                name, canonicalLink, texture = itemInfo[1], itemInfo[2], itemInfo[10]
            end
        end
        name = name or item.itemName or "Chosen item"
        self.selectedItemLink = canonicalLink or text
        self.sellItemBox:SetText(tostring(name))
        self.sellDropIcon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.sellDropName:SetText(tostring(name))
        self.sellDropHelp:SetText("Good. Now type how many you are selling in step 2.")
    else
        self.sellDropIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.sellDropName:SetText("ITEM NOT FOUND")
        self.sellDropHelp:SetText("Scan the market first, then drag the item here again.")
    end
    self:RefreshSell()
end

function BOD.Sidecar:RefreshSell()
    if self.activeView ~= "SELL" then return end
    if not self.selectedItemKey then self.sellText:SetText("Choose an item in step 1. Your selling price will appear here."); return end
    local recommendation = BOD.PricingService:GetRecommendation(self.selectedItemKey, tonumber(self.sellStackBox:GetText()) or 1, { strategy = "SMALL_UNDERCUT" })
    if recommendation.status == "RECOMMENDED" then
        self.sellText:SetText(table.concat({
            "|cffffd100LIST THE WHOLE STACK FOR " .. BOD:FormatMoney(recommendation.stackBuyout) .. "|r",
            "That is " .. BOD:FormatMoney(recommendation.unitBuyout) .. " for each item.",
            "",
            "In Blizzard's sell window:",
            "1. Put the item in the auction slot.",
            "2. Type " .. BOD:FormatMoney(recommendation.stackBuyout) .. " for both Bid and Buyout.",
            "3. Click Create Auction.",
            "",
            "Price confidence: " .. tostring(recommendation.confidence):lower() .. " · Scan age: " .. ageLabel(recommendation.dataAgeSeconds),
        }, "\n"))
    elseif recommendation.status == "REFRESH_DATA" then self.sellText:SetText("Your market data is old. Scan again before listing this item.")
    elseif recommendation.status == "INVALID_QUANTITY" then self.sellText:SetText("Enter the actual stack size.")
    else self.sellText:SetText("There is not enough reliable market data for this item yet.") end
end

function BOD.Sidecar:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self:ShowView()
    self:RefreshGuide()
    local lines, cooldown = BOD.FullScanProbe:GetCooldownStatusLines()
    self.status:SetText(table.concat(lines, "\n"))
    self.scanButton:SetText(BOD.FullScanProbe:GetPrimaryButtonText())
    self.scanButton:SetEnabled(BOD.FullScanProbe.active or (cooldown.state == "READY" and cooldown.canQueryAll == true))
    self:RefreshPlan(); self:RefreshCraft(); self:RefreshSell()
end

function BOD.Sidecar:OnEvent(event)
    if event == "ADDON_LOADED" then self:EnsureCreated()
    elseif event == "PLAYER_LOGIN" then self:InstallItemClickHook()
    elseif event == "AUCTION_HOUSE_SHOW" then if settings().openWithAuctionHouse then self:Show() end
    elseif event == "AUCTION_HOUSE_CLOSED" then self:Hide()
    elseif event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then self:Refresh() end
end
