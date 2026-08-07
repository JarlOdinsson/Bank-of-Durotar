local BOD = { db = { settings = {} } }
local chunk = assert(loadfile("MarketCache.lua"))
chunk("BankOfDurotar", BOD)

local function expect(value, label)
    if not value then error(label, 2) end
end

local function snapshot(id, scope, completedAt)
    return {
        schemaVersion = 4, id = id, scanId = id, marketScopeKey = scope,
        complete = true, scanCompletenessFlag = true, completedNormally = true,
        completedAt = completedAt, observationTimestamp = completedAt,
        auctionCount = 1, itemCount = 1, coverageStatus = "COMPLETE",
        items = { ["item:1"] = { itemKey = "item:1", itemID = 1, lowestUnitBuyout = 100, listingCount = 1, totalQuantity = 1 } },
    }
end

local alliance = BOD.MarketCache:GetScopeKey({ project = 2, region = 1, realm = "Test Realm", faction = "Alliance" })
local horde = BOD.MarketCache:GetScopeKey({ project = 2, region = 1, realm = "Test Realm", faction = "Horde" })
local otherRealm = BOD.MarketCache:GetScopeKey({ project = 2, region = 1, realm = "Other", faction = "Alliance" })
expect(alliance ~= horde and alliance ~= otherRealm, "market boundaries isolated")

local expected = {
    { 3599, "FRESH" }, { 3600, "RECENT" }, { 14400, "RECENT" }, { 14401, "AGING" },
    { 43200, "AGING" }, { 43201, "STALE" }, { 86400, "STALE" }, { 86401, "HISTORICAL_ONLY" },
}
for _, row in ipairs(expected) do expect(BOD.MarketCache:ClassifyAge(row[1]) == row[2], "freshness boundary " .. tostring(row[1])) end

local db = BOD.MarketCache:Migrate({}, alliance, "legacy")
expect(BOD.MarketCache:Get(db, alliance, {}) == nil, "no saved scan")
local first = snapshot("scan-1", alliance, 1000)
expect(BOD.MarketCache:Commit(db, first, alliance) == first, "valid completed scan committed")
expect(BOD.MarketCache:Get(db, alliance, {}) == first, "same scope loads")
expect(BOD.MarketCache:Get(db, horde, {}) == nil, "different faction blocked")
expect(BOD.MarketCache:Get(db, otherRealm, {}) == nil, "different realm blocked")
expect(BOD.MarketCache:Get(db, alliance, { reuseLastCompletedScan = false }) == nil, "reuse setting honored")

local interrupted = snapshot("scan-2", alliance, 2000)
interrupted.complete = false
expect(BOD.MarketCache:Commit(db, interrupted, alliance) == nil, "interrupted candidate rejected")
expect(BOD.MarketCache:Get(db, alliance, {}) == first, "interrupted scan preserves previous")
local corruptCandidate = snapshot("scan-3", alliance, 3000)
corruptCandidate.items["item:1"].listingCount = "bad"
expect(BOD.MarketCache:Commit(db, corruptCandidate, alliance) == nil, "invalid candidate rejected")
expect(BOD.MarketCache:Get(db, alliance, {}) == first, "invalid candidate preserves previous")

local reloaded = BOD.MarketCache:Migrate(db, alliance, "legacy")
expect(BOD.MarketCache:Get(reloaded, alliance, {}) == first, "snapshot survives reload migration")

local overlayItem = { itemKey = "item:1", lowestUnitBuyout = 90, listingCount = 2, totalQuantity = 4 }
local overlay = assert(BOD.MarketCache:RecordOverlay(db, alliance, "item:1", overlayItem, 4000, "scan-1"))
expect(BOD.MarketCache:GetOverlay(db, alliance, "item:1", 4010) == overlay, "targeted overlay loads")
expect(first.completedAt == 1000, "targeted overlay preserves full-scan timestamp")
expect(BOD.MarketCache:GetOverlay(db, alliance, "item:1", 4901) == nil, "targeted overlay expires")

for index = 1, 6 do
    local scope = "scope:" .. tostring(index)
    assert(BOD.MarketCache:Commit(db, snapshot("prune-" .. tostring(index), scope, 5000 + index), scope))
end
local limits = BOD.MarketCache:GetLimits()
expect(#db.scopeOrder <= limits.maxScopes, "snapshot scopes bounded")
local retained = 0
for _ in pairs(db.snapshotsByScope) do retained = retained + 1 end
expect(retained <= limits.maxScopes, "saved snapshot count bounded")

local oversized = snapshot("large-scan", alliance, 5500)
oversized.items = {}
for index = 1, limits.maxItemsPerSnapshot + 2 do
    oversized.items["item:" .. tostring(index)] = {
        itemKey = "item:" .. tostring(index), itemID = index, lowestUnitBuyout = 100,
        listingCount = 1, totalQuantity = 1, maxStack = 1,
    }
end
oversized.items["item:commodity"] = {
    itemKey = "item:commodity", itemID = 999999, lowestUnitBuyout = 100,
    listingCount = 1, totalQuantity = 1, maxStack = 20,
}
oversized.itemCount = limits.maxItemsPerSnapshot + 3
oversized.uniqueItemCount = oversized.itemCount
expect(BOD.MarketCache:Commit(db, oversized, alliance) == oversized, "oversized snapshot compacted and committed")
expect(oversized.itemCount == limits.maxItemsPerSnapshot, "snapshot item count bounded")
expect(oversized.observedItemCount == limits.maxItemsPerSnapshot + 3, "observed item count retained")
expect(oversized.items["item:commodity"] ~= nil, "stackable commodity retained first")
expect(oversized.coverageStatus == "BOUNDED_SUMMARY", "bounded cache coverage labeled")

local legacy = { currentSnapshot = snapshot("legacy-scan", "2:Test_Realm:Alliance", 6000) }
local migrated = BOD.MarketCache:Migrate(legacy, alliance, "2:Test_Realm:Alliance")
expect(BOD.MarketCache:Get(migrated, alliance, {}) ~= nil, "legacy current snapshot migrated to current scope")

local corruptDB = { snapshotsByScope = { [alliance] = { bad = true } }, scopeOrder = { alliance }, targetedByScope = {} }
expect(BOD.MarketCache:Get(corruptDB, alliance, {}) == nil and corruptDB.cacheLoadWarningPending == true, "corrupt cache recovered without fatal error")

print("market cache tests: PASS")
