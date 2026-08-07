local BOD = {
    db = {
        marketData = {},
        settings = { reuseLastCompletedScan = true, retainLatestSnapshotPerMarketScope = true },
    },
}

function BOD:InitializeDatabase()
    self.db = self.db or {}
    self.db.marketData = self.db.marketData or {}
end

function BOD:Log()
end

function BOD:FormatTimestamp(timestamp)
    return tostring(timestamp)
end

WOW_PROJECT_ID = 5
function GetRealmName()
    return "Test Realm"
end
function UnitFactionGroup()
    return "Horde"
end
function GetCurrentRegion()
    return 1
end

local currentTime = 1700000000
function time()
    currentTime = currentTime + 1
    return currentTime
end

local cacheChunk = assert(loadfile("MarketCache.lua"))
cacheChunk("BankOfDurotar", BOD)
local marketChunk = assert(loadfile("MarketData.lua"))
marketChunk("BankOfDurotar", BOD)

local function assertEquals(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, label)
    if not value then
        error(label .. ": expected truthy value", 2)
    end
end

BOD.MarketData:StartSnapshot({ test = "aggregation" })
BOD.MarketData:ObserveListing({
    itemID = 2589,
    name = "Linen Cloth",
    itemLink = "|cffffffff|Hitem:2589:0:0:0:0:0:0:0::::|h[Linen Cloth]|h|r",
    stackCount = 2,
    buyoutTotal = 200,
    maxStack = 20,
    vendorPrice = 13,
})
BOD.MarketData:ObserveListing({
    itemID = 2589,
    name = "Linen Cloth",
    itemLink = "|cffffffff|Hitem:2589:0:0:0:0:0:0:0::::|h[Linen Cloth]|h|r",
    stackCount = 3,
    buyoutTotal = 600,
    maxStack = 20,
    vendorPrice = 13,
})
BOD.MarketData:ObserveListing({
    itemID = 2589,
    name = "Linen Cloth",
    itemLink = "|cffffffff|Hitem:2589:0:0:0:0:0:0:0::::|h[Linen Cloth]|h|r",
    stackCount = 1,
    buyoutTotal = 150,
    maxStack = 20,
    vendorPrice = 13,
})
BOD.MarketData:ObserveListing({
    itemID = 1000,
    name = "Equipment Variant",
    itemLink = "|cff1eff00|Hitem:1000:15:0:0:0:0:0:0::::|h[Equipment Variant]|h|r",
    stackCount = 1,
    buyoutTotal = 500,
    maxStack = 1,
})
BOD.MarketData:ObserveListing({ name = "Missing Stack", stackCount = 0, buyoutTotal = 100 })
BOD.MarketData:ObserveListing({ name = "No Buyout", stackCount = 1, buyoutTotal = 0 })
BOD.MarketData:ObserveListing({ stackCount = 1, buyoutTotal = 100 })
BOD.MarketData:ObserveListing({ name = "Bad Numeric", stackCount = "bad", buyoutTotal = 100 })
BOD.MarketData:ObserveListing({ name = "Negative Buyout", stackCount = 1, buyoutTotal = -1 })
BOD.MarketData:ObserveListing({ name = "Overflow", stackCount = 1, buyoutTotal = 2147483648 })

local snapshot = assert(BOD.MarketData:FinalizeSnapshot({
    state = "COMPLETED",
    queryAccepted = true,
    resultCount = 10,
    processedRecords = 10,
}))
local item = snapshot.items["item:2589"]
local variant = snapshot.items["itemString:1000:15:0:0:0:0:0:0::::"]

assertTruthy(item, "aggregated item")
assertTruthy(variant, "variant item")
assertEquals(snapshot.schemaVersion, 4, "schema version")
assertEquals(snapshot.marketScopeKey, "5:1:Test_Realm:faction-Horde", "market scope key")
assertEquals(snapshot.scanCompletenessFlag, true, "scan completeness")
assertEquals(snapshot.scanAuctionCount, 10, "scan auction count")
assertEquals(snapshot.itemCount, 2, "snapshot item count")
assertEquals(snapshot.recordsAccepted, 4, "accepted records")
assertEquals(snapshot.recordsRejected, 6, "rejected records")
assertEquals(snapshot.rejected.invalidStack, 1, "invalid stack rejected")
assertEquals(snapshot.rejected.invalidBuyout, 2, "invalid buyout rejected")
assertEquals(snapshot.rejected.missingIdentity, 1, "missing identity rejected")
assertEquals(snapshot.rejected.invalidNumeric, 1, "invalid numeric rejected")
assertEquals(snapshot.rejected.overflowRisk, 1, "overflow rejected")
assertEquals(item.itemKey, "item:2589", "stackable item key")
assertEquals(item.itemName, "Linen Cloth", "item name")
assertEquals(item.lowestUnitBuyout, 100, "lowest unit buyout")
assertEquals(item.bestListingStackCount, 2, "best listing stack")
assertEquals(item.bestListingBuyoutTotal, 200, "best listing total")
assertEquals(item.medianUnitBuyout, 150, "median unit buyout")
assertEquals(item.weightedMedianUnitBuyout, 150, "weighted median unit buyout")
assertEquals(item.totalQuantity, 6, "total quantity")
assertEquals(item.listingCount, 3, "listing count")
assertEquals(item.sampleCount, 3, "sample count")
assertEquals(item.vendorPrice, 13, "vendor price")
assertEquals(#item.acquisitionGroups, 3, "bounded acquisition price groups")
assertEquals(item.acquisitionGroups[1].stackSize, 2, "acquisition groups sorted by unit price")
assertEquals(item.acquisitionGroups[1].buyoutTotal, 200, "acquisition group preserves exact stack total")
assertEquals(variant.lowestUnitBuyout, 500, "variant separated")

BOD.MarketData:StartSnapshot({ test = "failed" })
BOD.MarketData:ObserveListing({ itemID = 999, name = "Failed Scan Item", stackCount = 1, buyoutTotal = 100 })
local failedSnapshot, failure = BOD.MarketData:FinalizeSnapshot({ state = "FAILED", resultCount = 1 })
assertEquals(failedSnapshot, nil, "failed scan not persisted")
assertTruthy(failure, "failed scan reason")
assertEquals(BOD.MarketData:GetLatestSnapshot().id, snapshot.id, "failed scan leaves previous completed snapshot")

BOD.MarketData:StartSnapshot({ test = "replacement" })
BOD.MarketData:ObserveListing({ itemID = 765, name = "Silverleaf", stackCount = 1, buyoutTotal = 25, maxStack = 20 })
local replacement = assert(BOD.MarketData:FinalizeSnapshot({ state = "COMPLETED", queryAccepted = true, resultCount = 1, processedRecords = 1 }))
assertEquals(BOD.MarketData:GetLatestSnapshot().id, replacement.id, "completed scan replaces scoped snapshot")
assertEquals(BOD.db.marketData.currentByRealm, nil, "no duplicated realm snapshot table")

print("market_data_test.lua: PASS")
