local addonName, BOD = ...

BOD.Sidecar = {
    frame = nil,
    rows = {},
    resultScrollFrame = nil,
    resultScrollChild = nil,
    resultScrollBar = nil,
    selectedText = nil,
    statusText = nil,
    resultCountText = nil,
    searchBox = nil,
    buyoutOnlyCheck = nil,
    minStackBox = nil,
    maxUnitPriceBox = nil,
    sortButton = nil,
    collapsed = false,
}

local ROW_COUNT = 6
local ROW_HEIGHT = 42
local ROW_SPACING = 4
local ROW_STEP = ROW_HEIGHT + ROW_SPACING
local LIST_HEIGHT = ROW_COUNT * ROW_STEP
local COLLAPSED_WIDTH = 34
local MIN_WIDTH = 360
local MAX_WIDTH = 420

local function getSettings()
    if not BOD.db then
        BOD:InitializeDatabase()
    end
    return BOD.db.settings
end

local function clampWidth(width)
    return math.max(MIN_WIDTH, math.min(MAX_WIDTH, tonumber(width) or 390))
end

local function createFontString(parent, template)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
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
        frame:SetBackdropColor(0.04, 0.025, 0.015, 0.96)
    end
end

local function createButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 90, height or 24)
    button:SetText(label)
    return button
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or 0
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function getAuctionFrame()
    if AuctionFrame and AuctionFrame.IsShown then
        return AuctionFrame
    end
    if AuctionHouseFrame and AuctionHouseFrame.IsShown then
        return AuctionHouseFrame
    end
    return nil
end

local function isFrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function hasDockRoom(auctionFrame, width)
    if not auctionFrame or not auctionFrame.GetRight or not UIParent or not UIParent.GetWidth then
        return true
    end

    local frameRight = auctionFrame:GetRight()
    local screenWidth = UIParent:GetWidth()
    if not frameRight or not screenWidth then
        return true
    end

    return frameRight + width + 8 <= screenWidth
end

local function getQualityColor(result)
    local quality = tonumber(result and result.quality)
    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local color = ITEM_QUALITY_COLORS[quality]
        return color.r or 1, color.g or 1, color.b or 1
    end
    return 1, 1, 1
end

local function getStateLabel()
    local state = BOD.SearchController:GetState()
    if state == "IDLE" then
        return "Ready"
    elseif state == "WAITING_FOR_QUERY_PERMISSION" then
        return "Waiting for query cooldown"
    elseif state == "QUERY_SENT" or state == "WAITING_FOR_RESULTS" then
        return "Scanning"
    elseif state == "RESULTS_RECEIVED" or state == "EMPTY_RESULTS" then
        return "Completed"
    elseif state == "FAILED" or state == "TIMED_OUT" then
        return "Failed"
    elseif state == "CANCELLED" then
        return "Cancelled"
    elseif state == "WAITING_FOR_AH" then
        return "Waiting for Auction House"
    end
    return state
end

