local addonName, BOD = ...

BOD.PricingService = {}

local MAX_SAFE_INTEGER = 2147483647
local AUCTION_CUT_RATE = 0.05
local DEPOSIT_RATE_24H = 0.30

local function now()
    if type(time) == "function" then
        return time()
    end
    return os.time()
end

local function validCopper(value)
    local number = tonumber(value)
    return number and number == number and number >= 0 and number <= MAX_SAFE_INTEGER and number == math.floor(number)
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

local function getCurrentItem(itemKey, context)
    local snapshot = BOD.MarketData and BOD.MarketData:GetLatestSnapshot()
    if not snapshot or snapshot.complete ~= true or type(snapshot.items) ~= "table" then
        return nil, snapshot
    end
    local overlay = context and context.useTargetedOverlay ~= false and BOD.MarketData.GetTargetedOverlay
        and BOD.MarketData:GetTargetedOverlay(itemKey) or nil
    if overlay and type(overlay.item) == "table" then
        return overlay.item, snapshot, overlay
    elseif BOD.MarketData.GetCurrentItem then
        return BOD.MarketData:GetCurrentItem(itemKey), snapshot, nil
    end
    return snapshot.items[itemKey], snapshot
end

local function getAgeSeconds(snapshot)
    if not snapshot then
        return nil
    end
    return math.max(0, now() - (tonumber(snapshot.observationTimestamp or snapshot.completedAt) or now()))
end

local function freshness(ageSeconds)
    if not ageSeconds then return "NO_DATA" end
    return BOD.MarketCache and BOD.MarketCache:ClassifyAge(ageSeconds, BOD.db and BOD.db.settings) or "HISTORICAL_ONLY"
end

local function confidenceFor(item, fresh)
    if not item or not validCopper(item.medianUnitBuyout) then
        return "NONE"
    end
    local sampleCount = tonumber(item.sampleCount) or 0
    if fresh == "HISTORICAL_ONLY" or fresh == "NO_DATA" then
        return "NONE"
    elseif fresh == "STALE" then
        return sampleCount >= 20 and "LOW" or "NONE"
    elseif fresh == "AGING" then
        return sampleCount >= 20 and "MEDIUM" or "LOW"
    elseif sampleCount >= 30 then
        return "HIGH"
    elseif sampleCount >= 6 then
        return "MEDIUM"
    elseif sampleCount >= 2 then
        return "LOW"
    end
    return "LOW"
end

local function chooseWall(item)
    local lowest = tonumber(item.lowestUnitBuyout) or 0
    local median = tonumber(item.medianUnitBuyout) or lowest
    local weighted = tonumber(item.weightedMedianUnitBuyout) or median
    local listingCount = tonumber(item.listingCount) or 0
    local suspiciousLowOutlier = listingCount >= 4 and median > 0 and lowest < (median * 0.7)
    if suspiciousLowOutlier then
        return math.floor(math.max(lowest, math.min(median, weighted))), true
    end
    return math.floor(lowest), false
end

function BOD.PricingService:GetSaleEconomics(itemKey, quantity, grossSale)
    quantity = math.max(1, math.floor(tonumber(quantity) or 1))
    grossSale = math.max(0, math.floor(tonumber(grossSale) or 0))
    local item = BOD.MarketData and BOD.MarketData:GetCurrentItem(itemKey) or nil
    local vendorUnit = math.max(0, math.floor(tonumber(item and item.vendorPrice) or 0))
    local vendorValue = vendorUnit * quantity
    local deposit = math.floor(vendorValue * DEPOSIT_RATE_24H)
    local sales = BOD.SalesHistory and BOD.SalesHistory:GetSummary(itemKey, item and item.itemName) or { outcomeCount = 0 }
    local failureRate = 0.5
    if (tonumber(sales.outcomeCount) or 0) >= 3 and sales.saleRate then
        failureRate = clamp(1 - sales.saleRate, 0, 1)
    end
    local cut = math.floor(grossSale * AUCTION_CUT_RATE)
    local depositRisk = math.floor(deposit * failureRate)
    return {
        grossSale = grossSale,
        auctionCut = cut,
        deposit = deposit,
        expectedDepositLoss = depositRisk,
        expectedNetSale = math.max(0, grossSale - cut - depositRisk),
        vendorUnitPrice = vendorUnit,
        vendorValue = vendorValue,
        personalSales = sales,
    }
