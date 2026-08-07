local BOD = {
    db = { settings = {} },
    MarketCache = { ClassifyAge = function() return "FRESH" end },
    MarketHistory = {
        GetSummary = function()
            return { observationCount = 8, dayCount = 5, sevenDay = { median = 120 }, thirtyDay = { median = 125 } }
        end,
    },
}

BOD.MarketAnalysis = {
    BuildSupportedValues = function()
        return { fastExitUnitPrice = 114, normalExitUnitPrice = 120 }
    end,
    Analyze = function()
        return {
            supportedMarketValue = 120,
            fastExitUnitPrice = 114,
            confidence = BOD.testConfidence or "FAIR",
            demand = "ACTIVE",
        }
    end,
}

function time() return 2000 end

local chunk = assert(loadfile("AcquisitionEvaluator.lua"))
chunk("BankOfDurotar", BOD)

local item = {
    itemID = 1,
    itemName = "Test Cloth",
    medianUnitBuyout = 120,
    weightedMedianUnitBuyout = 118,
    acquisitionGroups = {
        { stackSize = 10, buyoutTotal = 1500, listingCount = 2 },
        { stackSize = 3, buyoutTotal = 270, listingCount = 1 },
        { stackSize = 5, buyoutTotal = 400, listingCount = 1 },
    },
}
local snapshot = { id = "scan", completedAt = 1900, observationTimestamp = 1900 }

local result = BOD.AcquisitionEvaluator:EvaluateItem("item:1", item, snapshot, {
    targetQuantity = 8,
    budgetCopper = 1000,
    context = { ownedQuantities = { ["item:1"] = 7 } },
})
assert(result.status == "RECOMMENDED", "supported target should be recommended")
assert(result.purchaseQuantity == 8 and result.capitalRequired == 670, "whole-stack target uses cheapest combination")
assert(result.averageUnitCost == 83, "cumulative weighted average uses exact totals")
assert(result.safeCeiling == 96, "safe ceiling uses conservative exit friction")
assert(result.cliffGroupIndex == 3 and result.cliffUnitPrice == 150, "unsafe 20 percent jump marks cliff")
assert(result.ownedQuantity == 7, "owned quantity stays separate from additional buy target")

local constrained = BOD.AcquisitionEvaluator:EvaluateItem("item:1", item, snapshot, {
    targetQuantity = 8,
    budgetCopper = 500,
})
assert(constrained.status == "TARGET_UNMET", "budget-limited target is explicit")
assert(constrained.purchaseQuantity == 5 and constrained.capitalRequired == 400, "budget fallback keeps only safe affordable stacks")

BOD.testConfidence = "SPECULATIVE"
local weak = BOD.AcquisitionEvaluator:EvaluateItem("item:1", item, snapshot, {})
assert(weak.status == "LOW_CONFIDENCE" and weak.actionable == false, "weak evidence never creates an aggressive recommendation")

local legacy = BOD.AcquisitionEvaluator:EvaluateItem("item:2", {
    itemID = 2, itemName = "Old Cache", medianUnitBuyout = 120, weightedMedianUnitBuyout = 118,
    bestListingStackCount = 2, bestListingBuyoutTotal = 160,
}, snapshot, {})
assert(legacy.legacyDepthFallback == true, "old snapshots remain readable with explicit depth warning")

print("acquisition_evaluator_test.lua: PASS")
