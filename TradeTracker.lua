local addonName, BOD = ...

BOD.TradeTracker = {}

local MAX_SAFE_INTEGER = 2147483647
local MAX_BATCHES = 20

local function wholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number > MAX_SAFE_INTEGER then return nil end
    return math.floor(number)
end

local function signedWholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number > MAX_SAFE_INTEGER or number < -MAX_SAFE_INTEGER then return nil end
    return number >= 0 and math.floor(number) or math.ceil(number)
end

local function now(value)
    return wholeNumber(value) or (type(time) == "function" and time() or os.time())
end

local function copyFields(source, fields)
    local result = {}
    for _, key in ipairs(fields) do result[key] = source[key] end
    return result
end

function BOD.TradeTracker:Migrate(trading)
    trading = type(trading) == "table" and trading or {}
    trading.schemaVersion = 1
    trading.nextTradeId = math.max(1, wholeNumber(trading.nextTradeId) or 1)
    trading.openTrades = type(trading.openTrades) == "table" and trading.openTrades or {}
    trading.closedTrades = type(trading.closedTrades) == "table" and trading.closedTrades or {}
    trading.settings = type(trading.settings) == "table" and trading.settings or {}
    for id, trade in pairs(trading.openTrades) do
        if type(trade) ~= "table" then
            trading.openTrades[id] = nil
        else
            trade.id = tostring(trade.id or id)
            trade.state = tostring(trade.state or "WATCHING"):upper()
            trade.purchaseBatches = type(trade.purchaseBatches) == "table" and trade.purchaseBatches or {}
            trade.quantityPurchased = wholeNumber(trade.quantityPurchased) or 0
            trade.quantitySold = wholeNumber(trade.quantitySold) or 0
            trade.quantityRemaining = wholeNumber(trade.quantityRemaining) or math.max(0, trade.quantityPurchased - trade.quantitySold)
            trade.totalPurchaseCost = wholeNumber(trade.totalPurchaseCost) or 0
            trade.remainingCostBasis = wholeNumber(trade.remainingCostBasis) or trade.totalPurchaseCost
            trade.realizedCostBasis = wholeNumber(trade.realizedCostBasis) or 0
            trade.netRevenue = wholeNumber(trade.netRevenue) or 0
            trade.realizedProfit = signedWholeNumber(trade.realizedProfit) or 0
        end
    end
    return trading
end

function BOD.TradeTracker:EnsureDB()
    if not BOD.db then BOD:InitializeDatabase() end
    BOD.db.trading = self:Migrate(BOD.db.trading)
    return BOD.db.trading
end

function BOD.TradeTracker:GetTrade(id)
    return self:EnsureDB().openTrades[tostring(id or "")]
end

