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
    selectedShopItemKey = nil,
    selectedShopItemLink = nil,
    selectedTradeId = nil,
    selectedTradeRecommendation = nil,
    tradeActionStatus = nil,
}

local WIDTH, HEIGHT = 520, 640
local BUY_ROWS, SELL_ROWS, CRAFT_ROWS = 10, 3, 3
local GUIDED_HEIGHT = 716
local MAX_SAFE_INTEGER = 2147483647

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

local function planMoneyBox(parent, width, denomination, helpText)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 24)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetText("0")
    box:SetScript("OnEditFocusGained", function(value) value:HighlightText() end)
    box:SetScript("OnEditFocusLost", function(value) if value:GetText() == "" then value:SetText("0") end end)
    box:SetScript("OnEnter", function(value)
        if not GameTooltip then return end
        GameTooltip:SetOwner(value, "ANCHOR_TOP")
        GameTooltip:SetText(denomination)
        GameTooltip:AddLine(helpText, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return box
end

local function moneySuffix(parent, anchor, text)
    local value = font(parent, "GameFontNormalSmall")
    value:SetPoint("LEFT", anchor, "RIGHT", 3, 0)
    value:SetText(text)
    return value
end

local function recommendationRow(parent, height, width, withIcon)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local container = CreateFrame("Frame", nil, parent, template)
    container:SetSize(width or 475, height)
    if container.SetBackdrop then
        container:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        container:SetBackdropColor(0.10, 0.075, 0.045, 0.72)
    end

    local value = font(container, "GameFontHighlightSmall")
    if withIcon then
        value.icon = container:CreateTexture(nil, "ARTWORK")
        value.icon:SetSize(36, 36)
        value.icon:SetPoint("LEFT", 8, 0)
        value.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        value:SetPoint("TOPLEFT", value.icon, "TOPRIGHT", 9, -1)
        container:EnableMouse(true)
        container:SetScript("OnEnter", function()
            if GameTooltip and (value.itemLink or value.helpLines) then
                GameTooltip:SetOwner(container, "ANCHOR_LEFT")
                if value.itemLink then
                    GameTooltip:SetHyperlink(value.itemLink)
                else
                    GameTooltip:SetText(value.helpTitle or "Bank of Durotar")
                end
                for _, line in ipairs(value.helpLines or {}) do
                    GameTooltip:AddLine(line, 1, 1, 1, true)
                end
                GameTooltip:Show()
            end
        end)
        container:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    else
        value:SetPoint("TOPLEFT", 10, -7)
    end
    value:SetPoint("BOTTOMRIGHT", -8, 5)
    value.container = container
    return value
end

local function setRow(row, text)
    text = tostring(text or "")
    row:SetText(text)
    if text == "" then row.container:Hide() else row.container:Show() end
end

local function setRowIcon(row, itemID, knownItemLink)
    if not row.icon then return end
    local texture, itemLink = nil, knownItemLink
    if itemID and type(GetItemIcon) == "function" then texture = GetItemIcon(itemID) end
    if itemID and type(GetItemInfo) == "function" then
        local cachedLink = select(2, GetItemInfo(itemID))
        if cachedLink then itemLink = cachedLink end
        if not texture then texture = select(10, GetItemInfo(itemID)) end
    end
    row.itemLink = itemLink
    row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
end

local function setRowHelp(row, title, lines)
    row.helpTitle = title
    row.helpLines = lines
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

local function trustLabel(value)
    local labels = { STRONG = "Strong", FAIR = "Fair", SPECULATIVE = "Speculative", AVOID = "Avoid" }
    return labels[tostring(value or "AVOID"):upper()] or "Avoid"
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

    local budgetHelp = "The maximum amount Bank of Durotar may recommend spending on a quick Plan action."
    self.budgetMoneyBoxes = {
        gold = planMoneyBox(panel, 48, "Gold", budgetHelp),
        silver = planMoneyBox(panel, 28, "Silver", budgetHelp),
        copper = planMoneyBox(panel, 28, "Copper", budgetHelp),
    }
    self.budgetMoneyBoxes.gold:SetPoint("LEFT", budgetLabel, "RIGHT", 5, 0)
    local budgetGoldSuffix = moneySuffix(panel, self.budgetMoneyBoxes.gold, "G")
    self.budgetMoneyBoxes.silver:SetPoint("LEFT", budgetGoldSuffix, "RIGHT", 4, 0)
    local budgetSilverSuffix = moneySuffix(panel, self.budgetMoneyBoxes.silver, "S")
    self.budgetMoneyBoxes.copper:SetPoint("LEFT", budgetSilverSuffix, "RIGHT", 4, 0)
    local budgetCopperSuffix = moneySuffix(panel, self.budgetMoneyBoxes.copper, "C")

    local minimumLabel = font(panel, "GameFontNormalSmall")
    minimumLabel:SetPoint("LEFT", budgetCopperSuffix, "RIGHT", 10, 0)
    minimumLabel:SetText("Min Profit")
    local profitHelp = "The minimum estimated net profit required before Plan recommends an action. Evaluated after known Auction House cuts and modeled costs where available."
    self.minimumProfitMoneyBoxes = {
        gold = planMoneyBox(panel, 48, "Gold", profitHelp),
        silver = planMoneyBox(panel, 28, "Silver", profitHelp),
        copper = planMoneyBox(panel, 28, "Copper", profitHelp),
    }
    self.minimumProfitMoneyBoxes.gold:SetPoint("LEFT", minimumLabel, "RIGHT", 5, 0)
    local profitGoldSuffix = moneySuffix(panel, self.minimumProfitMoneyBoxes.gold, "G")
    self.minimumProfitMoneyBoxes.silver:SetPoint("LEFT", profitGoldSuffix, "RIGHT", 4, 0)
    local profitSilverSuffix = moneySuffix(panel, self.minimumProfitMoneyBoxes.silver, "S")
    self.minimumProfitMoneyBoxes.copper:SetPoint("LEFT", profitSilverSuffix, "RIGHT", 4, 0)
    local profitCopperSuffix = moneySuffix(panel, self.minimumProfitMoneyBoxes.copper, "C")

    local apply = button(panel, "Apply", 62, 24)
    apply:SetPoint("LEFT", profitCopperSuffix, "RIGHT", 8, 0)
    apply:SetScript("OnClick", function() self:SaveBudget() end)
    self.planApplyButton = apply

    local order = {
        self.budgetMoneyBoxes.gold, self.budgetMoneyBoxes.silver, self.budgetMoneyBoxes.copper,
        self.minimumProfitMoneyBoxes.gold, self.minimumProfitMoneyBoxes.silver, self.minimumProfitMoneyBoxes.copper,
    }
    for index, box in ipairs(order) do
        local nextBox = order[index + 1]
        box:SetScript("OnEnterPressed", function(value) self:SaveBudget(); value:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(value) self:LoadPlanMoneyFields(); value:ClearFocus() end)
        box:SetScript("OnTabPressed", function(value)
            value:ClearFocus()
            if nextBox then nextBox:SetFocus() else self:SaveBudget() end
        end)
    end

    self:LoadPlanMoneyFields()

    self.planSummary = font(panel, "GameFontHighlightSmall")
    self.planSummary:SetPoint("TOPLEFT", budgetLabel, "BOTTOMLEFT", 0, -12)
    self.planSummary:SetSize(475, 30)

    local bestHeader = sectionLabel(panel, "BEST MOVE NOW")
    bestHeader:SetPoint("TOPLEFT", self.planSummary, "BOTTOMLEFT", 0, -8)
    self.viewTradeButton = button(panel, "View Trade", 92, 20)
    self.viewTradeButton:SetPoint("LEFT", bestHeader, "LEFT", 380, 0)
    self.viewTradeButton:SetScript("OnClick", function() self:SetView("TRADES") end)
    self.viewTradeButton:Hide()
    self.bestMoveRow = recommendationRow(panel, 82, 475, true)
    self.bestMoveRow.container:SetPoint("TOPLEFT", bestHeader, "BOTTOMLEFT", 0, -7)

    local buyHeader = sectionLabel(panel, "MORE SAFE FLIPS")
    buyHeader:SetPoint("TOPLEFT", self.bestMoveRow.container, "BOTTOMLEFT", 0, -8)
    local buyScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    self.buyScroll = buyScroll
    buyScroll:SetPoint("TOPLEFT", buyHeader, "BOTTOMLEFT", 0, -7)
    buyScroll:SetSize(462, 92)
    buyScroll:EnableMouseWheel(true)
    local buyScrollChild = CreateFrame("Frame", nil, buyScroll)
    self.buyScrollChild = buyScrollChild
    buyScrollChild:SetSize(438, (BUY_ROWS - 1) * 52)
    buyScroll:SetScrollChild(buyScrollChild)
    buyScroll:SetScript("OnMouseWheel", function(scroll, delta)
        local maximum = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or math.max(0, ((BUY_ROWS - 1) * 52) - 92)
        local nextValue = math.max(0, math.min(maximum, (scroll:GetVerticalScroll() or 0) - (delta * 52)))
        scroll:SetVerticalScroll(nextValue)
        local scrollBar = scroll.ScrollBar or scroll.scrollBar
        if scrollBar and scrollBar.SetValue then scrollBar:SetValue(nextValue) end
    end)
    for index = 1, BUY_ROWS - 1 do
        local row = recommendationRow(buyScrollChild, 48, 432, true)
        row.container:SetPoint("TOPLEFT", 0, -((index - 1) * 52))
        self.buyRows[index] = row
    end

    local bagHeader = sectionLabel(panel, "SELL These Items From Your Bags")
    bagHeader:SetPoint("TOPLEFT", buyScroll, "BOTTOMLEFT", 0, -10)
    for index = 1, SELL_ROWS do
        local row = recommendationRow(panel, 38, nil, true)
        row.container:SetPoint("TOPLEFT", bagHeader, "BOTTOMLEFT", 0, -7 - ((index - 1) * 42))
        self.bagRows[index] = row
    end

    self.planNote = font(panel, "GameFontDisableSmall")
    self.planNote:SetPoint("TOPLEFT", self.bagRows[SELL_ROWS].container, "BOTTOMLEFT", 0, -7)
    self.planNote:SetSize(475, 24)
    self.planNote:SetText("Flip score estimates resale ease; demand is never guaranteed. Buy and post manually.")
end

local function tradeStateLabel(value)
    return tostring(value or "WATCHING"):gsub("_", " "):lower():gsub("^%l", string.upper)
end

local function rateLabel(value)
    return tostring(math.floor((tonumber(value) or 0) * 100 + 0.5)) .. "%"
end

local function signedMoney(value)
    value = math.floor(tonumber(value) or 0)
    return value < 0 and ("-" .. BOD:FormatMoney(-value)) or BOD:FormatMoney(value)
end

function BOD.Sidecar:CreateTradesPanel(frame, anchor)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    panel:SetSize(488, 460)
    self.panels.TRADES = panel

    local heading = font(panel, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 4, -4)
    heading:SetText("Trades")
    local rulesButton = button(panel, "Trade Rules", 100, 22)
    rulesButton:SetPoint("TOPRIGHT", -8, -1)
    rulesButton:SetScript("OnClick", function() self:SetTradeRulesOpen(true) end)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    scroll:SetSize(462, 425)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(438, 940)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnMouseWheel", function(value, delta)
        local maximum = value.GetVerticalScrollRange and value:GetVerticalScrollRange() or 365
        value:SetVerticalScroll(math.max(0, math.min(maximum, (value:GetVerticalScroll() or 0) - delta * 52)))
    end)
    self.tradeScroll = scroll

    local capitalHeader = sectionLabel(child, "TRADING CAPITAL")
    capitalHeader:SetPoint("TOPLEFT", 0, 0)
    self.tradeCapitalText = font(child, "GameFontHighlightSmall")
    self.tradeCapitalText:SetPoint("TOPLEFT", capitalHeader, "BOTTOMLEFT", 0, -6)
    self.tradeCapitalText:SetSize(430, 68)

    local bestHeader = sectionLabel(child, "BEST TRADE")
    bestHeader:SetPoint("TOPLEFT", self.tradeCapitalText, "BOTTOMLEFT", 0, -8)
    self.bestTradeRow = recommendationRow(child, 158, 432, true)
    self.bestTradeRow.container:SetPoint("TOPLEFT", bestHeader, "BOTTOMLEFT", 0, -6)
    self.findTradeButton = button(child, "Find Auctions", 112, 24)
    self.findTradeButton:SetPoint("TOPLEFT", self.bestTradeRow.container, "BOTTOMLEFT", 0, -6)
    self.findTradeButton:SetScript("OnClick", function() self:FindSelectedTrade() end)
    self.trackTradeButton = button(child, "Track Trade", 105, 24)
    self.trackTradeButton:SetPoint("LEFT", self.findTradeButton, "RIGHT", 8, 0)
    self.trackTradeButton:SetScript("OnClick", function() self:TrackSelectedTrade() end)
    self.tradeStatusText = font(child, "GameFontDisableSmall")
    self.tradeStatusText:SetPoint("LEFT", self.trackTradeButton, "RIGHT", 10, 0)
    self.tradeStatusText:SetSize(190, 30)

    local moreHeader = sectionLabel(child, "MORE TRADES · click one to select it")
    moreHeader:SetPoint("TOPLEFT", self.findTradeButton, "BOTTOMLEFT", 0, -10)
    self.additionalTradeRows = {}
    for index = 1, 2 do
        local rowIndex = index
        local row = recommendationRow(child, 66, 432, true)
        row.container:SetPoint("TOPLEFT", moreHeader, "BOTTOMLEFT", 0, -6 - ((index - 1) * 72))
        row.container:SetScript("OnMouseUp", function() self:SelectTradeRecommendation(rowIndex + 1) end)
        self.additionalTradeRows[index] = row
    end

    local openHeader = sectionLabel(child, "OPEN TRADES · click one to manage it")
    openHeader:SetPoint("TOPLEFT", self.additionalTradeRows[2].container, "BOTTOMLEFT", 0, -10)
    self.openTradeRows = {}
    for index = 1, 5 do
        local rowIndex = index
        local row = recommendationRow(child, 48, 432, true)
        row.container:SetPoint("TOPLEFT", openHeader, "BOTTOMLEFT", 0, -6 - ((index - 1) * 54))
        row.container:SetScript("OnMouseUp", function() self:SelectOpenTrade(rowIndex) end)
        self.openTradeRows[index] = row
    end

    local actionAnchor = self.openTradeRows[5].container
    local buyQtyLabel = sectionLabel(child, "Purchased qty")
    buyQtyLabel:SetPoint("TOPLEFT", actionAnchor, "BOTTOMLEFT", 0, -10)
    self.tradeBuyQtyBox = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    self.tradeBuyQtyBox:SetSize(44, 22); self.tradeBuyQtyBox:SetPoint("LEFT", buyQtyLabel, "RIGHT", 7, 0); self.tradeBuyQtyBox:SetNumeric(true); self.tradeBuyQtyBox:SetAutoFocus(false); self.tradeBuyQtyBox:SetText("1")
    local buyPriceLabel = sectionLabel(child, "Unit silver")
    buyPriceLabel:SetPoint("LEFT", self.tradeBuyQtyBox, "RIGHT", 10, 0)
    self.tradeBuyPriceBox = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    self.tradeBuyPriceBox:SetSize(56, 22); self.tradeBuyPriceBox:SetPoint("LEFT", buyPriceLabel, "RIGHT", 7, 0); self.tradeBuyPriceBox:SetNumeric(true); self.tradeBuyPriceBox:SetAutoFocus(false); self.tradeBuyPriceBox:SetText("0")
    local addPurchase = button(child, "Mark Purchased", 112, 22)
    addPurchase:SetPoint("LEFT", self.tradeBuyPriceBox, "RIGHT", 8, 0)
    addPurchase:SetScript("OnClick", function() self:AddTradePurchase() end)

    local saleQtyLabel = sectionLabel(child, "Sold qty")
    saleQtyLabel:SetPoint("TOPLEFT", buyQtyLabel, "BOTTOMLEFT", 0, -12)
    self.tradeSaleQtyBox = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    self.tradeSaleQtyBox:SetSize(44, 22); self.tradeSaleQtyBox:SetPoint("LEFT", saleQtyLabel, "RIGHT", 7, 0); self.tradeSaleQtyBox:SetNumeric(true); self.tradeSaleQtyBox:SetAutoFocus(false); self.tradeSaleQtyBox:SetText("1")
    local revenueLabel = sectionLabel(child, "Net silver")
    revenueLabel:SetPoint("LEFT", self.tradeSaleQtyBox, "RIGHT", 10, 0)
    self.tradeSaleRevenueBox = CreateFrame("EditBox", nil, child, "InputBoxTemplate")
    self.tradeSaleRevenueBox:SetSize(56, 22); self.tradeSaleRevenueBox:SetPoint("LEFT", revenueLabel, "RIGHT", 7, 0); self.tradeSaleRevenueBox:SetNumeric(true); self.tradeSaleRevenueBox:SetAutoFocus(false); self.tradeSaleRevenueBox:SetText("0")
    local recordSale = button(child, "Record Sale", 92, 22)
    recordSale:SetPoint("LEFT", self.tradeSaleRevenueBox, "RIGHT", 8, 0)
    recordSale:SetScript("OnClick", function() self:RecordTradeSale() end)

    local listed = button(child, "Mark Listed", 92, 22)
    listed:SetPoint("TOPLEFT", saleQtyLabel, "BOTTOMLEFT", 0, -12)
    listed:SetScript("OnClick", function() self:MarkTradeListed() end)
    local closeTrade = button(child, "Close", 72, 22)
    closeTrade:SetPoint("LEFT", listed, "RIGHT", 8, 0)
    closeTrade:SetScript("OnClick", function() self:CloseSelectedTrade(false) end)
    local abandonTrade = button(child, "Abandon", 78, 22)
    abandonTrade:SetPoint("LEFT", closeTrade, "RIGHT", 8, 0)
    abandonTrade:SetScript("OnClick", function() self:CloseSelectedTrade(true) end)

    local historyHeader = sectionLabel(child, "TRADE HISTORY")
    historyHeader:SetPoint("TOPLEFT", listed, "BOTTOMLEFT", 0, -12)
    self.tradeHistoryRows = {}
    for index = 1, 2 do
        local row = recommendationRow(child, 48, 432, true)
        row.container:SetPoint("TOPLEFT", historyHeader, "BOTTOMLEFT", 0, -6 - ((index - 1) * 54))
        self.tradeHistoryRows[index] = row
    end

    self:CreateTradeRulesPanel(panel)
end

function BOD.Sidecar:CreateTradeRulesPanel(parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local panel = CreateFrame("Frame", nil, parent, template)
    self.tradeRulesPanel = panel
    panel:SetPoint("TOPLEFT", 0, -30)
    panel:SetSize(480, 430)
    if panel.SetBackdrop then
        panel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        panel:SetBackdropColor(0.07, 0.05, 0.025, 0.98)
    end
    local title = sectionLabel(panel, "TRADE RULES")
    title:SetPoint("TOPLEFT", 12, -12)
    local help = font(panel, "GameFontDisableSmall")
    help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    help:SetText("Balanced defaults are recommended. Zero capital caps use the selected risk mode.")

    self.tradeEnabledButton = button(panel, "Enabled", 92, 22)
    self.tradeEnabledButton:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
    self.tradeEnabledButton:SetScript("OnClick", function()
        local value = BOD.TradeService:GetSettings(); value.enabled = value.enabled == false; self:RefreshTradeRules()
    end)
    self.tradeRiskButton = button(panel, "Balanced", 112, 22)
    self.tradeRiskButton:SetPoint("LEFT", self.tradeEnabledButton, "RIGHT", 8, 0)
    self.tradeRiskButton:SetScript("OnClick", function()
        local value = BOD.TradeService:GetSettings()
        value.riskMode = value.riskMode == "CONSERVATIVE" and "BALANCED" or (value.riskMode == "BALANCED" and "AGGRESSIVE" or "CONSERVATIVE")
        self:RefreshTradeRules()
    end)
    self.tradeSpecButton = button(panel, "Speculative: OFF", 125, 22)
    self.tradeSpecButton:SetPoint("LEFT", self.tradeRiskButton, "RIGHT", 8, 0)
    self.tradeSpecButton:SetScript("OnClick", function()
        local value = BOD.TradeService:GetSettings(); value.showSpeculativeTrades = value.showSpeculativeTrades ~= true; self:RefreshTradeRules()
    end)

    local function editRow(labelText, y, width)
        local label = sectionLabel(panel, labelText)
        label:SetPoint("TOPLEFT", 12, y)
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(width or 72, 22); box:SetPoint("LEFT", label, "LEFT", 205, 0); box:SetNumeric(true); box:SetAutoFocus(false)
        return box
    end
    self.tradeReserveBox = editRow("Emergency reserve (gold)", -88)
    self.tradePerCapBox = editRow("Maximum per trade (gold, 0 = mode)", -116)
    self.tradeTotalCapBox = editRow("Maximum committed (gold, 0 = mode)", -144)
    self.tradeMaxOpenBox = editRow("Maximum open trades", -172, 52)
    self.tradeMinProfitBox = editRow("Minimum low-case profit (silver)", -200)
    self.tradeMinDiscountBox = editRow("Minimum discount (%)", -228, 52)
    self.tradeMinObservationsBox = editRow("Minimum observations", -256, 52)
    self.tradeRetentionBox = editRow("History entries retained", -284, 52)
    self.tradeMaxAgeBox = editRow("Maximum scan age (hours)", -312, 52)

    local demandLabel = sectionLabel(panel, "Minimum demand")
    demandLabel:SetPoint("TOPLEFT", 300, -88)
    self.tradeDemandButton = button(panel, "Active", 105, 22)
    self.tradeDemandButton:SetPoint("TOPLEFT", demandLabel, "BOTTOMLEFT", 0, -5)
    self.tradeDemandButton:SetScript("OnClick", function()
        local value = BOD.TradeService:GetSettings()
        value.minimumDemand = value.minimumDemand == "SLOW" and "ACTIVE" or (value.minimumDemand == "ACTIVE" and "HOT" or "SLOW")
        self:RefreshTradeRules()
    end)
    local confidenceLabel = sectionLabel(panel, "Minimum confidence")
    confidenceLabel:SetPoint("TOPLEFT", self.tradeDemandButton, "BOTTOMLEFT", 0, -12)
    self.tradeConfidenceButton = button(panel, "Fair", 105, 22)
    self.tradeConfidenceButton:SetPoint("TOPLEFT", confidenceLabel, "BOTTOMLEFT", 0, -5)
    self.tradeConfidenceButton:SetScript("OnClick", function()
        local value = BOD.TradeService:GetSettings()
        value.minimumConfidence = value.minimumConfidence == "SPECULATIVE" and "FAIR" or (value.minimumConfidence == "FAIR" and "STRONG" or "SPECULATIVE")
        self:RefreshTradeRules()
    end)

    self.tradeRulesStatus = font(panel, "GameFontHighlightSmall")
    self.tradeRulesStatus:SetPoint("BOTTOMLEFT", 12, 47)
    self.tradeRulesStatus:SetSize(250, 32)
    local apply = button(panel, "Apply Rules", 100, 24)
    apply:SetPoint("BOTTOMLEFT", 12, 14)
    apply:SetScript("OnClick", function() self:SaveTradeRules() end)
    self.tradeResetButton = button(panel, "Reset Trade Data", 125, 24)
    self.tradeResetButton:SetPoint("LEFT", apply, "RIGHT", 8, 0)
    self.tradeResetButton:SetScript("OnClick", function() self:ResetTradeData() end)
    local back = button(panel, "Back", 78, 24)
    back:SetPoint("BOTTOMRIGHT", -12, 14)
    back:SetScript("OnClick", function() self:SetTradeRulesOpen(false) end)
    panel:Hide()
end

function BOD.Sidecar:SetTradeRulesOpen(open)
    if not self.tradeRulesPanel then return end
    self.tradeRulesOpen = open == true
    if self.tradeRulesOpen then
        self.tradeScroll:Hide(); self.tradeRulesPanel:Show(); self:RefreshTradeRules()
    else
        self.tradeRulesPanel:Hide(); self.tradeScroll:Show(); self:RefreshTrades()
    end
end

function BOD.Sidecar:RefreshTradeRules()
    if not self.tradeRulesPanel then return end
    local value = BOD.TradeService:GetSettings()
    self.tradeEnabledButton:SetText(value.enabled == false and "Trades: OFF" or "Trades: ON")
    self.tradeRiskButton:SetText("Risk: " .. tostring(value.riskMode):lower():gsub("^%l", string.upper))
    self.tradeSpecButton:SetText(value.showSpeculativeTrades and "Speculative: ON" or "Speculative: OFF")
    self.tradeDemandButton:SetText(tostring(value.minimumDemand):lower():gsub("^%l", string.upper))
    self.tradeConfidenceButton:SetText(tostring(value.minimumConfidence):lower():gsub("^%l", string.upper))
    self.tradeReserveBox:SetText(tostring(math.floor((value.emergencyReserveCopper or 0) / 10000)))
    self.tradePerCapBox:SetText(tostring(math.floor((value.maximumCapitalPerTradeCopper or 0) / 10000)))
    self.tradeTotalCapBox:SetText(tostring(math.floor((value.maximumTotalCapitalCommittedCopper or 0) / 10000)))
    self.tradeMaxOpenBox:SetText(tostring(value.maxOpenTrades or 5))
    self.tradeMinProfitBox:SetText(tostring(math.floor((value.minimumAbsoluteProfitCopper or 0) / 100)))
    self.tradeMinDiscountBox:SetText(tostring(value.minimumDiscountPercent or 15))
    self.tradeMinObservationsBox:SetText(tostring(value.minimumObservationCount or 5))
    self.tradeRetentionBox:SetText(tostring(value.tradeHistoryRetention or 50))
    self.tradeMaxAgeBox:SetText(tostring(math.floor((value.maximumTradeDataAgeSeconds or 43200) / 3600)))
end

function BOD.Sidecar:SaveTradeRules()
    local value = BOD.TradeService:GetSettings()
    local function numeric(box, fallback) return math.max(0, math.floor(tonumber(box:GetText()) or fallback or 0)) end
    value.emergencyReserveCopper = math.min(MAX_SAFE_INTEGER, numeric(self.tradeReserveBox) * 10000)
    value.maximumCapitalPerTradeCopper = math.min(MAX_SAFE_INTEGER, numeric(self.tradePerCapBox) * 10000)
    value.maximumTotalCapitalCommittedCopper = math.min(MAX_SAFE_INTEGER, numeric(self.tradeTotalCapBox) * 10000)
    value.maxOpenTrades = math.max(1, math.min(5, numeric(self.tradeMaxOpenBox, 5)))
    value.minimumAbsoluteProfitCopper = math.min(MAX_SAFE_INTEGER, numeric(self.tradeMinProfitBox) * 100)
    value.minimumDiscountPercent = math.min(90, numeric(self.tradeMinDiscountBox, 15))
    value.minimumObservationCount = math.max(1, math.min(30, numeric(self.tradeMinObservationsBox, 5)))
    value.tradeHistoryRetention = math.max(1, math.min(500, numeric(self.tradeRetentionBox, 50)))
    value.maximumTradeDataAgeSeconds = math.max(0, math.min(86400, numeric(self.tradeMaxAgeBox, 12) * 3600))
    BOD.TradeService:Invalidate()
    self.tradeRulesStatus:SetText("Rules saved. Recommendations will be recalculated.")
    self:RefreshTradeRules()
end

function BOD.Sidecar:ResetTradeData()
    if not self.tradeResetArmed then
        self.tradeResetArmed = true
        self.tradeResetButton:SetText("Confirm Reset")
        self.tradeRulesStatus:SetText("Click Confirm Reset to erase open trades and trade history.")
        return
    end
    BOD.TradeTracker:Reset()
    BOD.TradeService:Invalidate()
    self.selectedTradeId = nil
    self.tradeResetArmed = false
    self.tradeResetButton:SetText("Reset Trade Data")
    self.tradeRulesStatus:SetText("Trade tracking data was reset. Market history was preserved.")
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
        local row = recommendationRow(panel, 70, nil, true)
        row.container:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -9 - ((index - 1) * 76))
        self.craftRows[index] = row
    end

    local note = font(panel, "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", self.craftRows[CRAFT_ROWS].container, "BOTTOMLEFT", 0, -8)
    note:SetSize(475, 32)
    note:SetText("Profit includes the 5% Auction House cut and modeled deposit loss. Unsold items are still a risk.")
end

function BOD.Sidecar:CreateShopPanel(frame, anchor)
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    panel:SetSize(488, 460)
    self.panels.SHOP = panel

    local heading = font(panel, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 4, -4)
    heading:SetText("Shop an Item")
    local intro = font(panel, "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -7)
    intro:SetSize(475, 28)
    intro:SetText("Choose one exact item. This reads the saved scan; every purchase stays manual.")

    self.shopItemBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    self.shopItemBox:SetSize(315, 24)
    self.shopItemBox:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 3, -8)
    self.shopItemBox:SetAutoFocus(false)
    self.shopItemBox:SetScript("OnEnterPressed", function(box) self:SelectShopItem(box:GetText()); box:ClearFocus() end)
    local find = button(panel, "Find", 68, 24)
    find:SetPoint("LEFT", self.shopItemBox, "RIGHT", 8, 0)
    find:SetScript("OnClick", function() self:SelectShopItem(self.shopItemBox:GetText()) end)
    local drop = button(panel, "Drop", 68, 24)
    drop:SetPoint("LEFT", find, "RIGHT", 6, 0)
    drop:RegisterForDrag("LeftButton")
    local function useCursorItem()
        local link = cursorItemLink()
        if link then
            self:SelectShopItem(link)
            if type(ClearCursor) == "function" then ClearCursor() end
        end
    end
    drop:SetScript("OnReceiveDrag", useCursorItem)
    drop:SetScript("OnClick", useCursorItem)

    local targetLabel = sectionLabel(panel, "ADDITIONAL QUANTITY TO BUY")
    targetLabel:SetPoint("TOPLEFT", self.shopItemBox, "BOTTOMLEFT", -3, -15)
    self.shopTargetBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    self.shopTargetBox:SetSize(70, 24)
    self.shopTargetBox:SetPoint("TOPLEFT", targetLabel, "BOTTOMLEFT", 3, -5)
    self.shopTargetBox:SetAutoFocus(false)
    self.shopTargetBox:SetNumeric(true)
    self.shopTargetBox:SetText("0")
    local targetHelp = font(panel, "GameFontDisableSmall")
    targetHelp:SetPoint("LEFT", self.shopTargetBox, "RIGHT", 9, 0)
    targetHelp:SetText("0 = buy only the safe value depth")

    local budgetLabel = sectionLabel(panel, "OPTIONAL BUDGET")
    budgetLabel:SetPoint("TOPLEFT", self.shopTargetBox, "BOTTOMLEFT", -3, -14)
    self.shopMoneyBoxes = {
        gold = planMoneyBox(panel, 62, "Gold", "Optional maximum spend for this item."),
        silver = planMoneyBox(panel, 45, "Silver", "Optional maximum spend for this item."),
        copper = planMoneyBox(panel, 45, "Copper", "Optional maximum spend for this item."),
    }
    self.shopMoneyBoxes.gold:SetPoint("TOPLEFT", budgetLabel, "BOTTOMLEFT", 3, -5)
    moneySuffix(panel, self.shopMoneyBoxes.gold, "g")
    self.shopMoneyBoxes.silver:SetPoint("LEFT", self.shopMoneyBoxes.gold, "RIGHT", 25, 0)
    moneySuffix(panel, self.shopMoneyBoxes.silver, "s")
    self.shopMoneyBoxes.copper:SetPoint("LEFT", self.shopMoneyBoxes.silver, "RIGHT", 25, 0)
    moneySuffix(panel, self.shopMoneyBoxes.copper, "c")
    local evaluate = button(panel, "Evaluate", 92, 24)
    evaluate:SetPoint("LEFT", self.shopMoneyBoxes.copper, "RIGHT", 28, 0)
    evaluate:SetScript("OnClick", function() self:SaveShopInputs(); self:RefreshShop() end)

    self.shopText = font(panel, "GameFontHighlightSmall")
    self.shopText:SetPoint("TOPLEFT", self.shopMoneyBoxes.gold, "BOTTOMLEFT", -3, -14)
    self.shopText:SetSize(475, 290)
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
    self.sellCheckButton = button(panel, "Check Current Item", 130, 24)
    self.sellCheckButton:SetPoint("LEFT", stackHelp, "RIGHT", 10, 0)
    self.sellCheckButton:SetScript("OnClick", function() self:CheckSelectedSellItem() end)

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
        if self.frame and self.frame:IsShown() and type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then
            if self.activeView == "SELL" then self:SelectSellItem(itemLink)
            elseif self.activeView == "SHOP" then self:SelectShopItem(itemLink) end
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

    self.guideBack = button(panel, "Exit", 62, 24)
    self.guideBack:SetPoint("BOTTOMRIGHT", -76, 8)
    self.guideBack:SetScript("OnClick", function() self:SetGuided(false) end)
    self.guideNext = button(panel, "Show me", 62, 24)
    self.guideNext:SetPoint("LEFT", self.guideBack, "RIGHT", 6, 0)
    self.guideNext:SetScript("OnClick", function()
        if self.guidedTargetView then self:SetView(self.guidedTargetView) end
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
    local title, message, targetView = "REVIEW THE PLAN", "Review the strongest safe opportunity. Always check the shown maximum price before buying.", "PLAN"
    local snapshot = BOD.MarketData and BOD.MarketData:GetLatestSnapshot() or nil
    local nowValue = type(time) == "function" and time() or os.time()
    local observedAt = snapshot and tonumber(snapshot.observationTimestamp or snapshot.completedAt) or nil
    if not BOD.AuctionAPI:IsAuctionHouseOpen() then
        title, message, targetView = "OPEN THE AUCTION HOUSE", "Open the Auction House to begin. Bank of Durotar never scans or buys by itself.", nil
    elseif BOD.FullScanProbe.active then
        title, message, targetView = "WAIT FOR THE SCAN", "The market scan is running. Wait for processing to finish before using a recommendation.", nil
    elseif not snapshot then
        title, message, targetView = "SCAN REQUIRED", "Click Scan Market above to collect prices. One deliberate click starts one scan.", nil
    elseif not observedAt or math.max(0, nowValue - observedAt) > 86400 then
        title, message, targetView = "PRICES ARE OLD", "Run a new market scan before buying. Old recommendations are not shown as safe.", nil
    elseif self.activeView == "SELL" and not self.selectedItemKey then
        title, message, targetView = "CHOOSE AN ITEM", "Drag one item from your bags into the large box, then enter the stack quantity.", "SELL"
    elseif self.activeView == "SELL" then
        title, message, targetView = "USE THE SELLING PRICE", "Copy the recommended Bid and Buyout into Blizzard's sell window, then post manually.", "SELL"
    elseif self.activeView == "CRAFT" then
        title, message, targetView = "REVIEW CRAFTS", "Open each profession once. Craft only when the shown material cost, profit, and confidence are supported.", "CRAFT"
    elseif self.currentPlan and self.currentPlan.bestMove and self.bestMoveFreshness and not self.bestMoveFreshness.safe then
        title, message, targetView = "PRICE NEEDS A RECHECK", tostring(self.bestMoveFreshness.message or "Run a new market scan before buying."), "PLAN"
    elseif self.currentPlan and self.currentPlan.bestMove then
        local best = self.currentPlan.bestMove
        if (tonumber(best.ownedQuantity) or 0) > 0 then
            title = "CHECK WHAT YOU OWN"
            message = string.format("You already own %d %s in your bags. Consider selling those before buying more.", tonumber(best.ownedQuantity) or 0, tostring(best.itemName or "of this item"))
        else
            title = "REVIEW THE BEST MOVE"
            message = "Review the featured item. Buy only the shown quantity and never pay above its maximum price."
        end
    elseif self.currentPlan and not self.currentPlan.bestMove and self.currentPlan.largerTradeAvailable then
        title, message, targetView = "LARGER OPPORTUNITY", "No simple quick move is safe, but a larger tracked opportunity is available under Trades.", "TRADES"
    elseif self.currentPlan and #(self.currentPlan.sells or {}) > 0 then
        title, message, targetView = "SELL INSTEAD", "No safe purchase is available. Review the bag-sale suggestions instead of forcing a buy.", "PLAN"
    else
        title, message, targetView = "WAIT", "No safe opportunity was found right now. Keep your gold and scan again later.", "PLAN"
    end
    self.guidedTargetView = targetView
    self.guideTitle:SetText("GUIDED · NEXT ACTION · " .. title)
    self.guideText:SetText(message)
    self.guideBack:SetEnabled(true)
    if targetView and targetView ~= self.activeView then self.guideNext:Show() else self.guideNext:Hide() end
end

function BOD.Sidecar:SetGuided(enabled)
    settings().guidedMode = enabled and true or false
    self:ApplyGuidedLayout()
    self:ApplyLayout()
    self:Refresh()
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
    self.status:SetSize(195, 48)
    self.scanDetailsButton = button(frame, "Scan Details", 88, 22)
    self.scanDetailsButton:SetPoint("TOPRIGHT", self.status, "TOPRIGHT", 96, 0)
    self.scanDetailsButton:SetScript("OnClick", function() self:ShowScanDetails() end)
    self.scanDetailsButton:SetScript("OnEnter", function(value)
        local cache = BOD.MarketData and BOD.MarketData:GetCacheStatus() or nil
        if not GameTooltip or not cache or not cache.available then return end
        GameTooltip:SetOwner(value, "ANCHOR_TOP")
        GameTooltip:SetText("Last completed full scan")
        GameTooltip:AddLine(BOD:FormatTimestamp(cache.completedAt), 1, 1, 1)
        GameTooltip:AddLine(tostring(cache.auctionCount) .. " auctions across " .. tostring(cache.itemCount) .. " items", 1, 1, 1)
        GameTooltip:AddLine("Coverage: " .. tostring(cache.coverageStatus), 1, 1, 1)
        GameTooltip:AddLine("Cached data is not live.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    self.scanDetailsButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    local tabs = { { "PLAN", "Plan" }, { "SHOP", "Shop" }, { "TRADES", "Trades" }, { "CRAFT", "Craft" }, { "SELL", "Sell" } }
    local previous
    for index, tab in ipairs(tabs) do
        local tabButton = button(frame, tab[2], 88, 28)
        self.viewButtons[tab[1]] = tabButton
        if index == 1 then tabButton:SetPoint("TOPLEFT", self.scanButton, "BOTTOMLEFT", 0, -12)
        else tabButton:SetPoint("LEFT", previous, "RIGHT", 8, 0) end
        tabButton:SetScript("OnClick", function() self:SetView(tab[1]) end)
        previous = tabButton
    end

    self:CreatePlanPanel(frame, self.viewButtons.PLAN)
    self:CreateShopPanel(frame, self.viewButtons.PLAN)
    self:CreateTradesPanel(frame, self.viewButtons.PLAN)
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
    if view == "PLAN" then self:LoadPlanMoneyFields() end
    if view == "SHOP" then self:LoadShopInputs() end
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

function BOD.Sidecar:LoadPlanMoneyFields()
    if not self.budgetMoneyBoxes or not BOD.PlanMoney then return end
    local budget = BOD.PlanMoney:ToFields(settings().goldBudgetCopper)
    local profit = BOD.PlanMoney:ToFields(settings().minimumExpectedProfitCopper)
    for denomination, box in pairs(self.budgetMoneyBoxes) do box:SetText(tostring(budget[denomination] or 0)) end
    for denomination, box in pairs(self.minimumProfitMoneyBoxes) do box:SetText(tostring(profit[denomination] or 0)) end
end

function BOD.Sidecar:SaveBudget(refresh)
    if not self.budgetMoneyBoxes or not self.minimumProfitMoneyBoxes or not BOD.PlanMoney then return end
    local budget = BOD.PlanMoney:NormalizeFields(
        self.budgetMoneyBoxes.gold:GetText(), self.budgetMoneyBoxes.silver:GetText(), self.budgetMoneyBoxes.copper:GetText())
    local profit = BOD.PlanMoney:NormalizeFields(
        self.minimumProfitMoneyBoxes.gold:GetText(), self.minimumProfitMoneyBoxes.silver:GetText(), self.minimumProfitMoneyBoxes.copper:GetText())
    settings().goldBudgetCopper = math.min(MAX_SAFE_INTEGER, budget.totalCopper)
    settings().minimumExpectedProfitCopper = math.min(MAX_SAFE_INTEGER, profit.totalCopper)
    self:LoadPlanMoneyFields()
    if refresh ~= false then
        self:RefreshPlan()
        self:RefreshGuide()
    end
end

function BOD.Sidecar:RefreshPlan()
    if self.activeView ~= "PLAN" then return end
    local plan = BOD.GoldPlan:Build(settings().goldBudgetCopper, { minimumExpectedProfitCopper = settings().minimumExpectedProfitCopper })
    self.currentPlan = plan
    if plan.status == "INVALID_BUDGET" then
        self.planSummary:SetText("Enter a gold budget of 1 or more.")
    elseif plan.status == "NO_DATA" then
        self.planSummary:SetText("Budget: " .. BOD:FormatMoney(plan.budgetCopper) .. "  ·  Scan the market first.\nMinimum profit: " .. BOD:FormatMoney(settings().minimumExpectedProfitCopper) .. "  ·  " .. marketMemoryLabel())
    elseif plan.status == "EMPTY" then
        self.planSummary:SetText("No safe buy right now. " .. tostring(plan.primaryRejectionReason or "Keep your gold and try again later.") .. "\nMinimum profit: " .. BOD:FormatMoney(plan.minimumExpectedProfitCopper) .. "  ·  " .. marketMemoryLabel())
    else
        self.planSummary:SetText("Budget: " .. BOD:FormatMoney(plan.budgetCopper) .. "  ·  Planned: " .. BOD:FormatMoney(plan.investedCopper) .. "  ·  Left: " .. BOD:FormatMoney(plan.remainingCopper) .. "\nMinimum profit: " .. BOD:FormatMoney(plan.minimumExpectedProfitCopper) .. "  ·  " .. marketMemoryLabel())
    end

    local best = plan.bestMove
    if self.viewTradeButton then
        if plan.largerTradeAvailable then self.viewTradeButton:Show() else self.viewTradeButton:Hide() end
    end
    if best then
        setRowIcon(self.bestMoveRow, best.itemID)
        setRowHelp(self.bestMoveRow, "How to read this", {
            "Trust describes the available evidence, not a guaranteed sale.",
            "Maximum buy price is for each item. Never pay more than that amount.",
            "Expected net profit subtracts the Auction House cut and modeled relisting deposits.",
        })
        local ownedText = (tonumber(best.ownedQuantity) or 0) > 0 and ("  ·  You own " .. tostring(best.ownedQuantity) .. " in your bags") or ""
        local freshness = BOD.OpportunityService:CheckRecommendationFreshness(best)
        self.bestMoveFreshness = freshness
        setRow(self.bestMoveRow, table.concat({
            "|cffffd100" .. tostring(best.itemName or best.itemKey) .. "|r",
            "Buy up to: " .. tostring(best.recommendedPurchaseQuantity or best.currentQuantity or 0) .. ownedText,
            "Maximum buy price: " .. BOD:FormatMoney(best.maximumSafeUnitPrice) .. " each",
            "Expected net profit: about " .. BOD:FormatMoney(best.conservativeNetProfit),
            "Trust: " .. trustLabel(best.trustLabel) .. "  ·  Main risk: " .. tostring(best.mainRisk or "Market conditions can change"),
            "Price check: " .. tostring(freshness.message),
        }, "\n"))
        self.planNote:SetText("Recommendation uses the latest completed scan, not a live purchase check. Buy and post manually.")
    else
        setRowIcon(self.bestMoveRow, nil)
        setRowHelp(self.bestMoveRow, "No safe opportunity", { "Waiting protects your gold when no item passes every safety rule." })
        setRow(self.bestMoveRow, "|cffffd100No safe opportunity found right now.|r\n" .. tostring(plan.primaryRejectionReason or "Keep your gold and scan again later."))
        self.bestMoveFreshness = nil
        self.planNote:SetText("Waiting is a valid gold-making decision. Never force a purchase.")
    end

    for index, row in ipairs(self.buyRows) do
        local rank = index + 1
        local buy = plan.buys[rank]
        if buy then
            setRowIcon(row, buy.itemID)
            setRowHelp(row, "How to read this", {
                "Trust describes price evidence, not sale speed.",
                "Max is the most you should pay for each item.",
                "Net profit includes the Auction House cut and modeled relisting deposits.",
            })
            local ownedText = (tonumber(buy.ownedQuantity) or 0) > 0 and (" · Own " .. tostring(buy.ownedQuantity)) or ""
            setRow(row, string.format("|cffffd100%d  %s × %d|r  ·  Trust: %s%s\nMax %s each  ·  Net profit ~%s\nRisk: %s", rank, tostring(buy.itemName or buy.itemKey), tonumber(buy.recommendedPurchaseQuantity) or 0, trustLabel(buy.trustLabel), ownedText, BOD:FormatMoney(buy.maximumSafeUnitPrice), BOD:FormatMoney(buy.conservativeNetProfit), tostring(buy.mainRisk or "Market conditions can change")))
        else
            setRowIcon(row, nil)
            setRowHelp(row, nil, nil)
            setRow(row, "")
        end
    end
    if self.buyScrollChild then
        local moreCount = math.max(0, #plan.buys - 1)
        self.buyScrollChild:SetHeight(math.max(92, math.max(1, moreCount) * 52))
        local maximum = math.max(0, (math.max(1, moreCount) * 52) - 92)
        if (self.buyScroll:GetVerticalScroll() or 0) > maximum then self.buyScroll:SetVerticalScroll(maximum) end
    end

    for index, row in ipairs(self.bagRows) do
        local sell = plan.sells[index]
        if sell then
            setRowIcon(row, sell.itemID, sell.itemLink)
            setRowHelp(row, "Bag sale suggestion", {
                "Confidence describes the price evidence; it does not guarantee a buyer.",
                "You must vendor or post the item manually.",
            })
            if sell.saleMethod == "VENDOR" then
                setRow(row, string.format("|cffffd100%d  Vendor %s × %d|r\nReceive %s  ·  Better than the expected Auction House return", index, tostring(sell.itemName), tonumber(sell.stackCount) or 0, BOD:FormatMoney(sell.stackPrice)))
            else
                setRow(row, string.format("|cffffd100%d  Sell %s × %d|r\nList at %s  ·  %s each  ·  %s confidence", index, tostring(sell.itemName), tonumber(sell.stackCount) or 0, BOD:FormatMoney(sell.stackPrice), BOD:FormatMoney(sell.unitPrice), tostring(sell.confidence):lower()))
            end
        else
            setRowIcon(row, nil)
            setRowHelp(row, nil, nil)
            setRow(row, index == 1 and "No bag items have enough reliable market data yet." or "")
        end
    end
end

function BOD.Sidecar:SelectTradeRecommendation(index)
    local trade = self.currentTrades and self.currentTrades.opportunities and self.currentTrades.opportunities[index]
    if not trade then return end
    self.selectedTradeRecommendation = trade
    self.tradeActionStatus = "Selected " .. tostring(trade.itemName) .. ". Use Find Auctions or Track Trade."
    self:RefreshTrades(true)
end

function BOD.Sidecar:FindSelectedTrade()
    local trade = self.selectedTradeRecommendation or (self.currentTrades and self.currentTrades.bestTrade)
    if not trade then return end
    local freshness = BOD.TradeService:CheckFreshness(trade)
    if freshness.state == "STALE" or freshness.state == "SCAN_REQUIRED" then
        self.tradeActionStatus = freshness.message
    else
        local started, message = BOD.TargetedScan:Start(trade.itemKey, trade.itemName, trade.itemID)
        self.tradeActionStatus = started and (message .. " Do not pay more than " .. BOD:FormatMoney(trade.maximumBuyUnitPrice) .. " each.") or message
    end
    self:RefreshTrades(true)
end

function BOD.Sidecar:TrackSelectedTrade()
    local trade = self.selectedTradeRecommendation or (self.currentTrades and self.currentTrades.bestTrade)
    if not trade then return end
    local tracked, reason = BOD.TradeService:Track(trade)
    if tracked then
        self.selectedTradeId = tracked.id
        self.tradeActionStatus = reason == "ALREADY_TRACKED" and "That item is already an open trade." or "Trade tracked. No purchase was made."
    else
        self.tradeActionStatus = reason == "MAX_OPEN_TRADES" and "Close an open trade before tracking another." or "Refresh the market before tracking this trade."
    end
    BOD.TradeService:Invalidate()
    self:RefreshTrades()
end

function BOD.Sidecar:SelectOpenTrade(index)
    local values = self.currentTrades and self.currentTrades.openTrades or {}
    if not values[index] then return end
    self.selectedTradeId = values[index].id
    self.tradeActionStatus = "Managing " .. tostring(values[index].itemName) .. ". All lifecycle updates are manual."
    self:RefreshTrades(true)
end

function BOD.Sidecar:AddTradePurchase()
    if not self.selectedTradeId then self.tradeActionStatus = "Select an open trade first."; self:RefreshTrades(true); return end
    local quantity = math.floor(tonumber(self.tradeBuyQtyBox:GetText()) or 0)
    local unitCost = math.floor(tonumber(self.tradeBuyPriceBox:GetText()) or 0) * 100
    local trade, reason = BOD.TradeTracker:AddPurchase(self.selectedTradeId, quantity, unitCost)
    if trade and reason == "PRICE_ABOVE_RECOMMENDATION" then
        self.tradeActionStatus = "Purchase recorded for accurate cost basis, but its price was above the tracked maximum."
    elseif trade and reason == "PURCHASE_QUANTITY_EXCEEDS_POSITION" then
        self.tradeActionStatus = "Purchase recorded, but its quantity exceeded the tracked safe position."
    else
        self.tradeActionStatus = trade and "Purchase batch recorded. The addon did not buy anything." or "Enter a valid quantity and unit price in silver."
    end
    BOD.TradeService:Invalidate(); self:RefreshTrades()
end

function BOD.Sidecar:MarkTradeListed()
    if not self.selectedTradeId then self.tradeActionStatus = "Select an open trade first."; self:RefreshTrades(true); return end
    local trade = BOD.TradeTracker:MarkListed(self.selectedTradeId)
    self.tradeActionStatus = trade and "Marked listed. Posting still happens manually in Blizzard's Auction House." or "Record a purchase before marking the trade listed."
    self:RefreshTrades()
end

function BOD.Sidecar:RecordTradeSale()
    if not self.selectedTradeId then self.tradeActionStatus = "Select an open trade first."; self:RefreshTrades(true); return end
    local quantity = math.floor(tonumber(self.tradeSaleQtyBox:GetText()) or 0)
    local revenue = math.floor(tonumber(self.tradeSaleRevenueBox:GetText()) or 0) * 100
    local trade = BOD.TradeTracker:RecordSale(self.selectedTradeId, quantity, revenue)
    self.tradeActionStatus = trade and "Sale recorded from the net revenue you entered." or "Enter a valid sold quantity and net revenue in silver."
    BOD.TradeService:Invalidate(); self:RefreshTrades()
end

function BOD.Sidecar:CloseSelectedTrade(abandon)
    if not self.selectedTradeId then self.tradeActionStatus = "Select an open trade first."; self:RefreshTrades(true); return end
    local trade = abandon and BOD.TradeTracker:Abandon(self.selectedTradeId) or BOD.TradeTracker:Close(self.selectedTradeId)
    self.tradeActionStatus = trade and (abandon and "Trade abandoned and moved to history." or "Trade closed and moved to history.") or "The selected trade no longer exists."
    self.selectedTradeId = nil
    BOD.TradeService:Invalidate(); self:RefreshTrades()
end

function BOD.Sidecar:RefreshTrades(keepResult)
    if self.activeView ~= "TRADES" or self.tradeRulesOpen then return end
    local result = keepResult and self.currentTrades or BOD.TradeService:Build()
    if not result then result = BOD.TradeService:Build() end
    self.currentTrades = result
    if not keepResult and self.selectedTradeRecommendation then
        local selectedKey = self.selectedTradeRecommendation.itemKey
        self.selectedTradeRecommendation = nil
        for _, trade in ipairs(result.opportunities or {}) do
            if trade.itemKey == selectedKey then self.selectedTradeRecommendation = trade; break end
        end
    end
    local limits = result.capitalLimits
    self.tradeCapitalText:SetText(table.concat({
        "Liquid gold: " .. BOD:FormatMoney(result.liquidGold),
        "Emergency reserve: " .. BOD:FormatMoney(limits.emergencyReserve) .. "  ·  Available to trade: " .. BOD:FormatMoney(limits.availableCapital),
        "Currently committed: " .. BOD:FormatMoney(result.committedCapital) .. "  ·  Open trades: " .. tostring(#result.openTrades),
        "Risk mode: " .. tostring(result.settings.riskMode):lower():gsub("^%l", string.upper),
    }, "\n"))

    local best = result.bestTrade
    if best then
        setRowIcon(self.bestTradeRow, best.itemID)
        setRowHelp(self.bestTradeRow, "Trade estimate", {
            "The exit range is clamped to recent local medians; it is not a guaranteed sale.",
            "Profit subtracts the 5% Auction House cut and modeled relisting deposits.",
            "The current snapshot stores the cheapest exact listing, not a complete price ladder.",
        })
        local freshness = BOD.TradeService:CheckFreshness(best)
        setRow(self.bestTradeRow, table.concat({
            "|cffffd100" .. tostring(best.itemName) .. "|r",
            "Recommended purchase: " .. tostring(best.recommendedPurchaseQuantity) .. "  ·  Maximum safe purchase: " .. tostring(best.maximumSafePurchaseQuantity),
            "Maximum buy price: " .. BOD:FormatMoney(best.maximumBuyUnitPrice) .. " each  ·  Required capital: " .. BOD:FormatMoney(best.requiredCapital),
            "Expected sale range: " .. BOD:FormatMoney(best.fastExitUnitPrice) .. "–" .. BOD:FormatMoney(best.normalExitUnitPrice) .. " each",
            "Estimated net profit: " .. BOD:FormatMoney(best.lowProfit) .. "–" .. BOD:FormatMoney(best.normalProfit),
            "Expected return: " .. rateLabel(best.lowReturnRate) .. "–" .. rateLabel(best.normalReturnRate),
            "Demand: " .. tostring(best.demand):lower():gsub("^%l", string.upper) .. "  ·  Confidence: " .. trustLabel(best.confidence),
            "Main risk: " .. tostring(best.mainRisk) .. "  ·  " .. tostring(freshness.message),
            "Why: " .. tostring(best.why),
        }, "\n"))
        self.findTradeButton:SetEnabled(true); self.trackTradeButton:SetEnabled(true)
    else
        setRowIcon(self.bestTradeRow, nil)
        setRowHelp(self.bestTradeRow, "No qualified trade", { tostring(result.primaryRejectionReason or "Waiting protects your capital.") })
        local message = result.status == "SCANNING" and "Trade opportunities will be evaluated after the market scan finishes."
            or (result.status == "NO_DATA" and "Run a market scan before evaluating trades.")
            or (result.status == "INSUFFICIENT_HISTORY" and "More market observations are needed before larger trades can be recommended.")
            or (result.status == "CAPITAL_TOO_LOW" and "Current opportunities require more trading capital than is safely available.")
            or (result.status == "CAPITAL_COMMITTED" and "Available trading capital is already committed to open trades.")
            or (result.status == "DISABLED" and "Trades is disabled. Open Trade Rules to enable it.")
            or "No sensible trade meets your profit, demand, and capital rules right now."
        setRow(self.bestTradeRow, "|cffffd100" .. message .. "|r\n" .. tostring(result.primaryRejectionReason or "No recommendation is forced."))
        self.findTradeButton:SetEnabled(false); self.trackTradeButton:SetEnabled(false)
    end
    self.tradeStatusText:SetText(self.tradeActionStatus or "Buying and tracking require your click.")

    for index, row in ipairs(self.additionalTradeRows) do
        local trade = result.opportunities[index + 1]
        if trade then
            setRowIcon(row, trade.itemID)
            setRowHelp(row, "Additional trade", { "Click to select this trade for Find Auctions or Track Trade." })
            setRow(row, string.format("|cffffd100%s|r  ·  %s\nCapital: %s  ·  Profit: %s–%s\nDemand: %s  ·  Confidence: %s", tostring(trade.itemName), tostring(trade.tag or "Qualified"), BOD:FormatMoney(trade.requiredCapital), BOD:FormatMoney(trade.lowProfit), BOD:FormatMoney(trade.normalProfit), tostring(trade.demand):lower(), trustLabel(trade.confidence)))
        else setRowIcon(row, nil); setRowHelp(row, nil, nil); setRow(row, "") end
    end

    local selectedFound
    for index, row in ipairs(self.openTradeRows) do
        local trade = result.openTrades[index]
        if trade then
            if trade.id == self.selectedTradeId then selectedFound = true end
            setRowIcon(row, trade.itemID)
            setRowHelp(row, "Tracked trade", { "This record changes only when you use the manual lifecycle buttons." })
            local prefix = trade.id == self.selectedTradeId and "|cff80ff80SELECTED|r · " or ""
            setRow(row, prefix .. string.format("|cffffd100%s|r  ·  %s\nBought %d  ·  Remaining %d  ·  Cost basis %s  ·  Realized %s", tostring(trade.itemName), tradeStateLabel(trade.state), tonumber(trade.quantityPurchased) or 0, tonumber(trade.quantityRemaining) or 0, BOD:FormatMoney(trade.remainingCostBasis), signedMoney(trade.realizedProfit)))
        else setRowIcon(row, nil); setRowHelp(row, nil, nil); setRow(row, index == 1 and "No open trades. Recommendations are never tracked automatically." or "") end
    end
    if self.selectedTradeId and not selectedFound then self.selectedTradeId = nil end

    for index, row in ipairs(self.tradeHistoryRows) do
        local trade = result.history[index]
        if trade then
            setRowIcon(row, trade.itemID)
            setRowHelp(row, "Trade outcome", {
                "Realized profit uses only the purchase cost and net sale revenue you recorded.",
                "Gross revenue, Auction House cut, and deposits remain unknown when only net revenue was entered.",
            })
            local returnText = trade.returnOnCapital and rateLabel(trade.returnOnCapital) or "unknown"
            local heldText = trade.timeHeldSeconds and ageLabel(trade.timeHeldSeconds) or "unknown"
            setRow(row, string.format("|cffffd100%s|r  ·  %s\nCost %s  ·  Net %s  ·  Profit %s  ·  Return %s  ·  Held %s", tostring(trade.itemName), tradeStateLabel(trade.state), BOD:FormatMoney(trade.totalPurchaseCost), BOD:FormatMoney(trade.netRevenue), signedMoney(trade.realizedProfit), returnText, heldText))
        else setRowIcon(row, nil); setRowHelp(row, nil, nil); setRow(row, index == 1 and "No completed or abandoned trades yet." or "") end
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
            setRowIcon(row, craft.outputItemID)
            setRowHelp(row, "Craft suggestion", {
                "Materials are valued at conservative market prices, even when you already own them.",
                "Profit subtracts the Auction House cut and modeled deposit loss.",
                "Crafting and posting remain manual; a sale is never guaranteed.",
            })
            setRow(row, string.format("|cffffd100%d  %s × %d|r  ·  %s\nMaterials: %s  ·  Sell: %s\nProfit ~%s  ·  %d%% margin  ·  %s confidence", index, tostring(craft.outputName), tonumber(craft.outputCount) or 1, tostring(craft.profession), BOD:FormatMoney(craft.reagentCost), BOD:FormatMoney(craft.sellPrice), BOD:FormatMoney(craft.estimatedProfit), math.floor((tonumber(craft.marginRate) or 0) * 100), tostring(craft.confidence):lower()))
        else
            setRowIcon(row, nil)
            setRowHelp(row, nil, nil)
            setRow(row, "")
        end
    end
end

function BOD.Sidecar:LoadShopInputs()
    if not self.shopMoneyBoxes or not BOD.PlanMoney then return end
    local values = BOD.PlanMoney:ToFields(settings().shopBudgetCopper or 0)
    for denomination, box in pairs(self.shopMoneyBoxes) do box:SetText(tostring(values[denomination] or 0)) end
    if self.shopTargetBox then self.shopTargetBox:SetText(tostring(settings().shopTargetQuantity or 0)) end
end

function BOD.Sidecar:SaveShopInputs()
    if not self.shopMoneyBoxes or not BOD.PlanMoney then return end
    local budget = BOD.PlanMoney:NormalizeFields(self.shopMoneyBoxes.gold:GetText(),
        self.shopMoneyBoxes.silver:GetText(), self.shopMoneyBoxes.copper:GetText())
    settings().shopBudgetCopper = math.min(MAX_SAFE_INTEGER, budget.totalCopper)
    settings().shopTargetQuantity = math.max(0, math.min(5000,
        math.floor(tonumber(self.shopTargetBox and self.shopTargetBox:GetText()) or 0)))
    self:LoadShopInputs()
end

function BOD.Sidecar:SelectShopItem(text)
    text = type(text) == "string" and text or ""
    local hasExactLink = text:match("Hitem:([^|%]]+)") ~= nil
    local linkedName = text:match("%[([^%]]+)%]")
    local item = hasExactLink and BOD.MarketData:FindItemByText(text)
        or BOD.MarketData:FindExactItemByName(linkedName or text)
    self.selectedShopItemKey = item and item.itemKey or nil
    self.selectedShopItemLink = item and text or nil
    if item then
        local displayName = item.itemName or item.name or item.itemKey
        self.shopItemBox:SetText(tostring(displayName))
    else
        self.shopItemBox:SetText(text)
    end
    self:RefreshShop()
end

function BOD.Sidecar:RefreshShop()
    if self.activeView ~= "SHOP" then return end
    if not self.selectedShopItemKey then
        self.shopText:SetText(table.concat({
            "Choose an exact item by name, Shift-click its link, or drag it onto Drop.",
            "",
            "Equipment variants require an exact item link. If a typed name matches more than one variant, no guess is made.",
            "A fresh full scan is needed to see multiple listing price levels.",
        }, "\n"))
        return
    end
    local snapshot = BOD.MarketData:GetLatestSnapshot()
    local item = BOD.MarketData:GetCurrentItem(self.selectedShopItemKey)
    if not snapshot or not item then
        self.shopText:SetText("That exact item is not present in the saved market scan. Scan again or choose another item.")
        return
    end
    local ownedInventory = BOD.GoldPlan:CollectBagInventory()
    local ownedQuantities = {}
    for itemKey, entry in pairs(ownedInventory) do ownedQuantities[itemKey] = tonumber(entry.ownedQuantity) or 0 end
    local result = BOD.AcquisitionEvaluator:EvaluateItem(self.selectedShopItemKey, item, snapshot, {
        targetQuantity = settings().shopTargetQuantity or 0,
        budgetCopper = settings().shopBudgetCopper or 0,
        context = { ownedQuantities = ownedQuantities },
    })
    local lines = {
        "|cffffd100" .. tostring(result.itemName or item.itemName or self.selectedShopItemKey) .. "|r",
        "Exact market identity: " .. tostring(self.selectedShopItemKey),
        "You own: " .. tostring(result.ownedQuantity or 0) .. "  ·  Saved scan age: " .. ageLabel(result.dataAgeSeconds),
        "Fair value: " .. BOD:FormatMoney(result.fairValue or 0) .. " each"
            .. (result.historicalValue and ("  ·  7-day: " .. BOD:FormatMoney(result.historicalValue)) or ""),
        "Evidence: " .. tostring(result.confidence or "unknown"):lower()
            .. "  ·  Demand: " .. tostring(result.demand or "unknown"):lower(),
        "",
    }
    if result.purchaseQuantity and result.purchaseQuantity > 0 then
        lines[#lines + 1] = "Buy " .. tostring(result.purchaseQuantity) .. " for " .. BOD:FormatMoney(result.capitalRequired)
            .. "  ·  Average " .. BOD:FormatMoney(result.averageUnitCost) .. " each"
        lines[#lines + 1] = "Stop above " .. BOD:FormatMoney(result.safeCeiling) .. " each"
            .. (result.cliffUnitPrice and ("  ·  Price cliff at " .. BOD:FormatMoney(result.cliffUnitPrice)) or "")
        lines[#lines + 1] = "Conservative value after resale friction: " .. BOD:FormatMoney(result.conservativeUnitValue) .. " each"
        lines[#lines + 1] = "Conservative profit: about " .. BOD:FormatMoney(result.conservativeProfit)
            .. "  ·  Capital efficiency: " .. string.format("%.1f%%", (result.capitalEfficiencyBps or 0) / 100)
        if result.status == "TARGET_UNMET" then
            lines[#lines + 1] = "|cffffa040Target not met within the safe listings and budget.|r"
        elseif result.status == "LOW_CONFIDENCE" then
            lines[#lines + 1] = "|cffffa040Low-confidence context only. No buy recommendation is made.|r"
        end
    else
        lines[#lines + 1] = "No saved listing is below the conservative stop price. Keep your gold."
    end
    if (tonumber(result.dataAgeSeconds) or 0) > 43200 then
        lines[#lines + 1] = "|cffff4040Warning: this snapshot is stale enough that listings may have changed.|r"
    end
    if result.legacyDepthFallback then
        lines[#lines + 1] = "|cffffa040This older snapshot has only the cheapest stack. Run a fresh scan for depth.|r"
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Saved listing groups (manual buys):"
    for index, group in ipairs(result.offerGroups or {}) do
        if index > 6 then lines[#lines + 1] = "…and " .. tostring(#result.offerGroups - 6) .. " more price groups"; break end
        local selected = tonumber(result.selectedCounts and result.selectedCounts[index]) or 0
        local marker = selected > 0 and ("BUY " .. tostring(selected) .. "/" .. tostring(group.listingCount)) or "skip"
        lines[#lines + 1] = string.format("%s · %dx%d · %s total · %s each", marker,
            tonumber(group.listingCount) or 0, tonumber(group.stackSize) or 0,
            BOD:FormatMoney(group.buyoutTotal), BOD:FormatMoney(group.unitPrice))
    end
    lines[#lines + 1] = "Nothing here clicks, buys, bids, or searches the Auction House for you."
    self.shopText:SetText(table.concat(lines, "\n"))
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
    if self.sellCheckButton then self.sellCheckButton:SetEnabled(self.selectedItemKey ~= nil and not (BOD.TargetedScan and BOD.TargetedScan.active)) end
    if not self.selectedItemKey then self.sellText:SetText("Choose an item in step 1. Your selling price will appear here."); return end
    local recommendation = BOD.PricingService:GetRecommendation(self.selectedItemKey, tonumber(self.sellStackBox:GetText()) or 1, { strategy = "SMALL_UNDERCUT", requireCurrentValidation = true, useTargetedOverlay = true })
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
            "Price confidence: " .. tostring(recommendation.confidence):lower() .. " · Full scan age: " .. ageLabel(recommendation.dataAgeSeconds),
            recommendation.targetedValidationAt and ("Current item checked: " .. ageLabel(math.max(0, (type(time) == "function" and time() or os.time()) - recommendation.targetedValidationAt)) .. " ago") or "",
        }, "\n"))
    elseif recommendation.status == "VALIDATION_REQUIRED" then
        self.sellText:SetText("Cached price context: " .. BOD:FormatMoney(recommendation.cachedUnitBuyout) .. " each.\n\nThis full-market scan is " .. ageLabel(recommendation.dataAgeSeconds) .. " old. Check this item before using a posting price.")
    elseif recommendation.status == "REFRESH_DATA" then self.sellText:SetText("Your market data is old. Scan again before listing this item.")
    elseif recommendation.status == "INVALID_QUANTITY" then self.sellText:SetText("Enter the actual stack size.")
    else self.sellText:SetText("There is not enough reliable market data for this item yet.") end
end

function BOD.Sidecar:CheckSelectedSellItem()
    if not self.selectedItemKey then return end
    local item = BOD.MarketData:GetCurrentItem(self.selectedItemKey)
    local ok, message = BOD.TargetedScan:Start(self.selectedItemKey, item and (item.itemName or item.name), item and item.itemID)
    self.sellText:SetText(message or (ok and "Checking item..." or "Unable to check this item."))
end

function BOD.Sidecar:ShowScanDetails()
    local cache = BOD.MarketData and BOD.MarketData:GetCacheStatus() or nil
    if not cache or not cache.available then BOD:Print("No valid completed market scan is cached for this market."); return end
    BOD:Print(string.format("Cached full scan %s: %d auctions across %d items; coverage %s; completed %s.", cache.ageText, cache.auctionCount, cache.itemCount, tostring(cache.coverageStatus), BOD:FormatTimestamp(cache.completedAt)))
end

function BOD.Sidecar:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    self:ShowView()
    local lines, cooldown = BOD.FullScanProbe:GetCooldownStatusLines()
    local cache = BOD.MarketData and BOD.MarketData:GetCacheStatus() or nil
    if not BOD.FullScanProbe.active and cache and cache.available then
        lines = { cache.message, tostring(cache.auctionCount) .. " auctions · " .. tostring(cache.itemCount) .. " items" }
    end
    self.status:SetText(table.concat(lines, "\n"))
    self.scanButton:SetText(BOD.FullScanProbe.active and "CANCEL SCAN" or (cache and cache.available and "REFRESH SCAN" or "SCAN MARKET"))
    self.scanDetailsButton:SetEnabled(cache and cache.available or false)
    self.scanButton:SetEnabled(BOD.FullScanProbe.active or (cooldown.state == "READY" and cooldown.canQueryAll == true))
    if BOD.FullScanProbe.active then
        self:RefreshGuide()
        return
    end
    self:RefreshPlan(); self:RefreshShop(); self:RefreshTrades(); self:RefreshCraft(); self:RefreshSell()
    self:RefreshGuide()
end

function BOD.Sidecar:OnEvent(event)
    if event == "ADDON_LOADED" then return
    elseif event == "PLAYER_LOGIN" then self:InstallItemClickHook()
    elseif event == "AUCTION_HOUSE_SHOW" then
        if BOD.MarketData then BOD.MarketData:GetLatestSnapshot() end
        local warning = BOD.MarketData and BOD.MarketData:ConsumeCacheWarning() or nil
        if warning then BOD:Print(warning) end
        if settings().openWithAuctionHouse then self:Show() end
    elseif event == "AUCTION_HOUSE_CLOSED" then self:Hide()
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_MONEY" then
        if BOD.TradeService then BOD.TradeService:Invalidate() end
        self:Refresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" then self:Refresh() end
end
