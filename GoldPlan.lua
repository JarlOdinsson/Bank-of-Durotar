local addonName, BOD = ...

BOD.GoldPlan = {}

local MAX_SAFE_INTEGER = 2147483647
local BAG_FIRST = 0
local BAG_LAST = 4
local BUY_LIMIT = 10
local SELL_LIMIT = 3
local CONFIDENCE_RANK = { NONE = 0, LOW = 1, MEDIUM = 2, HIGH = 3 }

local function wholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number > MAX_SAFE_INTEGER then return nil end
    return math.floor(number)
end

local function getBagSlots(bag)
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
        return tonumber(C_Container.GetContainerNumSlots(bag)) or 0
    end
    if type(GetContainerNumSlots) == "function" then
        return tonumber(GetContainerNumSlots(bag)) or 0
    end
    return 0
end

local function getBagItem(bag, slot)
    if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then return nil end
        return {
            link = info.hyperlink,
            count = info.stackCount,
            itemID = info.itemID,
            isBound = info.isBound,
        }
    end
    if type(GetContainerItemInfo) == "function" then
        local _, count, _, _, _, _, link, _, _, itemID, isBound = GetContainerItemInfo(bag, slot)
        if not link and type(GetContainerItemLink) == "function" then link = GetContainerItemLink(bag, slot) end
        if not link then return nil end
        return { link = link, count = count, itemID = itemID, isBound = isBound }
    end
end

local function getItemDetails(link)
    if type(GetItemInfo) ~= "function" or type(link) ~= "string" then return nil end
    local name, canonicalLink, quality, _, _, itemType, itemSubType, maxStack, _, texture, vendorPrice = GetItemInfo(link)
    if not name then return nil end
    return {
        name = name,
        link = canonicalLink or link,
        quality = quality,
        itemType = itemType,
        itemSubType = itemSubType,
        maxStack = math.max(1, wholeNumber(maxStack) or 1),
        texture = texture,
        vendorPrice = wholeNumber(vendorPrice) or 0,
    }
end

local function findBagMarketItem(details)
    if not details then return nil end
    if details.maxStack > 1 then return BOD.MarketData:FindItemByText(details.link) end
    local itemString = details.link:match("Hitem:([^|%]]+)")
    return itemString and BOD.MarketData:GetCurrentItem("itemString:" .. itemString) or nil
end

function BOD.GoldPlan:CollectBagInventory()
    local owned = {}
    for bag = BAG_FIRST, BAG_LAST do
        for slot = 1, getBagSlots(bag) do
            local bagItem = getBagItem(bag, slot)
            if bagItem and bagItem.link and bagItem.isBound ~= true then
                local details = getItemDetails(bagItem.link)
                local marketItem = findBagMarketItem(details)
                if marketItem and marketItem.itemKey then
                    local entry = owned[marketItem.itemKey]
                    if not entry then
                        entry = {
                            itemKey = marketItem.itemKey,
                            itemID = bagItem.itemID or marketItem.itemID,
                            itemName = details.name,
                            itemLink = details.link,
                            texture = details.texture,
                            maxStack = details.maxStack,
                            vendorUnitPrice = details.vendorPrice,
                            ownedQuantity = 0,
                        }
                        owned[marketItem.itemKey] = entry
                    end
                    entry.ownedQuantity = entry.ownedQuantity + math.max(1, wholeNumber(bagItem.count) or 1)
                end
            end
        end
    end
    return owned
end