function BOD.TradeTracker:GetOpenTrades()
    local values = {}
    for _, trade in pairs(self:EnsureDB().openTrades) do values[#values + 1] = trade end
    table.sort(values, function(left, right)
        if (left.createdAt or 0) ~= (right.createdAt or 0) then return (left.createdAt or 0) < (right.createdAt or 0) end
        return tostring(left.id) < tostring(right.id)
    end)
    return values
end

function BOD.TradeTracker:GetHistory()
    local values = {}
    for _, trade in pairs(self:EnsureDB().closedTrades) do values[#values + 1] = trade end
    table.sort(values, function(left, right)
        if (left.closedAt or 0) ~= (right.closedAt or 0) then return (left.closedAt or 0) > (right.closedAt or 0) end
        return tostring(left.id) > tostring(right.id)
    end)
    return values
end

function BOD.TradeTracker:GetCommittedCapital()
    local total = 0
    for _, trade in pairs(self:EnsureDB().openTrades) do total = total + (wholeNumber(trade.remainingCostBasis) or 0) end
    return total
end

function BOD.TradeTracker:Track(recommendation, timestamp)
    if type(recommendation) ~= "table" or recommendation.actionable ~= true or not recommendation.itemKey then return nil, "INVALID_RECOMMENDATION" end
    local db = self:EnsureDB()
    for _, trade in pairs(db.openTrades) do
        if trade.itemKey == recommendation.itemKey then return trade, "ALREADY_TRACKED" end
    end
    local maximum = wholeNumber(db.settings.maxOpenTrades) or 5
    if #self:GetOpenTrades() >= maximum then return nil, "MAX_OPEN_TRADES" end
    local id = "T" .. tostring(db.nextTradeId)
    db.nextTradeId = db.nextTradeId + 1
    local trade = copyFields(recommendation, {
        "itemKey", "itemID", "itemName", "recommendedPurchaseQuantity", "maximumSafePurchaseQuantity",
        "maximumBuyUnitPrice", "fastExitUnitPrice", "normalExitUnitPrice", "lowProfit", "normalProfit",
        "confidence", "demand", "mainRisk", "snapshotId", "observedUnitPrice",
    })
    trade.id = id
    trade.state = "WATCHING"
    trade.createdAt = now(timestamp)
    trade.recommendationTimestamp = recommendation.recommendationTimestamp or trade.createdAt
    trade.purchaseBatches = {}
    trade.quantityPurchased = 0
    trade.quantitySold = 0
    trade.quantityRemaining = 0
    trade.totalPurchaseCost = 0
    trade.remainingCostBasis = 0
    trade.realizedCostBasis = 0
    trade.grossRevenue = nil
    trade.auctionHouseCut = nil
    trade.deposits = nil
    trade.netRevenue = 0
    trade.realizedProfit = 0
    db.openTrades[id] = trade
    return trade
end

function BOD.TradeTracker:AddPurchase(id, quantity, unitCost, timestamp)
    local trade = self:GetTrade(id)
    quantity, unitCost = wholeNumber(quantity), wholeNumber(unitCost)
    if not trade then return nil, "TRADE_NOT_FOUND" end
    if not quantity or quantity <= 0 or not unitCost or unitCost <= 0 then return nil, "INVALID_PURCHASE" end
    if #trade.purchaseBatches >= MAX_BATCHES then return nil, "TOO_MANY_BATCHES" end
    local warning
    if unitCost > (wholeNumber(trade.maximumBuyUnitPrice) or 0) then warning = "PRICE_ABOVE_RECOMMENDATION" end
    if trade.quantityPurchased + quantity > (wholeNumber(trade.maximumSafePurchaseQuantity) or 0) then warning = warning or "PURCHASE_QUANTITY_EXCEEDS_POSITION" end
    if quantity > math.floor(MAX_SAFE_INTEGER / unitCost) then return nil, "VALUE_TOO_LARGE" end
    local cost = quantity * unitCost
    if cost > MAX_SAFE_INTEGER or trade.totalPurchaseCost + cost > MAX_SAFE_INTEGER then return nil, "VALUE_TOO_LARGE" end
    local purchasedAt = now(timestamp)
    trade.purchaseBatches[#trade.purchaseBatches + 1] = { quantity = quantity, unitCost = unitCost, totalCost = cost, purchasedAt = purchasedAt }
    trade.quantityPurchased = trade.quantityPurchased + quantity
    trade.quantityRemaining = trade.quantityRemaining + quantity
    trade.totalPurchaseCost = trade.totalPurchaseCost + cost
    trade.remainingCostBasis = trade.remainingCostBasis + cost
    trade.averageUnitCost = math.floor(trade.totalPurchaseCost / trade.quantityPurchased)
    trade.firstPurchasedAt = trade.firstPurchasedAt or purchasedAt
    trade.lastPurchasedAt = purchasedAt
    trade.state = "PURCHASED"
    return trade, warning
end

function BOD.TradeTracker:MarkListed(id, timestamp)
    local trade = self:GetTrade(id)
    if not trade then return nil, "TRADE_NOT_FOUND" end
    if (wholeNumber(trade.quantityRemaining) or 0) <= 0 then return nil, "NOTHING_TO_LIST" end
    trade.state = "LISTED"
    trade.listedAt = now(timestamp)
    return trade
end

function BOD.TradeTracker:RecordSale(id, quantity, netRevenue, costs, timestamp)
    local trade = self:GetTrade(id)
    quantity, netRevenue = wholeNumber(quantity), wholeNumber(netRevenue)
    costs = type(costs) == "table" and costs or {}
    if not trade then return nil, "TRADE_NOT_FOUND" end
    if not quantity or quantity <= 0 or quantity > trade.quantityRemaining or not netRevenue then return nil, "INVALID_SALE" end
    if trade.netRevenue + netRevenue > MAX_SAFE_INTEGER then return nil, "VALUE_TOO_LARGE" end
    local remainingBefore = trade.quantityRemaining
    local allocatedCost = quantity == remainingBefore and trade.remainingCostBasis
        or math.floor(trade.remainingCostBasis * quantity / remainingBefore)
    trade.quantitySold = trade.quantitySold + quantity
    trade.quantityRemaining = trade.quantityRemaining - quantity
    trade.remainingCostBasis = trade.remainingCostBasis - allocatedCost
    trade.realizedCostBasis = (wholeNumber(trade.realizedCostBasis) or 0) + allocatedCost
    if wholeNumber(costs.grossRevenue) then trade.grossRevenue = (wholeNumber(trade.grossRevenue) or 0) + wholeNumber(costs.grossRevenue) end
    if wholeNumber(costs.auctionHouseCut) then trade.auctionHouseCut = (wholeNumber(trade.auctionHouseCut) or 0) + wholeNumber(costs.auctionHouseCut) end
    if wholeNumber(costs.deposits) then trade.deposits = (wholeNumber(trade.deposits) or 0) + wholeNumber(costs.deposits) end
    trade.netRevenue = trade.netRevenue + netRevenue
    trade.realizedProfit = trade.realizedProfit + netRevenue - allocatedCost
    trade.lastSaleAt = now(timestamp)
    trade.state = trade.quantityRemaining == 0 and "SOLD" or "PARTIALLY_SOLD"
    return trade
end

local function pruneHistory(db)
    local maximum = math.max(1, math.min(wholeNumber(db.settings.tradeHistoryRetention) or 50, 500))
    local history = {}
    for id, trade in pairs(db.closedTrades) do history[#history + 1] = { id = id, trade = trade } end
    table.sort(history, function(left, right) return (left.trade.closedAt or 0) > (right.trade.closedAt or 0) end)
    for index = maximum + 1, #history do db.closedTrades[history[index].id] = nil end
end

function BOD.TradeTracker:Close(id, timestamp)
    local db = self:EnsureDB()
    local trade = db.openTrades[tostring(id or "")]
    if not trade then return nil, "TRADE_NOT_FOUND" end
    trade.state = "CLOSED"
    trade.closedAt = now(timestamp)
    if trade.firstPurchasedAt then trade.timeHeldSeconds = math.max(0, trade.closedAt - trade.firstPurchasedAt) end
    trade.returnOnCapital = trade.realizedCostBasis > 0 and trade.realizedProfit / trade.realizedCostBasis or nil
    db.openTrades[trade.id] = nil
    db.closedTrades[trade.id] = trade
    pruneHistory(db)
    return trade
end

function BOD.TradeTracker:Abandon(id, timestamp)
    local db = self:EnsureDB()
    local trade = db.openTrades[tostring(id or "")]
    if not trade then return nil, "TRADE_NOT_FOUND" end
    trade.state = "ABANDONED"
    trade.closedAt = now(timestamp)
    db.openTrades[trade.id] = nil
    db.closedTrades[trade.id] = trade
    pruneHistory(db)
    return trade
end

function BOD.TradeTracker:Reset()
    local db = self:EnsureDB()
    db.openTrades = {}
    db.closedTrades = {}
    db.nextTradeId = 1
end
