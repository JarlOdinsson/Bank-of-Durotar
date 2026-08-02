local addonName, BOD = ...

BOD.OpportunityService = {}

local DEFAULT_LIMIT = 25
local ESTIMATED_AUCTION_CUT_RATE = 0.05
local MINIMUM_MARGIN_RATE = 0.10
local CONFIDENCE_RANK = {
    NONE = 0,
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3,
}

local function validCopper(value)
    local number = tonumber(value)
    return number and number == number and number > 0 and number < math.huge and number == math.floor(number)
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

local function confidence(sampleCount, listingCount, hasHistory)
    sampleCount = tonumber(sampleCount) or 0
    listingCount = tonumber(listingCount) or 0
    if sampleCount >= 30 and listingCount >= 10 and hasHistory then
        return "HIGH"
    elseif sampleCount >= 6 and listingCount >= 3 then
        return "MEDIUM"
    elseif sampleCount >= 2 then
        return "LOW"
    end
    return "NONE"
end

local function confidencePenalty(value)
    if value == "HIGH" then
        return 0
    elseif value == "MEDIUM" then
        return 10
    elseif value == "LOW" then
        return 25
    end
    return 100
end

local function buildOpportunity(itemKey, item, snapshotTimestamp)
    if not validCopper(item.lowestUnitBuyout) or not validCopper(item.medianUnitBuyout) then
        return nil
    end

    local historySummary = BOD.MarketHistory and BOD.MarketHistory.GetSummary and BOD.MarketHistory:GetSummary(itemKey) or nil
    local observationCount = tonumber(historySummary and historySummary.observationCount) or 0
    local hasHistory = observationCount >= 2
    local scanReference = math.max(tonumber(item.weightedMedianUnitBuyout) or 0, tonumber(item.medianUnitBuyout) or 0)
    local historicalMedian = hasHistory and historySummary.sevenDay and tonumber(historySummary.sevenDay.median) or nil
    local reference = historicalMedian and historicalMedian > 0 and math.min(scanReference, historicalMedian) or scanReference
    local current = tonumber(item.lowestUnitBuyout) or 0
    local availableQuantity = math.max(1, math.floor(tonumber(item.bestListingStackCount) or 1))
    local economics = BOD.PricingService:GetSaleEconomics(itemKey, availableQuantity, reference * availableQuantity)
    local estimatedNetResalePerUnit = math.floor(economics.expectedNetSale / availableQuantity)
    local maximumSafeUnitPrice = math.floor(estimatedNetResalePerUnit - (reference * MINIMUM_MARGIN_RATE))
    if reference <= current or current > maximumSafeUnitPrice or estimatedNetResalePerUnit <= current then
        return nil
    end

    local quantity = tonumber(item.totalQuantity) or 0
    local listings = tonumber(item.listingCount) or 0
    local sampleCount = tonumber(item.sampleCount) or 0
    local upsidePerUnit = estimatedNetResalePerUnit - current
    local capitalRequired = math.floor(tonumber(item.bestListingBuyoutTotal) or (current * availableQuantity))
    local estimatedTotalUpside = upsidePerUnit * availableQuantity
    local confidenceValue = confidence(sampleCount, listings, hasHistory)
    if confidenceValue == "NONE" then
        return nil
    end
    local personalSales = economics.personalSales or {}
    if (tonumber(personalSales.outcomeCount) or 0) >= 3 and (tonumber(personalSales.saleRate) or 0) < 0.25 then
        return nil
    end

    local deviation = reference > 0 and (upsidePerUnit / reference) or 0
    local scarcityScore = quantity > 0 and clamp(30 - quantity, 0, 30) or 0
    local wallScore = clamp(deviation * 60, 0, 40)
    local sampleScore = clamp(sampleCount, 0, 20)
    local personalScore = personalSales.saleRate and ((personalSales.saleRate - 0.5) * 20) or 0
    local score = clamp(math.floor(scarcityScore + wallScore + sampleScore + personalScore - confidencePenalty(confidenceValue)), 0, 100)
    local outcomeCount = tonumber(personalSales.outcomeCount) or 0
    local profitRate = capitalRequired > 0 and (estimatedTotalUpside / capitalRequired) or 0
    local confidenceScore = confidenceValue == "HIGH" and 25 or (confidenceValue == "MEDIUM" and 16 or 6)
    local historyScore = clamp(observationCount * 3, 0, 18)
    local marketDepthScore = clamp(listings * 2, 0, 16) + clamp(quantity / 4, 0, 10)
    local personalEaseScore = outcomeCount >= 3 and clamp((tonumber(personalSales.saleRate) or 0) * 20, 0, 20) or 6
    local returnScore = clamp(profitRate * 35, 0, 15)
    local easeScore = clamp(math.floor(confidenceScore + historyScore + marketDepthScore + personalEaseScore + returnScore), 0, 100)
    local flipScore = clamp(math.floor((easeScore * 0.65) + (score * 0.35)), 0, 100)

    local reasons = {}
    if deviation >= 0.2 then
        reasons[#reasons + 1] = "CURRENT_PRICE_BELOW_REFERENCE"
    end
    if quantity <= 10 then
        reasons[#reasons + 1] = "LOW_SUPPLY"
    end
    if hasHistory then
        reasons[#reasons + 1] = "HAS_LOCAL_HISTORY"
    else
        reasons[#reasons + 1] = "CURRENT_SNAPSHOT_ONLY"
    end

    local historicalReference = historicalMedian or reference
    historicalReference = tonumber(historicalReference) or reference

    return {
        itemKey = itemKey,
        itemName = item.itemName or item.name,
        category = hasHistory and "BELOW_RECENT_VALUE" or "CHEAPEST_LISTING_BELOW_MARKET",
        score = score,
        opportunityScore = score,
        easeScore = easeScore,
        flipScore = flipScore,
        profitRate = profitRate,
        confidence = confidenceValue,
        currentUnitPrice = current,
        historicalReferencePrice = historicalReference,
        historyObservationCount = observationCount,
        historyDayCount = tonumber(historySummary and historySummary.dayCount) or 0,
        resaleTargetUnitPrice = reference,
        maximumSafeUnitPrice = maximumSafeUnitPrice,
        estimatedAuctionCutRate = ESTIMATED_AUCTION_CUT_RATE,
        estimatedAuctionCut = economics.auctionCut,
        estimatedDeposit = economics.deposit,
        expectedDepositLoss = economics.expectedDepositLoss,
        estimatedNetResalePerUnit = estimatedNetResalePerUnit,
        estimatedUpsidePerUnit = upsidePerUnit,
        estimatedTotalUpside = estimatedTotalUpside,
        availableQuantity = availableQuantity,
        currentQuantity = availableQuantity,
        totalMarketQuantity = quantity,
        listingCount = listings,
        capitalRequired = capitalRequired,
        personalSoldCount = tonumber(personalSales.soldCount) or 0,
        personalExpiredCount = tonumber(personalSales.expiredCount) or 0,
        personalOutcomeCount = outcomeCount,
        personalSaleRate = personalSales.saleRate,
        dataAgeSeconds = math.max(0, (type(time) == "function" and time() or os.time()) - (tonumber(snapshotTimestamp) or 0)),
        reasonCodes = reasons,
        explanation = {
            "The cheapest listings are at least 15% below the local reference price.",
            "Estimated gain includes the 5% Auction House cut and expected deposit losses.",
            "This estimate is not realized profit and is never guaranteed.",
        },
    }
end

function BOD.OpportunityService:FindOpportunities(filters, context)
    filters = filters or {}
    context = context or {}
    local limit = math.max(1, math.min(tonumber(filters.limit) or DEFAULT_LIMIT, 100))
    local minScore = tonumber(filters.minimumScore) or 1
    local maxCapital = tonumber(filters.maximumCapitalRequired) or math.huge
    local minUpside = tonumber(filters.minimumEstimatedUpside) or 0
    local minimumConfidence = tostring(filters.minimumConfidence or "LOW"):upper()
    local includeLowSample = filters.includeLowSample == true
    local minimumRank = CONFIDENCE_RANK[minimumConfidence] or 1
    local snapshot = BOD.MarketData and BOD.MarketData:GetLatestSnapshot()
    if not snapshot or snapshot.complete ~= true or type(snapshot.items) ~= "table" then
        return {
            status = "NO_DATA",
            opportunities = {},
            reasonCodes = { "NO_COMPLETE_CURRENT_SNAPSHOT" },
        }
    end

    local opportunities = {}
    for itemKey, item in pairs(snapshot.items) do
        local opportunity = buildOpportunity(itemKey, item, snapshot.observationTimestamp or snapshot.completedAt)
        if opportunity
            and opportunity.opportunityScore >= minScore
            and opportunity.capitalRequired <= maxCapital
            and opportunity.estimatedTotalUpside >= minUpside
            and (CONFIDENCE_RANK[opportunity.confidence] or 0) >= minimumRank
            and (includeLowSample or opportunity.confidence ~= "LOW")
        then
            opportunities[#opportunities + 1] = opportunity
        end
    end

    table.sort(opportunities, function(left, right)
        local leftRank = CONFIDENCE_RANK[left.confidence] or 0
        local rightRank = CONFIDENCE_RANK[right.confidence] or 0
        if left.flipScore ~= right.flipScore then
            return left.flipScore > right.flipScore
        elseif leftRank ~= rightRank then
            return leftRank > rightRank
        elseif left.opportunityScore ~= right.opportunityScore then
            return left.opportunityScore > right.opportunityScore
        elseif left.estimatedTotalUpside ~= right.estimatedTotalUpside then
            return left.estimatedTotalUpside > right.estimatedTotalUpside
        end
        return tostring(left.itemName or left.itemKey) < tostring(right.itemName or right.itemKey)
    end)

    while #opportunities > limit do
        table.remove(opportunities)
    end

    return {
        status = #opportunities > 0 and "OK" or "EMPTY",
        opportunities = opportunities,
        resultCount = #opportunities,
        snapshotId = snapshot.scanId or snapshot.id,
        explanation = "Results are estimated opportunities only, not guaranteed profit.",
    }
end
