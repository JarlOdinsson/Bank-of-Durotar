local addonName, BOD = ...

BOD.AcquisitionEvaluator = {}

local MAX_SAFE_INTEGER = 2147483647
local MAX_OFFER_INSTANCES = 100
local MAX_TARGET_QUANTITY = 5000

local function wholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number > MAX_SAFE_INTEGER then return nil end
    return math.floor(number)
end

local function now()
    return type(time) == "function" and time() or os.time()
end

local function offerLess(left, right)
    local leftCost = left.buyoutTotal * right.stackSize
    local rightCost = right.buyoutTotal * left.stackSize
    if leftCost ~= rightCost then return leftCost < rightCost end
    if left.buyoutTotal ~= right.buyoutTotal then return left.buyoutTotal < right.buyoutTotal end
    return left.stackSize < right.stackSize
end

local function normalizedGroups(item)
    local groups = {}
    for _, source in ipairs(type(item.acquisitionGroups) == "table" and item.acquisitionGroups or {}) do
        local stackSize = wholeNumber(source.stackSize)
        local buyoutTotal = wholeNumber(source.buyoutTotal)
        local listingCount = wholeNumber(source.listingCount)
        if stackSize and stackSize > 0 and buyoutTotal and buyoutTotal > 0 and listingCount and listingCount > 0 then
            groups[#groups + 1] = {
                stackSize = stackSize,
                buyoutTotal = buyoutTotal,
                listingCount = math.min(listingCount, MAX_OFFER_INSTANCES),
                unitPrice = math.floor(buyoutTotal / stackSize),
            }
        end
    end
    if #groups == 0 then
        local stackSize = wholeNumber(item.bestListingStackCount)
        local buyoutTotal = wholeNumber(item.bestListingBuyoutTotal)
        if stackSize and stackSize > 0 and buyoutTotal and buyoutTotal > 0 then
            groups[1] = { stackSize = stackSize, buyoutTotal = buyoutTotal, listingCount = 1,
                unitPrice = math.floor(buyoutTotal / stackSize), legacyFallback = true }
        end
    end
    table.sort(groups, offerLess)
    return groups
end

local function expandOffers(groups)
    local offers = {}
    for groupIndex, group in ipairs(groups) do
        for _ = 1, group.listingCount do
            if #offers >= MAX_OFFER_INSTANCES then return offers end
            offers[#offers + 1] = {
                stackSize = group.stackSize,
                buyoutTotal = group.buyoutTotal,
                unitPrice = group.unitPrice,
                groupIndex = groupIndex,
            }
        end
    end
    return offers
end

local function supportedEvidence(itemKey, item, snapshot, context)
    local analysis = BOD.MarketAnalysis and BOD.MarketAnalysis:Analyze(itemKey, item, snapshot, context) or nil
    local history = BOD.MarketHistory and BOD.MarketHistory:GetSummary(itemKey) or nil
    local seven = history and history.sevenDay or nil
    local thirty = history and history.thirtyDay or nil
    local supported = BOD.MarketAnalysis and BOD.MarketAnalysis:BuildSupportedValues(
        item.medianUnitBuyout, item.weightedMedianUnitBuyout,
        seven and seven.median, thirty and thirty.median) or nil
    local fairValue = wholeNumber(analysis and analysis.supportedMarketValue)
        or wholeNumber(supported and supported.normalExitUnitPrice)
    local fastExit = wholeNumber(analysis and analysis.fastExitUnitPrice)
        or wholeNumber(supported and supported.fastExitUnitPrice)
    local confidence = analysis and analysis.confidence or "SPECULATIVE"
    return analysis, history, fairValue, fastExit, confidence
end

local function findCliff(groups, safeCeiling)
    for index = 1, #groups - 1 do
        local current = groups[index]
        local following = groups[index + 1]
        if following.unitPrice * 100 >= current.unitPrice * 120 and following.unitPrice > safeCeiling then
            return index + 1, following.unitPrice
        end
    end
end

