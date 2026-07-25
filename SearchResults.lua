local addonName, BOD = ...

BOD.SearchResults = {}

local SORTERS = {
    unitBuyout = "Lowest unit buyout",
    totalBuyout = "Lowest total buyout",
    stackSize = "Stack size",
    timeLeft = "Time remaining",
    itemName = "Item name",
}

local SORT_ORDER = {
    "unitBuyout",
    "totalBuyout",
    "stackSize",
    "timeLeft",
    "itemName",
}

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyResult(result)
    local copy = {}
    for key, value in pairs(result or {}) do
        copy[key] = value
    end
    return copy
end

local function hasValidBuyout(result)
    return (tonumber(result.buyoutTotal) or 0) > 0
end

local function getUnitBuyout(result)
    if result.buyoutPerUnit then
        return tonumber(result.buyoutPerUnit) or 0
    end

    local stackCount = tonumber(result.stackCount) or 0
    local buyoutTotal = tonumber(result.buyoutTotal) or 0
    if stackCount > 0 and buyoutTotal > 0 then
        return math.floor(buyoutTotal / stackCount)
    end
    return 0
end

local function defaultCompare(left, right)
    local leftHasBuyout = hasValidBuyout(left)
    local rightHasBuyout = hasValidBuyout(right)
    if leftHasBuyout ~= rightHasBuyout then
        return leftHasBuyout
    end

    local leftUnit = getUnitBuyout(left)
    local rightUnit = getUnitBuyout(right)
    if leftUnit ~= rightUnit then
        if leftUnit == 0 then
            return false
        end
        if rightUnit == 0 then
            return true
        end
        return leftUnit < rightUnit
    end

    local leftTotal = tonumber(left.buyoutTotal) or 0
    local rightTotal = tonumber(right.buyoutTotal) or 0
    if leftTotal ~= rightTotal then
        if leftTotal == 0 then
            return false
        end
        if rightTotal == 0 then
            return true
        end
        return leftTotal < rightTotal
    end

    return (tonumber(left.index) or 0) < (tonumber(right.index) or 0)
end

local function compareBySort(left, right, sortKey)
    if sortKey == "totalBuyout" then
        local leftTotal = tonumber(left.buyoutTotal) or 0
        local rightTotal = tonumber(right.buyoutTotal) or 0
        if leftTotal ~= rightTotal then
            if leftTotal == 0 then
                return false
            end
            if rightTotal == 0 then
                return true
            end
            return leftTotal < rightTotal
        end
    elseif sortKey == "stackSize" then
        local leftStack = tonumber(left.stackCount) or 0
        local rightStack = tonumber(right.stackCount) or 0
        if leftStack ~= rightStack then
            return leftStack > rightStack
        end
    elseif sortKey == "timeLeft" then
        local leftTime = tonumber(left.timeLeft) or 999
        local rightTime = tonumber(right.timeLeft) or 999
        if leftTime ~= rightTime then
            return leftTime < rightTime
        end
    elseif sortKey == "itemName" then
        local leftName = tostring(left.name or ""):lower()
        local rightName = tostring(right.name or ""):lower()
        if leftName ~= rightName then
            return leftName < rightName
        end
    end

    return defaultCompare(left, right)
end

function BOD.SearchResults:GetSortOptions()
    return SORT_ORDER, SORTERS
end

function BOD.SearchResults:GetSortLabel(sortKey)
    return SORTERS[sortKey] or SORTERS.unitBuyout
end

function BOD.SearchResults:GetNextSortKey(sortKey)
    for index, key in ipairs(SORT_ORDER) do
        if key == sortKey then
            return SORT_ORDER[index + 1] or SORT_ORDER[1]
        end
    end
    return SORT_ORDER[1]
end

function BOD.SearchResults:ParseMoney(text)
    text = trim(text):lower()
    if text == "" then
        return nil
    end

    local gold = tonumber(text:match("(%d+)%s*g")) or 0
    local silver = tonumber(text:match("(%d+)%s*s")) or 0
    local copper = tonumber(text:match("(%d+)%s*c")) or 0

    if gold == 0 and silver == 0 and copper == 0 then
        local plainNumber = tonumber(text)
        if plainNumber then
            gold = plainNumber
        else
            return nil
        end
    end

    return math.floor(gold * 10000 + silver * 100 + copper)
end

function BOD.SearchResults:ApplyFiltersAndSort(results, filters, sortKey)
    local filtered = {}
    filters = filters or {}
    sortKey = sortKey or "unitBuyout"

    local minStack = tonumber(filters.minStackSize) or 0
    local maxUnitPrice = tonumber(filters.maxUnitPrice) or nil

    for _, result in ipairs(results or {}) do
        local stackCount = tonumber(result.stackCount) or 0
        local buyoutTotal = tonumber(result.buyoutTotal) or 0
        local unitBuyout = getUnitBuyout(result)
        local include = true

        if filters.buyoutOnly and buyoutTotal <= 0 then
            include = false
        end
        if include and minStack > 0 and stackCount < minStack then
            include = false
        end
        if include and maxUnitPrice and maxUnitPrice > 0 then
            if unitBuyout <= 0 or unitBuyout > maxUnitPrice then
                include = false
            end
        end

        if include then
            filtered[#filtered + 1] = copyResult(result)
        end
    end

    table.sort(filtered, function(left, right)
        return compareBySort(left, right, sortKey)
    end)

    return filtered
end

function BOD.SearchResults:GetUnitBuyout(result)
    return getUnitBuyout(result)
end

function BOD.SearchResults:GetTimeLeftLabel(timeLeft)
    local value = tonumber(timeLeft)
    if value == 1 then
        return "Short"
    elseif value == 2 then
        return "Medium"
    elseif value == 3 then
        return "Long"
    elseif value == 4 then
        return "Very Long"
    end
    return "Unknown"
end
