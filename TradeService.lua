local addonName, BOD = ...

BOD.TradeService = { cachedResult = nil }

local function wholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number > 2147483647 then return nil end
    return math.floor(number)
end

local function liquidGold(context)
    if context and context.liquidGoldCopper ~= nil then return wholeNumber(context.liquidGoldCopper) or 0 end
    if type(GetMoney) == "function" then return wholeNumber(GetMoney()) or 0 end
    return 0
end

local function tradeSettings()
    if not BOD.db then BOD:InitializeDatabase() end
    return BOD.TradeTracker:EnsureDB().settings
end

local function copyAnalysis(analysis, policy)
    local result = {}
    for key, value in pairs(analysis) do result[key] = value end
    for key, value in pairs(policy) do result[key] = value end
    return result
end

local function settingsSignature(settings)
    return table.concat({
        tostring(settings.enabled), tostring(settings.riskMode), tostring(settings.emergencyReserveCopper),
        tostring(settings.maximumCapitalPerTradeCopper), tostring(settings.maximumTotalCapitalCommittedCopper),
        tostring(settings.maxOpenTrades), tostring(settings.minimumAbsoluteProfitCopper),
        tostring(settings.minimumDiscountPercent), tostring(settings.minimumDemand), tostring(settings.minimumConfidence),
        tostring(settings.minimumObservationCount), tostring(settings.showSpeculativeTrades),
    }, ":")
end

local function chooseTag(candidate, best)
    if not best then return nil end
    if candidate.confidence == "STRONG" and best.confidence ~= "STRONG" then return "Safer" end
    if candidate.normalProfit > best.normalProfit then return "Higher profit" end
    if candidate.requiredCapital < best.requiredCapital then return "Lower capital" end
    if candidate.mainRiskCode == "MARKET_CAN_CHANGE" and best.mainRiskCode ~= "MARKET_CAN_CHANGE" then return "Safer" end
    return nil
end

function BOD.TradeService:GetSettings()
    return tradeSettings()
end

function BOD.TradeService:GetCachedResult()
    return self.cachedResult
end

function BOD.TradeService:Invalidate()
    self.cachedResult = nil
end

