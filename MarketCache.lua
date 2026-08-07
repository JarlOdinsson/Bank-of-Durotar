local addonName, BOD = ...

BOD.MarketCache = {
    validatedSnapshots = setmetatable({}, { __mode = "k" }),
}

local SCHEMA_VERSION = 4
local MAX_SCOPES = 4
local MAX_ITEMS_PER_SNAPSHOT = 2500
local MAX_OVERLAYS_PER_SCOPE = 100
local TARGETED_OVERLAY_MAX_AGE = 900
local DEFAULT_THRESHOLDS = { fresh = 3600, recent = 14400, aging = 43200, stale = 86400 }

local function now()
    return type(time) == "function" and time() or os.time()
end

local function whole(value)
    value = tonumber(value)
    if not value or value ~= value or value < 0 or value == math.huge then return nil end
    return math.floor(value)
end

local function clean(value, fallback)
    value = tostring(value or fallback or "unknown"):gsub("%s+", "_"):gsub(":", "_")
    return value ~= "" and value or tostring(fallback or "unknown")
end

function BOD.MarketCache:GetLegacyScopeKey(context)
    context = type(context) == "table" and context or {}
    local project = context.project or WOW_PROJECT_ID or "unknown-project"
    local realm = context.realm or (type(GetRealmName) == "function" and GetRealmName()) or "unknown-realm"
    local faction = context.faction or (type(UnitFactionGroup) == "function" and UnitFactionGroup("player")) or "unknown-faction"
    return clean(project) .. ":" .. clean(realm) .. ":" .. clean(faction)
end

function BOD.MarketCache:GetScopeKey(context)
    context = type(context) == "table" and context or {}
    local project = context.project or WOW_PROJECT_ID or "unknown-project"
    local region = context.region or (type(GetCurrentRegion) == "function" and GetCurrentRegion()) or "unknown-region"
    local realm = context.realm or (type(GetNormalizedRealmName) == "function" and GetNormalizedRealmName())
        or (type(GetRealmName) == "function" and GetRealmName()) or "unknown-realm"
    local faction = context.faction or (type(UnitFactionGroup) == "function" and UnitFactionGroup("player")) or "unknown-faction"
    local auctionScope = context.auctionScope or ("faction-" .. tostring(faction))
    return table.concat({ clean(project), clean(region), clean(realm), clean(auctionScope) }, ":")
end

function BOD.MarketCache:GetThresholds(settings)
    settings = type(settings) == "table" and settings or {}
    local fresh = whole(settings.marketFreshThresholdSeconds) or DEFAULT_THRESHOLDS.fresh
    local recent = math.max(fresh, whole(settings.marketRecentThresholdSeconds) or DEFAULT_THRESHOLDS.recent)
    local aging = math.max(recent, whole(settings.marketAgingThresholdSeconds) or DEFAULT_THRESHOLDS.aging)
    local stale = math.max(aging, whole(settings.marketStaleThresholdSeconds) or DEFAULT_THRESHOLDS.stale)
    return { fresh = fresh, recent = recent, aging = aging, stale = stale }
end

function BOD.MarketCache:ClassifyAge(ageSeconds, settings)
    ageSeconds = math.max(0, whole(ageSeconds) or 0)
    local limits = self:GetThresholds(settings)
    if ageSeconds < limits.fresh then return "FRESH" end
    if ageSeconds <= limits.recent then return "RECENT" end
    if ageSeconds <= limits.aging then return "AGING" end
    if ageSeconds <= limits.stale then return "STALE" end
    return "HISTORICAL_ONLY"
end

