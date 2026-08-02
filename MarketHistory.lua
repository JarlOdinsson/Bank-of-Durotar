local addonName, BOD = ...

BOD.MarketHistory = {}

local HISTORY_SCHEMA_VERSION = 3
local DAY_SECONDS = 86400
local RETENTION_DAYS = 30
local MAX_TRACKED_ITEMS = 1000
local MINIMUM_SAMPLE_COUNT = 6

-- Daily rows use numeric fields to keep SavedVariables small:
-- [1] scan count, [2] average median price, [3] average quantity, [4] average listings.
local SCANS, PRICE, QUANTITY, LISTINGS = 1, 2, 3, 4

local function now()
    if type(time) == "function" then return time() end
    return os.time()
end

local function dayKey(timestamp)
    return math.floor((tonumber(timestamp) or 0) / DAY_SECONDS)
end

local function realmKey()
    if BOD.MarketData and BOD.MarketData.GetRealmKey then return BOD.MarketData:GetRealmKey() end
    return "unknown-realm"
end

local function itemCount(items)
    local count = 0
    for _ in pairs(items or {}) do count = count + 1 end
    return count
end

local function ensureDB()
    if not BOD.db then BOD:InitializeDatabase() end
    BOD.db.history = type(BOD.db.history) == "table" and BOD.db.history or {}
    local db = BOD.db.history
    local currentRealm = realmKey()
    if db.schemaVersion ~= HISTORY_SCHEMA_VERSION or (db.realmKey and db.realmKey ~= currentRealm) then
        db.items = {}
        db.scanDays = {}
        db.totalScans = 0
        db.firstObservedAt = nil
        db.latestScanId = nil
    end
    db.schemaVersion = HISTORY_SCHEMA_VERSION
    db.realmKey = currentRealm
    db.items = type(db.items) == "table" and db.items or {}
    db.scanDays = type(db.scanDays) == "table" and db.scanDays or {}
    db.totalScans = math.max(0, math.floor(tonumber(db.totalScans) or 0))
    return db
end

local function validWholeNumber(value)
    local number = tonumber(value)
    return number and number == number and number >= 0 and number < math.huge and number == math.floor(number)
end

