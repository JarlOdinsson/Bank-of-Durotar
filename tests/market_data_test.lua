local BOD = {
    db = {
        marketData = {},
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

local currentTime = 1700000000
function time()
    currentTime = currentTime + 1
    return currentTime
end

local chunk = assert(loadfile("MarketData.lua"))
chunk("BankOfDurotar", BOD)

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
    resultCount = 10,
    processedRecords = 10,
}))
local item = snapshot.items["item:2589"]
local variant = snapshot.items["itemString:1000:15:0:0:0:0:0:0::::"]

assertTruthy(item, "aggregated item")
assertTruthy(variant, "variant item")
assertEquals(snapshot.schemaVersion, 3, "schema version")
assertEquals(snapshot.realmKey, "5:Test_Realm:Horde", "realm key")
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
assertEquals(variant.lowestUnitBuyout, 500, "variant separated")

BOD.MarketData:StartSnapshot({ test = "failed" })
BOD.MarketData:ObserveListing({ itemID = 999, name = "Failed Scan Item", stackCount = 1, buyoutTotal = 100 })
local failedSnapshot, failure = BOD.MarketData:FinalizeSnapshot({ state = "FAILED", resultCount = 1 })
assertEquals(failedSnapshot, nil, "failed scan not persisted")
assertTruthy(failure, "failed scan reason")
assertEquals(BOD.db.marketData.currentSnapshot.id, snapshot.id, "failed scan leaves previous current snapshot")

BOD.MarketData:StartSnapshot({ test = "replacement" })
BOD.MarketData:ObserveListing({ itemID = 765, name = "Silverleaf", stackCount = 1, buyoutTotal = 25, maxStack = 20 })
local replacement = assert(BOD.MarketData:FinalizeSnapshot({ state = "COMPLETED", resultCount = 1 }))
assertEquals(BOD.db.marketData.currentSnapshot.id, replacement.id, "completed scan replaces current snapshot")
assertEquals(BOD.db.marketData.currentByRealm, nil, "no duplicated realm snapshot table")

print("market_data_test.lua: PASS")
