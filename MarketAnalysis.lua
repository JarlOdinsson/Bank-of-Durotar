local addonName, BOD = ...

BOD.MarketAnalysis = {}

local DAY_SECONDS = 86400
local MAX_SAFE_INTEGER = 2147483647
local PRICE_INDEX = 1

local function wholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number > MAX_SAFE_INTEGER then return nil end
    return math.floor(number)
end

local function now()
    return type(time) == "function" and time() or os.time()
end

local function minimumPositive(...)
    local result
    for index = 1, select("#", ...) do
        local value = wholeNumber(select(index, ...))
        if value and value > 0 and (not result or value < result) then result = value end
    end
    return result
end

local function dailyStability(itemKey, referenceTime, supportedValue)
    local history = BOD.MarketHistory and BOD.MarketHistory:GetItemHistory(itemKey) or nil
    local cutoff = math.floor(referenceTime / DAY_SECONDS) - 6
    local low, high, count
    count = 0
    for key, row in pairs(history and history.days or {}) do
        local day = tonumber(key)
        local price = wholeNumber(type(row) == "table" and row[PRICE_INDEX])
        if day and day >= cutoff and price and price > 0 then
            low = not low and price or math.min(low, price)
            high = not high and price or math.max(high, price)
            count = count + 1
        end
    end
    if count < 2 or not supportedValue or supportedValue <= 0 then return nil, count end
    return math.max(0, (high - low) / supportedValue), count
end

function BOD.MarketAnalysis:BuildSupportedValues(currentMedian, weightedMedian, sevenDayMedian, thirtyDayMedian)
    local scanSupport = minimumPositive(currentMedian, weightedMedian)
    if not scanSupport then return nil end
    local normal = sevenDayMedian and sevenDayMedian > 0 and math.min(scanSupport, sevenDayMedian) or scanSupport
    local fast = math.max(1, math.floor(normal * 0.95))
    local optimistic = math.floor(normal * 1.03)
    if thirtyDayMedian and thirtyDayMedian > 0 then optimistic = math.min(optimistic, thirtyDayMedian) end
    optimistic = math.max(normal, optimistic)
    return {
        scanSupport = scanSupport,
        fastExitUnitPrice = fast,
        normalExitUnitPrice = normal,
        optimisticExitUnitPrice = optimistic,
    }
end

function BOD.MarketAnalysis:ClassifyDemand(evidence)
    evidence = type(evidence) == "table" and evidence or {}
    local observations = wholeNumber(evidence.observationCount) or 0
    local days = wholeNumber(evidence.dayCount) or 0
    local quantity = wholeNumber(evidence.typicalQuantity) or 0
    local listings = wholeNumber(evidence.typicalListingCount) or 0
    local stability = tonumber(evidence.stabilityRate)
    local outcomes = wholeNumber(evidence.personalOutcomeCount) or 0
    local saleRate = tonumber(evidence.personalSaleRate)
    local personalSupport = outcomes < 3 or (saleRate and saleRate >= 0.50)

    -- A single scan can never be Hot. These labels describe repeated local evidence,
    -- not server-wide sale volume or a promised holding time.
    if days >= 5 and observations >= 8 and quantity >= 20 and listings >= 5
        and stability and stability <= 0.25 and personalSupport
    then
        return "HOT"
    elseif days >= 3 and observations >= 4 and quantity >= 8 and listings >= 3
        and stability and stability <= 0.50 and personalSupport
    then
        return "ACTIVE"
    elseif observations >= 2 and (quantity < 5 or listings < 2 or (outcomes >= 3 and saleRate and saleRate < 0.35)) then
        return "SLOW"
    end
    return "UNKNOWN"
end

function BOD.MarketAnalysis:ClassifyConfidence(evidence)
    evidence = type(evidence) == "table" and evidence or {}
    local age = wholeNumber(evidence.dataAgeSeconds) or MAX_SAFE_INTEGER
    local observations = wholeNumber(evidence.observationCount) or 0
    local days = wholeNumber(evidence.dayCount) or 0
    local samples = wholeNumber(evidence.sampleCount) or 0
    local listings = wholeNumber(evidence.listingCount) or 0
    local stability = tonumber(evidence.stabilityRate)
    local demand = tostring(evidence.demand or "UNKNOWN"):upper()
    if age <= 21600 and observations >= 8 and days >= 5 and samples >= 20 and listings >= 5
        and stability and stability <= 0.25 and (demand == "HOT" or demand == "ACTIVE")
    then
        return "STRONG"
    elseif age <= 43200 and observations >= 4 and days >= 3 and samples >= 10 and listings >= 3
        and stability and stability <= 0.50 and demand ~= "UNKNOWN"
    then
        return "FAIR"
    end
    return "SPECULATIVE"
end

