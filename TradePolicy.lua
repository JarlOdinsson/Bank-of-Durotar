local addonName, BOD = ...

BOD.TradePolicy = {}

local MAX_SAFE_INTEGER = 2147483647
local DEMAND_RANK = { UNKNOWN = 0, SLOW = 1, ACTIVE = 2, HOT = 3 }
local CONFIDENCE_RANK = { AVOID = 0, SPECULATIVE = 1, FAIR = 2, STRONG = 3 }

local MODES = {
    CONSERVATIVE = { perTradeRate = 0.15, totalRate = 0.35, minimumProfit = 10000, minimumDiscount = 0.20, minimumDemand = "HOT", minimumConfidence = "STRONG", minimumObservations = 8, relists = 1 },
    BALANCED = { perTradeRate = 0.25, totalRate = 0.50, minimumProfit = 5000, minimumDiscount = 0.15, minimumDemand = "ACTIVE", minimumConfidence = "FAIR", minimumObservations = 5, relists = 2 },
    AGGRESSIVE = { perTradeRate = 0.40, totalRate = 0.70, minimumProfit = 2500, minimumDiscount = 0.12, minimumDemand = "SLOW", minimumConfidence = "SPECULATIVE", minimumObservations = 3, relists = 2 },
}

local REASON_TEXT = {
    INVALID_DATA = "Required trade data is missing or invalid.",
    TRADES_DISABLED = "Trades is disabled in Trade Rules.",
    STALE_DATA = "Market data is old. Run a new scan.",
    INSUFFICIENT_HISTORY = "More market observations are needed before a larger trade can be recommended.",
    UNSUPPORTED_EXIT_PRICE = "The expected exit price is not supported by recent market history.",
    DISCOUNT_TOO_SMALL = "Prices are above supported entry levels.",
    PROFIT_TOO_LOW = "Estimated profit is below the trade minimum.",
    RELISTING_ERASES_PROFIT = "Auction House fees and modeled relists erase the low-case profit.",
    DEMAND_TOO_WEAK = "Demand evidence is too weak for this risk mode.",
    CONFIDENCE_TOO_LOW = "Price confidence is too low for this risk mode.",
    CAPITAL_TOO_LOW = "Current opportunities require more trading capital than is safely available.",
    TOTAL_CAPITAL_COMMITTED = "Available trading capital is already committed to open trades.",
    MAX_OPEN_TRADES = "Close an open trade before tracking another.",
    POSITION_TOO_LARGE = "This listing would concentrate too much capital in one item.",
    EXISTING_EXPOSURE_TOO_HIGH = "Existing bag inventory already uses the safe item exposure.",
    PRICE_MAY_BE_MANIPULATED = "Price may be manipulated",
    NOT_COMMODITY = "Trades currently focuses on stackable commodities.",
}

local function wholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number > MAX_SAFE_INTEGER then return nil end
    return math.floor(number)
end

local function reject(code)
    return { actionable = false, confidence = "AVOID", rejectionCode = code, reason = REASON_TEXT[code] or REASON_TEXT.INVALID_DATA }
end

local function rankValue(map, value)
    return map[tostring(value or ""):upper()] or 0
end

function BOD.TradePolicy:GetModeRules(mode)
    return MODES[tostring(mode or "BALANCED"):upper()] or MODES.BALANCED
end

function BOD.TradePolicy:GetReasonText(code)
    return REASON_TEXT[code] or REASON_TEXT.INVALID_DATA
end

