local addonName, BOD = ...

BOD.QuickMovePolicy = {}

local REASON_TEXT = {
    QUICK_POSITION_TOO_LARGE = "The position is too large for a simple quick move.",
    QUICK_CAPITAL_TOO_HIGH = "The purchase commits too much gold for a quick move.",
    QUICK_DEMAND_TOO_SLOW = "The available evidence suggests a slow market.",
    QUICK_RELISTING_TOO_HIGH = "This opportunity may require too many relists for a quick move.",
}

local function reject(code)
    return {
        actionable = false,
        trustLabel = "AVOID",
        rejectionCode = code,
        mainRiskCode = code,
        mainRisk = REASON_TEXT[code] or "This is not a simple quick move.",
        recommendedPurchaseQuantity = 0,
    }
end

function BOD.QuickMovePolicy:GetReasonText(code)
    return REASON_TEXT[code] or (BOD.RecommendationPolicy and BOD.RecommendationPolicy:GetRiskText(code))
end

function BOD.QuickMovePolicy:Evaluate(candidate, options)
    options = type(options) == "table" and options or {}
    local result = BOD.RecommendationPolicy:Evaluate(candidate, options)
    if not result.actionable then return result end
    local quantity = math.max(0, math.floor(tonumber(candidate.purchaseQuantity) or 0))
    local capital = math.max(0, math.floor(tonumber(candidate.capitalRequired) or 0))
    local maximumQuantity = math.max(1, math.floor(tonumber(options.maximumQuickQuantity) or 20))
    local maximumCapital = math.max(1, math.floor(tonumber(options.maximumQuickCapitalCopper) or 200000))
    local demand = tostring(candidate.demand or "UNKNOWN"):upper()
    local relists = math.max(0, math.floor(tonumber(candidate.relistFailuresModeled) or 1))
    if quantity > maximumQuantity then return reject("QUICK_POSITION_TOO_LARGE") end
    if capital > maximumCapital then return reject("QUICK_CAPITAL_TOO_HIGH") end
    if demand == "SLOW" then return reject("QUICK_DEMAND_TOO_SLOW") end
    if relists > 2 then return reject("QUICK_RELISTING_TOO_HIGH") end
    return result
end

function BOD.QuickMovePolicy:EvaluateAnalysis(analysis, options)
    if type(analysis) ~= "table" then return reject("INVALID_DATA") end
    options = type(options) == "table" and options or {}
    local quantity = math.max(1, math.floor(tonumber(analysis.listingPurchaseQuantity) or 1))
    local normalGross = math.floor((tonumber(analysis.normalExitUnitPrice) or 0) * quantity)
    local fastGross = math.floor((tonumber(analysis.fastExitUnitPrice) or 0) * quantity)
    local capital = math.floor(tonumber(analysis.listingCapitalRequired) or 0)
    local relists = analysis.confidence == "STRONG" and 1 or 2
    local depositLoss = math.floor((tonumber(analysis.estimatedDepositPerListing) or 0) * quantity * relists)
    local normalProfit = normalGross - math.floor(normalGross * 0.05) - depositLoss - capital
    local lowProfit = fastGross - math.floor(fastGross * 0.05) - depositLoss - capital
    local maximumPrice = math.floor(((tonumber(analysis.fastExitUnitPrice) or 0) * 0.95) - ((tonumber(analysis.supportedMarketValue) or 0) * 0.10))
    local confidence = analysis.confidence == "STRONG" and "HIGH" or "MEDIUM"
    return self:Evaluate({
        currentUnitPrice = analysis.currentUnitPrice,
        maximumSafeUnitPrice = maximumPrice,
        expectedNetProfit = normalProfit,
        conservativeNetProfit = lowProfit,
        purchaseQuantity = quantity,
        capitalRequired = capital,
        dataAgeSeconds = analysis.dataAgeSeconds,
        confidence = confidence,
        historyObservationCount = analysis.observationCount,
        historyDayCount = analysis.observationDayCount,
        listingCount = analysis.listingCount,
        sampleCount = analysis.sampleCount,
        totalMarketQuantity = analysis.totalMarketQuantity,
        ownedQuantity = analysis.ownedQuantity,
        referenceUnitPrice = analysis.supportedMarketValue,
        grossSale = normalGross,
        estimatedDeposit = (tonumber(analysis.estimatedDepositPerListing) or 0) * quantity,
        expectedNetSale = normalGross - math.floor(normalGross * 0.05) - depositLoss,
        vendorValue = (tonumber(analysis.vendorUnitPrice) or 0) * quantity,
        demand = analysis.demand,
        relistFailuresModeled = relists,
    }, options)
end