end

function BOD.PricingService:GetRecommendation(itemKey, stackCount, context)
    stackCount = math.max(1, math.floor(tonumber(stackCount) or 1))
    context = context or {}

    if type(itemKey) ~= "string" or itemKey == "" then
        return {
            status = "INVALID_ITEM",
            confidence = "NONE",
            reasonCodes = { "INVALID_ITEM_KEY" },
        }
    end

    local item, snapshot, overlay = getCurrentItem(itemKey, context)
    if not item then
        return {
            status = "NO_DATA",
            confidence = "NONE",
            itemKey = itemKey,
            stackCount = stackCount,
            reasonCodes = { "NO_CURRENT_SNAPSHOT" },
            explanation = { "No reliable market data is available for this item." },
        }
    end

    local ageSeconds = getAgeSeconds(snapshot)
    local fresh = freshness(ageSeconds)
    local confidence = confidenceFor(item, overlay and "FRESH" or fresh)
    local reasonCodes = {}
    local history = BOD.MarketHistory and BOD.MarketHistory.GetSummary and BOD.MarketHistory:GetSummary(itemKey) or nil
    local sevenDayMedian = history and history.sevenDay and history.sevenDay.median or nil
    local thirtyDayMedian = history and history.thirtyDay and history.thirtyDay.median or nil

    local maximumSellAge = tonumber(BOD.db and BOD.db.settings and BOD.db.settings.maximumSellRecommendationAgeSeconds) or 3600
    local targetedCheckedAt = overlay and tonumber(overlay.checkedAt) or nil
    if context.requireCurrentValidation == true and not targetedCheckedAt and ageSeconds > maximumSellAge then
        return {
            status = "VALIDATION_REQUIRED", confidence = confidence, itemKey = itemKey,
            itemName = item.itemName or item.name, stackCount = stackCount, dataAgeSeconds = ageSeconds,
            freshness = fresh, cachedUnitBuyout = item.lowestUnitBuyout, snapshotId = snapshot.scanId or snapshot.id,
            sourceScanCompletedAt = snapshot.completedAt, reasonCodes = { "CURRENT_ITEM_CHECK_REQUIRED" },
            explanation = { "The cached price is useful for context, but this item must be checked before posting." },
        }
    end
    if fresh == "STALE" and not targetedCheckedAt then
        reasonCodes[#reasonCodes + 1] = "STALE_DATA"
    elseif fresh == "HISTORICAL_ONLY" and not targetedCheckedAt then
        return {
            status = "REFRESH_DATA",
            confidence = "NONE",
            itemKey = itemKey,
            itemName = item.itemName or item.name,
            stackCount = stackCount,
            dataAgeSeconds = ageSeconds,
            freshness = fresh,
            reasonCodes = { "DATA_TOO_OLD" },
            explanation = { "Market data is stale. Run a new market scan before relying on this price." },
        }
    end

    if confidence == "NONE" then
        return {
            status = "INSUFFICIENT_DATA",
            confidence = "NONE",
            itemKey = itemKey,
            itemName = item.itemName or item.name,
            stackCount = stackCount,
            dataAgeSeconds = ageSeconds,
            freshness = fresh,
            currentLowest = item.lowestUnitBuyout,
            currentMedian = item.medianUnitBuyout,
            currentLowestUnitBuyout = item.lowestUnitBuyout,
            currentMedianUnitBuyout = item.medianUnitBuyout,
            sevenDayMedian = sevenDayMedian or 0,
            thirtyDayMedian = thirtyDayMedian or 0,
            reasonCodes = { "INSUFFICIENT_SAMPLE_CONFIDENCE" },
            explanation = { "There is not enough reliable history to calculate a supported recommendation." },
        }
    end

    local strategy = context.strategy or "MATCH"
    local wall, ignoredLowOutlier = chooseWall(item)
    local unitBuyout = wall
    if strategy == "SMALL_UNDERCUT" and wall > 1 then
        unitBuyout = wall - 1
        reasonCodes[#reasonCodes + 1] = "SMALL_UNDERCUT"
    elseif strategy == "HOLD_VALUE" then
        unitBuyout = math.max(wall, tonumber(item.weightedMedianUnitBuyout) or wall)
        reasonCodes[#reasonCodes + 1] = "HOLD_VALUE"
    else
        reasonCodes[#reasonCodes + 1] = "MATCH_MEANINGFUL_WALL"
    end

    unitBuyout = math.max(0, math.floor(unitBuyout))
    if unitBuyout <= 0 or stackCount > math.floor(MAX_SAFE_INTEGER / unitBuyout) then
        return {
            status = "INVALID_QUANTITY",
            confidence = "NONE",
            itemKey = itemKey,
            itemName = item.itemName or item.name,
            stackCount = stackCount,
            reasonCodes = { "STACK_TOTAL_OVERFLOW_RISK" },
            explanation = { "The requested stack would create an unsafe price total." },
        }
    end
    local stackBuyout = unitBuyout * stackCount
    local unitBid = unitBuyout
    local stackBid = stackBuyout
    local economics = self:GetSaleEconomics(itemKey, stackCount, stackBuyout)

    local explanation = {
        targetedCheckedAt and "Recommendation uses a current targeted-item check layered over the completed full scan."
            or "Recommendation is based on cached local completed-scan data.",
        "Player must enter values manually in Blizzard's Auction House.",
    }
    if sevenDayMedian then
        explanation[#explanation + 1] = "Seven-day market data is available for comparison."
    end
    if ignoredLowOutlier then
        explanation[#explanation + 1] = "One unusually cheap listing was ignored instead of dragging your price down."
        reasonCodes[#reasonCodes + 1] = "IGNORED_LOW_OUTLIER"
    end

    return {
        status = "RECOMMENDED",
        confidence = confidence,
        itemKey = itemKey,
        itemName = item.itemName or item.name,
        stackCount = stackCount,
        unitBid = unitBid,
        stackBid = stackBid,
        unitBuyout = unitBuyout,
        stackBuyout = stackBuyout,
        recommendedUnitBuyout = unitBuyout,
        recommendedStackBuyout = stackBuyout,
        recommendedUnitBid = unitBid,
        recommendedStackBid = stackBid,
        meaningfulPriceWall = wall,
        meaningfulMarketWall = wall,
        currentLowest = item.lowestUnitBuyout,
        currentMedian = item.medianUnitBuyout,
        sevenDayMedian = sevenDayMedian or 0,
        thirtyDayMedian = thirtyDayMedian or 0,
        currentLowestUnitBuyout = item.lowestUnitBuyout,
        currentMedianUnitBuyout = item.medianUnitBuyout,
        weightedMedianUnitBuyout = item.weightedMedianUnitBuyout,
        currentQuantity = item.totalQuantity,
        listingCount = item.listingCount,
        sampleCount = item.sampleCount,
        dataAgeSeconds = ageSeconds,
        freshness = fresh,
        reasonCodes = reasonCodes,
        explanation = explanation,
        auctionCut = economics.auctionCut,
        estimatedDeposit = economics.deposit,
        expectedDepositLoss = economics.expectedDepositLoss,
        expectedNetSale = economics.expectedNetSale,
        vendorValue = economics.vendorValue,
        personalSales = economics.personalSales,
        snapshotId = snapshot.scanId or snapshot.id,
        sourceScanCompletedAt = snapshot.completedAt,
        recommendationTimestamp = now(),
        sourceType = targetedCheckedAt and "TARGETED_ITEM" or "FULL_SCAN_CACHE",
        targetedValidationAt = targetedCheckedAt,
        observedUnitPrice = item.lowestUnitBuyout,
    }
end