function BOD.Sidecar:EnsureCreated()
    if self.frame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "BankOfDurotarSidecar", UIParent, template)
    self.frame = frame
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if not self:IsDocked() then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)
    setBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.titleText = title
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Bank of Durotar")

    local collapseButton = createButton(frame, "<", 24, 22)
    self.collapseButton = collapseButton
    collapseButton:SetPoint("TOPRIGHT", -10, -12)
    collapseButton:SetScript("OnClick", function()
        self:SetCollapsed(not getSettings().sidecarCollapsed)
    end)

    local primaryButton = createButton(frame, "SEARCH MARKET", 190, 34)
    self.primaryButton = primaryButton
    primaryButton:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    primaryButton:SetText("SEARCH MARKET")
    primaryButton.redBackdrop = primaryButton:CreateTexture(nil, "BACKGROUND")
    primaryButton.redBackdrop:SetAllPoints(primaryButton)
    if primaryButton.redBackdrop.SetColorTexture then
        primaryButton.redBackdrop:SetColorTexture(0.45, 0.05, 0.02, 0.9)
    else
        primaryButton.redBackdrop:SetTexture(0.45, 0.05, 0.02, 0.9)
    end
    if primaryButton:GetFontString() then
        primaryButton:GetFontString():SetTextColor(1, 0.82, 0.18)
    end
    primaryButton:SetScript("OnClick", function()
        self:StartSearchFromUI()
    end)

    self.statusText = createFontString(frame, "GameFontNormalSmall")
    self.statusText:SetPoint("LEFT", primaryButton, "RIGHT", 10, 0)
    self.statusText:SetSize(155, 34)

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.searchBox = searchBox
    searchBox:SetSize(178, 24)
    searchBox:SetPoint("TOPLEFT", primaryButton, "BOTTOMLEFT", 0, -12)
    searchBox:SetAutoFocus(false)
    searchBox:SetText(getSettings().lastSearchText or BOD:GetSearchText())
    searchBox:SetScript("OnEnterPressed", function()
        self:StartSearchFromUI()
        searchBox:ClearFocus()
    end)
    searchBox:SetScript("OnEditFocusLost", function(box)
        getSettings().lastSearchText = box:GetText()
    end)

    local searchButton = createButton(frame, "Search", 70, 24)
    self.searchButton = searchButton
    searchButton:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    searchButton:SetScript("OnClick", function()
        self:StartSearchFromUI()
    end)

    local clearButton = createButton(frame, "Clear", 56, 24)
    self.clearButton = clearButton
    clearButton:SetPoint("LEFT", searchButton, "RIGHT", 6, 0)
    clearButton:SetScript("OnClick", function()
        self:ClearSearch()
    end)

    local refreshButton = createButton(frame, "Refresh", 72, 24)
    self.refreshButton = refreshButton
    refreshButton:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -8)
    refreshButton:SetScript("OnClick", function()
        self:StartSearchFromUI()
    end)

    self.resultCountText = createFontString(frame, "GameFontNormalSmall")
    self.resultCountText:SetPoint("LEFT", refreshButton, "RIGHT", 10, 0)
    self.resultCountText:SetSize(230, 24)

    local buyoutOnlyCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    self.buyoutOnlyCheck = buyoutOnlyCheck
    buyoutOnlyCheck:SetSize(24, 24)
    buyoutOnlyCheck:SetPoint("TOPLEFT", refreshButton, "BOTTOMLEFT", -4, -8)
    buyoutOnlyCheck:SetScript("OnClick", function(check)
        getSettings().filters.buyoutOnly = check:GetChecked() and true or false
        self:ApplyFiltersFromUI()
    end)

    local buyoutLabel = createFontString(frame, "GameFontNormalSmall")
    buyoutLabel:SetPoint("LEFT", buyoutOnlyCheck, "RIGHT", 0, 0)
    buyoutLabel:SetText("Buyout only")

    local minStackLabel = createFontString(frame, "GameFontNormalSmall")
    minStackLabel:SetPoint("TOPLEFT", buyoutOnlyCheck, "BOTTOMLEFT", 4, -5)
    minStackLabel:SetText("Min stack")

    local minStackBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.minStackBox = minStackBox
    minStackBox:SetSize(54, 22)
    minStackBox:SetPoint("LEFT", minStackLabel, "RIGHT", 8, 0)
    minStackBox:SetAutoFocus(false)
    minStackBox:SetNumeric(true)
    minStackBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
        self:ApplyFiltersFromUI()
    end)
    minStackBox:SetScript("OnEditFocusLost", function()
        self:ApplyFiltersFromUI()
    end)

    local maxPriceLabel = createFontString(frame, "GameFontNormalSmall")
    maxPriceLabel:SetPoint("LEFT", minStackBox, "RIGHT", 12, 0)
    maxPriceLabel:SetText("Max each")

    local maxUnitPriceBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.maxUnitPriceBox = maxUnitPriceBox
    maxUnitPriceBox:SetSize(78, 22)
    maxUnitPriceBox:SetPoint("LEFT", maxPriceLabel, "RIGHT", 8, 0)
    maxUnitPriceBox:SetAutoFocus(false)
    maxUnitPriceBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
        self:ApplyFiltersFromUI()
    end)
    maxUnitPriceBox:SetScript("OnEditFocusLost", function()
        self:ApplyFiltersFromUI()
    end)

    local sortButton = createButton(frame, "Sort", 170, 24)
    self.sortButton = sortButton
    sortButton:SetPoint("TOPLEFT", minStackLabel, "BOTTOMLEFT", 0, -10)
    sortButton:SetScript("OnClick", function()
        local settings = getSettings()
        settings.selectedSort = BOD.SearchResults:GetNextSortKey(settings.selectedSort)
        BOD.SearchController:RefreshVisibleResults()
        BOD.SearchController.selectedResult = nil
        self:ResetResultScroll()
        self:Refresh()
    end)

    local header = createFontString(frame, "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", sortButton, "BOTTOMLEFT", 0, -8)
    header:SetText("Listings")

    local scrollFrame = CreateFrame("ScrollFrame", "BankOfDurotarResultScrollFrame", frame, "UIPanelScrollFrameTemplate")
    self.resultScrollFrame = scrollFrame
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetSize(340, LIST_HEIGHT)
    scrollFrame:EnableMouseWheel(true)

    local scrollChild = CreateFrame("Frame", "BankOfDurotarResultScrollChild", scrollFrame)
    self.resultScrollChild = scrollChild
    scrollChild:SetSize(320, LIST_HEIGHT)
    scrollFrame:SetScrollChild(scrollChild)

    self.resultScrollBar = _G.BankOfDurotarResultScrollFrameScrollBar
    if self.resultScrollBar then
        self.resultScrollBar:SetValueStep(ROW_STEP)
        self.resultScrollBar:SetScript("OnValueChanged", function(_, value)
            if self.updatingScrollRange then
                return
            end
            scrollFrame:SetVerticalScroll(clamp(value, 0, scrollFrame.maxScroll or 0))
            self:RefreshResultRows()
        end)
    end

    scrollFrame:SetScript("OnMouseWheel", function(scroll, delta)
        local maxScroll = scroll.maxScroll or 0
        local value = clamp((scroll:GetVerticalScroll() or 0) - (delta * ROW_STEP), 0, maxScroll)
        scroll:SetVerticalScroll(value)
        if self.resultScrollBar then
            self.resultScrollBar:SetValue(value)
        end
        self:RefreshResultRows()
    end)

    for index = 1, ROW_COUNT do
        local row = CreateFrame("Button", nil, scrollChild, template)
        row:SetSize(316, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * ROW_STEP))
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:SetScript("OnClick", function(button)
            if button.result then
                BOD.SearchController:SelectResult(button.result)
            end
        end)
        setBackdrop(row)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(32, 32)
        row.icon:SetPoint("LEFT", 6, 0)

        row.name = createFontString(row, "GameFontNormalSmall")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
        row.name:SetSize(146, 14)

        row.stack = createFontString(row, "GameFontHighlightSmall")
        row.stack:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.stack:SetSize(92, 12)

        row.price = createFontString(row, "GameFontHighlightSmall")
        row.price:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
        row.price:SetSize(104, 28)
        row.price:SetJustifyH("RIGHT")

        row.seller = createFontString(row, "GameFontDisableSmall")
        row.seller:SetPoint("TOPLEFT", row.stack, "BOTTOMLEFT", 0, -2)
        row.seller:SetSize(255, 12)

        self.rows[index] = row
    end

    local selectionHeader = createFontString(frame, "GameFontNormalSmall")
    self.selectionHeader = selectionHeader
    selectionHeader:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -10)
    selectionHeader:SetText("Selected Listing")

    self.selectedText = createFontString(frame, "GameFontHighlightSmall")
    self.selectedText:SetPoint("TOPLEFT", selectionHeader, "BOTTOMLEFT", 0, -4)
    self.selectedText:SetSize(340, 95)

    self.contentFrames = {
        title,
        primaryButton,
        self.statusText,
        searchBox,
        searchButton,
        clearButton,
        refreshButton,
        self.resultCountText,
        buyoutOnlyCheck,
        buyoutLabel,
        minStackLabel,
        minStackBox,
        maxPriceLabel,
        maxUnitPriceBox,
        sortButton,
        header,
        scrollFrame,
        selectionHeader,
        self.selectedText,
    }

    frame:Hide()
    self:ApplySavedSettings()