local function weightedMedian(samples)
    table.sort(samples, function(left, right) return left.value < right.value end)
    local totalWeight = 0
    for _, sample in ipairs(samples) do totalWeight = totalWeight + sample.weight end
    if totalWeight <= 0 then return nil end
    local threshold = math.floor((totalWeight + 1) / 2)
    local seen = 0
    for _, sample in ipairs(samples) do
        seen = seen + sample.weight
        if seen >= threshold then return sample.value end
    end
    return samples[#samples] and samples[#samples].value or nil
end

local function trimDays(days, referenceTime)
    local cutoff = dayKey(referenceTime) - RETENTION_DAYS + 1
    for key in pairs(days or {}) do
        local day = tonumber(key)
        if not day or day < cutoff then days[key] = nil end
    end
    return days
end

local function updateAverage(previousAverage, previousCount, value)
    return math.floor((((tonumber(previousAverage) or 0) * previousCount) + value) / (previousCount + 1))
end

local function validSnapshotItem(item)
    local samples = tonumber(item and item.sampleCount)
    return type(item) == "table"
        and validWholeNumber(item.medianUnitBuyout)
        and validWholeNumber(item.totalQuantity)
        and validWholeNumber(item.listingCount)
        and validWholeNumber(samples)
        and samples >= MINIMUM_SAMPLE_COUNT
end

function BOD.MarketHistory:RecordSnapshot(snapshot)
    if type(snapshot) ~= "table" or snapshot.complete ~= true or snapshot.scanCompletenessFlag ~= true
        or snapshot.realmKey ~= realmKey() or type(snapshot.items) ~= "table" or not snapshot.scanId
    then
        return false, "Snapshot is missing, incomplete, or belongs to another realm."
    end

    local db = ensureDB()
    if db.latestScanId == snapshot.scanId then return false, "Duplicate scan ID ignored." end

    local candidates = {}
    for itemKey, item in pairs(snapshot.items) do
        if validSnapshotItem(item) then candidates[#candidates + 1] = { itemKey = itemKey, item = item } end
    end
    table.sort(candidates, function(left, right)
        local leftSamples = tonumber(left.item.sampleCount) or 0
        local rightSamples = tonumber(right.item.sampleCount) or 0
        if leftSamples ~= rightSamples then return leftSamples > rightSamples end
        return tostring(left.itemKey) < tostring(right.itemKey)
    end)

    local observedAt = math.floor(tonumber(snapshot.observationTimestamp or snapshot.completedAt) or now())
    local currentDay = dayKey(observedAt)
    local nextItems = {}
    local limit = math.min(#candidates, MAX_TRACKED_ITEMS)
    for index = 1, limit do
        local candidate = candidates[index]
        local history = db.items[candidate.itemKey] or { days = {} }
        history.days = trimDays(type(history.days) == "table" and history.days or {}, observedAt)
        local key = tostring(currentDay)
        local row = history.days[key] or { 0, 0, 0, 0 }
        local count = math.max(0, math.floor(tonumber(row[SCANS]) or 0))
        row[PRICE] = updateAverage(row[PRICE], count, candidate.item.medianUnitBuyout)
        row[QUANTITY] = updateAverage(row[QUANTITY], count, candidate.item.totalQuantity)
        row[LISTINGS] = updateAverage(row[LISTINGS], count, candidate.item.listingCount)
        row[SCANS] = count + 1
        history.days[key] = row
        history.lastSeen = observedAt
        nextItems[candidate.itemKey] = history
    end
    db.items = nextItems

    trimDays(db.scanDays, observedAt)
    local scanDayKey = tostring(currentDay)
    db.scanDays[scanDayKey] = math.max(0, math.floor(tonumber(db.scanDays[scanDayKey]) or 0)) + 1
    db.totalScans = db.totalScans + 1
    db.firstObservedAt = tonumber(db.firstObservedAt) or observedAt
    db.latestObservedAt = observedAt
    db.latestScanId = snapshot.scanId
    return true, { recorded = limit, skipped = math.max(0, #candidates - limit) }
end

local function summarize(days, maxDays, referenceTime)
    local cutoff = dayKey(referenceTime) - maxDays + 1
    local prices, quantities, listings = {}, {}, {}
    local scanCount, dayCount = 0, 0
    local latestDay, latestRow
    for key, row in pairs(days or {}) do
        local day = tonumber(key)
        local scans = math.max(0, math.floor(tonumber(row[SCANS]) or 0))
        if day and day >= cutoff and scans > 0 then
            dayCount = dayCount + 1
            scanCount = scanCount + scans
            prices[#prices + 1] = { value = tonumber(row[PRICE]) or 0, weight = scans }
            quantities[#quantities + 1] = { value = tonumber(row[QUANTITY]) or 0, weight = scans }
            listings[#listings + 1] = { value = tonumber(row[LISTINGS]) or 0, weight = scans }
            if not latestDay or day > latestDay then latestDay, latestRow = day, row end
        end
    end
    return {
        observationCount = scanCount,
        dayCount = dayCount,
        median = weightedMedian(prices),
        typicalQuantity = weightedMedian(quantities),
        typicalListingCount = weightedMedian(listings),
        latestObservation = latestRow and {
            timestamp = latestDay * DAY_SECONDS,
            medianUnitBuyout = latestRow[PRICE],
            totalQuantity = latestRow[QUANTITY],
            listingCount = latestRow[LISTINGS],
        } or nil,
    }
end

function BOD.MarketHistory:Cleanup(referenceTime)
    local db = ensureDB()
    referenceTime = math.floor(tonumber(referenceTime) or now())
    local removed = 0
    for itemKey, history in pairs(db.items) do
        history.days = trimDays(type(history.days) == "table" and history.days or {}, referenceTime)
        if not next(history.days) then db.items[itemKey] = nil; removed = removed + 1 end
    end
    trimDays(db.scanDays, referenceTime)
    db.lastCleanupAt = referenceTime
    db.lastCleanup = { timestamp = referenceTime, removed = removed, complete = true }
    return db.lastCleanup
end

function BOD.MarketHistory:GetItemHistory(itemKey)
    return ensureDB().items[itemKey]
end

function BOD.MarketHistory:GetLatestObservation(itemKey)
    local summary = self:GetSummary(itemKey)
    return summary.latestObservation
end

function BOD.MarketHistory:GetSummary(itemKey)
    local history = self:GetItemHistory(itemKey)
    local referenceTime = now()
    local thirtyDay = summarize(history and history.days, 30, referenceTime)
    local sevenDay = summarize(history and history.days, 7, referenceTime)
    local latest = thirtyDay.latestObservation
    return {
        available = thirtyDay.observationCount > 0,
        latestObservation = latest,
        observationCount = thirtyDay.observationCount,
        dayCount = thirtyDay.dayCount,
        sevenDay = sevenDay,
        thirtyDay = thirtyDay,
        dataAgeSeconds = latest and math.max(0, referenceTime - latest.timestamp) or nil,
    }
end

function BOD.MarketHistory:GetLearningStatus()
    local db = ensureDB()
    local days = 0
    for _ in pairs(db.scanDays) do days = days + 1 end
    return {
        totalScans = db.totalScans,
        daysObserved = days,
        trackedItems = itemCount(db.items),
        ready = db.totalScans >= 2,
        mature = days >= 3 and db.totalScans >= 5,
    }
end