function BOD.MarketAnalysis:Analyze(itemKey, item, snapshot, context)
    context = type(context) == "table" and context or {}
    if type(itemKey) ~= "string" or itemKey == "" or type(item) ~= "table" or type(snapshot) ~= "table" then
        return nil, "INVALID_DATA"
    end
    local current = wholeNumber(item.lowestUnitBuyout)
    local currentMedian = wholeNumber(item.medianUnitBuyout)
    local weightedMedian = wholeNumber(item.weightedMedianUnitBuyout)
    local listingQuantity = wholeNumber(item.bestListingStackCount)
    local capitalRequired = wholeNumber(item.bestListingBuyoutTotal)
    if not current or current <= 0 or not currentMedian or currentMedian <= 0 or not listingQuantity
        or listingQuantity <= 0 or not capitalRequired or capitalRequired <= 0
    then
        return nil, "INVALID_DATA"
    end
    if (wholeNumber(item.maxStack) or 1) <= 1 then return nil, "NOT_COMMODITY" end

    local referenceTime = wholeNumber(context.now) or now()
    local observedAt = wholeNumber(snapshot.observationTimestamp or snapshot.completedAt)
    if not observedAt then return nil, "INVALID_DATA" end
    local age = math.max(0, referenceTime - observedAt)
    local history = BOD.MarketHistory and BOD.MarketHistory:GetSummary(itemKey) or nil
    local seven = history and history.sevenDay or nil
    local thirty = history and history.thirtyDay or nil
    local supported = self:BuildSupportedValues(currentMedian, weightedMedian, seven and seven.median, thirty and thirty.median)
    if not supported then return nil, "UNSUPPORTED_EXIT_PRICE" end
    local stabilityRate, stabilityDays = dailyStability(itemKey, referenceTime, supported.normalExitUnitPrice)
    local sales = BOD.SalesHistory and BOD.SalesHistory:GetSummary(itemKey, item.itemName or item.name) or { outcomeCount = 0 }
    local evidence = {
        observationCount = wholeNumber(history and history.observationCount) or 0,
        dayCount = wholeNumber(history and history.dayCount) or 0,
        typicalQuantity = wholeNumber(thirty and thirty.typicalQuantity) or 0,
        typicalListingCount = wholeNumber(thirty and thirty.typicalListingCount) or 0,
        stabilityRate = stabilityRate,
        personalOutcomeCount = wholeNumber(sales.outcomeCount) or 0,
        personalSaleRate = sales.saleRate,
    }
    local demand = self:ClassifyDemand(evidence)
    local confidence = self:ClassifyConfidence({
        dataAgeSeconds = age,
        observationCount = evidence.observationCount,
        dayCount = evidence.dayCount,
        sampleCount = wholeNumber(item.sampleCount) or 0,
        listingCount = wholeNumber(item.listingCount) or 0,
        stabilityRate = stabilityRate,
        demand = demand,
    })
    local owned = wholeNumber(context.ownedQuantities and context.ownedQuantities[itemKey]) or 0
    local economics = BOD.PricingService:GetSaleEconomics(itemKey, 1, supported.normalExitUnitPrice)
    local discountRate = supported.normalExitUnitPrice > 0 and math.max(0, (supported.normalExitUnitPrice - current) / supported.normalExitUnitPrice) or 0

    return {
        itemKey = itemKey,
        itemID = item.itemID,
        itemName = item.itemName or item.name or itemKey,
        currentUnitPrice = current,
        observedUnitPrice = current,
        listingPurchaseQuantity = listingQuantity,
        listingCapitalRequired = capitalRequired,
        totalMarketQuantity = wholeNumber(item.totalQuantity) or 0,
        listingCount = wholeNumber(item.listingCount) or 0,
        sampleCount = wholeNumber(item.sampleCount) or 0,
        supportedMarketValue = supported.normalExitUnitPrice,
        fastExitUnitPrice = supported.fastExitUnitPrice,
        normalExitUnitPrice = supported.normalExitUnitPrice,
        optimisticExitUnitPrice = supported.optimisticExitUnitPrice,
        discountRate = discountRate,
        estimatedDepositPerListing = wholeNumber(economics.deposit) or 0,
        vendorUnitPrice = wholeNumber(economics.vendorUnitPrice) or 0,
        ownedQuantity = owned,
        dataAgeSeconds = age,
        observationCount = evidence.observationCount,
        observationDayCount = evidence.dayCount,
        stabilityRate = stabilityRate,
        stabilityDayCount = stabilityDays,
        typicalQuantity = evidence.typicalQuantity,
        typicalListingCount = evidence.typicalListingCount,
        personalSales = sales,
        demand = demand,
        confidence = confidence,
        snapshotId = snapshot.scanId or snapshot.id,
        recommendationTimestamp = referenceTime,
    }
end
