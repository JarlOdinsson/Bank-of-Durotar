local BOD = { db = { trading = { settings = { maxOpenTrades = 5, tradeHistoryRetention = 50 }, openTrades = {}, closedTrades = {}, nextTradeId = 1 } } }

local function loadModule(path)
    local chunk = assert(loadfile(path))
    chunk("BankOfDurotar", BOD)
end

loadModule("MarketAnalysis.lua")
loadModule("RecommendationPolicy.lua")
loadModule("QuickMovePolicy.lua")
loadModule("TradePolicy.lua")
loadModule("TradeTracker.lua")

local function copy(source, changes)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    for key, value in pairs(changes or {}) do result[key] = value end
    return result
end

local function expect(value, label)
    if not value then error(label, 2) end
end

local settings = {
    enabled = true,
    riskMode = "BALANCED",
    emergencyReserveCopper = 100000,
    maximumCapitalPerTradeCopper = 0,
    maximumTotalCapitalCommittedCopper = 0,
    maxOpenTrades = 5,
    minimumAbsoluteProfitCopper = 5000,
    minimumDiscountPercent = 15,
    minimumDemand = "ACTIVE",
    minimumConfidence = "FAIR",
    minimumObservationCount = 5,
    showSpeculativeTrades = false,
    tradeHistoryRetention = 50,
}

local base = {
    itemKey = "item:23424",
    itemID = 23424,
    itemName = "Fel Iron Ore",
    currentUnitPrice = 5000,
    observedUnitPrice = 5000,
    listingPurchaseQuantity = 40,
    listingCapitalRequired = 200000,
    totalMarketQuantity = 200,
    listingCount = 20,
    sampleCount = 50,
    supportedMarketValue = 7000,
    fastExitUnitPrice = 6500,
    normalExitUnitPrice = 7000,
    optimisticExitUnitPrice = 7200,
    discountRate = 0.285,
    estimatedDepositPerListing = 100,
    vendorUnitPrice = 200,
    ownedQuantity = 0,
    dataAgeSeconds = 3600,
    observationCount = 10,
    observationDayCount = 7,
    stabilityRate = 0.10,
    typicalQuantity = 200,
    typicalListingCount = 20,
    demand = "HOT",
    confidence = "STRONG",
    snapshotId = "scan-1",
    recommendationTimestamp = 1000,
}

local limits = BOD.TradePolicy:GetCapitalLimits(1000000, 0, settings)
expect(limits.emergencyReserve == 100000 and limits.availableCapital == 450000, "emergency reserve and total cap")
local strong = BOD.TradePolicy:Evaluate(base, { settings = settings, capitalLimits = limits })
expect(strong.actionable and strong.confidence == "STRONG", "strong commodity trade")
expect(strong.lowProfit > 0 and strong.normalProfit >= strong.lowProfit, "profit range")

local small = copy(base, { listingPurchaseQuantity = 10, listingCapitalRequired = 50000 })
local quickSmall = BOD.QuickMovePolicy:EvaluateAnalysis(small, { minimumExpectedProfitCopper = 1000, maximumQuickCapitalCopper = 100000, maximumQuickQuantity = 20 })
expect(quickSmall.actionable, "small liquid flip qualifies for quick move")
expect(BOD.TradePolicy:Evaluate(small, { settings = settings, capitalLimits = limits }).actionable, "same item qualifies as trade at another size")
local quickLarge = BOD.QuickMovePolicy:EvaluateAnalysis(base, { minimumExpectedProfitCopper = 1000, maximumQuickCapitalCopper = 100000, maximumQuickQuantity = 20 })
expect(not quickLarge.actionable and quickLarge.rejectionCode == "QUICK_POSITION_TOO_LARGE", "large position is trade only")
local quickOnly = copy(small, { observationCount = 3, observationDayCount = 2, demand = "UNKNOWN", confidence = "SPECULATIVE", stabilityRate = nil })
expect(BOD.QuickMovePolicy:EvaluateAnalysis(quickOnly, { minimumExpectedProfitCopper = 1000, maximumQuickCapitalCopper = 100000, maximumQuickQuantity = 20 }).actionable, "quick move can qualify without trade history")
expect(not BOD.TradePolicy:Evaluate(quickOnly, { settings = settings, capitalLimits = limits }).actionable, "weak history blocks trade")

expect(BOD.MarketAnalysis:ClassifyDemand({ observationCount = 10, dayCount = 6, typicalQuantity = 100, typicalListingCount = 10, stabilityRate = 0.10 }) == "HOT", "hot demand")
expect(BOD.MarketAnalysis:ClassifyDemand({ observationCount = 20, dayCount = 1, typicalQuantity = 100, typicalListingCount = 10, stabilityRate = 0.10 }) ~= "HOT", "one day cannot be hot")
expect(BOD.MarketAnalysis:ClassifyDemand({ observationCount = 5, dayCount = 3, typicalQuantity = 20, typicalListingCount = 4, stabilityRate = 0.30 }) == "ACTIVE", "active demand")
expect(BOD.MarketAnalysis:ClassifyDemand({ observationCount = 3, dayCount = 2, typicalQuantity = 2, typicalListingCount = 1, stabilityRate = 0.20 }) == "SLOW", "slow demand")
expect(BOD.MarketAnalysis:ClassifyDemand({ observationCount = 1, dayCount = 1 }) == "UNKNOWN", "unknown demand")

