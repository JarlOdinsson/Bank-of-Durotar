local addonName, BOD = ...

BOD.TransactionProbe = {
    frame = nil,
    enabled = false,
    blocked = false,
    state = "DISABLED",
    token = 0,
    listGeneration = 0,
    ownerGeneration = 0,
    bidderGeneration = 0,
    selectedType = nil,
    prepared = nil,
    lastReport = nil,
    events = {},
    selectedPostDurationKey = "12H",
    lastAction = "None",
    lastResult = "None",
    postTestResult = {
        Result = "NOT RUN",
        Reason = "Click Prepare Post Test after entering post values.",
        Output = "Prepared Post Test\nResult: NOT RUN\nNext action: Click Prepare Post Test after entering post values.",
    },
    latestTestOutput = "Latest Test Output\nResult: NOT RUN\nNext action: Run a prepare test.",
}

local ENABLE_PHRASE = "ENABLE TRANSACTION PROBE"
local MAX_EVENTS = 80
local SAMPLE_LIMIT = 8
local RESULT_TIMEOUT = 15
local MAX_POST_GOLD = 214748
local DEFAULT_POST_DURATION_KEY = "12H"
-- Legacy StartAuction uses a duration index, not literal hour counts:
-- 1 = 12 hours, 2 = 24 hours, 3 = 48 hours.
local POST_DURATION_OPTIONS = {
    { key = "12H", label = "12 Hours", apiValue = 1 },
    { key = "24H", label = "24 Hours", apiValue = 2 },
    { key = "48H", label = "48 Hours", apiValue = 3 },
}
local POST_DURATION_BY_KEY = {}
for _, option in ipairs(POST_DURATION_OPTIONS) do
    POST_DURATION_BY_KEY[option.key] = option
end
local TRANSACTION_EVENTS = {
    AUCTION_ITEM_LIST_UPDATE = true,
    AUCTION_OWNED_LIST_UPDATE = true,
    AUCTION_BIDDER_LIST_UPDATE = true,
    AUCTION_MULTISELL_START = true,
    AUCTION_MULTISELL_UPDATE = true,
    AUCTION_MULTISELL_FAILURE = true,
    CHAT_MSG_SYSTEM = true,
    UI_ERROR_MESSAGE = true,
    BAG_UPDATE = true,
    BAG_UPDATE_DELAYED = true,
    ITEM_LOCK_CHANGED = true,
    PLAYER_MONEY = true,
    PLAYER_LOGOUT = true,
    AUCTION_HOUSE_CLOSED = true,
    ADDON_ACTION_BLOCKED = true,
    ADDON_ACTION_FORBIDDEN = true,
}

local BUSY_STATES = {
    CALL_SENT = true,
    WAITING_FOR_RESULT = true,
}

local CAPABILITY_NAMES = {
    "PlaceAuctionBid",
    "StartAuction",
    "CancelAuction",
    "ClickAuctionSellItemButton",
    "GetAuctionSellItemInfo",
    "ClearCursor",
    "PickupContainerItem",
    "GetAuctionDeposit",
    "GetAuctionItemInfo",
    "GetAuctionItemLink",
    "GetAuctionItemTimeLeft",
    "GetNumAuctionItems",
    "QueryAuctionItems",
    "CanSendAuctionQuery",
    "GetMoney",
}

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function valueType(value)
    if value == nil then
        return "nil"
    end
    return type(value)
end

local function isFunction(name)
    return type(_G[name]) == "function"
end

local function createFontString(parent, template)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

local function disableTextWrap(text)
    if not text then
        return
    end
    if text.SetWordWrap then
        text:SetWordWrap(false)
    end
    if text.SetNonSpaceWrap then
        text:SetNonSpaceWrap(false)
    end
end

local function createButton(parent, label, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 130, height or 24)
    button:SetText(label)
    return button
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
        frame:SetBackdropColor(0.04, 0.025, 0.015, 0.98)
    end
end

local function getMoney()
    if type(GetMoney) == "function" then
        local ok, money = pcall(GetMoney)
        if ok then
            return tonumber(money) or 0
        end
    end
    return nil
end

local function formatMoney(copper)
    if copper == nil then
        return "unknown"
    end
    return BOD:FormatMoney(copper)
end