end

function BOD.Sidecar:IsDocked()
    local auctionFrame = getAuctionFrame()
    local width = clampWidth(getSettings().sidecarWidth)
    return getSettings().dockToAuctionHouse and auctionFrame and isFrameShown(auctionFrame) and hasDockRoom(auctionFrame, width)
end

function BOD.Sidecar:ApplySavedSettings()
    local settings = getSettings()
    self.collapsed = settings.sidecarCollapsed and true or false
    self:ApplyLayout()
    self:RefreshFilterControls()
end

function BOD.Sidecar:ApplyResultListLayout(width)
    if not self.resultScrollFrame or self.collapsed then
        return
    end

    local listWidth = math.max(300, width - 50)
    self.resultScrollFrame:SetSize(listWidth, LIST_HEIGHT)
    if self.resultScrollChild then
        self.resultScrollChild:SetSize(listWidth - 22, LIST_HEIGHT)
    end

    for _, row in ipairs(self.rows) do
        row:SetSize(listWidth - 24, ROW_HEIGHT)
        row.name:SetSize(math.max(120, listWidth - 190), 14)
        row.seller:SetSize(math.max(160, listWidth - 72), 12)
    end
end

function BOD.Sidecar:ApplyLayout()
    if not self.frame then
        return
    end

    local settings = getSettings()
    local auctionFrame = getAuctionFrame()
    local width = self.collapsed and COLLAPSED_WIDTH or clampWidth(settings.sidecarWidth)

    self.frame:SetSize(width, 650)
    self.frame:ClearAllPoints()
    self.frame:SetParent(UIParent)
    self.frame:SetMovable(true)

    if settings.dockToAuctionHouse and auctionFrame and isFrameShown(auctionFrame) and hasDockRoom(auctionFrame, width) then
        self.frame:SetParent(auctionFrame)
        self.frame:SetPoint("TOPLEFT", auctionFrame, "TOPRIGHT", 4, -12)
        self.frame:SetMovable(false)
    else
        local position = settings.sidecarPosition or {}
        self.frame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER", position.x or 0, position.y or 0)
        self.frame:SetMovable(true)
    end

    self.collapseButton:SetText(self.collapsed and ">" or "<")

    for _, child in ipairs(self.contentFrames or {}) do
        if child then
            if self.collapsed then
                child:Hide()
            else
                child:Show()
            end
        end
    end
    for _, row in ipairs(self.rows) do
        if self.collapsed then
            row:Hide()
        end
    end

    self:ApplyResultListLayout(width)
