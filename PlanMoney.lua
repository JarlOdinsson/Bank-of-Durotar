local addonName, BOD = ...

BOD.PlanMoney = {}

local COPPER_PER_GOLD = 10000
local COPPER_PER_SILVER = 100
local MAX_COPPER = 2147483647

local function wholeNonNegative(value)
    if type(value) == "number" then
        if value < 0 or value ~= math.floor(value) then return 0 end
        return value
    end
    if type(value) ~= "string" then return 0 end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" or not value:match("^%d+$") then return 0 end
    return tonumber(value) or 0
end

function BOD.PlanMoney:SanitizeComponent(value)
    return wholeNonNegative(value)
end

function BOD.PlanMoney:FromFields(gold, silver, copper)
    gold = wholeNonNegative(gold)
    silver = wholeNonNegative(silver)
    copper = wholeNonNegative(copper)
    if gold > math.floor(MAX_COPPER / COPPER_PER_GOLD) then return MAX_COPPER end
    local total = gold * COPPER_PER_GOLD
    if silver > math.floor((MAX_COPPER - total) / COPPER_PER_SILVER) then return MAX_COPPER end
    total = total + silver * COPPER_PER_SILVER
    if copper > MAX_COPPER - total then return MAX_COPPER end
    return math.floor(total + copper)
end

function BOD.PlanMoney:ToFields(totalCopper)
    totalCopper = wholeNonNegative(totalCopper)
    totalCopper = math.min(MAX_COPPER, totalCopper)
    return {
        gold = math.floor(totalCopper / COPPER_PER_GOLD),
        silver = math.floor((totalCopper % COPPER_PER_GOLD) / COPPER_PER_SILVER),
        copper = totalCopper % COPPER_PER_SILVER,
        totalCopper = totalCopper,
    }
end

function BOD.PlanMoney:NormalizeFields(gold, silver, copper)
    return self:ToFields(self:FromFields(gold, silver, copper))
end

function BOD.PlanMoney:MigrateStoredCopper(value, fallback)
    if value == nil then return self:ToFields(fallback).totalCopper end
    if type(value) == "number" and (value < 0 or value ~= math.floor(value)) then
        return self:ToFields(fallback).totalCopper
    end
    if type(value) == "string" then
        local trimmed = value:gsub("^%s+", ""):gsub("%s+$", "")
        if not trimmed:match("^%d+$") then return self:ToFields(fallback).totalCopper end
        value = trimmed
    elseif type(value) ~= "number" then
        return self:ToFields(fallback).totalCopper
    end
    return self:ToFields(value).totalCopper
end