function BOD.MarketCache:FormatAge(ageSeconds)
    ageSeconds = math.max(0, whole(ageSeconds) or 0)
    if ageSeconds < 60 then return tostring(ageSeconds) .. "s ago" end
    local minutes = math.floor(ageSeconds / 60)
    if minutes < 60 then return tostring(minutes) .. "m ago" end
    local hours = math.floor(minutes / 60)
    local remainingMinutes = minutes % 60
    if hours < 24 then return tostring(hours) .. "h" .. (remainingMinutes > 0 and (" " .. tostring(remainingMinutes) .. "m") or "") .. " ago" end
    return tostring(math.floor(hours / 24)) .. "d " .. tostring(hours % 24) .. "h ago"
end

function BOD.MarketCache:ValidateSnapshot(snapshot, expectedScope)
    if type(snapshot) ~= "table" then return false, "NOT_A_TABLE" end
    if snapshot.complete ~= true or snapshot.scanCompletenessFlag ~= true then return false, "NOT_COMPLETED" end
    local completedAt = whole(snapshot.completedAt)
    if not completedAt or completedAt <= 0 then return false, "INVALID_COMPLETION_TIME" end
    local scope = snapshot.marketScopeKey or snapshot.realmKey
    if expectedScope and scope ~= expectedScope then return false, "WRONG_MARKET_SCOPE" end
    if type(snapshot.items) ~= "table" then return false, "INVALID_ITEMS" end
    local auctionCount, itemCount = whole(snapshot.auctionCount or snapshot.scanAuctionCount), whole(snapshot.itemCount or snapshot.uniqueItemCount)
    if not auctionCount or not itemCount then return false, "INVALID_COUNTS" end
    local counted = 0
    for itemKey, item in pairs(snapshot.items) do
        if type(itemKey) ~= "string" or itemKey == "" or type(item) ~= "table"
            or not whole(item.lowestUnitBuyout) or not whole(item.listingCount) or not whole(item.totalQuantity)
        then return false, "INVALID_ITEM_RECORD" end
        counted = counted + 1
    end
    if counted ~= itemCount then return false, "ITEM_COUNT_MISMATCH" end
    return true
end

local function removeOrderKey(order, key)
    for index = #order, 1, -1 do if order[index] == key then table.remove(order, index) end end
end

local function itemRetentionOrder(left, right)
    local leftStackable = (whole(left.item.maxStack) or 1) > 1
    local rightStackable = (whole(right.item.maxStack) or 1) > 1
    if leftStackable ~= rightStackable then return leftStackable end
    local leftListings = whole(left.item.listingCount) or 0
    local rightListings = whole(right.item.listingCount) or 0
    if leftListings ~= rightListings then return leftListings > rightListings end
    local leftQuantity = whole(left.item.totalQuantity) or 0
    local rightQuantity = whole(right.item.totalQuantity) or 0
    if leftQuantity ~= rightQuantity then return leftQuantity > rightQuantity end
    return left.key < right.key
end