function BOD.TradePolicy:GetCapitalLimits(liquidGold, committedCapital, settings)
    settings = type(settings) == "table" and settings or {}
    liquidGold = wholeNumber(liquidGold) or 0
    committedCapital = wholeNumber(committedCapital) or 0
    local reserve = math.min(liquidGold, wholeNumber(settings.emergencyReserveCopper) or 0)
    local deployable = math.max(0, liquidGold - reserve)
    local mode = self:GetModeRules(settings.riskMode)
    local modePerTrade = math.floor(deployable * mode.perTradeRate)
    local modeTotal = math.floor(deployable * mode.totalRate)
    local explicitPerTrade = wholeNumber(settings.maximumCapitalPerTradeCopper) or 0
    local explicitTotal = wholeNumber(settings.maximumTotalCapitalCommittedCopper) or 0
    local perTradeLimit = explicitPerTrade > 0 and math.min(modePerTrade, explicitPerTrade) or modePerTrade
    local totalLimit = explicitTotal > 0 and math.min(modeTotal, explicitTotal) or modeTotal
    return {
        liquidGold = liquidGold,
        emergencyReserve = reserve,
        deployableCapital = deployable,
        committedCapital = committedCapital,
        perTradeLimit = perTradeLimit,
        totalCommitmentLimit = totalLimit,
        availableCapital = math.max(0, math.min(deployable - committedCapital, totalLimit - committedCapital)),
    }
end

function BOD.TradePolicy:SizePosition(analysis, limits, supportsPartialPurchase)
    local current = wholeNumber(analysis and analysis.currentUnitPrice) or 0
    local listingQuantity = wholeNumber(analysis and analysis.listingPurchaseQuantity) or 0
    local owned = wholeNumber(analysis and analysis.ownedQuantity) or 0
    if current <= 0 or listingQuantity <= 0 then return 0, 0 end
    local maximumByCapital = math.floor(math.min(limits.perTradeLimit, limits.availableCapital) / current)
    local remainingExposure = math.max(0, maximumByCapital - owned)
    local recommended = listingQuantity
    if supportsPartialPurchase == true then recommended = math.min(listingQuantity, remainingExposure) end
    if recommended <= 0 or (supportsPartialPurchase ~= true and listingQuantity > remainingExposure) then return 0, remainingExposure end
    return recommended, remainingExposure
end

local function chooseRisk(analysis, lowProfit, normalProfit, minimumProfit, maximumUnitPrice)
    local stability = tonumber(analysis.stabilityRate)
    if analysis.discountRate >= 0.55 and (not stability or stability > 0.50) then return "PRICE_MAY_BE_MANIPULATED", REASON_TEXT.PRICE_MAY_BE_MANIPULATED end
    if analysis.observationCount < 8 or analysis.observationDayCount < 5 then return "LOW_HISTORICAL_CONFIDENCE", "Low historical confidence" end
    local deposit = (tonumber(analysis.estimatedDepositPerListing) or 0)
    if analysis.normalExitUnitPrice > 0 and deposit >= (analysis.normalExitUnitPrice * 0.10) then return "HIGH_DEPOSIT_COST", "High deposit cost" end
    if normalProfit > 0 and lowProfit < (normalProfit * 0.50) then return "PROFIT_DEPENDS_ON_RELISTING", "Profit depends on relisting" end
    if analysis.ownedQuantity > 0 then return "OWNED_INVENTORY", "You already own " .. tostring(analysis.ownedQuantity) .. " in your bags" end
    if analysis.currentUnitPrice >= (maximumUnitPrice * 0.90) then return "CURRENT_PRICE_NEAR_MAXIMUM", "Current price is near the maximum buy price" end
    if analysis.listingCount < 5 or analysis.totalMarketQuantity < 20 then return "THIN_CURRENT_SUPPLY", "Current supply is thin" end
    if lowProfit < (minimumProfit * 2) then return "LOW_ABSOLUTE_PROFIT", "Low absolute profit" end
    return "MARKET_CAN_CHANGE", "Market conditions can change"
end