local function selectGreedy(offers, safeCeiling, stopGroup, targetQuantity, budgetCopper, quantityCap)
    local selected, totalQuantity, totalCost = {}, 0, 0
    for index, offer in ipairs(offers) do
        local withinTarget = targetQuantity <= 0 or totalQuantity < targetQuantity
        local withinCap = not quantityCap or totalQuantity + offer.stackSize <= quantityCap
        local withinBudget = not budgetCopper or totalCost + offer.buyoutTotal <= budgetCopper
        if withinTarget and withinCap and withinBudget and offer.unitPrice <= safeCeiling
            and (not stopGroup or offer.groupIndex < stopGroup)
        then
            selected[#selected + 1] = index
            totalQuantity = totalQuantity + offer.stackSize
            totalCost = totalCost + offer.buyoutTotal
        end
    end
    return selected, totalQuantity, totalCost
end

-- Finds the cheapest whole-stack combination that reaches an explicit target.
-- Quantity is bounded, so this remains deterministic and cheap inside the UI.
local function selectForTarget(offers, safeCeiling, stopGroup, targetQuantity, budgetCopper, quantityCap)
    local candidates, maxStack = {}, 0
    for index, offer in ipairs(offers) do
        if offer.unitPrice <= safeCeiling and (not stopGroup or offer.groupIndex < stopGroup) then
            candidates[#candidates + 1] = { offerIndex = index, offer = offer }
            maxStack = math.max(maxStack, offer.stackSize)
        end
    end
    local maxQuantity = math.min(MAX_TARGET_QUANTITY, targetQuantity + math.max(0, maxStack - 1))
    if quantityCap then maxQuantity = math.min(maxQuantity, quantityCap) end
    local states = { [0] = { cost = 0, selected = {} } }
    for _, candidate in ipairs(candidates) do
        local nextStates = {}
        for quantity, state in pairs(states) do nextStates[quantity] = state end
        for quantity, state in pairs(states) do
            local newQuantity = quantity + candidate.offer.stackSize
            local newCost = state.cost + candidate.offer.buyoutTotal
            if newQuantity <= maxQuantity and (not budgetCopper or newCost <= budgetCopper) then
                local prior = nextStates[newQuantity]
                if not prior or newCost < prior.cost then
                    local selected = {}
                    for index, value in ipairs(state.selected) do selected[index] = value end
                    selected[#selected + 1] = candidate.offerIndex
                    nextStates[newQuantity] = { cost = newCost, selected = selected }
                end
            end
        end
        states = nextStates
    end
    local bestQuantity, best
    for quantity, state in pairs(states) do
        if quantity >= targetQuantity and (not best or state.cost < best.cost
            or (state.cost == best.cost and quantity < bestQuantity))
        then
            bestQuantity, best = quantity, state
        end
    end
    if best then return best.selected, bestQuantity, best.cost, true end
    local selected, quantity, cost = selectGreedy(offers, safeCeiling, stopGroup, 0, budgetCopper, quantityCap)
    return selected, quantity, cost, false
end

function BOD.AcquisitionEvaluator:EvaluateItem(itemKey, item, snapshot, options)
    options = type(options) == "table" and options or {}
    if type(itemKey) ~= "string" or itemKey == "" or type(item) ~= "table" or type(snapshot) ~= "table" then
        return { status = "INVALID_DATA", actionable = false }
    end
    local groups = normalizedGroups(item)
    local offers = expandOffers(groups)
    if #offers == 0 then return { status = "NO_LISTINGS", actionable = false, offerGroups = groups } end

    local context = type(options.context) == "table" and options.context or {}
    local analysis, history, fairValue, fastExit, confidence = supportedEvidence(itemKey, item, snapshot, context)
    if not fairValue or fairValue <= 0 or not fastExit or fastExit <= 0 then
        return { status = "UNSUPPORTED_VALUE", actionable = false, offerGroups = groups, allOffers = offers }
    end
    local safeCeiling = math.max(0, math.floor(fastExit * 95 / 100) - math.floor(fairValue * 10 / 100))
    local cliffGroup, cliffUnitPrice = findCliff(groups, safeCeiling)
    local targetQuantity = math.min(MAX_TARGET_QUANTITY, wholeNumber(options.targetQuantity) or 0)
    local budgetCopper = wholeNumber(options.budgetCopper)
    if not budgetCopper or budgetCopper <= 0 then budgetCopper = nil end
    local quantityCap = wholeNumber(options.quantityCap)
    if not quantityCap or quantityCap <= 0 then quantityCap = nil end

    local selected, quantity, cost, targetMet
    if targetQuantity > 0 then
        selected, quantity, cost, targetMet = selectForTarget(offers, safeCeiling, cliffGroup,
            targetQuantity, budgetCopper, quantityCap)
    else
        selected, quantity, cost = selectGreedy(offers, safeCeiling, cliffGroup, 0, budgetCopper, quantityCap)
        targetMet = true
    end
    local selectedOffers, selectedCounts, steps = {}, {}, {}
    local cumulativeQuantity, cumulativeCost = 0, 0
    for _, offerIndex in ipairs(selected) do
        local offer = offers[offerIndex]
        selectedOffers[#selectedOffers + 1] = offer
        selectedCounts[offer.groupIndex] = (selectedCounts[offer.groupIndex] or 0) + 1
        cumulativeQuantity = cumulativeQuantity + offer.stackSize
        cumulativeCost = cumulativeCost + offer.buyoutTotal
        steps[#steps + 1] = { quantity = cumulativeQuantity, cost = cumulativeCost,
            averageUnitCost = math.floor(cumulativeCost / cumulativeQuantity) }
    end
    local average = quantity > 0 and math.floor(cost / quantity) or 0
    local conservativeUnitValue = math.floor(fastExit * 95 / 100)
    local conservativeNetSale = conservativeUnitValue * quantity
    local conservativeProfit = math.max(0, conservativeNetSale - cost)
    local marginBps = cost > 0 and math.floor(conservativeProfit * 10000 / cost) or 0
    local confidenceWeight = confidence == "STRONG" and 100 or (confidence == "FAIR" and 75 or 40)
    local depthWeight = quantity > 0 and math.min(100, 25 + math.floor(math.min(quantity, 20) * 75 / 20)) or 0
    local capitalEfficiencyBps = math.floor(marginBps * confidenceWeight * depthWeight / 10000)
    local age = math.max(0, (wholeNumber(options.now) or now())
        - (wholeNumber(snapshot.observationTimestamp or snapshot.completedAt) or 0))
    local lowConfidence = confidence ~= "STRONG" and confidence ~= "FAIR"
    local status = quantity <= 0 and "NO_SAFE_OFFERS"
        or (targetQuantity > 0 and not targetMet and "TARGET_UNMET")
        or (lowConfidence and "LOW_CONFIDENCE") or "RECOMMENDED"

    return {
        status = status,
        actionable = quantity > 0 and not lowConfidence,
        itemKey = itemKey,
        itemID = item.itemID,
        itemName = item.itemName or item.name or itemKey,
        exactIdentity = itemKey,
        offerGroups = groups,
        allOffers = offers,
        selectedOffers = selectedOffers,
        selectedCounts = selectedCounts,
        cumulativeSteps = steps,
        purchaseQuantity = quantity,
        capitalRequired = cost,
        averageUnitCost = average,
        targetQuantity = targetQuantity,
        targetMet = targetMet,
        budgetCopper = budgetCopper,
        fairValue = fairValue,
        historicalValue = wholeNumber(history and history.sevenDay and history.sevenDay.median),
        fastExitUnitPrice = fastExit,
        conservativeUnitValue = conservativeUnitValue,
        conservativeNetSale = conservativeNetSale,
        conservativeProfit = conservativeProfit,
        safeCeiling = safeCeiling,
        cliffGroupIndex = cliffGroup,
        cliffUnitPrice = cliffUnitPrice,
        nextOffer = cliffGroup and groups[cliffGroup] or groups[#groups + 1],
        confidence = confidence,
        demand = analysis and analysis.demand or "UNKNOWN",
        discountBps = fairValue > 0 and math.floor(math.max(0, fairValue - average) * 10000 / fairValue) or 0,
        marginBps = marginBps,
        confidenceWeight = confidenceWeight,
        depthWeight = depthWeight,
        capitalEfficiencyBps = capitalEfficiencyBps,
        ownedQuantity = wholeNumber(context.ownedQuantities and context.ownedQuantities[itemKey]) or 0,
        dataAgeSeconds = age,
        freshnessLabel = BOD.MarketCache and BOD.MarketCache:ClassifyAge(age, BOD.db and BOD.db.settings) or nil,
        snapshotId = snapshot.scanId or snapshot.id,
        legacyDepthFallback = groups[1] and groups[1].legacyFallback == true or false,
    }
end
