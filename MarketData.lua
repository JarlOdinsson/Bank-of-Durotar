local addonName, BOD = ...

BOD.MarketData = {
    activeSnapshot = nil,
}

local MARKET_DATA_SCHEMA_VERSION = 3
local MAX_SAFE_INTEGER = 2147483647

local function now()
    if type(time) == "function" then
        return time()
    end
    return os.time()
end

local function ensureDB()
    if not BOD.db then
        BOD:InitializeDatabase()
    end

    BOD.db.marketData = BOD.db.marketData or {}
    BOD.db.marketData.schemaVersion = MARKET_DATA_SCHEMA_VERSION
    BOD.db.marketData.latestSnapshotID = BOD.db.marketData.latestSnapshotID or nil
    BOD.db.marketData.currentSnapshot = BOD.db.marketData.currentSnapshot or nil
    BOD.db.marketData.currentByRealm = nil
    BOD.db.marketData.realmOrder = nil
    if type(BOD.db.marketData.currentSnapshot) ~= "table" then
        BOD.db.marketData.latestSnapshotID = nil
    end
    BOD.db.marketData.snapshots = nil
    BOD.db.marketData.maxSnapshots = nil
    return BOD.db.marketData
end

local function isWholeNumber(value)
    local number = tonumber(value)
    return number
        and number == number
        and number >= 0
        and number < math.huge
        and number <= MAX_SAFE_INTEGER
        and number == math.floor(number)
end

local function toWholeNumber(value)
    if not isWholeNumber(value) then
        return nil
    end
    return tonumber(value)
end