local function formatMoneyPreview(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100
    if gold > 0 then
        return string.format("%dg %02ds %02dc", gold, silver, copperOnly)
    end
    return string.format("%ds %02dc", silver, copperOnly)
end

local function denominationsToCopper(gold, silver, copper)
    return (gold * 10000) + (silver * 100) + copper
end

local function parseDenominationField(text, label, maxValue)
    local valueText = trim(text)
    if valueText == "" then
        return nil, label .. " is blank."
    end
    if not valueText:match("^%d+$") then
        return nil, label .. " must be a non-negative whole number."
    end

    local value = tonumber(valueText)
    if not value or value < 0 or value > maxValue then
        return nil, label .. " must be between 0 and " .. tostring(maxValue) .. "."
    end
    return value, nil
end

local function getItemIDFromLink(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end
    return tonumber(itemLink:match("item:(%d+)"))
end

local function normalizeAuctionResult(listType, index)
    if not isFunction("GetAuctionItemInfo") then
        return nil, "GetAuctionItemInfo unavailable"
    end

    local ok, name, texture, stackCount, quality, canUse, requiredLevel, levelColHeader,
        minimumBid, minimumIncrement, buyoutTotal, currentBid, highBidder,
        bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo =
        pcall(GetAuctionItemInfo, listType, index)

    if not ok then
        return nil, tostring(name)
    end

    local itemLink
    if isFunction("GetAuctionItemLink") then
        local linkOk, link = pcall(GetAuctionItemLink, listType, index)
        if linkOk then
            itemLink = link
        end
    end

    local timeLeft
    if isFunction("GetAuctionItemTimeLeft") then
        local timeOk, value = pcall(GetAuctionItemTimeLeft, listType, index)
        if timeOk then
            timeLeft = value
        end
    end

    stackCount = tonumber(stackCount) or 0
    buyoutTotal = tonumber(buyoutTotal) or 0

    local result = {
        listType = listType,
        index = index,
        name = name,
        itemLink = itemLink,
        itemID = tonumber(itemID) or getItemIDFromLink(itemLink),
        texture = texture,
        stackCount = stackCount,
        quality = quality,
        requiredLevel = requiredLevel,
        minimumBid = tonumber(minimumBid) or 0,
        minimumIncrement = tonumber(minimumIncrement) or 0,
        buyoutTotal = buyoutTotal,
        currentBid = tonumber(currentBid) or 0,
        highBidder = highBidder,
        bidderFullName = bidderFullName,
        owner = owner,
        ownerFullName = ownerFullName,
        timeLeft = timeLeft,
        saleStatus = saleStatus,
        hasAllInfo = hasAllInfo,
    }

    if buyoutTotal > 0 and stackCount > 0 then
        result.buyoutPerUnit = math.floor(buyoutTotal / stackCount)
    end

    return result
end

local function snapshotMatches(left, right, requireBuyout)
    if not left or not right then
        return false, "Missing listing data"
    end
    if left.name ~= right.name then
        return false, "Item name changed"
    end
    if left.itemID and right.itemID and left.itemID ~= right.itemID then
        return false, "Item ID changed"
    end
    if tonumber(left.stackCount) ~= tonumber(right.stackCount) then
        return false, "Stack count changed"
    end
    if requireBuyout and tonumber(left.buyoutTotal or 0) ~= tonumber(right.buyoutTotal or 0) then
        return false, "Buyout changed"
    end
    if left.ownerFullName and right.ownerFullName and left.ownerFullName ~= right.ownerFullName then
        return false, "Seller changed"
    end
    return true, "matched"
end

local function fieldTypes(record)
    local lines = {}
    for key, value in pairs(record or {}) do
        lines[#lines + 1] = tostring(key) .. "=" .. type(value)
    end
    table.sort(lines)
    return table.concat(lines, ", ")
end

function BOD.TransactionProbe:SetState(state, detail)
    self.state = state
    self.lastAction = state
    self.lastResult = detail or state
    self:AddLine("State: " .. state .. (detail and (": " .. detail) or ""))
    self:Refresh()
end

function BOD.TransactionProbe:AddEvent(event, ...)
    if not TRANSACTION_EVENTS[event] then
        return
    end

    local args = {}
    if event == "CHAT_MSG_SYSTEM" then
        args[1] = "[system message redacted]"
    else
        for index = 1, select("#", ...) do
            args[index] = tostring(select(index, ...))
        end
    end

    self.events[#self.events + 1] = {
        timestamp = time(),
        event = event,
        args = args,
    }
    while #self.events > MAX_EVENTS do
        table.remove(self.events, 1)
    end
end

function BOD.TransactionProbe:AddLine(line)
    self.reportLines = self.reportLines or {}
    self.reportLines[#self.reportLines + 1] = BOD:FormatTimestamp(time()) .. " " .. tostring(line)
    while #self.reportLines > 120 do
        table.remove(self.reportLines, 1)
    end
end

function BOD.TransactionProbe:ClearPrepared(reason)
    self.prepared = nil
    self.selectedType = nil
    if self.enabled and not self.blocked then
        self.state = "IDLE"
    elseif self.blocked then
        self.state = "BLOCKED"
    else
        self.state = "DISABLED"
    end
    if reason then
        self:AddLine("Prepared transaction cleared: " .. tostring(reason))
    end
    self:Refresh()
end

function BOD.TransactionProbe:ReadMoneyInput(prefix, boxes)
    if not boxes then
        return nil, prefix .. " fields are unavailable."
    end

    local gold, goldError = parseDenominationField(boxes.gold and boxes.gold:GetText(), prefix .. " gold", MAX_POST_GOLD)
    if goldError then
        return nil, goldError
    end

    local silver, silverError = parseDenominationField(boxes.silver and boxes.silver:GetText(), prefix .. " silver", 99)
    if silverError then
        return nil, silverError
    end

    local copper, copperError = parseDenominationField(boxes.copper and boxes.copper:GetText(), prefix .. " copper", 99)
    if copperError then
        return nil, copperError
    end

    return denominationsToCopper(gold, silver, copper), nil
end

function BOD.TransactionProbe:UpdateMoneyPreview(prefix, boxes, preview)
    if not preview then
        return
    end

    local total, errorMessage = self:ReadMoneyInput(prefix, boxes)
    if errorMessage then
        preview:SetText(prefix .. " total: invalid - " .. errorMessage)
        return
    end

    preview:SetText(prefix .. " total: " .. formatMoneyPreview(total))
end

function BOD.TransactionProbe:RefreshPricePreviews()
    self:UpdateMoneyPreview("Bid", self.bidMoneyBoxes, self.bidPreviewText)
    self:UpdateMoneyPreview("Buyout", self.buyoutMoneyBoxes, self.buyoutPreviewText)
end

function BOD.TransactionProbe:SetPostTestResult(result)
    self.postTestResult = result or {
        Result = "NOT RUN",
        Reason = "Click Prepare Post Test after entering post values.",
        Output = table.concat({
            "Prepared Post Test",
            "Result: NOT RUN",
            "Next action: Click Prepare Post Test after entering post values.",
        }, "\n"),
    }
    self.latestTestOutput = self.postTestResult.Output
    self:RefreshPostResultRows()
    self:RefreshLatestTestOutput()
end

function BOD.TransactionProbe:SetLatestTestOutput(title, result, lines)
    local output = {
        tostring(title or "Latest Test Output"),
        "Result: " .. tostring(result or "UNKNOWN"),
    }
    for _, line in ipairs(lines or {}) do
        output[#output + 1] = tostring(line)
    end
    self.latestTestOutput = table.concat(output, "\n")
    self:RefreshLatestTestOutput()
end

function BOD.TransactionProbe:PersistProtectedAttempt(actionType, functionName, args)
    local record = {
        timestamp = time(),
        actionType = tostring(actionType or "UNKNOWN"),
        functionName = tostring(functionName or "UNKNOWN"),
        argumentTypes = fieldTypes(args),
        stateBeforeCall = tostring(self.state),
        warning = "Direct protected Auction House call attempted by developer probe; do not retry if blocked or disabled.",
    }
    self.lastProtectedAttempt = record
    if BOD.db and BOD.db.diagnostics and BOD.db.diagnostics.transactionProbe then
        BOD.db.diagnostics.transactionProbe.lastProtectedAttempt = record
    end
end

function BOD.TransactionProbe:PersistTerminalFailure(classification, detail)
    local record = {
        timestamp = time(),
        classification = tostring(classification or "UNKNOWN"),
        detail = tostring(detail or "No detail."),
        state = tostring(self.state),
        blocked = tostring(self.blocked),
        preparedType = self.prepared and tostring(self.prepared.actionType) or "none",
        protectedAttempt = self.lastProtectedAttempt,
        instruction = "Do not retry this direct protected action. Review compliant Blizzard-UI-assisted approaches only.",
    }
    self.lastTerminalFailure = record
    if BOD.db and BOD.db.diagnostics and BOD.db.diagnostics.transactionProbe then
        BOD.db.diagnostics.transactionProbe.lastTerminalFailure = record
    end
end

function BOD.TransactionProbe:SetPostTestFailed(reason)
    self:SetPostTestResult({
        Result = "FAILED",
        Reason = tostring(reason or "Unknown validation error."),
        Output = table.concat({
            "Prepared Post Test",
            "Result: FAILED",
            "Reason: " .. tostring(reason or "Unknown validation error."),
        }, "\n"),
    })
end

function BOD.TransactionProbe:SetPostTestPassed(snapshot)
    local output = {
        "Prepared Post Test",
        "Result: PASSED",
        "Item: " .. tostring(snapshot.name or "unknown"),
        "Stack: " .. tostring(snapshot.stackSize or snapshot.count or "unknown"),
        "Bid total: " .. formatMoneyPreview(snapshot.bid),
        "Buyout total: " .. formatMoneyPreview(snapshot.buyout),
        "Duration: " .. tostring(snapshot.durationLabel or "unknown"),
        "API value: " .. tostring(snapshot.duration or "unknown"),
        "Deposit: " .. formatMoney(snapshot.deposit),
        "Validation: Safe to prepare final click",
        "Next action: Review values, then click Prepare Final Click",
        "",
        "Validation checks:",
        "- Sell slot item: PASS",
        "- Bid price: PASS",
        "- Buyout price: PASS",
        "- Buyout >= bid: PASS",
        "- Stack count: PASS",
        "- Duration mapping: PASS",
        "- Protected call made: NO",
    }
    self:SetPostTestResult({
        Result = "PASSED",
        Item = tostring(snapshot.name or "unknown"),
        Stack = tostring(snapshot.stackSize or snapshot.count or "unknown"),
        ["Bid total"] = formatMoneyPreview(snapshot.bid),
        ["Buyout total"] = formatMoneyPreview(snapshot.buyout),
        ["Auction duration"] = tostring(snapshot.durationLabel or "unknown"),
        ["Legacy duration API value"] = tostring(snapshot.duration or "unknown"),
        Deposit = formatMoney(snapshot.deposit),
        ["Validation status"] = "Safe to prepare final click",
        ["Next action"] = "Review values, then click Prepare Final Click",
        Output = table.concat(output, "\n"),
    })
end

function BOD.TransactionProbe:MarkPostResultStale(reason)
    if not self.postTestResult or self.postTestResult.Result == "NOT RUN" then
        return
    end
    self:SetPostTestResult({
        Result = "STALE",
        Reason = tostring(reason or "Post test inputs changed; run Prepare Post Test again."),
        Output = table.concat({
            "Prepared Post Test",
            "Result: STALE",
            "Reason: " .. tostring(reason or "Post test inputs changed; run Prepare Post Test again."),
            "Next action: Run Prepare Post Test again.",
        }, "\n"),
    })
end

function BOD.TransactionProbe:OnPostPriceFieldChanged()
    self:RefreshPricePreviews()
    self:MarkPostResultStale("Price changed; run Prepare Post Test again.")
    if self.prepared and self.prepared.actionType == "POST" and (self.state == "PREPARED" or self.state == "READY_FOR_FINAL_CLICK") then
        self:ClearPrepared("Post price changed; prepare the post test again.")
    else
        self:Refresh()
    end
end

function BOD.TransactionProbe:OnPostStackFieldChanged()
    self:MarkPostResultStale("Stack fields changed; run Prepare Post Test again.")
    if self.prepared and self.prepared.actionType == "POST" and (self.state == "PREPARED" or self.state == "READY_FOR_FINAL_CLICK") then
        self:ClearPrepared("Post stack changed; prepare the post test again.")
    else
        self:Refresh()
    end
end

function BOD.TransactionProbe:GetSelectedPostDurationOption()
    local option = POST_DURATION_BY_KEY[self.selectedPostDurationKey or DEFAULT_POST_DURATION_KEY]
    if not option then
        option = POST_DURATION_BY_KEY[DEFAULT_POST_DURATION_KEY]
        self.selectedPostDurationKey = DEFAULT_POST_DURATION_KEY
    end
    return option
end

function BOD.TransactionProbe:RefreshDurationButtons()
    if not self.durationButtons then
        return
    end

    local selected = self:GetSelectedPostDurationOption()
    for key, button in pairs(self.durationButtons) do
        button:SetChecked(key == selected.key)
    end
end

function BOD.TransactionProbe:RefreshSelectedBrowseIndex()
    if not self.selectedBrowseIndexBox then
        return
    end

    local selected = BOD.SearchController and BOD.SearchController.selectedResult
    if selected and selected.index then
        self.selectedBrowseIndexBox:SetText(tostring(selected.index))
    else
        self.selectedBrowseIndexBox:SetText("")
    end
end

function BOD.TransactionProbe:SelectPostDuration(key)
    if not POST_DURATION_BY_KEY[key] then
        key = DEFAULT_POST_DURATION_KEY
    end

    local changed = self.selectedPostDurationKey ~= key
    self.selectedPostDurationKey = key
    self:RefreshDurationButtons()

    if changed and self.prepared and self.prepared.actionType == "POST" and (self.state == "PREPARED" or self.state == "READY_FOR_FINAL_CLICK") then
        self:MarkPostResultStale("Auction duration changed; run Prepare Post Test again.")
        self:ClearPrepared("Auction duration changed; prepare the post test again.")
    else
        if changed then
            self:MarkPostResultStale("Auction duration changed; run Prepare Post Test again.")
        end
        self:Refresh()
    end
end

function BOD.TransactionProbe:EnableFromPhrase(phrase)
    if trim(phrase) ~= ENABLE_PHRASE then
        self:AddLine("Enable phrase did not match.")
        self:Refresh()
        return false
    end

    self.enabled = true
    self.blocked = false
    self.events = {}
    self.reportLines = {}
    self:SetState("IDLE", "Developer transaction probe enabled for this session.")
    BOD:Print("Developer transaction probe enabled for this session only.")
    return true
end

function BOD.TransactionProbe:Disable(reason)
    self.enabled = false
    self.prepared = nil
    self.selectedType = nil
    self.selectedPostDurationKey = DEFAULT_POST_DURATION_KEY
    self:RefreshDurationButtons()
    self:SetState(self.blocked and "BLOCKED" or "DISABLED", reason or "Disabled.")
end

function BOD.TransactionProbe:RequireEnabled()
    if self.blocked then
        self:SetState("BLOCKED", "The client blocked this action. No retry was attempted.")
        return false
    end
    if not self.enabled then
        self:SetState("DISABLED", "Enter the enable phrase first.")
        return false
    end
    return true
end

function BOD.TransactionProbe:IsBusy()
    return BUSY_STATES[self.state] == true
end

function BOD.TransactionProbe:GetCapabilities()
    local capabilities = {}
    local seen = {}
    for _, name in ipairs(CAPABILITY_NAMES) do
        seen[name] = true
        capabilities[#capabilities + 1] = {
            name = name,
            valueType = valueType(_G[name]),
            available = type(_G[name]) == "function",
        }
    end
    for name, value in pairs(_G) do
        if type(name) == "string" and type(value) == "function" and not seen[name] and name:find("Auction") then
            capabilities[#capabilities + 1] = {
                name = name,
                valueType = "function",
                available = true,
                discovered = true,
            }
        end
    end
    table.sort(capabilities, function(left, right)
        return tostring(left.name) < tostring(right.name)
    end)
    return capabilities
end

function BOD.TransactionProbe:InspectCapabilities()
    if not self:RequireEnabled() then
        return
    end
    self.capabilities = self:GetCapabilities()
    self:AddLine("Capability inspection completed.")
    self:PersistReport()
    self:Refresh()
end

function BOD.TransactionProbe:InspectAuctionList(listType)
    if not self:RequireEnabled() then
        return
    end
    if not isFunction("GetNumAuctionItems") then
        self:SetState("FAILED", "GetNumAuctionItems unavailable.")
        return
    end

    local ok, count = pcall(GetNumAuctionItems, listType)
    if not ok then
        self:SetState("FAILED", "GetNumAuctionItems(" .. listType .. ") failed: " .. tostring(count))
        return
    end

    count = tonumber(count) or 0
    local sample = {}
    for index = 1, math.min(count, SAMPLE_LIMIT) do
        local result = normalizeAuctionResult(listType, index)
        if result then
            sample[#sample + 1] = result
        end
    end

    if listType == "owner" then
        self.ownerSample = sample
        self.ownerCount = count
        self.ownerFieldTypes = sample[1] and fieldTypes(sample[1]) or "none"
    else
        self.bidderSample = sample
        self.bidderCount = count
        self.bidderFieldTypes = sample[1] and fieldTypes(sample[1]) or "none"
    end

    self:AddLine("Read-only " .. listType .. " inspection completed; count=" .. tostring(count) .. ", sampled=" .. tostring(#sample) .. ".")
    self:PersistReport()
    self:Refresh()
end

function BOD.TransactionProbe:InspectSellSlot()
    if not self:RequireEnabled() then
        return
    end

    local durationOption = self:GetSelectedPostDurationOption()
    local info = {
        available = isFunction("GetAuctionSellItemInfo"),
        depositAvailable = isFunction("GetAuctionDeposit"),
        duration = durationOption.apiValue,
        durationLabel = durationOption.label,
    }

    if isFunction("GetAuctionSellItemInfo") then
        local ok, name, texture, count, quality, canUse, price = pcall(GetAuctionSellItemInfo)
        info.callSucceeded = ok
        if ok then
            info.name = name
            info.texture = texture
            info.count = tonumber(count) or 0
            info.quality = quality
            info.canUse = canUse
            info.price = price
        else
            info.error = tostring(name)
        end
    end

    if isFunction("GetAuctionDeposit") then
        local depositOk, deposit = pcall(GetAuctionDeposit, info.duration, 1, 1)
        info.depositCallSucceeded = depositOk
        if depositOk then
            info.deposit = tonumber(deposit) or 0
        else
            info.depositError = tostring(deposit)
        end
    end

    self.sellSlot = info
    self:AddLine("Read-only sell-slot inspection completed.")
    self:PersistReport()
    self:Refresh()
end

function BOD.TransactionProbe:PrepareBuyout()
    if not self:RequireEnabled() then
        self:SetLatestTestOutput("Prepared Buyout Test", "FAILED", {
            "Reason: Enter the enable phrase first.",
        })
        return
    end
    if self:IsBusy() then
        self:SetLatestTestOutput("Prepared Buyout Test", "FAILED", {
            "Reason: A transaction call is already pending; no queue was created.",
        })
        self:SetState(self.state, "A transaction call is already pending; no queue was created.")
        return
    end
    if not BOD.SearchController or not BOD.SearchController.selectedResult then
        self:SetLatestTestOutput("Prepared Buyout Test", "FAILED", {
            "Reason: Select one sidecar search result before preparing a buyout test.",
        })
        self:SetState("FAILED", "Select one sidecar search result before preparing a buyout test.")
        return
    end

    local selected = BOD.SearchController.selectedResult
    local live = normalizeAuctionResult("list", selected.index)
    local matches, reason = snapshotMatches(selected, live, true)
    if not matches then
        self:SetLatestTestOutput("Prepared Buyout Test", "FAILED", {
            "Reason: Selected auction is stale: " .. tostring(reason),
        })
        self:SetState("FAILED", "Selected auction is stale: " .. reason)
        return
    end
    if (tonumber(live.buyoutTotal) or 0) <= 0 then
        self:SetLatestTestOutput("Prepared Buyout Test", "FAILED", {
            "Reason: Selected auction has no buyout.",
        })
        self:SetState("FAILED", "Selected auction has no buyout.")
        return
    end
    if getMoney() and getMoney() < live.buyoutTotal then
        self:SetLatestTestOutput("Prepared Buyout Test", "FAILED", {
            "Reason: Insufficient money for selected buyout.",
        })
        self:SetState("FAILED", "Insufficient money for selected buyout.")
        return
    end

    self.token = self.token + 1
    self.prepared = {
        token = self.token,
        actionType = "BUYOUT",
        listGeneration = self.listGeneration,
        snapshot = live,
        moneyBefore = getMoney(),
        preparedAt = time(),
    }
    self.selectedType = "BUYOUT"
    self:SetLatestTestOutput("Prepared Buyout Test", "PASSED", {
        "Item: " .. tostring(live.name or "unknown"),
        "Stack: " .. tostring(live.count or "unknown"),
        "Selected index: " .. tostring(live.index or selected.index or "unknown"),
        "Buyout total: " .. formatMoney(live.buyoutTotal),
        "Validation: Safe to prepare final click",
        "Next action: Review values, then click Prepare Final Click",
    })
    self:SetState("PREPARED", "Buyout test prepared. Review, then use Prepare Final Click.")
end

function BOD.TransactionProbe:PrepareCancel()
    if not self:RequireEnabled() then
        self:SetLatestTestOutput("Prepared Cancel Test", "FAILED", {
            "Reason: Enter the enable phrase first.",
        })
        return
    end
    if self:IsBusy() then
        self:SetLatestTestOutput("Prepared Cancel Test", "FAILED", {
            "Reason: A transaction call is already pending; no queue was created.",
        })
        self:SetState(self.state, "A transaction call is already pending; no queue was created.")
        return
    end
    local index = tonumber(self.ownerIndexBox and self.ownerIndexBox:GetText())
    if not index or index < 1 then
        self:SetLatestTestOutput("Prepared Cancel Test", "FAILED", {
            "Reason: Enter one owned-auction index before preparing cancel.",
        })
        self:SetState("FAILED", "Enter one owned-auction index before preparing cancel.")
        return
    end

    local live, errorMessage = normalizeAuctionResult("owner", index)
    if not live then
        self:SetLatestTestOutput("Prepared Cancel Test", "FAILED", {
            "Reason: Could not read owner listing: " .. tostring(errorMessage),
        })
        self:SetState("FAILED", "Could not read owner listing: " .. tostring(errorMessage))
        return
    end

    self.token = self.token + 1
    self.prepared = {
        token = self.token,
        actionType = "CANCEL",
        ownerGeneration = self.ownerGeneration,
        snapshot = live,
        moneyBefore = getMoney(),
        preparedAt = time(),
    }
    self.selectedType = "CANCEL"
    self:SetLatestTestOutput("Prepared Cancel Test", "PASSED", {
        "Item: " .. tostring(live.name or "unknown"),
        "Stack: " .. tostring(live.count or "unknown"),
        "Owned auction index: " .. tostring(index),
        "Validation: Safe to prepare final click",
        "Next action: Review values, then click Prepare Final Click",
    })
    self:SetState("PREPARED", "Cancel test prepared. Review, then use Prepare Final Click.")
end

function BOD.TransactionProbe:PreparePost()
    if not self:RequireEnabled() then
        self:SetPostTestFailed("Enter the enable phrase first.")
        return
    end
    if self:IsBusy() then
        self:SetPostTestFailed("A transaction call is already pending; no queue was created.")
        self:SetState(self.state, "A transaction call is already pending; no queue was created.")
        return
    end

    self:InspectSellSlot()
    local slot = self.sellSlot
    if not slot or not slot.callSucceeded or not slot.name or (tonumber(slot.count) or 0) <= 0 then
        self:SetPostTestFailed("Place one cheap item in Blizzard's sell slot first.")
        self:SetState("FAILED", "Place one cheap item in Blizzard's sell slot first.")
        return
    end

    local bid, bidError = self:ReadMoneyInput("Bid", self.bidMoneyBoxes)
    if bidError then
        self:SetPostTestFailed(bidError)
        self:SetState("FAILED", bidError)
        return
    end

    local buyout, buyoutError = self:ReadMoneyInput("Buyout", self.buyoutMoneyBoxes)
    if buyoutError then
        self:SetPostTestFailed(buyoutError)
        self:SetState("FAILED", buyoutError)
        return
    end

    local durationOption = self:GetSelectedPostDurationOption()
    local duration = durationOption.apiValue
    local stackSize = tonumber(self.stackSizeBox and self.stackSizeBox:GetText()) or tonumber(slot.count) or 1
    local numStacks = tonumber(self.numStacksBox and self.numStacksBox:GetText()) or 1

    if bid <= 0 then
        self:SetPostTestFailed("Bid price must be greater than zero.")
        self:SetState("FAILED", "Bid price must be greater than zero.")
        return
    end
    if buyout <= 0 then
        self:SetPostTestFailed("Buyout price must be greater than zero.")
        self:SetState("FAILED", "Buyout price must be greater than zero.")
        return
    end
    if buyout < bid then
        self:SetPostTestFailed("Buyout price must be at least as high as bid.")
        self:SetState("FAILED", "Buyout price must be at least as high as bid.")
        return
    end
    if numStacks ~= 1 then
        self:SetPostTestFailed("This probe supports exactly one stack.")
        self:SetState("FAILED", "This probe supports exactly one stack.")
        return
    end

    self.token = self.token + 1
    self.prepared = {
        token = self.token,
        actionType = "POST",
        snapshot = {
            name = slot.name,
            count = tonumber(slot.count) or 0,
            bid = bid,
            buyout = buyout,
            duration = duration,
            durationLabel = durationOption.label,
            stackSize = stackSize,
            numStacks = numStacks,
            deposit = slot.deposit,
        },
        moneyBefore = getMoney(),
        preparedAt = time(),
    }
    self.selectedType = "POST"
    self:SetPostTestPassed(self.prepared.snapshot)
    self:SetState("PREPARED", "Post test prepared. Review, then use Prepare Final Click.")
end

function BOD.TransactionProbe:PrepareFinalClick()
    if not self:RequireEnabled() then
        self:SetLatestTestOutput("Final Confirmation", "FAILED", {
            "Reason: Enter the enable phrase first.",
        })
        return
    end
    if not self.prepared then
        self:SetLatestTestOutput("Final Confirmation", "FAILED", {
            "Reason: No prepared transaction.",
            "Next action: Run Prepare Buyout Test, Prepare Post Test, or Prepare Cancel Test first.",
        })
        return
    end
    local ok, reason = self:RevalidatePrepared()
    if not ok then
        local actionType = self.prepared and self.prepared.actionType or "UNKNOWN"
        self:SetLatestTestOutput("Final Confirmation", "FAILED", {
            "Prepared type: " .. tostring(actionType),
            "Reason: " .. tostring(reason),
            "Next action: Fix the input, then run the matching prepare test again.",
        })
        self:SetState("FAILED", reason)
        self:ClearPrepared(reason)
        return
    end
    self:SetLatestTestOutput("Final Confirmation", "PASSED", {
        "Prepared type: " .. tostring(self.prepared.actionType),
        "Validation: Safe to execute exactly one protected call",
        "Next action: Click " .. tostring(self.executeButton and self.executeButton:GetText() or "the execute button") .. " once.",
    })
    self:SetState("READY_FOR_FINAL_CLICK", "Final button may execute exactly one " .. self.prepared.actionType .. " call.")
end

function BOD.TransactionProbe:RevalidatePrepared()
    local prepared = self.prepared
    if not prepared then
        return false, "No prepared transaction."
    end
    if not BOD.AuctionAPI:IsAuctionHouseOpen() then
        return false, "Auction House is closed."
    end
    if prepared.actionType == "BUYOUT" then
        if prepared.listGeneration ~= self.listGeneration then
            return false, "Result list refreshed after preparation."
        end
        local live = normalizeAuctionResult("list", prepared.snapshot.index)
        local matches, reason = snapshotMatches(prepared.snapshot, live, true)
        if not matches then
            return false, reason
        end
        if getMoney() and getMoney() < prepared.snapshot.buyoutTotal then
            return false, "Insufficient money."
        end
    elseif prepared.actionType == "CANCEL" then
        if prepared.ownerGeneration ~= self.ownerGeneration then
            return false, "Owner list refreshed after preparation."
        end
        local live = normalizeAuctionResult("owner", prepared.snapshot.index)
        local matches, reason = snapshotMatches(prepared.snapshot, live, false)
        if not matches then
            return false, reason
        end
    elseif prepared.actionType == "POST" then
        if not isFunction("GetAuctionSellItemInfo") then
            return false, "GetAuctionSellItemInfo unavailable."
        end
        local ok, name, texture, count = pcall(GetAuctionSellItemInfo)
        if not ok then
            return false, "Sell slot re-read failed: " .. tostring(name)
        end
        if name ~= prepared.snapshot.name then
            return false, "Sell-slot item changed."
        end
        if tonumber(count) ~= tonumber(prepared.snapshot.count) then
            return false, "Sell-slot quantity changed."
        end
    end
    return true, "matched"
end

function BOD.TransactionProbe:ExecutePreparedFromClick()
    if not self:RequireEnabled() then
        self:SetLatestTestOutput("Execute Prepared Test", "FAILED", {
            "Reason: Enter the enable phrase first.",
        })
        return
    end
    if not self.prepared then
        self:SetLatestTestOutput("Execute Prepared Test", "FAILED", {
            "Reason: No prepared transaction.",
            "Next action: Run a prepare test, then Prepare Final Click.",
        })
        return
    end
    if self.state ~= "READY_FOR_FINAL_CLICK" then
        self:SetLatestTestOutput("Execute Prepared Test", "FAILED", {
            "Prepared type: " .. tostring(self.prepared.actionType),
            "Reason: Use Prepare Final Click before executing.",
        })
        self:SetState("FAILED", "Use Prepare Final Click before executing.")
        return
    end

    local ok, reason = self:RevalidatePrepared()
    if not ok then
        local actionType = self.prepared and self.prepared.actionType or "UNKNOWN"
        self:SetLatestTestOutput("Execute Prepared Test", "FAILED", {
            "Prepared type: " .. tostring(actionType),
            "Reason: " .. tostring(reason),
            "Next action: Run the matching prepare test again.",
        })
        self:SetState("FAILED", reason)
        self:ClearPrepared(reason)
        return
    end

    self:SetState("CALL_SENT", "Calling one protected function from final visible button.")
    self.prepared.moneyBefore = getMoney()

    if self.prepared.actionType == "BUYOUT" then
        self:ExecuteBuyoutFromClick()
    elseif self.prepared.actionType == "POST" then
        self:ExecutePostFromClick()
    elseif self.prepared.actionType == "CANCEL" then
        self:ExecuteCancelFromClick()
    end
end

function BOD.TransactionProbe:ExecuteBuyoutFromClick()
    local snapshot = self.prepared.snapshot
    self.prepared.functionCalled = "PlaceAuctionBid"
    self.prepared.arguments = { "list", snapshot.index, snapshot.buyoutTotal }
    self:PersistProtectedAttempt("BUYOUT", "PlaceAuctionBid", self.prepared.arguments)
    local ok, errorMessage = pcall(PlaceAuctionBid, "list", snapshot.index, snapshot.buyoutTotal)
    self:AfterProtectedCall(ok, errorMessage)
end

function BOD.TransactionProbe:ExecutePostFromClick()
    local snapshot = self.prepared.snapshot
    self.prepared.functionCalled = "StartAuction"
    self.prepared.arguments = { snapshot.bid, snapshot.buyout, snapshot.duration, snapshot.stackSize, 1 }
    self:PersistProtectedAttempt("POST", "StartAuction", self.prepared.arguments)
    local ok, errorMessage = pcall(StartAuction, snapshot.bid, snapshot.buyout, snapshot.duration, snapshot.stackSize, 1)
    self:AfterProtectedCall(ok, errorMessage)
end

function BOD.TransactionProbe:ExecuteCancelFromClick()
    local snapshot = self.prepared.snapshot
    self.prepared.functionCalled = "CancelAuction"
    self.prepared.arguments = { snapshot.index }
    self:PersistProtectedAttempt("CANCEL", "CancelAuction", self.prepared.arguments)
    local ok, errorMessage = pcall(CancelAuction, snapshot.index)
    self:AfterProtectedCall(ok, errorMessage)
end

function BOD.TransactionProbe:AfterProtectedCall(ok, errorMessage)
    self.prepared.callSucceeded = ok
    self.prepared.callError = ok and nil or tostring(errorMessage)
    self.prepared.moneyAfterImmediate = getMoney()
    if not ok then
        self:SetLatestTestOutput("Execute Prepared Test", "FAILED", {
            "Prepared type: " .. tostring(self.prepared.actionType),
            "Reason: Protected call failed: " .. tostring(errorMessage),
        })
        self:SetState("FAILED", tostring(errorMessage))
        self:PersistTerminalFailure("Lua error from protected call", tostring(errorMessage))
        self:PersistReport()
        return
    end

    self:SetLatestTestOutput("Execute Prepared Test", "CALLED", {
        "Prepared type: " .. tostring(self.prepared.actionType),
        "Protected call: one call was issued",
        "Next action: Wait for a terminal event or timeout.",
    })
    self:SetState("WAITING_FOR_RESULT", "One call sent; no retry will be attempted.")
    local token = self.token
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(RESULT_TIMEOUT, function()
            if token == self.token and self.state == "WAITING_FOR_RESULT" then
                self:Timeout()
            end
        end)
    end
end

function BOD.TransactionProbe:Timeout()
    if self.prepared then
        self:SetLatestTestOutput("Execute Prepared Test", "TIMED OUT", {
            "Prepared type: " .. tostring(self.prepared.actionType),
            "Reason: No terminal event observed before timeout.",
        })
        self.prepared.moneyAfter = getMoney()
    end
    self:SetState("TIMED_OUT", "No terminal event observed before timeout.")
    self:PersistTerminalFailure("timeout", "No terminal event observed before timeout.")
    self:PersistReport()
end

function BOD.TransactionProbe:MarkSucceeded(reason)
    if self.state == "WAITING_FOR_RESULT" and self.prepared then
        self:SetLatestTestOutput("Execute Prepared Test", "SUCCEEDED", {
            "Prepared type: " .. tostring(self.prepared.actionType),
            "Reason: " .. tostring(reason),
        })
        self.prepared.moneyAfter = getMoney()
        self:SetState("SUCCEEDED", reason)
        self:PersistReport()
    end
end

function BOD.TransactionProbe:MarkBlocked(event, ...)
    self.blocked = true
    self.enabled = false
    local blockedAddon = tostring(select(1, ...))
    local blockedFunction = tostring(select(2, ...))
    self.blockedEvent = {
        event = event,
        addon = blockedAddon,
        functionName = blockedFunction,
        timestamp = time(),
    }
    local preparedType = self.prepared and tostring(self.prepared.actionType) or "none"
    self:SetLatestTestOutput("Execute Prepared Test", "BLOCKED", {
        "Prepared type: " .. preparedType,
        "Event: " .. tostring(event),
        "Function: " .. tostring(blockedFunction),
        "Reason: The live client rejected the direct protected call.",
        "Next action: Do not retry. Reload and inspect diagnostics.",
    })
    if self.prepared then
        self.prepared.moneyAfter = getMoney()
    end
    self:SetState("FAILED", tostring(event) .. " for " .. tostring(blockedFunction) .. ". Direct protected transaction path is no-go.")
    self:PersistTerminalFailure(tostring(event), "Addon=" .. blockedAddon .. "; Function=" .. blockedFunction)
    self:PersistReport()
end

function BOD.TransactionProbe:PersistReport()
    self.lastReport = self:BuildReport()
    if BOD.db and BOD.db.diagnostics and BOD.db.diagnostics.transactionProbe then
        BOD.db.diagnostics.transactionProbe.latestReport = self.lastReport
    end
    if BOD.UI and BOD.UI.RefreshReport then
        BOD.UI:RefreshReport()
    end
end

function BOD.TransactionProbe:BuildReport()
    local lines = {}
    local client = BOD.Diagnostics:GetClientInfo()
    lines[#lines + 1] = "Developer Transaction Probe"
    lines[#lines + 1] = "Enabled this session: " .. tostring(self.enabled)
    lines[#lines + 1] = "State: " .. tostring(self.state)
    lines[#lines + 1] = "Blocked: " .. tostring(self.blocked)
    lines[#lines + 1] = "Addon version: " .. tostring(client.addonVersion)
    lines[#lines + 1] = "WoW: " .. tostring(client.wowVersion) .. " build " .. tostring(client.build)
    lines[#lines + 1] = "Interface: " .. tostring(client.tocVersion)
    lines[#lines + 1] = "Project ID: " .. tostring(client.projectID)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Latest protected attempt"
    local protectedAttempt = self.lastProtectedAttempt
        or (BOD.db and BOD.db.diagnostics and BOD.db.diagnostics.transactionProbe and BOD.db.diagnostics.transactionProbe.lastProtectedAttempt)
    if protectedAttempt then
        lines[#lines + 1] = "Timestamp: " .. BOD:FormatTimestamp(protectedAttempt.timestamp)
        lines[#lines + 1] = "Action type: " .. tostring(protectedAttempt.actionType)
        lines[#lines + 1] = "Function: " .. tostring(protectedAttempt.functionName)
        lines[#lines + 1] = "Argument types: " .. tostring(protectedAttempt.argumentTypes)
        lines[#lines + 1] = "State before call: " .. tostring(protectedAttempt.stateBeforeCall)
        lines[#lines + 1] = "Warning: " .. tostring(protectedAttempt.warning)
    else
        lines[#lines + 1] = "None."
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Latest terminal failure"
    local terminalFailure = self.lastTerminalFailure
        or (BOD.db and BOD.db.diagnostics and BOD.db.diagnostics.transactionProbe and BOD.db.diagnostics.transactionProbe.lastTerminalFailure)
    if terminalFailure then
        lines[#lines + 1] = "Timestamp: " .. BOD:FormatTimestamp(terminalFailure.timestamp)
        lines[#lines + 1] = "Classification: " .. tostring(terminalFailure.classification)
        lines[#lines + 1] = "Detail: " .. tostring(terminalFailure.detail)
        lines[#lines + 1] = "Prepared type: " .. tostring(terminalFailure.preparedType)
        lines[#lines + 1] = "Instruction: " .. tostring(terminalFailure.instruction)
    else
        lines[#lines + 1] = "None."
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Capabilities"
    for _, capability in ipairs(self.capabilities or self:GetCapabilities()) do
        lines[#lines + 1] = capability.name .. ": " .. tostring(capability.available) .. " (" .. capability.valueType .. ")"
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Sell slot"
    if self.sellSlot then
        for key, value in pairs(self.sellSlot) do
            lines[#lines + 1] = tostring(key) .. ": " .. tostring(value) .. " (" .. type(value) .. ")"
        end
    else
        lines[#lines + 1] = "Not inspected."
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Owned auctions"
    lines[#lines + 1] = "Count: " .. tostring(self.ownerCount or "unknown")
    lines[#lines + 1] = "Field types: " .. tostring(self.ownerFieldTypes or "unknown")
    lines[#lines + 1] = "Bidder auctions"
    lines[#lines + 1] = "Count: " .. tostring(self.bidderCount or "unknown")
    lines[#lines + 1] = "Field types: " .. tostring(self.bidderFieldTypes or "unknown")
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Prepared transaction"
    if self.prepared then
        lines[#lines + 1] = "Type: " .. tostring(self.prepared.actionType)
        lines[#lines + 1] = "Function called: " .. tostring(self.prepared.functionCalled or "none")
        lines[#lines + 1] = "Argument types: " .. fieldTypes(self.prepared.arguments)
        lines[#lines + 1] = "Money before: " .. formatMoney(self.prepared.moneyBefore)
        lines[#lines + 1] = "Money after: " .. formatMoney(self.prepared.moneyAfter or self.prepared.moneyAfterImmediate)
        lines[#lines + 1] = "Snapshot fields: " .. fieldTypes(self.prepared.snapshot)
    else
        lines[#lines + 1] = "None."
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Events"
    for _, entry in ipairs(self.events or {}) do
        lines[#lines + 1] = BOD:FormatTimestamp(entry.timestamp) .. " " .. entry.event .. " " .. table.concat(entry.args or {}, ", ")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Log"
    for _, line in ipairs(self.reportLines or {}) do
        lines[#lines + 1] = line
    end
    if self.blockedEvent then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Blocked action"
        lines[#lines + 1] = "Event: " .. tostring(self.blockedEvent.event)
        lines[#lines + 1] = "Addon: " .. tostring(self.blockedEvent.addon)
        lines[#lines + 1] = "Function: " .. tostring(self.blockedEvent.functionName)
    end
    return table.concat(lines, "\n")
end

function BOD.TransactionProbe:GetStatusText()
    return table.concat({
        "Session enabled: " .. tostring(self.enabled),
        "State: " .. tostring(self.state),
        "Blocked: " .. tostring(self.blocked),
        "Addon version: " .. tostring(BOD.version or "unknown"),
        "Last action: " .. tostring(self.lastAction or "None"),
        "Last result: " .. tostring(self.lastResult or "None"),
    }, "\n")
end

function BOD.TransactionProbe:GetPreparedSnapshotValues()
    local values = {
        Type = "None",
        Item = "None",
        Stack = "None",
        ["Selected index"] = "None",
        ["Bid total"] = "None",
        ["Buyout total"] = "None",
        Duration = "None",
        Deposit = "None",
        State = tostring(self.state),
    }

    if not self.prepared or not self.prepared.snapshot then
        return values
    end

    local snapshot = self.prepared.snapshot
    values.Type = tostring(self.prepared.actionType)
    values.Item = tostring(snapshot.name or snapshot.itemLink or "unknown")
    values.Stack = tostring(snapshot.stackSize or snapshot.stackCount or snapshot.count or "unknown")
    values["Selected index"] = tostring(snapshot.index or "sell-slot")
    values["Bid total"] = formatMoney(snapshot.bid or snapshot.currentBid or snapshot.minimumBid)
    values["Buyout total"] = formatMoney(snapshot.buyoutTotal or snapshot.buyout)
    if self.prepared.actionType == "POST" then
        values.Duration = tostring(snapshot.durationLabel) .. " (API value " .. tostring(snapshot.duration) .. ")"
        values.Deposit = formatMoney(snapshot.deposit)
    end
    return values
end

function BOD.TransactionProbe:BuildEventLogText()
    local lines = {}
    lines[#lines + 1] = "Events"
    if self.events and #self.events > 0 then
        for _, entry in ipairs(self.events) do
            lines[#lines + 1] = BOD:FormatTimestamp(entry.timestamp) .. " " .. entry.event .. " " .. table.concat(entry.args or {}, ", ")
        end
    else
        lines[#lines + 1] = "No events recorded."
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Action log"
    if self.reportLines and #self.reportLines > 0 then
        for _, line in ipairs(self.reportLines) do
            lines[#lines + 1] = line
        end
    else
        lines[#lines + 1] = "No actions recorded."
    end

    return table.concat(lines, "\n")
end

function BOD.TransactionProbe:RefreshStatusRows()
    if not self.statusRows then
        return
    end

    local values = {
        ["Session enabled"] = tostring(self.enabled),
        State = tostring(self.state),
        Blocked = tostring(self.blocked),
        ["Addon version"] = tostring(BOD.version or "unknown"),
        ["Last action"] = tostring(self.lastAction or "None"),
        ["Last result"] = tostring(self.lastResult or "None"),
    }

    for _, row in ipairs(self.statusRows) do
        row.value:SetText(values[row.label] or "unknown")
    end
end

function BOD.TransactionProbe:RefreshPreparedRows()
    if not self.preparedRows then
        return
    end

    local values = self:GetPreparedSnapshotValues()
    for _, row in ipairs(self.preparedRows) do
        row.value:SetText(values[row.label] or "None")
    end
end

function BOD.TransactionProbe:RefreshPostResultRows()
    if not self.postResultRows then
        return
    end

    local values = self.postTestResult or {}
    for _, row in ipairs(self.postResultRows) do
        row.value:SetText(values[row.label] or "")
    end
    if self.postResultOutputText then
        self.postResultOutputText:SetText(values.Output or "")
    end
end

function BOD.TransactionProbe:RefreshLatestTestOutput()
    if self.latestTestOutputText then
        self.latestTestOutputText:SetText(self.latestTestOutput or "")
    end
end

function BOD.TransactionProbe:Refresh()
    if not self.frame or not self.frame:IsShown() then
        return
    end
    self:RefreshPricePreviews()
    self:RefreshSelectedBrowseIndex()
    self:RefreshStatusRows()
    self:RefreshPreparedRows()
    self:RefreshPostResultRows()
    self:RefreshLatestTestOutput()
    if self.eventLogBox then
        self.eventLogBox:SetText(self:BuildEventLogText())
    end
    local enabled = self.enabled and not self.blocked
    local canPrepare = enabled and not self:IsBusy()
    self.capabilityButton:SetEnabled(enabled)
    self.ownerButton:SetEnabled(enabled)
    self.bidderButton:SetEnabled(enabled)
    self.sellSlotButton:SetEnabled(enabled)
    self.prepareBuyButton:SetEnabled(canPrepare)
    self.preparePostButton:SetEnabled(canPrepare)
    self.prepareCancelButton:SetEnabled(canPrepare)
    self.prepareFinalButton:SetEnabled(canPrepare and self.prepared ~= nil)
    self.executeButton:SetEnabled(enabled and self.prepared ~= nil and self.state == "READY_FOR_FINAL_CLICK")
    if self.prepared and self.prepared.actionType == "BUYOUT" then
        self.executeButton:SetText("Execute 1 Buyout Test")
    elseif self.prepared and self.prepared.actionType == "POST" then
        self.executeButton:SetText("Execute 1 Post Test")
    elseif self.prepared and self.prepared.actionType == "CANCEL" then
        self.executeButton:SetText("Execute 1 Cancel Test")
    else
        self.executeButton:SetText("Execute 1 Prepared Test")
    end
end

function BOD.TransactionProbe:EnsureCreated()
    if self.frame then
        return
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "BankOfDurotarTransactionProbeFrame", UIParent, template)
    self.frame = frame
    frame:SetSize(1000, 900)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    setBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText("DEVELOPER TRANSACTION PROBE")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    local warning = createFontString(frame, "GameFontHighlightSmall")
    warning:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    warning:SetSize(940, 34)
    warning:SetText("This tool may spend gold or change auctions. Use only low-value test items. Every action requires an explicit click. Disabled by default.")

    local phrase = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.phraseBox = phrase
    phrase:SetSize(230, 24)
    phrase:SetPoint("TOPLEFT", warning, "BOTTOMLEFT", 0, -10)
    phrase:SetAutoFocus(false)

    local enableButton = createButton(frame, "Enable Probe", 110, 24)
    enableButton:SetPoint("LEFT", phrase, "RIGHT", 8, 0)
    enableButton:SetScript("OnClick", function()
        self:EnableFromPhrase(phrase:GetText())
        phrase:SetText("")
    end)

    local disableButton = createButton(frame, "Disable", 80, 24)
    disableButton:SetPoint("LEFT", enableButton, "RIGHT", 8, 0)
    disableButton:SetScript("OnClick", function()
        self:Disable("Disabled by player.")
    end)

    local inspectionHeading = createFontString(frame, "GameFontNormal")
    inspectionHeading:SetPoint("TOPLEFT", phrase, "BOTTOMLEFT", 0, -14)
    inspectionHeading:SetText("Inspection controls")

    self.capabilityButton = createButton(frame, "Inspect Capabilities", 150, 24)
    self.capabilityButton:SetPoint("TOPLEFT", inspectionHeading, "BOTTOMLEFT", 0, -8)
    self.capabilityButton:SetScript("OnClick", function() self:InspectCapabilities() end)

    self.ownerButton = createButton(frame, "Inspect Owner", 120, 24)
    self.ownerButton:SetPoint("LEFT", self.capabilityButton, "RIGHT", 8, 0)
    self.ownerButton:SetScript("OnClick", function() self:InspectAuctionList("owner") end)

    self.bidderButton = createButton(frame, "Inspect Bidder", 120, 24)
    self.bidderButton:SetPoint("LEFT", self.ownerButton, "RIGHT", 8, 0)
    self.bidderButton:SetScript("OnClick", function() self:InspectAuctionList("bidder") end)

    self.sellSlotButton = createButton(frame, "Inspect Sell Slot", 130, 24)
    self.sellSlotButton:SetPoint("LEFT", self.bidderButton, "RIGHT", 8, 0)
    self.sellSlotButton:SetScript("OnClick", function() self:InspectSellSlot() end)

    local inputsHeading = createFontString(frame, "GameFontNormal")
    inputsHeading:SetPoint("TOPLEFT", self.capabilityButton, "BOTTOMLEFT", 0, -14)
    inputsHeading:SetText("Selection / Transaction Inputs")

    local function createSectionHeading(anchor, title, helperText)
        local heading = createFontString(frame, "GameFontNormalSmall")
        heading:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
        heading:SetText(title)

        local helper = createFontString(frame, "GameFontHighlightSmall")
        helper:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
        helper:SetSize(300, 18)
        helper:SetText(helperText)

        return heading, helper
    end

    local function createPanel(title, width, height)
        local panel = CreateFrame("Frame", nil, frame, template)
        panel:SetSize(width, height)
        setBackdrop(panel)
        if panel.SetBackdropColor then
            panel:SetBackdropColor(0.02, 0.015, 0.01, 0.9)
        end

        local panelTitle = createFontString(panel, "GameFontNormalSmall")
        panelTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
        panelTitle:SetText(title)
        return panel, panelTitle
    end

    local function createLabelRows(parent, anchor, labels, labelWidth, valueWidth, rowHeight)
        local rows = {}
        local previous
        for index, label in ipairs(labels) do
            local labelText = createFontString(parent, "GameFontNormalSmall")
            if index == 1 then
                labelText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
            else
                labelText:SetPoint("TOPLEFT", previous.label, "BOTTOMLEFT", 0, -rowHeight)
            end
            labelText:SetWidth(labelWidth)
            labelText:SetText(label)
            disableTextWrap(labelText)

            local valueText = createFontString(parent, "GameFontHighlightSmall")
            valueText:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
            valueText:SetWidth(valueWidth)
            valueText:SetText("None")
            disableTextWrap(valueText)

            rows[#rows + 1] = {
                label = label,
                labelText = labelText,
                value = valueText,
            }
            previous = rows[#rows]
        end
        return rows
    end

    local buyoutHeading, buyoutHelper = createSectionHeading(inputsHeading, "Buyout Test", "Uses the currently selected Bank of Durotar listing.")

    local selectedBrowseLabel = createFontString(frame, "GameFontNormalSmall")
    selectedBrowseLabel:SetPoint("TOPLEFT", buyoutHelper, "BOTTOMLEFT", 0, -6)
    selectedBrowseLabel:SetText("Selected Browse Index")
    self.selectedBrowseIndexBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.selectedBrowseIndexBox:SetSize(50, 22)
    self.selectedBrowseIndexBox:SetPoint("LEFT", selectedBrowseLabel, "RIGHT", 8, 0)
    self.selectedBrowseIndexBox:SetAutoFocus(false)
    self.selectedBrowseIndexBox:SetEnabled(false)

    self.prepareBuyButton = createButton(frame, "Prepare Buyout Test", 150, 24)
    self.prepareBuyButton:SetPoint("TOPLEFT", selectedBrowseLabel, "BOTTOMLEFT", 0, -8)
    self.prepareBuyButton:SetScript("OnClick", function() self:PrepareBuyout() end)

    local postHeading, postHelper = createSectionHeading(self.prepareBuyButton, "Post Test", "Uses the item manually placed in Blizzard's sell slot.")

    local function createMoneyRow(title, anchor, previewLabel)
        local titleText = createFontString(frame, "GameFontNormalSmall")
        titleText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
        titleText:SetText(title)

        local goldLabel = createFontString(frame, "GameFontNormalSmall")
        goldLabel:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
        goldLabel:SetText("Gold")
        local goldBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        goldBox:SetSize(44, 22)
        goldBox:SetPoint("LEFT", goldLabel, "RIGHT", 6, 0)
        goldBox:SetNumeric(true)
        goldBox:SetAutoFocus(false)
        goldBox:SetText("0")

        local silverLabel = createFontString(frame, "GameFontNormalSmall")
        silverLabel:SetPoint("LEFT", goldBox, "RIGHT", 10, 0)
        silverLabel:SetText("Silver")
        local silverBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        silverBox:SetSize(34, 22)
        silverBox:SetPoint("LEFT", silverLabel, "RIGHT", 6, 0)
        silverBox:SetNumeric(true)
        silverBox:SetAutoFocus(false)
        silverBox:SetText("0")

        local copperLabel = createFontString(frame, "GameFontNormalSmall")
        copperLabel:SetPoint("LEFT", silverBox, "RIGHT", 10, 0)
        copperLabel:SetText("Copper")
        local copperBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        copperBox:SetSize(34, 22)
        copperBox:SetPoint("LEFT", copperLabel, "RIGHT", 6, 0)
        copperBox:SetNumeric(true)
        copperBox:SetAutoFocus(false)
        copperBox:SetText("0")

        local preview = createFontString(frame, "GameFontHighlightSmall")
        preview:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)
        preview:SetText(previewLabel .. " total: " .. formatMoneyPreview(0))

        local boxes = {
            gold = goldBox,
            silver = silverBox,
            copper = copperBox,
        }
        local function onChanged()
            self:OnPostPriceFieldChanged()
        end
        goldBox:SetScript("OnTextChanged", onChanged)
        silverBox:SetScript("OnTextChanged", onChanged)
        copperBox:SetScript("OnTextChanged", onChanged)

        return boxes, preview
    end

    self.bidMoneyBoxes, self.bidPreviewText = createMoneyRow("Bidding Price", postHelper, "Bid")
    self.buyoutMoneyBoxes, self.buyoutPreviewText = createMoneyRow("Buyout Price", self.bidPreviewText, "Buyout")

    local durationLabel = createFontString(frame, "GameFontNormalSmall")
    durationLabel:SetPoint("TOPLEFT", self.buyoutPreviewText, "BOTTOMLEFT", 0, -14)
    durationLabel:SetText("Auction Duration")

    self.durationButtons = {}
    local previousDurationButton
    for index, option in ipairs(POST_DURATION_OPTIONS) do
        local button = CreateFrame("CheckButton", nil, frame, "UIRadioButtonTemplate")
        self.durationButtons[option.key] = button
        button.durationKey = option.key
        if index == 1 then
            button:SetPoint("TOPLEFT", durationLabel, "BOTTOMLEFT", 0, -6)
        else
            button:SetPoint("TOPLEFT", previousDurationButton, "BOTTOMLEFT", 0, -2)
        end
        button:SetScript("OnClick", function(clicked)
            self:SelectPostDuration(clicked.durationKey)
        end)

        local buttonText = createFontString(frame, "GameFontHighlightSmall")
        buttonText:SetPoint("LEFT", button, "RIGHT", 4, 0)
        buttonText:SetText(option.label)
        button.labelText = buttonText
        previousDurationButton = button
    end
    self.selectedPostDurationKey = DEFAULT_POST_DURATION_KEY
    self:RefreshDurationButtons()

    local stackLabel = createFontString(frame, "GameFontNormalSmall")
    stackLabel:SetPoint("TOPLEFT", previousDurationButton, "BOTTOMLEFT", 0, -10)
    stackLabel:SetText("Stack size")
    self.stackSizeBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.stackSizeBox:SetSize(40, 22)
    self.stackSizeBox:SetPoint("LEFT", stackLabel, "RIGHT", 8, 0)
    self.stackSizeBox:SetNumeric(true)
    self.stackSizeBox:SetAutoFocus(false)
    self.stackSizeBox:SetText("1")
    self.stackSizeBox:SetScript("OnTextChanged", function() self:OnPostStackFieldChanged() end)

    local stacksLabel = createFontString(frame, "GameFontNormalSmall")
    stacksLabel:SetPoint("LEFT", self.stackSizeBox, "RIGHT", 10, 0)
    stacksLabel:SetText("Stacks")
    self.numStacksBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.numStacksBox:SetSize(30, 22)
    self.numStacksBox:SetPoint("LEFT", stacksLabel, "RIGHT", 8, 0)
    self.numStacksBox:SetNumeric(true)
    self.numStacksBox:SetAutoFocus(false)
    self.numStacksBox:SetText("1")
    self.numStacksBox:SetScript("OnTextChanged", function() self:OnPostStackFieldChanged() end)

    self.preparePostButton = createButton(frame, "Prepare Post Test", 140, 24)
    self.preparePostButton:SetPoint("TOPLEFT", stackLabel, "BOTTOMLEFT", 0, -12)
    self.preparePostButton:SetScript("OnClick", function() self:PreparePost() end)

    self.postResultPanel, self.postResultPanelTitle = createPanel("Prepared Post Test", 470, 210)
    self.postResultPanel:SetPoint("TOPLEFT", self.preparePostButton, "BOTTOMLEFT", 0, -12)
    self.postResultRows = {}
    self.postResultOutputText = createFontString(self.postResultPanel, "GameFontHighlightSmall")
    self.postResultOutputText:SetPoint("TOPLEFT", self.postResultPanelTitle, "BOTTOMLEFT", 0, -8)
    self.postResultOutputText:SetPoint("BOTTOMRIGHT", self.postResultPanel, "BOTTOMRIGHT", -12, 12)
    self.postResultOutputText:SetText("Prepared Post Test\nResult: NOT RUN\nNext action: Click Prepare Post Test after entering post values.")

    local cancelHeading = createFontString(frame, "GameFontNormalSmall")
    cancelHeading:SetPoint("TOPLEFT", inputsHeading, "TOPLEFT", 500, -36)
    cancelHeading:SetText("Cancel Test")

    local cancelHelper = createFontString(frame, "GameFontHighlightSmall")
    cancelHelper:SetPoint("TOPLEFT", cancelHeading, "BOTTOMLEFT", 0, -4)
    cancelHelper:SetSize(300, 18)
    cancelHelper:SetText("Uses one selected owned auction.")

    local ownerLabel = createFontString(frame, "GameFontNormalSmall")
    ownerLabel:SetPoint("TOPLEFT", cancelHelper, "BOTTOMLEFT", 0, -6)
    ownerLabel:SetText("Owned Auction Index")
    self.ownerIndexBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    self.ownerIndexBox:SetSize(50, 22)
    self.ownerIndexBox:SetPoint("LEFT", ownerLabel, "RIGHT", 8, 0)
    self.ownerIndexBox:SetNumeric(true)
    self.ownerIndexBox:SetAutoFocus(false)

    self.prepareCancelButton = createButton(frame, "Prepare Cancel Test", 150, 24)
    self.prepareCancelButton:SetPoint("TOPLEFT", ownerLabel, "BOTTOMLEFT", 0, -8)
    self.prepareCancelButton:SetScript("OnClick", function() self:PrepareCancel() end)

    local finalHeading = createFontString(frame, "GameFontNormal")
    finalHeading:SetPoint("TOPLEFT", self.prepareCancelButton, "BOTTOMLEFT", 0, -14)
    finalHeading:SetText("Final confirmation")

    self.prepareFinalButton = createButton(frame, "Prepare Final Click", 150, 24)
    self.prepareFinalButton:SetPoint("TOPLEFT", finalHeading, "BOTTOMLEFT", 0, -8)
    self.prepareFinalButton:SetScript("OnClick", function() self:PrepareFinalClick() end)

    self.executeButton = createButton(frame, "Execute 1 Prepared Test", 180, 24)
    self.executeButton:SetPoint("LEFT", self.prepareFinalButton, "RIGHT", 8, 0)
    self.executeButton:SetScript("OnClick", function() self:ExecutePreparedFromClick() end)

    self.latestTestPanel, self.latestTestPanelTitle = createPanel("Latest Test Output", 460, 128)
    self.latestTestPanel:SetPoint("TOPLEFT", self.prepareFinalButton, "BOTTOMLEFT", 0, -18)
    self.latestTestOutputText = createFontString(self.latestTestPanel, "GameFontHighlightSmall")
    self.latestTestOutputText:SetPoint("TOPLEFT", self.latestTestPanelTitle, "BOTTOMLEFT", 0, -8)
    self.latestTestOutputText:SetPoint("BOTTOMRIGHT", self.latestTestPanel, "BOTTOMRIGHT", -12, 12)
    self.latestTestOutputText:SetText(self.latestTestOutput or "")

    self.statusPanel, self.statusPanelTitle = createPanel("Status", 460, 150)
    self.statusPanel:SetPoint("TOPLEFT", self.latestTestPanel, "BOTTOMLEFT", 0, -14)
    self.statusRows = createLabelRows(self.statusPanel, self.statusPanelTitle, {
        "Session enabled",
        "State",
        "Blocked",
        "Addon version",
        "Last action",
        "Last result",
    }, 96, 320, 5)

    self.preparedPanel, self.preparedPanelTitle = createPanel("Prepared transaction", 460, 162)
    self.preparedPanel:SetPoint("TOPLEFT", self.statusPanel, "BOTTOMLEFT", 0, -14)
    self.preparedRows = createLabelRows(self.preparedPanel, self.preparedPanelTitle, {
        "Type",
        "Item",
        "Stack",
        "Selected index",
        "Bid total",
        "Buyout total",
        "Duration",
        "Deposit",
        "State",
    }, 92, 320, 1)

    local eventLogLabel = createFontString(frame, "GameFontNormal")
    eventLogLabel:SetPoint("TOPLEFT", self.postResultPanel, "BOTTOMLEFT", 0, -14)
    eventLogLabel:SetText("Event log")

    local eventLogScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    eventLogScroll:SetPoint("TOPLEFT", eventLogLabel, "BOTTOMLEFT", 0, -8)
    eventLogScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 488, 18)
    self.eventLogBox = CreateFrame("EditBox", nil, eventLogScroll)
    self.eventLogBox:SetMultiLine(true)
    self.eventLogBox:SetAutoFocus(false)
    self.eventLogBox:SetFontObject(ChatFontNormal)
    self.eventLogBox:SetWidth(430)
    self.eventLogBox:EnableMouse(false)
    eventLogScroll:SetScrollChild(self.eventLogBox)

    frame:Hide()
    self:Refresh()
end

function BOD.TransactionProbe:Show()
    self:EnsureCreated()
    self.frame:Show()
    self:Refresh()
end

function BOD.TransactionProbe:OnEvent(event, ...)
    self:AddEvent(event, ...)
    if event == "ADDON_LOADED" then
        self.enabled = false
        self.blocked = false
        self.state = "DISABLED"
        self.selectedPostDurationKey = DEFAULT_POST_DURATION_KEY
        self:EnsureCreated()
        self:RefreshDurationButtons()
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        self.listGeneration = self.listGeneration + 1
        if self.prepared and self.prepared.actionType == "BUYOUT" and self.state ~= "WAITING_FOR_RESULT" then
            self:ClearPrepared("Result list refreshed.")
        elseif self.state == "WAITING_FOR_RESULT" and self.prepared and self.prepared.actionType == "BUYOUT" then
            self:MarkSucceeded("Result list updated after buyout call.")
        end
    elseif event == "AUCTION_OWNED_LIST_UPDATE" then
        self.ownerGeneration = self.ownerGeneration + 1
        if self.prepared and (self.prepared.actionType == "CANCEL" or self.prepared.actionType == "POST") and self.state ~= "WAITING_FOR_RESULT" then
            self:ClearPrepared("Owned list refreshed.")
        elseif self.state == "WAITING_FOR_RESULT" and self.prepared and (self.prepared.actionType == "CANCEL" or self.prepared.actionType == "POST") then
            self:MarkSucceeded("Owned list updated after transaction call.")
        end
    elseif event == "AUCTION_BIDDER_LIST_UPDATE" then
        self.bidderGeneration = self.bidderGeneration + 1
    elseif event == "AUCTION_HOUSE_CLOSED" then
        self:ClearPrepared("Auction House closed.")
    elseif event == "PLAYER_LOGOUT" then
        self.enabled = false
        self.selectedPostDurationKey = DEFAULT_POST_DURATION_KEY
        self:ClearPrepared("Player logout.")
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "ITEM_LOCK_CHANGED" then
        self:MarkPostResultStale("Sell-slot item or stack may have changed; run Prepare Post Test again.")
        if self.prepared and self.prepared.actionType == "POST" and self.state ~= "WAITING_FOR_RESULT" then
            self:ClearPrepared("Bag or item lock changed.")
        end
    elseif event == "UI_ERROR_MESSAGE" then
        if self.state == "WAITING_FOR_RESULT" then
            self:SetState("FAILED", "UI error observed; no retry attempted.")
            self:PersistTerminalFailure("UI_ERROR_MESSAGE", "UI error observed while waiting for transaction result.")
            self:PersistReport()
        end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        self:MarkBlocked(event, ...)
    end
    self:Refresh()
end