function BOD.GoldPlan:GetBagSellCandidates(limit, owned)
    limit = math.max(1, math.min(wholeNumber(limit) or SELL_LIMIT, 20))
    owned = type(owned) == "table" and owned or self:CollectBagInventory()
    local candidates = {}
    for _, entry in pairs(owned) do
        local stackCount = math.min(entry.ownedQuantity, entry.maxStack)
        local recommendation = BOD.PricingService:GetRecommendation(entry.itemKey, stackCount, { strategy = "SMALL_UNDERCUT" })
        if recommendation.status == "RECOMMENDED" and (CONFIDENCE_RANK[recommendation.confidence] or 0) >= CONFIDENCE_RANK.MEDIUM then
            entry.stackCount = stackCount
            local vendorValue = (tonumber(entry.vendorUnitPrice) or 0) * stackCount
            local useVendor = vendorValue > 0 and vendorValue >= (tonumber(recommendation.expectedNetSale) or 0)
            entry.saleMethod = useVendor and "VENDOR" or "AUCTION"
            entry.unitPrice = useVendor and entry.vendorUnitPrice or recommendation.unitBuyout
            entry.stackPrice = useVendor and vendorValue or recommendation.stackBuyout
            entry.expectedNetSale = useVendor and vendorValue or recommendation.expectedNetSale
            entry.confidence = recommendation.confidence
            entry.personalSales = recommendation.personalSales
            candidates[#candidates + 1] = entry
        end
    end

    table.sort(candidates, function(left, right)
        local leftRank = CONFIDENCE_RANK[left.confidence] or 0
        local rightRank = CONFIDENCE_RANK[right.confidence] or 0
        if leftRank ~= rightRank then return leftRank > rightRank end
        local leftRate = left.personalSales and left.personalSales.saleRate or -1
        local rightRate = right.personalSales and right.personalSales.saleRate or -1
        if leftRate ~= rightRate then return leftRate > rightRate end
        if left.expectedNetSale ~= right.expectedNetSale then return left.expectedNetSale > right.expectedNetSale end
        return tostring(left.itemName) < tostring(right.itemName)
    end)
    while #candidates > limit do table.remove(candidates) end
    return candidates
end

function BOD.GoldPlan:Build(budgetCopper, options)
    options = type(options) == "table" and options or {}
    budgetCopper = wholeNumber(budgetCopper)
    if not budgetCopper or budgetCopper <= 0 then
        return { status = "INVALID_BUDGET", budgetCopper = 0, buys = {}, sells = {} }
    end

    local perItemLimit = math.max(1, math.floor(budgetCopper * 0.5))
    local ownedInventory = self:CollectBagInventory()
    local ownedQuantities = {}
    for itemKey, entry in pairs(ownedInventory) do ownedQuantities[itemKey] = wholeNumber(entry.ownedQuantity) or 0 end
    local minimumProfit = wholeNumber(options.minimumExpectedProfitCopper)
        or (BOD.db and BOD.db.settings and wholeNumber(BOD.db.settings.minimumExpectedProfitCopper)) or 1000
    local result = BOD.OpportunityService:FindOpportunities({
        limit = 25,
        minimumConfidence = "MEDIUM",
        maximumCapitalRequired = math.min(perItemLimit, 200000),
        minimumExpectedProfitCopper = minimumProfit,
        maximumAgeSeconds = 86400,
    }, { ownedQuantities = ownedQuantities })
    local buys = {}
    local remaining = budgetCopper
    for _, opportunity in ipairs(result.opportunities or {}) do
        if #buys >= BUY_LIMIT then break end
        local cost = wholeNumber(opportunity.capitalRequired) or 0
        if cost > 0 and cost <= remaining then
            buys[#buys + 1] = opportunity
            remaining = remaining - cost
        end
    end

    local status = result.status == "NO_DATA" and "NO_DATA" or (#buys > 0 and "OK" or "EMPTY")
    local largerTrade
    local cachedTrades = BOD.TradeService and BOD.TradeService:GetCachedResult() or nil
    for _, trade in ipairs(cachedTrades and cachedTrades.opportunities or {}) do
        if trade.tradeEligible and not trade.quickMoveEligible then largerTrade = trade; break end
    end
    return {
        status = status,
        budgetCopper = budgetCopper,
        investedCopper = budgetCopper - remaining,
        remainingCopper = remaining,
        perItemLimit = perItemLimit,
        minimumExpectedProfitCopper = minimumProfit,
        buys = buys,
        bestMove = buys[1],
        largerTradeAvailable = largerTrade ~= nil,
        largerTrade = largerTrade,
        primaryRejectionCode = result.primaryRejectionCode,
        primaryRejectionReason = result.primaryRejectionReason,
        ownedQuantities = ownedQuantities,
        sells = self:GetBagSellCandidates(SELL_LIMIT, ownedInventory),
    }
end
