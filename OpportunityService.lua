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

local function buildOpportunity(itemKey, item, snapshot, filters, context)
    if not validCopper(item.lowestUnitBuyout) or not validCopper(item.medianUnitBuyout) then
        return nil, "INVALID_DATA"
    end

    local historySummary = BOD.MarketHistory and BOD.MarketHistory.GetSummary and BOD.MarketHistory:GetSummary(itemKey) or nil
    local sharedAnalysis = BOD.MarketAnalysis and BOD.MarketAnalysis:Analyze(itemKey, item, snapshot, {
        ownedQuantities = context and context.ownedQuantities,
    }) or nil
    local acquisition = BOD.AcquisitionEvaluator and BOD.AcquisitionEvaluator:EvaluateItem(itemKey, item, snapshot, {
        budgetCopper = filters.maximumCapitalRequired,
        quantityCap = filters.maximumQuickQuantity or 20,
        context = { ownedQuantities = context and context.ownedQuantities },
    }) or nil
    if not acquisition or (tonumber(acquisition.purchaseQuantity) or 0) <= 0 then
        return nil, acquisition and acquisition.status or "INVALID_DATA"
    end
    local observationCount = tonumber(sharedAnalysis and sharedAnalysis.observationCount)
        or tonumber(historySummary and historySummary.observationCount) or 0
    local hasHistory = observationCount >= 2
    local scanReference = math.max(tonumber(item.weightedMedianUnitBuyout) or 0, tonumber(item.medianUnitBuyout) or 0)
    local historicalMedian = hasHistory and historySummary.sevenDay and tonumber(historySummary.sevenDay.median) or nil
    local reference = tonumber(sharedAnalysis and sharedAnalysis.supportedMarketValue)
        or (historicalMedian and historicalMedian > 0 and math.min(scanReference, historicalMedian) or scanReference)
    local current = tonumber(acquisition.averageUnitCost) or tonumber(item.lowestUnitBuyout) or 0
    local availableQuantity = math.max(1, math.floor(tonumber(acquisition.purchaseQuantity) or 1))
    local economics = BOD.PricingService:GetSaleEconomics(itemKey, availableQuantity, reference * availableQuantity)
    local estimatedNetResalePerUnit = math.floor(economics.expectedNetSale / availableQuantity)
    local maximumSafeUnitPrice = math.min(
        math.floor(estimatedNetResalePerUnit - (reference * MINIMUM_MARGIN_RATE)),
        tonumber(acquisition.safeCeiling) or 2147483647)
    if reference <= current or current > maximumSafeUnitPrice or estimatedNetResalePerUnit <= current then
        return nil, "PRICE_ABOVE_SAFE_LIMIT"
    end

    local quantity = tonumber(item.totalQuantity) or 0
    local listings = tonumber(item.listingCount) or 0
    local sampleCount = tonumber(item.sampleCount) or 0
    local upsidePerUnit = estimatedNetResalePerUnit - current
    local capitalRequired = math.floor(tonumber(acquisition.capitalRequired) or (current * availableQuantity))
    local estimatedTotalUpside = upsidePerUnit * availableQuantity
    local confidenceValue = confidence(sampleCount, listings, hasHistory)
    if confidenceValue == "NONE" then
        return nil, "INSUFFICIENT_DATA"
    end
    local personalSales = economics.personalSales or {}
    if (tonumber(personalSales.outcomeCount) or 0) >= 3 and (tonumber(personalSales.saleRate) or 0) < 0.25 then
        return nil, "POOR_PERSONAL_SALES"
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

    local grossSale = math.floor(reference * availableQuantity)
    local relistFailures = outcomeCount >= 3 and (tonumber(personalSales.saleRate) or 0) >= 0.75 and 1 or 2
    local conservativeDepositLoss = math.floor((tonumber(economics.deposit) or 0) * relistFailures)
    local conservativeNetSale = math.max(0, grossSale - (tonumber(economics.auctionCut) or 0) - conservativeDepositLoss)
    local conservativeNetProfit = conservativeNetSale - capitalRequired
    local ownedQuantity = tonumber(context and context.ownedQuantities and context.ownedQuantities[itemKey]) or 0
    local dataAgeSeconds = tonumber(sharedAnalysis and sharedAnalysis.dataAgeSeconds)
        or math.max(0, (type(time) == "function" and time() or os.time()) - (tonumber(snapshot.observationTimestamp or snapshot.completedAt) or 0))
    local policy = BOD.QuickMovePolicy:Evaluate({
        currentUnitPrice = current,
        maximumSafeUnitPrice = maximumSafeUnitPrice,
        expectedNetProfit = estimatedTotalUpside,
        conservativeNetProfit = conservativeNetProfit,
        purchaseQuantity = availableQuantity,
        capitalRequired = capitalRequired,
        dataAgeSeconds = dataAgeSeconds,
        confidence = confidenceValue,
        historyObservationCount = observationCount,
        historyDayCount = tonumber(historySummary and historySummary.dayCount) or 0,
        listingCount = listings,
        sampleCount = sampleCount,
        totalMarketQuantity = quantity,
        ownedQuantity = ownedQuantity,
        referenceUnitPrice = reference,
        grossSale = grossSale,
        estimatedDeposit = economics.deposit,
        expectedNetSale = economics.expectedNetSale,
        vendorValue = economics.vendorValue,
        demand = sharedAnalysis and sharedAnalysis.demand or "UNKNOWN",
        relistFailuresModeled = relistFailures,
    }, {
        minimumExpectedProfitCopper = filters.minimumExpectedProfitCopper,
        maximumAgeSeconds = filters.maximumAgeSeconds,
        maximumQuickCapitalCopper = filters.maximumCapitalRequired,
        maximumQuickQuantity = filters.maximumQuickQuantity or 20,
    })
    if not policy.actionable then return nil, policy.rejectionCode, policy end

    return {
        itemKey = itemKey,
        itemID = item.itemID,
        itemName = item.itemName or item.name,
        category = hasHistory and "BELOW_RECENT_VALUE" or "CHEAPEST_LISTING_BELOW_MARKET",
        score = score,
        opportunityScore = score,
        easeScore = easeScore,
        flipScore = flipScore,
        capitalEfficiencyBps = acquisition.capitalEfficiencyBps,
        profitRate = profitRate,
        confidence = confidenceValue,
        demand = sharedAnalysis and sharedAnalysis.demand or "UNKNOWN",
        marketConfidence = sharedAnalysis and sharedAnalysis.confidence or nil,
        stabilityRate = sharedAnalysis and sharedAnalysis.stabilityRate or nil,
        trustLabel = policy.trustLabel,
        mainRiskCode = policy.mainRiskCode,
        mainRisk = policy.mainRisk,
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
        conservativeNetProfit = conservativeNetProfit,
        conservativeNetSale = conservativeNetSale,
        conservativeDepositLoss = conservativeDepositLoss,
        relistFailuresModeled = relistFailures,
        grossSale = grossSale,
        availableQuantity = availableQuantity,
        currentQuantity = availableQuantity,
        acquisition = acquisition,
        totalMarketQuantity = quantity,
        listingCount = listings,
        capitalRequired = capitalRequired,
        personalSoldCount = tonumber(personalSales.soldCount) or 0,
        personalExpiredCount = tonumber(personalSales.expiredCount) or 0,
        personalOutcomeCount = outcomeCount,
        personalSaleRate = personalSales.saleRate,
        ownedQuantity = ownedQuantity,
        recommendedPurchaseQuantity = policy.recommendedPurchaseQuantity,
        dataAgeSeconds = dataAgeSeconds,
        recommendationTimestamp = type(time) == "function" and time() or os.time(),
        snapshotId = snapshot.scanId or snapshot.id,
        sourceScanCompletedAt = snapshot.completedAt,
        sourceType = "FULL_SCAN_CACHE",
        freshnessLabel = BOD.MarketCache and BOD.MarketCache:ClassifyAge(dataAgeSeconds, BOD.db and BOD.db.settings) or nil,
        observedUnitPrice = current,
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
    local rejectionCounts = {}
    local function reject(code)
        code = tostring(code or "INVALID_DATA")
        rejectionCounts[code] = (rejectionCounts[code] or 0) + 1
    end
    for itemKey, item in pairs(snapshot.items) do
        local opportunity, rejectionCode = buildOpportunity(itemKey, item, snapshot, filters, context)
        if opportunity
            and opportunity.opportunityScore >= minScore
            and opportunity.capitalRequired <= maxCapital
            and opportunity.conservativeNetProfit >= minUpside
            and (CONFIDENCE_RANK[opportunity.confidence] or 0) >= minimumRank
            and (includeLowSample or opportunity.confidence ~= "LOW")
        then
            opportunities[#opportunities + 1] = opportunity
        elseif opportunity and opportunity.capitalRequired > maxCapital then
            reject("BUDGET_TOO_LOW")
        elseif opportunity then
            reject("INSUFFICIENT_DATA")
        else
            reject(rejectionCode)
        end
    end

    table.sort(opportunities, function(left, right)
        return BOD.RecommendationPolicy:IsBetterOpportunity(left, right)
    end)

    while #opportunities > limit do
        table.remove(opportunities)
    end

    local primaryRejectionCode, primaryCount
    for code, count in pairs(rejectionCounts) do
        if not primaryCount or count > primaryCount or (count == primaryCount and code < primaryRejectionCode) then
            primaryRejectionCode, primaryCount = code, count
        end
    end
    return {
        status = #opportunities > 0 and "OK" or "EMPTY",
        opportunities = opportunities,
        resultCount = #opportunities,
        snapshotId = snapshot.scanId or snapshot.id,
        rejectionCounts = rejectionCounts,
        primaryRejectionCode = primaryRejectionCode,
        primaryRejectionReason = primaryRejectionCode and BOD.QuickMovePolicy:GetReasonText(primaryRejectionCode) or nil,
        explanation = "Results are estimated opportunities only, not guaranteed profit.",
    }
end

function BOD.OpportunityService:CheckRecommendationFreshness(recommendation)
    local snapshot = BOD.MarketData and BOD.MarketData:GetLatestSnapshot() or nil
    local item = recommendation and BOD.MarketData and BOD.MarketData:GetCurrentItem(recommendation.itemKey) or nil
    local currentTime = type(time) == "function" and time() or os.time()
    return BOD.RecommendationPolicy:CheckFreshness(recommendation, item, snapshot, currentTime, 86400)
end
