local BOD = {}
local chunk = assert(loadfile("RecommendationPolicy.lua"))
chunk("BankOfDurotar", BOD)

local function copy(source, changes)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    for key, value in pairs(changes or {}) do result[key] = value end
    return result
end

local function expect(value, label)
    if not value then error(label, 2) end
end

local base = {
    itemName = "Peacebloom",
    currentUnitPrice = 700,
    maximumSafeUnitPrice = 900,
    expectedNetProfit = 4000,
    conservativeNetProfit = 3000,
    purchaseQuantity = 5,
    capitalRequired = 3500,
    dataAgeSeconds = 3600,
    confidence = "HIGH",
    historyObservationCount = 6,
    historyDayCount = 4,
    listingCount = 10,
    sampleCount = 30,
    totalMarketQuantity = 20,
    ownedQuantity = 0,
    referenceUnitPrice = 1000,
    grossSale = 7500,
    estimatedDeposit = 100,
    expectedNetSale = 7100,
    vendorValue = 0,
}

local options = { minimumExpectedProfitCopper = 1000, maximumAgeSeconds = 86400 }
local strong = BOD.RecommendationPolicy:Evaluate(base, options)
expect(strong.actionable and strong.trustLabel == "STRONG", "strong label")

local fair = BOD.RecommendationPolicy:Evaluate(copy(base, {
    confidence = "MEDIUM", historyObservationCount = 3, historyDayCount = 2,
    listingCount = 4, conservativeNetProfit = 1500,
}), options)
expect(fair.actionable and fair.trustLabel == "FAIR", "fair label")

local speculative = BOD.RecommendationPolicy:Evaluate(copy(base, {
    confidence = "MEDIUM", historyObservationCount = 1, historyDayCount = 1,
}), options)
expect(speculative.actionable and speculative.trustLabel == "SPECULATIVE", "speculative label")
local aging = BOD.RecommendationPolicy:Evaluate(copy(base, { dataAgeSeconds = 14401 }), options)
expect(aging.actionable and aging.trustLabel == "SPECULATIVE" and aging.mainRiskCode == "CACHED_DATA_AGING", "aging cache lowers Plan confidence")

local negative = BOD.RecommendationPolicy:Evaluate(copy(base, { expectedNetProfit = -1 }), options)
expect(not negative.actionable and negative.rejectionCode == "NO_EXPECTED_PROFIT", "negative profit avoided")
local tiny = BOD.RecommendationPolicy:Evaluate(copy(base, { conservativeNetProfit = 999 }), options)
expect(not tiny.actionable and tiny.rejectionCode == "BELOW_MINIMUM_PROFIT", "small profit avoided")
local insufficient = BOD.RecommendationPolicy:Evaluate(copy(base, { confidence = "LOW" }), options)
expect(not insufficient.actionable and insufficient.rejectionCode == "INSUFFICIENT_DATA", "insufficient data avoided")
local relisting = BOD.RecommendationPolicy:Evaluate(copy(base, { conservativeNetProfit = 0 }), options)
expect(not relisting.actionable and relisting.rejectionCode == "RELISTING_ERASES_PROFIT", "relisting loss avoided")
local manipulated = BOD.RecommendationPolicy:Evaluate(copy(base, {
    currentUnitPrice = 100, historyObservationCount = 1,
}), options)
expect(not manipulated.actionable and manipulated.rejectionCode == "PRICE_MAY_BE_MANIPULATED", "manipulation avoided")
local owned = BOD.RecommendationPolicy:Evaluate(copy(base, { ownedQuantity = 5 }), options)
expect(not owned.actionable and owned.rejectionCode == "OWNED_EXPOSURE_REACHED", "owned exposure avoided")
local reduced = BOD.RecommendationPolicy:Evaluate(copy(base, {
    ownedQuantity = 2, supportsPartialPurchase = true,
}), options)
expect(reduced.actionable and reduced.recommendedPurchaseQuantity == 3, "owned quantity reduces a divisible purchase")
local malformed = BOD.RecommendationPolicy:Evaluate({ currentUnitPrice = "bad" }, options)
expect(not malformed.actionable and malformed.rejectionCode == "INVALID_DATA", "malformed input avoided")
local vendor = BOD.RecommendationPolicy:Evaluate(copy(base, { vendorValue = 7100 }), options)
expect(not vendor.actionable and vendor.rejectionCode == "VENDOR_VALUE_DOMINATES", "vendor floor avoided")

local depositRisk = BOD.RecommendationPolicy:Evaluate(copy(base, { estimatedDeposit = 800 }), options)
expect(depositRisk.actionable and depositRisk.mainRiskCode == "HIGH_DEPOSIT_COST", "deposit is primary risk")
local relistRisk = BOD.RecommendationPolicy:Evaluate(copy(base, { conservativeNetProfit = 1500 }), options)
expect(relistRisk.actionable and relistRisk.mainRiskCode == "PROFIT_DEPENDS_ON_RELISTING", "relisting is primary risk")

local rankedStrong = copy(base, { trustLabel = "STRONG" })
local rankedFair = copy(base, { trustLabel = "FAIR", conservativeNetProfit = 999999 })
expect(BOD.RecommendationPolicy:IsBetterOpportunity(rankedStrong, rankedFair), "trust outranks raw profit")
local alpha = copy(base, { trustLabel = "FAIR", itemName = "Alpha" })
local beta = copy(alpha, { itemName = "Beta" })
expect(BOD.RecommendationPolicy:IsBetterOpportunity(alpha, beta), "stable name tie break")
local unowned = copy(alpha, { itemName = "Unowned", ownedQuantity = 0 })
local partlyOwned = copy(alpha, { itemName = "Owned", ownedQuantity = 2 })
expect(BOD.RecommendationPolicy:IsBetterOpportunity(unowned, partlyOwned), "owned inventory lowers rank")
local efficient = copy(alpha, { itemName = "Efficient", capitalEfficiencyBps = 1800, conservativeNetProfit = 2000 })
local absoluteProfit = copy(alpha, { itemName = "Absolute", capitalEfficiencyBps = 900, conservativeNetProfit = 9000 })
expect(BOD.RecommendationPolicy:IsBetterOpportunity(efficient, absoluteProfit), "capital efficiency ranks equal-trust unowned buys")

local stale = BOD.RecommendationPolicy:CheckFreshness(
    { maximumSafeUnitPrice = 900, snapshotId = 1 },
    { lowestUnitBuyout = 700 },
    { id = 1, observationTimestamp = 1000 },
    1000 + 86401,
    86400
)
expect(not stale.safe and stale.state == "STALE", "stale data")
local changed = BOD.RecommendationPolicy:CheckFreshness(
    { maximumSafeUnitPrice = 900, snapshotId = 1 },
    { lowestUnitBuyout = 901 },
    { id = 2, observationTimestamp = 1000 },
    1100,
    86400
)
expect(not changed.safe and changed.state == "PRICE_CHANGED", "changed price")
local superseded = BOD.RecommendationPolicy:CheckFreshness(
    { maximumSafeUnitPrice = 900, snapshotId = 1 },
    { lowestUnitBuyout = 700 },
    { id = 2, observationTimestamp = 1000 },
    1100,
    86400
)
expect(superseded.safe and superseded.state == "UPDATED_SAFE", "new scan identifies superseded recommendation")

print("recommendation policy: PASS")