function BOD.TradePolicy:Evaluate(analysis, context)
    context = type(context) == "table" and context or {}
    local settings = type(context.settings) == "table" and context.settings or {}
    if settings.enabled == false then return reject("TRADES_DISABLED") end
    if type(analysis) ~= "table" then return reject("INVALID_DATA") end
    if not wholeNumber(analysis.currentUnitPrice) or analysis.currentUnitPrice <= 0
        or not wholeNumber(analysis.listingPurchaseQuantity) or analysis.listingPurchaseQuantity <= 0
        or not wholeNumber(analysis.listingCapitalRequired) or analysis.listingCapitalRequired <= 0
    then
        return reject("INVALID_DATA")
    end
    if (wholeNumber(context.openTradeCount) or 0) >= (wholeNumber(settings.maxOpenTrades) or 5) then return reject("MAX_OPEN_TRADES") end
    local mode = self:GetModeRules(settings.riskMode)
    local limits = context.capitalLimits or self:GetCapitalLimits(context.liquidGold, context.committedCapital, settings)
    if limits.availableCapital <= 0 then
        return reject(limits.committedCapital > 0 and limits.totalCommitmentLimit > 0
            and limits.committedCapital >= limits.totalCommitmentLimit and "TOTAL_CAPITAL_COMMITTED" or "CAPITAL_TOO_LOW")
    end
    if (wholeNumber(analysis.dataAgeSeconds) or MAX_SAFE_INTEGER) > 43200 then return reject("STALE_DATA") end
    local minimumObservations = math.max(mode.minimumObservations, wholeNumber(settings.minimumObservationCount) or 0)
    if analysis.observationCount < minimumObservations or analysis.observationDayCount < math.min(5, minimumObservations) then return reject("INSUFFICIENT_HISTORY") end
    if not analysis.fastExitUnitPrice or analysis.fastExitUnitPrice <= analysis.currentUnitPrice
        or not analysis.normalExitUnitPrice or analysis.normalExitUnitPrice < analysis.fastExitUnitPrice
    then
        return reject("UNSUPPORTED_EXIT_PRICE")
    end
    local minimumDiscount = math.max(mode.minimumDiscount, (wholeNumber(settings.minimumDiscountPercent) or 0) / 100)
    if analysis.discountRate < minimumDiscount then return reject("DISCOUNT_TOO_SMALL") end
    if analysis.discountRate >= 0.55 and (not analysis.stabilityRate or analysis.stabilityRate > 0.50 or analysis.observationCount < 8) then return reject("PRICE_MAY_BE_MANIPULATED") end
    local minimumDemand = tostring(settings.minimumDemand or mode.minimumDemand):upper()
    if rankValue(DEMAND_RANK, analysis.demand) < math.max(rankValue(DEMAND_RANK, mode.minimumDemand), rankValue(DEMAND_RANK, minimumDemand)) then return reject("DEMAND_TOO_WEAK") end
    local minimumConfidence = tostring(settings.minimumConfidence or mode.minimumConfidence):upper()
    local confidenceFloor = math.max(rankValue(CONFIDENCE_RANK, mode.minimumConfidence), rankValue(CONFIDENCE_RANK, minimumConfidence))
    if rankValue(CONFIDENCE_RANK, analysis.confidence) < confidenceFloor then return reject("CONFIDENCE_TOO_LOW") end
    if analysis.confidence == "SPECULATIVE" and settings.showSpeculativeTrades ~= true then return reject("CONFIDENCE_TOO_LOW") end

    local recommendedQuantity, remainingExposure = self:SizePosition(analysis, limits, false)
    if recommendedQuantity <= 0 then
        return reject(analysis.ownedQuantity > 0 and "EXISTING_EXPOSURE_TOO_HIGH" or "POSITION_TOO_LARGE")
    end
    local capital = analysis.currentUnitPrice * recommendedQuantity
    if capital > limits.availableCapital then return reject("CAPITAL_TOO_LOW") end
    if recommendedQuantity > math.floor(MAX_SAFE_INTEGER / analysis.normalExitUnitPrice) then return reject("INVALID_DATA") end
    local relists = mode.relists
    if analysis.confidence == "STRONG" and analysis.demand == "HOT" then relists = 1 end
    local depositLoss = math.floor((tonumber(analysis.estimatedDepositPerListing) or 0) * recommendedQuantity * relists)
    local lowGross = analysis.fastExitUnitPrice * recommendedQuantity
    local normalGross = analysis.normalExitUnitPrice * recommendedQuantity
    local lowNet = lowGross - math.floor(lowGross * 0.05) - depositLoss
    local normalNet = normalGross - math.floor(normalGross * 0.05) - depositLoss
    local lowProfit = lowNet - capital
    local normalProfit = normalNet - capital
    if lowProfit <= 0 then return reject("RELISTING_ERASES_PROFIT") end
    local minimumProfit = math.max(mode.minimumProfit, wholeNumber(settings.minimumAbsoluteProfitCopper) or 0)
    if lowProfit < minimumProfit then return reject("PROFIT_TOO_LOW") end
    local maximumUnitPrice = math.floor((lowNet - minimumProfit) / recommendedQuantity)
    if maximumUnitPrice <= analysis.currentUnitPrice then return reject("PROFIT_TOO_LOW") end

    local confidence = "SPECULATIVE"
    if analysis.confidence == "STRONG" and analysis.demand == "HOT" and lowProfit >= (minimumProfit * 2)
        and analysis.discountRate >= 0.20 and analysis.stabilityRate and analysis.stabilityRate <= 0.25
    then
        confidence = "STRONG"
    elseif (analysis.confidence == "STRONG" or analysis.confidence == "FAIR")
        and (analysis.demand == "HOT" or analysis.demand == "ACTIVE")
    then
        confidence = "FAIR"
    end
    local riskCode, mainRisk = chooseRisk(analysis, lowProfit, normalProfit, minimumProfit, maximumUnitPrice)
    return {
        actionable = true,
        confidence = confidence,
        demand = analysis.demand,
        recommendedPurchaseQuantity = recommendedQuantity,
        maximumSafePurchaseQuantity = math.min(recommendedQuantity, remainingExposure),
        maximumBuyUnitPrice = maximumUnitPrice,
        requiredCapital = capital,
        lowProfit = lowProfit,
        normalProfit = normalProfit,
        lowReturnRate = capital > 0 and lowProfit / capital or 0,
        normalReturnRate = capital > 0 and normalProfit / capital or 0,
        modeledRelists = relists,
        modeledDepositLoss = depositLoss,
        mainRiskCode = riskCode,
        mainRisk = mainRisk,
        capitalAfterPurchaseRate = limits.deployableCapital > 0 and (limits.committedCapital + capital) / limits.deployableCapital or 0,
        why = "Repeated local observations support the exit range, and the current exact listing is below that range after fees.",
    }
