local addonName, BOD = ...

BOD.CraftingService = {}

local SCHEMA_VERSION = 1
local MAX_RECIPES_PER_PROFESSION = 400
local MAX_PROFESSION_SETS = 12
local MINIMUM_MARGIN_RATE = 0.15
local AUCTION_CUT_RATE = 0.05

local function now()
    if type(time) == "function" then return time() end
    return os.time()
end

local function wholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number >= math.huge then return nil end
    return math.floor(number)
end

local function itemIDFromLink(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function ensureDB()
    if not BOD.db then BOD:InitializeDatabase() end
    BOD.db.crafting = type(BOD.db.crafting) == "table" and BOD.db.crafting or {}
    local db = BOD.db.crafting
    db.schemaVersion = SCHEMA_VERSION
    db.professions = type(db.professions) == "table" and db.professions or {}
    return db
end

local function professionSetCount(professions)
    local count = 0
    for _ in pairs(professions or {}) do count = count + 1 end
    return count
end

local function pruneProfessionSets(db)
    while professionSetCount(db.professions) > MAX_PROFESSION_SETS do
        local oldestKey, oldestTime
        for key, profession in pairs(db.professions) do
            local updatedAt = tonumber(profession.updatedAt) or 0
            if not oldestTime or updatedAt < oldestTime then
                oldestKey, oldestTime = key, updatedAt
            end
        end
        if not oldestKey then break end
        db.professions[oldestKey] = nil
    end
end

function BOD.CraftingService:CaptureOpenProfession()
    if type(GetTradeSkillLine) ~= "function" or type(GetNumTradeSkills) ~= "function"
        or type(GetTradeSkillInfo) ~= "function" or type(GetTradeSkillItemLink) ~= "function"
        or type(GetTradeSkillNumReagents) ~= "function" or type(GetTradeSkillReagentInfo) ~= "function"
        or type(GetTradeSkillReagentItemLink) ~= "function"
    then
        return false, "Trade skill API unavailable."
    end

    local professionName = GetTradeSkillLine()
    if type(professionName) ~= "string" or professionName == "" or professionName == "UNKNOWN" then
        return false, "No profession is open."
    end

    local owner = type(UnitName) == "function" and UnitName("player") or "Character"
    owner = tostring(owner or "Character")
    local recipes = {}
    local skillCount = math.max(0, wholeNumber(GetNumTradeSkills()) or 0)
    for skillIndex = 1, skillCount do
        if #recipes >= MAX_RECIPES_PER_PROFESSION then break end
        local recipeName, skillType = GetTradeSkillInfo(skillIndex)
        if skillType ~= "header" then
            local outputLink = GetTradeSkillItemLink(skillIndex)
            local outputItemID = itemIDFromLink(outputLink)
            local reagentCount = math.max(0, wholeNumber(GetTradeSkillNumReagents(skillIndex)) or 0)
            if outputItemID and reagentCount > 0 then
                local reagents = {}
                local complete = true
                for reagentIndex = 1, reagentCount do
                    local reagentName, _, count = GetTradeSkillReagentInfo(skillIndex, reagentIndex)
                    local reagentItemID = itemIDFromLink(GetTradeSkillReagentItemLink(skillIndex, reagentIndex))
                    count = wholeNumber(count)
                    if not reagentItemID or not count or count <= 0 then
                        complete = false
                        break
                    end
                    reagents[#reagents + 1] = {
                        itemID = reagentItemID,
                        name = reagentName,
                        count = count,
                    }
                end
                if complete then
                    local outputName = type(GetItemInfo) == "function" and GetItemInfo(outputLink) or nil
                    local outputCount = type(GetTradeSkillNumMade) == "function" and wholeNumber(GetTradeSkillNumMade(skillIndex)) or 1
                    local cooldownSeconds
                    if type(GetTradeSkillCooldown) == "function" then
                        local cooldownOk, cooldown = pcall(GetTradeSkillCooldown, skillIndex)
                        if cooldownOk then cooldownSeconds = wholeNumber(cooldown) end
                    end
                    recipes[#recipes + 1] = {
                        name = recipeName or outputName or ("Item " .. tostring(outputItemID)),
                        outputName = outputName or recipeName or ("Item " .. tostring(outputItemID)),
                        outputItemID = outputItemID,
                        outputCount = math.max(1, outputCount or 1),
                        reagents = reagents,
                        cooldownSeconds = cooldownSeconds,
                        cooldownCheckedAt = now(),
                    }
                end
            end
        end
    end

    local db = ensureDB()
    local key = owner .. ":" .. professionName
    db.professions[key] = {
        owner = owner,
        name = professionName,
        updatedAt = now(),
        recipes = recipes,
    }
    pruneProfessionSets(db)
    return true, { profession = professionName, owner = owner, recipeCount = #recipes }
end

local function marketItemFor(itemID)
    return BOD.MarketData and BOD.MarketData.GetBestCurrentItemByItemID
        and BOD.MarketData:GetBestCurrentItemByItemID(itemID) or nil
end

local function conservativeReagentUnitPrice(item)
    if not item or (tonumber(item.sampleCount) or 0) < 2 then return nil end
    local currentPrice = math.floor(math.max(
        tonumber(item.lowestUnitBuyout) or 0,
        tonumber(item.medianUnitBuyout) or 0,
        tonumber(item.weightedMedianUnitBuyout) or 0
    ))
    local history = BOD.MarketHistory and BOD.MarketHistory:GetSummary(item.itemKey) or nil
    local historyPrice = history and history.observationCount >= 2 and history.sevenDay and tonumber(history.sevenDay.median) or 0
    return math.max(currentPrice, historyPrice or 0)
end

function BOD.CraftingService:GetRecommendations(limit, budgetCopper)
    limit = math.max(1, math.min(wholeNumber(limit) or 3, 10))
    budgetCopper = math.max(1, wholeNumber(budgetCopper) or 2147483647)
    local db = ensureDB()
    local candidates = {}
    local recipeCount = 0

    for _, profession in pairs(db.professions) do
        for _, recipe in ipairs(profession.recipes or {}) do
            recipeCount = recipeCount + 1
            local cooldownRemaining = math.max(0, (tonumber(recipe.cooldownSeconds) or 0) - (now() - (tonumber(recipe.cooldownCheckedAt) or 0)))
            local outputItem = marketItemFor(recipe.outputItemID)
            local outputCount = math.max(1, wholeNumber(recipe.outputCount) or 1)
            local recommendation = outputItem and BOD.PricingService:GetRecommendation(outputItem.itemKey, outputCount, { strategy = "SMALL_UNDERCUT" }) or nil
            if cooldownRemaining <= 0 and recommendation and recommendation.status == "RECOMMENDED" and recommendation.confidence ~= "LOW" then
                local reagentCost = 0
                local complete = true
                for _, reagent in ipairs(recipe.reagents or {}) do
                    local unitPrice = conservativeReagentUnitPrice(marketItemFor(reagent.itemID))
                    if not unitPrice or unitPrice <= 0 then
                        complete = false
                        break
                    end
                    reagentCost = reagentCost + (unitPrice * (wholeNumber(reagent.count) or 0))
                end
                local outputUnitPrice = tonumber(recommendation.unitBuyout) or 0
                local outputHistory = BOD.MarketHistory and BOD.MarketHistory:GetSummary(outputItem.itemKey) or nil
                local historicalOutput = outputHistory and outputHistory.observationCount >= 2 and outputHistory.sevenDay and tonumber(outputHistory.sevenDay.median) or nil
                if historicalOutput and historicalOutput > 0 then outputUnitPrice = math.min(outputUnitPrice, historicalOutput) end
                local supportedSalePrice = math.floor(outputUnitPrice * outputCount)
                local economics = BOD.PricingService:GetSaleEconomics(outputItem.itemKey, outputCount, supportedSalePrice)
                local netSale = economics.expectedNetSale
                local profit = netSale - reagentCost
                local marginRate = reagentCost > 0 and (profit / reagentCost) or 0
                local personalSales = economics.personalSales or {}
                local poorPersonalSales = (tonumber(personalSales.outcomeCount) or 0) >= 3 and (tonumber(personalSales.saleRate) or 0) < 0.25
                if complete and not poorPersonalSales and reagentCost > 0 and reagentCost <= budgetCopper and profit > 0 and marginRate >= MINIMUM_MARGIN_RATE then
                    candidates[#candidates + 1] = {
                        profession = profession.name,
                        owner = profession.owner,
                        recipeName = recipe.name,
                        outputName = recipe.outputName,
                        outputItemID = recipe.outputItemID,
                        outputCount = outputCount,
                        reagentCost = reagentCost,
                        sellPrice = supportedSalePrice,
                        estimatedProfit = profit,
                        marginRate = marginRate,
                        confidence = recommendation.confidence,
                        historyObservationCount = tonumber(outputHistory and outputHistory.observationCount) or 0,
                        estimatedAuctionCut = economics.auctionCut,
                        expectedDepositLoss = economics.expectedDepositLoss,
                        personalSales = personalSales,
                    }
                end
            end
        end
    end

    table.sort(candidates, function(left, right)
        local leftRate = left.personalSales and left.personalSales.saleRate or -1
        local rightRate = right.personalSales and right.personalSales.saleRate or -1
        if leftRate ~= rightRate then return leftRate > rightRate end
        if left.estimatedProfit ~= right.estimatedProfit then return left.estimatedProfit > right.estimatedProfit end
        if left.marginRate ~= right.marginRate then return left.marginRate > right.marginRate end
        return tostring(left.outputName) < tostring(right.outputName)
    end)
    while #candidates > limit do table.remove(candidates) end

    local status
    if recipeCount == 0 then status = "NO_RECIPES"
    elseif not BOD.MarketData:GetLatestSnapshot() then status = "NO_DATA"
    elseif #candidates == 0 then status = "EMPTY"
    else status = "OK" end
    return {
        status = status,
        recommendations = candidates,
        recipeCount = recipeCount,
        professionCount = professionSetCount(db.professions),
    }
end

function BOD.CraftingService:OnEvent(event)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        self:CaptureOpenProfession()
        if BOD.Sidecar then BOD.Sidecar:Refresh() end
    end
end