function BOD.TradeService:Build(context)
    context = type(context) == "table" and context or {}
    local settings = tradeSettings()
    local snapshot = BOD.MarketData and BOD.MarketData:GetLatestSnapshot() or nil
    local committed = BOD.TradeTracker:GetCommittedCapital()
    local money = liquidGold(context)
    local signature = settingsSignature(settings)
    local snapshotId = snapshot and (snapshot.scanId or snapshot.id) or nil
    if not context.force and not (BOD.FullScanProbe and BOD.FullScanProbe.active) and self.cachedResult
        and self.cachedResult.snapshotId == snapshotId and self.cachedResult.settingsSignature == signature
        and self.cachedResult.liquidGold == money and self.cachedResult.committedCapital == committed
    then
        return self.cachedResult
    end
    local limits = BOD.TradePolicy:GetCapitalLimits(money, committed, settings)
    local openTrades = BOD.TradeTracker:GetOpenTrades()
    local history = BOD.TradeTracker:GetHistory()
    local baseResult = {
        settings = settings,
        liquidGold = money,
        capitalLimits = limits,
        committedCapital = committed,
        openTrades = openTrades,
        history = history,
        opportunities = {},
        routeCounts = { QUICK_ONLY = 0, TRADE_ONLY = 0, BOTH = 0, NEITHER = 0 },
        snapshotId = snapshotId,
        settingsSignature = signature,
    }
    if settings.enabled == false then baseResult.status = "DISABLED"; self.cachedResult = baseResult; return baseResult end
    if BOD.FullScanProbe and BOD.FullScanProbe.active then baseResult.status = "SCANNING"; self.cachedResult = baseResult; return baseResult end
    if not snapshot or snapshot.complete ~= true or type(snapshot.items) ~= "table" then baseResult.status = "NO_DATA"; self.cachedResult = baseResult; return baseResult end

    local ownedQuantities = context.ownedQuantities
    if type(ownedQuantities) ~= "table" then
        ownedQuantities = {}
        local inventory = BOD.GoldPlan and BOD.GoldPlan:CollectBagInventory() or {}
        for itemKey, entry in pairs(inventory) do ownedQuantities[itemKey] = wholeNumber(entry.ownedQuantity) or 0 end
    end
    local rejectionCounts = {}
    local quickCapital = math.min(math.floor((wholeNumber(BOD.db.settings.goldBudgetCopper) or 1000000) * 0.5), 200000)
    if quickCapital <= 0 then quickCapital = 1 end
    for itemKey, item in pairs(snapshot.items) do
        local analysis, analysisRejection = BOD.MarketAnalysis:Analyze(itemKey, item, snapshot, {
            now = context.now,
            ownedQuantities = ownedQuantities,
        })
        local quickResult = analysis and BOD.QuickMovePolicy:EvaluateAnalysis(analysis, {
            minimumExpectedProfitCopper = BOD.db.settings.minimumExpectedProfitCopper,
            maximumAgeSeconds = 86400,
            maximumQuickCapitalCopper = quickCapital,
            maximumQuickQuantity = 20,
        }) or { actionable = false, rejectionCode = analysisRejection }
        local tradeResult = analysis and BOD.TradePolicy:Evaluate(analysis, {
            settings = settings,
            liquidGold = money,
            committedCapital = committed,
            capitalLimits = limits,
            openTradeCount = #openTrades,
        }) or { actionable = false, rejectionCode = analysisRejection }
        local route = quickResult.actionable and (tradeResult.actionable and "BOTH" or "QUICK_ONLY")
            or (tradeResult.actionable and "TRADE_ONLY" or "NEITHER")
        baseResult.routeCounts[route] = baseResult.routeCounts[route] + 1
        if tradeResult.actionable then
            local candidate = copyAnalysis(analysis, tradeResult)
            candidate.quickMoveEligible = quickResult.actionable == true
            candidate.tradeEligible = true
            candidate.route = route
            baseResult.opportunities[#baseResult.opportunities + 1] = candidate
        else
            local code = tostring(tradeResult.rejectionCode or analysisRejection or "INVALID_DATA")
            rejectionCounts[code] = (rejectionCounts[code] or 0) + 1
        end
    end

    table.sort(baseResult.opportunities, function(left, right) return BOD.TradePolicy:IsBetter(left, right) end)
    while #baseResult.opportunities > 3 do table.remove(baseResult.opportunities) end
    baseResult.bestTrade = baseResult.opportunities[1]
    for index = 2, #baseResult.opportunities do baseResult.opportunities[index].tag = chooseTag(baseResult.opportunities[index], baseResult.bestTrade) end
    baseResult.rejectionCounts = rejectionCounts
    local primaryCode, primaryCount
    for code, count in pairs(rejectionCounts) do
        if not primaryCount or count > primaryCount or (count == primaryCount and code < primaryCode) then primaryCode, primaryCount = code, count end
    end
    baseResult.primaryRejectionCode = primaryCode
    baseResult.primaryRejectionReason = primaryCode and BOD.TradePolicy:GetReasonText(primaryCode) or nil
    if #baseResult.opportunities > 0 then
        baseResult.status = "OK"
    elseif limits.availableCapital <= 0 then
        baseResult.status = committed > 0 and "CAPITAL_COMMITTED" or "CAPITAL_TOO_LOW"
    elseif primaryCode == "INSUFFICIENT_HISTORY" then
        baseResult.status = "INSUFFICIENT_HISTORY"
    elseif primaryCode == "CAPITAL_TOO_LOW" or primaryCode == "POSITION_TOO_LARGE" then
        baseResult.status = "CAPITAL_TOO_LOW"
    else
        baseResult.status = "EMPTY"
    end
    baseResult.snapshotId = snapshotId
    self.cachedResult = baseResult
    return baseResult
end

function BOD.TradeService:CheckFreshness(recommendation, context)
    local snapshot = BOD.MarketData and BOD.MarketData:GetLatestSnapshot() or nil
    local item = recommendation and BOD.MarketData and BOD.MarketData:GetCurrentItem(recommendation.itemKey) or nil
    local currentTime = context and context.now or (type(time) == "function" and time() or os.time())
    return BOD.RecommendationPolicy:CheckFreshness({
        maximumSafeUnitPrice = recommendation and recommendation.maximumBuyUnitPrice,
        snapshotId = recommendation and recommendation.snapshotId,
    }, item, snapshot, currentTime, 43200)
end

function BOD.TradeService:Track(recommendation, timestamp)
    local freshness = self:CheckFreshness(recommendation, { now = timestamp })
    if not freshness.safe then return nil, freshness.state end
    return BOD.TradeTracker:Track(recommendation, timestamp)
end