expect(not BOD.TradePolicy:Evaluate(copy(base, { demand = "SLOW" }), { settings = settings, capitalLimits = limits }).actionable, "illiquid high margin rejected")
expect(not BOD.TradePolicy:Evaluate(copy(base, { fastExitUnitPrice = 5100, normalExitUnitPrice = 5200, supportedMarketValue = 5200, discountRate = 0.038 }), { settings = settings, capitalLimits = limits }).actionable, "trivial absolute trade rejected")
expect(not BOD.TradePolicy:Evaluate(copy(base, { listingPurchaseQuantity = 100, listingCapitalRequired = 500000 }), { settings = settings, capitalLimits = limits }).actionable, "excessive exposure rejected")
expect(BOD.TradePolicy:Evaluate(copy(base, { discountRate = 0.70, stabilityRate = 0.80 }), { settings = settings, capitalLimits = limits }).rejectionCode == "PRICE_MAY_BE_MANIPULATED", "thin manipulation rejected")
expect(not BOD.TradePolicy:Evaluate(copy(base, { dataAgeSeconds = 43201 }), { settings = settings, capitalLimits = limits }).actionable, "stale data rejected")
expect(not BOD.TradePolicy:Evaluate(copy(base, { fastExitUnitPrice = 4900 }), { settings = settings, capitalLimits = limits }).actionable, "unsupported exit rejected")
expect(not BOD.TradePolicy:Evaluate(copy(base, { estimatedDepositPerListing = 2000 }), { settings = settings, capitalLimits = limits }).actionable, "relisting loss rejected")

local reduced, capacity = BOD.TradePolicy:SizePosition(copy(base, { ownedQuantity = 5, listingPurchaseQuantity = 20 }), limits, true)
expect(reduced == 20 and capacity < math.floor(limits.perTradeLimit / base.currentUnitPrice), "owned inventory reduces exposure capacity")
local eliminated = BOD.TradePolicy:Evaluate(copy(base, { ownedQuantity = 50 }), { settings = settings, capitalLimits = limits })
expect(not eliminated.actionable and eliminated.rejectionCode == "EXISTING_EXPOSURE_TOO_HIGH", "owned inventory eliminates purchase")

local safer = copy(strong, { itemName = "Safer", lowProfit = strong.lowProfit - 1, demand = "HOT", confidence = "STRONG", requiredCapital = strong.requiredCapital, stabilityRate = 0.05, ownedQuantity = 0 })
local bigger = copy(strong, { itemName = "Bigger", lowProfit = strong.lowProfit + 1000, demand = "ACTIVE", confidence = "FAIR", requiredCapital = strong.requiredCapital, stabilityRate = 0.20, ownedQuantity = 0 })
expect(BOD.TradePolicy:IsBetter(bigger, safer), "absolute low-case profit leads ranking")
local alpha = copy(strong, { itemName = "Alpha", lowProfit = 10000, normalProfit = 20000, requiredCapital = 100000, ownedQuantity = 0 })
local beta = copy(alpha, { itemName = "Beta" })
expect(BOD.TradePolicy:IsBetter(alpha, beta), "deterministic trade tie break")

local conservative = copy(settings, { riskMode = "CONSERVATIVE", minimumDemand = "HOT", minimumConfidence = "STRONG" })
expect(BOD.TradePolicy:Evaluate(base, { settings = conservative, capitalLimits = BOD.TradePolicy:GetCapitalLimits(2000000, 0, conservative) }).actionable, "conservative mode strong trade")
local aggressive = copy(settings, { riskMode = "AGGRESSIVE", minimumDemand = "SLOW", minimumConfidence = "SPECULATIVE", minimumObservationCount = 3, showSpeculativeTrades = true })
expect(not BOD.TradePolicy:Evaluate(copy(base, { currentUnitPrice = 0 }), { settings = aggressive, capitalLimits = limits }).actionable, "aggressive mode still rejects invalid trade")
local committedLimits = BOD.TradePolicy:GetCapitalLimits(1000000, 450000, settings)
expect(committedLimits.availableCapital == 0, "total committed capital enforced")

local recommendation = copy(base, strong)
recommendation.actionable = true
recommendation.maximumBuyUnitPrice = 6000
local tracked = assert(BOD.TradeTracker:Track(recommendation, 1000))
expect(tracked.state == "WATCHING" and #BOD.TradeTracker:GetOpenTrades() == 1, "explicit tracking")
expect(tracked.quantityPurchased == 0, "tracking is not a purchase")
assert(BOD.TradeTracker:AddPurchase(tracked.id, 10, 1000, 1100))
local afterSecond = assert(BOD.TradeTracker:AddPurchase(tracked.id, 10, 2000, 1200))
expect(afterSecond.averageUnitCost == 1500 and afterSecond.totalPurchaseCost == 30000, "weighted multiple-batch cost basis")
local partial = assert(BOD.TradeTracker:RecordSale(tracked.id, 10, 25000, nil, 1300))
expect(partial.quantityRemaining == 10 and partial.remainingCostBasis == 15000 and partial.realizedProfit == 10000, "partial sale and realized profit")
assert(BOD.TradeTracker:MarkListed(tracked.id, 1400))
local closed = assert(BOD.TradeTracker:Close(tracked.id, 1500))
expect(closed.state == "CLOSED" and #BOD.TradeTracker:GetHistory() == 1, "closed trade history")

local abandonedRecommendation = copy(recommendation, { itemKey = "item:abandoned", itemName = "Abandoned Test Item" })
local abandoned = assert(BOD.TradeTracker:Track(abandonedRecommendation, 1600))
assert(BOD.TradeTracker:Abandon(abandoned.id, 1700))
expect(abandoned.state == "ABANDONED" and #BOD.TradeTracker:GetHistory() == 2, "abandoned trade history")

local migrated = BOD.TradeTracker:Migrate({ nextTradeId = 9, openTrades = {}, closedTrades = {}, settings = { sentinel = true } })
expect(migrated.nextTradeId == 9 and migrated.settings.sentinel == true, "saved-variable migration preserves settings")

print("trade system: PASS")