local function getItemString(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end
    return itemLink:match("Hitem:([^|%]]+)")
end

local function getRealmKey()
    local realm = type(GetRealmName) == "function" and GetRealmName() or "unknown-realm"
    local faction = type(UnitFactionGroup) == "function" and UnitFactionGroup("player") or "unknown-faction"
    local project = tostring(WOW_PROJECT_ID or "unknown-project")
    realm = tostring(realm or "unknown-realm"):gsub("%s+", "_")
    faction = tostring(faction or "unknown-faction")
    return project .. ":" .. realm .. ":" .. faction
end

local function getItemIdentity(result)
    local itemString = getItemString(result.itemLink)
    local itemID = toWholeNumber(result.itemID) or (itemString and tonumber(itemString:match("^(%d+)")))
    if itemID and itemID > 0 and tonumber(result.maxStack) and tonumber(result.maxStack) > 1 then
        return "item:" .. tostring(itemID), itemID, itemString
    end
    if itemString then
        return "itemString:" .. itemString, itemID, itemString
    end

    -- A missing link is safe only for known stackable items. Treating equipment by
    -- item ID would merge enchants, suffixes, and other variants into fake prices.
    if itemID and itemID > 0 and tonumber(result.maxStack) and tonumber(result.maxStack) > 1 then
        return "item:" .. tostring(itemID), itemID, nil
    end
    return nil, nil, nil
end

local function median(values)
    table.sort(values)
    local count = #values
    if count == 0 then
        return nil
    end
    local middle = math.floor((count + 1) / 2)
    if count % 2 == 1 then
        return values[middle]
    end
    return math.floor((values[middle] + values[middle + 1]) / 2)
end

local function weightedMedian(samples)
    table.sort(samples, function(left, right)
        if left.price == right.price then
            return left.quantity < right.quantity
        end
        return left.price < right.price
    end)

    local totalQuantity = 0
    for _, sample in ipairs(samples) do
        totalQuantity = totalQuantity + sample.quantity
    end
    if totalQuantity <= 0 then
        return nil
    end

    local threshold = math.floor((totalQuantity + 1) / 2)
    local seenQuantity = 0
    for _, sample in ipairs(samples) do
        seenQuantity = seenQuantity + sample.quantity
        if seenQuantity >= threshold then
            return sample.price
        end
    end
    return samples[#samples] and samples[#samples].price or nil
end

local function compactItem(key, aggregate)
    return {
        itemKey = key,
        itemID = aggregate.itemID,
        itemName = aggregate.itemName,
        lowestUnitBuyout = aggregate.lowestUnitBuyout,
        bestListingStackCount = aggregate.bestListingStackCount or 0,
        bestListingBuyoutTotal = aggregate.bestListingBuyoutTotal or 0,
        medianUnitBuyout = median(aggregate.unitBuyouts or {}),
        weightedMedianUnitBuyout = weightedMedian(aggregate.weightedUnitBuyouts or {}),
        totalQuantity = aggregate.totalQuantity or 0,
        listingCount = aggregate.listingCount or 0,
        sampleCount = aggregate.sampleCount or 0,
        vendorPrice = aggregate.vendorPrice or 0,
        maxStack = aggregate.maxStack or 1,
        equipSlot = aggregate.equipSlot,
    }
end

function BOD.MarketData:GetRealmKey()
    return getRealmKey()
end

function BOD.MarketData:StartSnapshot(metadata)
    self.activeSnapshot = {
        id = tostring(now()) .. "-" .. tostring(math.random(1000, 9999)),
        startedAt = now(),
        source = "full-scan-probe",
        metadata = metadata or {},
        items = {},
        acceptedRecords = 0,
        rejectedRecords = 0,
        rejected = {
            missingIdentity = 0,
            invalidStack = 0,
            invalidBuyout = 0,
            invalidNumeric = 0,
            overflowRisk = 0,
        },
    }
end

function BOD.MarketData:ObserveListing(result)
    if not self.activeSnapshot or not result then
        return
    end

    local key, itemID, itemString = getItemIdentity(result)
    if not key then
        self.activeSnapshot.rejected.missingIdentity = self.activeSnapshot.rejected.missingIdentity + 1
        self.activeSnapshot.rejectedRecords = self.activeSnapshot.rejectedRecords + 1
        return
    end

    local stackCount = toWholeNumber(result.stackCount)
    local buyoutTotal = toWholeNumber(result.buyoutTotal)
    if not stackCount or not buyoutTotal then
        local rawStack = tonumber(result.stackCount)
        local rawBuyout = tonumber(result.buyoutTotal)
        if (rawStack and rawStack > MAX_SAFE_INTEGER) or (rawBuyout and rawBuyout > MAX_SAFE_INTEGER) then
            self.activeSnapshot.rejected.overflowRisk = self.activeSnapshot.rejected.overflowRisk + 1
        else
            self.activeSnapshot.rejected.invalidNumeric = self.activeSnapshot.rejected.invalidNumeric + 1
        end
        self.activeSnapshot.rejectedRecords = self.activeSnapshot.rejectedRecords + 1
        return
    end
    if stackCount <= 0 then
        self.activeSnapshot.rejected.invalidStack = self.activeSnapshot.rejected.invalidStack + 1
        self.activeSnapshot.rejectedRecords = self.activeSnapshot.rejectedRecords + 1
        return
    end
    if buyoutTotal <= 0 then
        self.activeSnapshot.rejected.invalidBuyout = self.activeSnapshot.rejected.invalidBuyout + 1
        self.activeSnapshot.rejectedRecords = self.activeSnapshot.rejectedRecords + 1
        return
    end

    local unitBuyout = math.floor(buyoutTotal / stackCount)
    if unitBuyout <= 0 then
        self.activeSnapshot.rejected.invalidBuyout = self.activeSnapshot.rejected.invalidBuyout + 1
        self.activeSnapshot.rejectedRecords = self.activeSnapshot.rejectedRecords + 1
        return
    end

    local aggregate = self.activeSnapshot.items[key]
    if not aggregate then
        aggregate = {
            itemID = itemID or result.itemID,
            itemName = result.name or tostring(key),
            itemLink = result.itemLink,
            itemString = itemString,
            quality = result.quality,
            vendorPrice = tonumber(result.vendorPrice) or 0,
            maxStack = tonumber(result.maxStack) or 1,
            equipSlot = result.equipSlot,
            observationTimestamp = now(),
            lowestUnitBuyout = unitBuyout,
            lowestPriceQuantity = 0,
            lowestPriceListingCount = 0,
            lowestPriceCapital = 0,
            bestListingStackCount = 0,
            bestListingBuyoutTotal = 0,
            highestRelevantUnitBuyout = unitBuyout,
            listingCount = 0,
            totalQuantity = 0,
            sampleCount = 0,
            unitBuyouts = {},
            weightedUnitBuyouts = {},
            priceLevels = {},
        }
        self.activeSnapshot.items[key] = aggregate
    end

    aggregate.itemID = aggregate.itemID or itemID or result.itemID
    aggregate.itemName = aggregate.itemName or result.name or tostring(key)
    aggregate.itemLink = aggregate.itemLink or result.itemLink
    aggregate.itemString = aggregate.itemString or itemString
    aggregate.quality = aggregate.quality or result.quality
    aggregate.vendorPrice = math.max(tonumber(aggregate.vendorPrice) or 0, tonumber(result.vendorPrice) or 0)
    aggregate.maxStack = math.max(tonumber(aggregate.maxStack) or 1, tonumber(result.maxStack) or 1)
    aggregate.equipSlot = aggregate.equipSlot or result.equipSlot
    aggregate.observationTimestamp = now()
    local previousLowest = aggregate.lowestUnitBuyout
    if not previousLowest or unitBuyout < previousLowest then
        aggregate.lowestUnitBuyout = unitBuyout
        aggregate.lowestPriceQuantity = stackCount
        aggregate.lowestPriceListingCount = 1
        aggregate.lowestPriceCapital = buyoutTotal
        aggregate.bestListingStackCount = stackCount
        aggregate.bestListingBuyoutTotal = buyoutTotal
    elseif unitBuyout == previousLowest then
        aggregate.lowestPriceQuantity = (aggregate.lowestPriceQuantity or 0) + stackCount
        aggregate.lowestPriceListingCount = (aggregate.lowestPriceListingCount or 0) + 1
        aggregate.lowestPriceCapital = (aggregate.lowestPriceCapital or 0) + buyoutTotal
        if not aggregate.bestListingBuyoutTotal or aggregate.bestListingBuyoutTotal <= 0 or buyoutTotal < aggregate.bestListingBuyoutTotal then
            aggregate.bestListingStackCount = stackCount
            aggregate.bestListingBuyoutTotal = buyoutTotal
        end
    end
    aggregate.highestRelevantUnitBuyout = math.max(aggregate.highestRelevantUnitBuyout or unitBuyout, unitBuyout)
    aggregate.listingCount = aggregate.listingCount + 1
    aggregate.totalQuantity = aggregate.totalQuantity + stackCount
    aggregate.sampleCount = aggregate.sampleCount + 1
    aggregate.unitBuyouts[#aggregate.unitBuyouts + 1] = unitBuyout
    aggregate.weightedUnitBuyouts[#aggregate.weightedUnitBuyouts + 1] = {
        price = unitBuyout,
        quantity = stackCount,
    }
    aggregate.priceLevels[unitBuyout] = true
    self.activeSnapshot.acceptedRecords = self.activeSnapshot.acceptedRecords + 1
end

function BOD.MarketData:FinalizeSnapshot(scanSummary)
    if not self.activeSnapshot then
        return nil, "No active market snapshot."
    end
    if not scanSummary or scanSummary.state ~= "COMPLETED" then
        self:AbortSnapshot("Snapshot persistence requires a completed full scan.")
        return nil, "Snapshot persistence requires a completed full scan."
    end

    local snapshot = self.activeSnapshot
    local scanAuctionCount = tonumber(scanSummary.resultCount or scanSummary.processedRecords) or 0
    local items = {}
    local itemCount = 0
    for key, aggregate in pairs(snapshot.items) do
        items[key] = compactItem(key, aggregate)
        itemCount = itemCount + 1
    end

    local record = {
        schemaVersion = MARKET_DATA_SCHEMA_VERSION,
        id = snapshot.id,
        scanId = snapshot.id,
        realmKey = getRealmKey(),
        source = snapshot.source,
        startedAt = snapshot.startedAt,
        completedAt = now(),
        observationTimestamp = now(),
        scanAuctionCount = scanAuctionCount,
        auctionCount = scanAuctionCount,
        scanCompletenessFlag = true,
        complete = true,
        itemCount = itemCount,
        uniqueItemCount = itemCount,
        recordsAccepted = snapshot.acceptedRecords,
        recordsRejected = snapshot.rejectedRecords,
        rejected = snapshot.rejected,
        items = items,
        note = "Current compact aggregate snapshot only; raw auction listings and history are not persisted.",
    }
    local db = ensureDB()
    db.currentSnapshot = record
    db.latestSnapshotID = record.id

    self.activeSnapshot = nil
    return record, nil
end

function BOD.MarketData:AbortSnapshot(reason)
    self.activeSnapshot = nil
    BOD:Log("INFO", "MarketData", "Market snapshot aborted: " .. tostring(reason or "unknown"))
end

function BOD.MarketData:GetLatestSnapshot()
    local db = ensureDB()
    local snapshot = db.currentSnapshot
    if snapshot and snapshot.realmKey == getRealmKey() then
        return snapshot
    end
    return nil
end

function BOD.MarketData:GetSnapshotTimestamp()
    local snapshot = self:GetLatestSnapshot()
    return snapshot and tonumber(snapshot.observationTimestamp or snapshot.completedAt) or nil
end

function BOD.MarketData:IsSnapshotComplete()
    local snapshot = self:GetLatestSnapshot()
    return snapshot and snapshot.complete == true and snapshot.scanCompletenessFlag == true or false
end

function BOD.MarketData:GetCurrentItem(itemKey)
    local snapshot = self:GetLatestSnapshot()
    if type(itemKey) ~= "string" or itemKey == "" or not snapshot or type(snapshot.items) ~= "table" then
        return nil
    end
    return snapshot.items[itemKey]
end

function BOD.MarketData:GetCurrentItemByItemID(itemID)
    itemID = tonumber(itemID)
    local snapshot = self:GetLatestSnapshot()
    if not itemID or not snapshot or type(snapshot.items) ~= "table" then
        return nil
    end

    local match
    for _, item in pairs(snapshot.items) do
        if tonumber(item.itemID) == itemID then
            if match then
                return nil, "ambiguous"
            end
            match = item
        end
    end
    return match
end

function BOD.MarketData:GetBestCurrentItemByItemID(itemID)
    itemID = tonumber(itemID)
    local snapshot = self:GetLatestSnapshot()
    if not itemID or not snapshot or type(snapshot.items) ~= "table" then return nil end

    local best
    for _, item in pairs(snapshot.items) do
        if tonumber(item.itemID) == itemID then
            local samples = tonumber(item.sampleCount) or 0
            local bestSamples = tonumber(best and best.sampleCount) or -1
            if not best or samples > bestSamples then best = item end
        end
    end
    return best
end

function BOD.MarketData:FindItemByName(itemName)
    itemName = type(itemName) == "string" and itemName:lower() or ""
    local snapshot = self:GetLatestSnapshot()
    if itemName == "" or not snapshot or type(snapshot.items) ~= "table" then
        return nil
    end

    local exactMatch
    local partialMatch
    for itemKey, item in pairs(snapshot.items) do
        local name = tostring(item.itemName or item.name or ""):lower()
        if name == itemName then
            exactMatch = item
            exactMatch.itemKey = exactMatch.itemKey or itemKey
            break
        elseif not partialMatch and name:find(itemName, 1, true) then
            partialMatch = item
            partialMatch.itemKey = partialMatch.itemKey or itemKey
        end
    end
    return exactMatch or partialMatch
end

function BOD.MarketData:FindExactItemByName(itemName)
    itemName = type(itemName) == "string" and itemName:lower() or ""
    local snapshot = self:GetLatestSnapshot()
    if itemName == "" or not snapshot or type(snapshot.items) ~= "table" then return nil end
    local match
    for itemKey, item in pairs(snapshot.items) do
        if tostring(item.itemName or item.name or ""):lower() == itemName then
            if match then return nil end
            item.itemKey = item.itemKey or itemKey
            match = item
        end
    end
    return match
end

function BOD.MarketData:FindItemByText(value)
    value = type(value) == "string" and value or ""
    local itemString = value:match("Hitem:([^|%]]+)")
    if itemString then
        local exact = self:GetCurrentItem("itemString:" .. itemString)
        if exact then
            return exact
        end
    end

    local linkedName = value:match("%[([^%]]+)%]")
    return self:FindItemByName(linkedName or value)
end