end

function BOD.TradePolicy:IsBetter(left, right)
    if not right then return true end
    if left.lowProfit ~= right.lowProfit then return left.lowProfit > right.lowProfit end
    local leftDemand, rightDemand = rankValue(DEMAND_RANK, left.demand), rankValue(DEMAND_RANK, right.demand)
    if leftDemand ~= rightDemand then return leftDemand > rightDemand end
    if left.normalProfit ~= right.normalProfit then return left.normalProfit > right.normalProfit end
    local leftEfficiency = left.requiredCapital > 0 and left.lowProfit / left.requiredCapital or 0
    local rightEfficiency = right.requiredCapital > 0 and right.lowProfit / right.requiredCapital or 0
    if leftEfficiency ~= rightEfficiency then return leftEfficiency > rightEfficiency end
    local leftConfidence, rightConfidence = rankValue(CONFIDENCE_RANK, left.confidence), rankValue(CONFIDENCE_RANK, right.confidence)
    if leftConfidence ~= rightConfidence then return leftConfidence > rightConfidence end
    local leftStability = tonumber(left.stabilityRate) or math.huge
    local rightStability = tonumber(right.stabilityRate) or math.huge
    if leftStability ~= rightStability then return leftStability < rightStability end
    if left.ownedQuantity ~= right.ownedQuantity then return left.ownedQuantity < right.ownedQuantity end
    if left.requiredCapital ~= right.requiredCapital then return left.requiredCapital < right.requiredCapital end
    return tostring(left.itemName or left.itemKey) < tostring(right.itemName or right.itemKey)
end