end

function BOD.Sidecar:SavePosition()
    if self:IsDocked() or not self.frame then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    getSettings().sidecarPosition = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = math.floor((x or 0) + 0.5),
        y = math.floor((y or 0) + 0.5),
    }
end

function BOD.Sidecar:SetCollapsed(collapsed)
    getSettings().sidecarCollapsed = collapsed and true or false
    self.collapsed = getSettings().sidecarCollapsed
    self:ApplyLayout()
end

function BOD.Sidecar:ResetResultScroll()
    if not self.resultScrollFrame then
        return
    end

    self.resultScrollFrame:SetVerticalScroll(0)
    if self.resultScrollBar then
        self.resultScrollBar:SetValue(0)
    end
end

function BOD.Sidecar:Show()
    self:EnsureCreated()
    self:ApplyLayout()
    self.frame:Show()
    self:Refresh()
end

function BOD.Sidecar:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function BOD.Sidecar:Toggle()
    self:EnsureCreated()
    if self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BOD.Sidecar:StartSearchFromUI()
    self:EnsureCreated()
    local searchText = self.searchBox:GetText()
    getSettings().lastSearchText = searchText
    self:ResetResultScroll()
    BOD.SearchController:StartSearch(searchText)
    self:Refresh()
end

function BOD.Sidecar:ClearSearch()
    if BOD.SearchController.active then
        BOD.SearchController:Cancel("Search cleared by player.")
    end
    self.searchBox:SetText("")
    getSettings().lastSearchText = ""
    BOD.SearchController.rawResults = {}
    BOD.SearchController.visibleResults = {}
    BOD.SearchController.selectedResult = nil
    BOD.SearchController.resultCount = 0
    BOD.SearchController:SetState("IDLE")
    self:ResetResultScroll()
    self:Refresh()