function BOD.MarketCache:BoundSnapshot(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.items) ~= "table" then return 0 end
    local declaredCount = whole(snapshot.itemCount)
    if snapshot.cacheItemLimit == MAX_ITEMS_PER_SNAPSHOT
        and declaredCount and declaredCount <= MAX_ITEMS_PER_SNAPSHOT
    then
        return 0
    end
    local candidates = {}
    for itemKey, item in pairs(snapshot.items) do
        if type(itemKey) == "string" and type(item) == "table" then
            candidates[#candidates + 1] = { key = itemKey, item = item }
        end
    end
    local observedCount = math.max(#candidates, whole(snapshot.observedItemCount) or whole(snapshot.uniqueItemCount) or 0)
    if #candidates > MAX_ITEMS_PER_SNAPSHOT then
        table.sort(candidates, itemRetentionOrder)
        local retained = {}
        for index = 1, MAX_ITEMS_PER_SNAPSHOT do
            local candidate = candidates[index]
            retained[candidate.key] = candidate.item
        end
        snapshot.items = retained
        snapshot.coverageStatus = "BOUNDED_SUMMARY"
    end
    snapshot.observedItemCount = observedCount
    snapshot.itemCount = math.min(#candidates, MAX_ITEMS_PER_SNAPSHOT)
    snapshot.cacheItemLimit = MAX_ITEMS_PER_SNAPSHOT
    return #candidates - snapshot.itemCount
end

function BOD.MarketCache:Migrate(db, currentScope, legacyScope)
    db = type(db) == "table" and db or {}
    local oldCurrent = type(db.currentSnapshot) == "table" and db.currentSnapshot or nil
    db.snapshotsByScope = type(db.snapshotsByScope) == "table" and db.snapshotsByScope or {}
    db.scopeOrder = type(db.scopeOrder) == "table" and db.scopeOrder or {}
    db.targetedByScope = type(db.targetedByScope) == "table" and db.targetedByScope or {}
    if oldCurrent then
        local oldScope = oldCurrent.marketScopeKey or oldCurrent.realmKey
        local destination = oldScope == legacyScope and currentScope or oldScope
        if destination then
            oldCurrent.marketScopeKey = destination
            oldCurrent.realmKey = nil
            if self:ValidateSnapshot(oldCurrent, destination) then
                db.snapshotsByScope[destination] = oldCurrent
                removeOrderKey(db.scopeOrder, destination)
                db.scopeOrder[#db.scopeOrder + 1] = destination
            end
        end
    end
    db.currentSnapshot = nil
    db.latestSnapshotID = nil
    db.currentByRealm = nil
    db.realmOrder = nil
    db.snapshots = nil
    db.maxSnapshots = nil
    db.schemaVersion = SCHEMA_VERSION
    for _, snapshot in pairs(db.snapshotsByScope) do self:BoundSnapshot(snapshot) end
    self:Prune(db)
    return db
end

function BOD.MarketCache:Prune(db)
    db.scopeOrder = type(db.scopeOrder) == "table" and db.scopeOrder or {}
    while #db.scopeOrder > MAX_SCOPES do
        local key = table.remove(db.scopeOrder, 1)
        db.snapshotsByScope[key] = nil
        db.targetedByScope[key] = nil
    end
end

function BOD.MarketCache:Commit(db, candidate, scopeKey)
    self:BoundSnapshot(candidate)
    local valid, reason = self:ValidateSnapshot(candidate, scopeKey)
    if not valid then return nil, reason end
    self.validatedSnapshots[candidate] = scopeKey
    db.snapshotsByScope = type(db.snapshotsByScope) == "table" and db.snapshotsByScope or {}
    db.targetedByScope = type(db.targetedByScope) == "table" and db.targetedByScope or {}
    db.scopeOrder = type(db.scopeOrder) == "table" and db.scopeOrder or {}
    db.snapshotsByScope[scopeKey] = candidate
    db.targetedByScope[scopeKey] = nil
    removeOrderKey(db.scopeOrder, scopeKey)
    db.scopeOrder[#db.scopeOrder + 1] = scopeKey
    self:Prune(db)
    return candidate
end

function BOD.MarketCache:Get(db, scopeKey, settings)
    if settings and settings.reuseLastCompletedScan == false then return nil end
    local snapshot = type(db) == "table" and type(db.snapshotsByScope) == "table" and db.snapshotsByScope[scopeKey] or nil
    if snapshot then self:BoundSnapshot(snapshot) end
    if snapshot and self.validatedSnapshots[snapshot] == scopeKey then return snapshot end
    if snapshot and self:ValidateSnapshot(snapshot, scopeKey) then
        self.validatedSnapshots[snapshot] = scopeKey
        return snapshot
    end
    if snapshot then
        db.snapshotsByScope[scopeKey] = nil
        db.cacheLoadWarningPending = true
    end
    return nil
end

function BOD.MarketCache:GetStatus(snapshot, settings, currentTime)
    if not snapshot then return { available = false, label = "NO_DATA", message = "Market data: No completed scan" } end
    local completedAt = whole(snapshot.completedAt) or 0
    local age = math.max(0, (whole(currentTime) or now()) - completedAt)
    local label = self:ClassifyAge(age, settings)
    local suffix = label == "AGING" and ". Refresh recommended."
        or (label == "STALE" and ". Verify before buying.")
        or (label == "HISTORICAL_ONLY" and ". Historical context only.") or ""
    return {
        available = true, label = label, ageSeconds = age, ageText = self:FormatAge(age), completedAt = completedAt,
        auctionCount = whole(snapshot.auctionCount or snapshot.scanAuctionCount) or 0,
        itemCount = whole(snapshot.itemCount or snapshot.uniqueItemCount) or 0,
        coverageStatus = snapshot.coverageStatus or "COMPLETE",
        scanId = snapshot.scanId or snapshot.id,
        message = "Market data: " .. label:gsub("_", " "):lower():gsub("^%l", string.upper) .. " — scanned " .. self:FormatAge(age) .. suffix,
    }
end

function BOD.MarketCache:RecordOverlay(db, scopeKey, itemKey, item, checkedAt, sourceScanId)
    if type(itemKey) ~= "string" or itemKey == "" or type(item) ~= "table" then return nil, "INVALID_OVERLAY" end
    db.targetedByScope = type(db.targetedByScope) == "table" and db.targetedByScope or {}
    local scope = type(db.targetedByScope[scopeKey]) == "table" and db.targetedByScope[scopeKey] or { items = {}, order = {} }
    scope.items, scope.order = type(scope.items) == "table" and scope.items or {}, type(scope.order) == "table" and scope.order or {}
    local overlay = { item = item, checkedAt = whole(checkedAt) or now(), sourceScanId = sourceScanId, source = "TARGETED_ITEM" }
    scope.items[itemKey] = overlay
    removeOrderKey(scope.order, itemKey)
    scope.order[#scope.order + 1] = itemKey
    while #scope.order > MAX_OVERLAYS_PER_SCOPE do scope.items[table.remove(scope.order, 1)] = nil end
    db.targetedByScope[scopeKey] = scope
    return overlay
end

function BOD.MarketCache:GetOverlay(db, scopeKey, itemKey, currentTime)
    local scope = type(db) == "table" and type(db.targetedByScope) == "table" and db.targetedByScope[scopeKey] or nil
    local overlay = scope and type(scope.items) == "table" and scope.items[itemKey] or nil
    if not overlay then return nil end
    if math.max(0, (whole(currentTime) or now()) - (whole(overlay.checkedAt) or 0)) > TARGETED_OVERLAY_MAX_AGE then
        scope.items[itemKey] = nil
        removeOrderKey(scope.order or {}, itemKey)
        return nil
    end
    return overlay
end

function BOD.MarketCache:ClearOverlay(db, scopeKey, itemKey)
    local scope = type(db) == "table" and type(db.targetedByScope) == "table" and db.targetedByScope[scopeKey] or nil
    if not scope or type(scope.items) ~= "table" then return end
    scope.items[itemKey] = nil
    removeOrderKey(scope.order or {}, itemKey)
end

function BOD.MarketCache:Clear(db, scopeKey)
    if type(db) ~= "table" then return end
    if scopeKey then
        if type(db.snapshotsByScope) == "table" then db.snapshotsByScope[scopeKey] = nil end
        if type(db.targetedByScope) == "table" then db.targetedByScope[scopeKey] = nil end
        removeOrderKey(db.scopeOrder or {}, scopeKey)
    else
        db.snapshotsByScope, db.scopeOrder, db.targetedByScope = {}, {}, {}
    end
end

function BOD.MarketCache:GetLimits()
    return {
        maxScopes = MAX_SCOPES,
        maxItemsPerSnapshot = MAX_ITEMS_PER_SNAPSHOT,
        maxOverlaysPerScope = MAX_OVERLAYS_PER_SCOPE,
        overlayMaxAgeSeconds = TARGETED_OVERLAY_MAX_AGE,
    }
end