end

function BOD.Sidecar:RefreshFilterControls()
    local filters = getSettings().filters or {}
    if self.buyoutOnlyCheck then
        self.buyoutOnlyCheck:SetChecked(filters.buyoutOnly and true or false)
    end
    if self.minStackBox then
        self.minStackBox:SetText(tostring(filters.minStackSize or ""))
    end
    if self.maxUnitPriceBox then
        self.maxUnitPriceBox:SetText(filters.maxUnitPriceText or "")
    end
end

function BOD.Sidecar:ApplyFiltersFromUI()
    local settings = getSettings()
    settings.filters = settings.filters or {}
    settings.filters.buyoutOnly = self.buyoutOnlyCheck and self.buyoutOnlyCheck:GetChecked() and true or false
    settings.filters.minStackSize = tonumber(self.minStackBox and self.minStackBox:GetText()) or 0
    settings.filters.maxUnitPriceText = self.maxUnitPriceBox and self.maxUnitPriceBox:GetText() or ""
    settings.filters.maxUnitPrice = BOD.SearchResults:ParseMoney(settings.filters.maxUnitPriceText)
    BOD.SearchController:RefreshVisibleResults()
    BOD.SearchController.selectedResult = nil
    self:ResetResultScroll()
    self:Refresh()
end

function BOD.Sidecar:GetScrollOffset()
    if not self.resultScrollFrame then
        return 0
    end
    return math.floor(((self.resultScrollFrame:GetVerticalScroll() or 0) / ROW_STEP) + 0.5)
end

function BOD.Sidecar:UpdateScrollRange()
    if not self.resultScrollFrame then
        return
    end

    local visibleCount = #(BOD.SearchController.visibleResults or {})
    local contentHeight = math.max(LIST_HEIGHT, visibleCount * ROW_STEP)
    local maxScroll = math.max(0, contentHeight - LIST_HEIGHT)
    self.resultScrollFrame.maxScroll = maxScroll

    if self.resultScrollChild then
        local width = self.resultScrollChild:GetWidth() or 320
        self.resultScrollChild:SetSize(width, contentHeight)
    end

    local current = clamp(self.resultScrollFrame:GetVerticalScroll() or 0, 0, maxScroll)
    self.resultScrollFrame:SetVerticalScroll(current)
    if self.resultScrollBar then
        self.updatingScrollRange = true
        self.resultScrollBar:SetMinMaxValues(0, maxScroll)
        self.resultScrollBar:SetValue(current)
        self.updatingScrollRange = false
        if maxScroll > 0 then
            self.resultScrollBar:Show()
        else
            self.resultScrollBar:Hide()
        end
    end
end

function BOD.Sidecar:RefreshResultRows()
    if not self.resultScrollFrame or self.collapsed then
        return
    end

    self:UpdateScrollRange()

    local results = BOD.SearchController.visibleResults or {}
    local scrollOffset = self:GetScrollOffset()
    local selectedResult = BOD.SearchController.selectedResult

    for poolIndex, row in ipairs(self.rows) do
        local dataIndex = scrollOffset + poolIndex
        local result = results[dataIndex]
        row.result = result
        row.dataIndex = dataIndex

        if result then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.resultScrollChild, "TOPLEFT", 0, -((dataIndex - 1) * ROW_STEP))
            row:Show()
            row.icon:SetTexture(result.texture or "Interface\\Icons\\INV_Misc_QuestionMark")

            local r, g, b = getQualityColor(result)
            row.name:SetTextColor(r, g, b)
            row.name:SetText(result.name or "Unknown item")
            row.stack:SetText(tostring(result.stackCount or 0) .. " items")

            if (tonumber(result.buyoutTotal) or 0) > 0 then
                local each = BOD.SearchResults:GetUnitBuyout(result)
                row.price:SetText(BOD:FormatMoney(result.buyoutTotal) .. " total\n" .. BOD:FormatMoney(each) .. " each")
            else
                row.price:SetText("No buyout\nBid: " .. BOD:FormatMoney(result.currentBid or result.minimumBid or 0))
            end

            row.seller:SetText("Seller: " .. tostring(result.ownerFullName or result.owner or "Unknown") .. "  Time: " .. BOD.SearchResults:GetTimeLeftLabel(result.timeLeft))

            if selectedResult and selectedResult.index == result.index then
                row:LockHighlight()
            else
                row:UnlockHighlight()
            end
        else
            row:UnlockHighlight()
            row:Hide()
        end
    end
end

function BOD.Sidecar:Refresh()
    if not self.frame or not self.frame:IsShown() then
        return
    end

    self:ApplyLayout()
    if self.collapsed then
        return
    end

    local stateLabel = getStateLabel()
    local canQuery, queryDetail = BOD.AuctionAPI:CanQuery()
    local queryLine = canQuery and "Query ready" or tostring(queryDetail or "Query unavailable")
    self.statusText:SetText(stateLabel .. "\n" .. queryLine)

    local resultCount = BOD.SearchController.resultCount or 0
    local visibleCount = #(BOD.SearchController.visibleResults or {})
    self.resultCountText:SetText(string.format("%d results, %d shown", resultCount, visibleCount))

    local sortKey = getSettings().selectedSort or "unitBuyout"
    self.sortButton:SetText("Sort: " .. BOD.SearchResults:GetSortLabel(sortKey))

    local searchActive = BOD.SearchController.active == true
    self.primaryButton:SetEnabled(not searchActive)
    self.searchButton:SetEnabled(not searchActive)
    self.refreshButton:SetEnabled(not searchActive)

    self:RefreshResultRows()
    self:RefreshSelection()
end

function BOD.Sidecar:RefreshSelection()
    if not self.selectedText then
        return
    end

    local result = BOD.SearchController.selectedResult
    if not result then
        self.selectedText:SetText("Select a listing to inspect it.\nPurchasing will be added after protected-action verification.")
        return
    end

    local unitBuyout = BOD.SearchResults:GetUnitBuyout(result)
    local lines = {
        tostring(result.itemLink or result.name or "Unknown item"),
        "Stack: " .. tostring(result.stackCount or 0),
        "Total buyout: " .. (((tonumber(result.buyoutTotal) or 0) > 0) and BOD:FormatMoney(result.buyoutTotal) or "No buyout"),
        "Unit buyout: " .. ((unitBuyout > 0) and BOD:FormatMoney(unitBuyout) or "No buyout"),
        "Bid: " .. BOD:FormatMoney(result.currentBid or result.minimumBid or 0),
        "Seller: " .. tostring(result.ownerFullName or result.owner or "Unknown"),
        "Time: " .. BOD.SearchResults:GetTimeLeftLabel(result.timeLeft),
        "Purchasing will be added after protected-action verification.",
    }
    self.selectedText:SetText(table.concat(lines, "\n"))
end

function BOD.Sidecar:ResetPosition()
    getSettings().sidecarPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    }
    self:ApplyLayout()
end

function BOD.Sidecar:OnEvent(event)
    if event == "ADDON_LOADED" then
        self:EnsureCreated()
    elseif event == "AUCTION_HOUSE_SHOW" then
        if getSettings().openWithAuctionHouse then
            self:Show()
        elseif self.frame then
            self:ApplyLayout()
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        self:Hide()
    elseif self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end
