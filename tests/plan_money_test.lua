local BOD = {}
local chunk = assert(loadfile("PlanMoney.lua"))
chunk("BankOfDurotar", BOD)

local function expect(value, label)
    if not value then error(label, 2) end
end

local function fields(gold, silver, copper, expected, label)
    local normalized = BOD.PlanMoney:NormalizeFields(gold, silver, copper)
    expect(normalized.totalCopper == expected, label .. " total")
    local reopened = BOD.PlanMoney:ToFields(normalized.totalCopper)
    expect(BOD.PlanMoney:FromFields(reopened.gold, reopened.silver, reopened.copper) == expected, label .. " reopen")
    return normalized
end

fields(0, 0, 0, 0, "zero")
fields(7, 0, 0, 70000, "gold only")
fields(0, 42, 0, 4200, "silver only")
fields(0, 0, 73, 73, "copper only")
fields(12, 34, 56, 123456, "mixed")
fields(0, 99, 99, 9999, "maximum denominations")

local silverOverflow = fields(1, 125, 0, 22500, "silver overflow")
expect(silverOverflow.gold == 2 and silverOverflow.silver == 25 and silverOverflow.copper == 0, "silver normalized")
local copperOverflow = fields(1, 0, 240, 10240, "copper overflow")
expect(copperOverflow.gold == 1 and copperOverflow.silver == 2 and copperOverflow.copper == 40, "copper normalized")
local combined = fields(1, 125, 240, 22740, "combined overflow")
expect(combined.gold == 2 and combined.silver == 27 and combined.copper == 40, "combined normalized")

fields("", "", "", 0, "empty")
fields("letters", "S", "$", 0, "nonnumeric")
fields("-1", -2, "-3", 0, "negative")
fields("1.5", 2.5, "3.1", 0, "decimal")
expect(BOD.PlanMoney:FromFields("999999999999", 0, 0) == 2147483647, "large gold clamped")

expect(BOD.PlanMoney:MigrateStoredCopper(123456, 1000000) == 123456, "existing copper remains copper")
expect(BOD.PlanMoney:MigrateStoredCopper("123456", 1000000) == 123456, "historical numeric string")
expect(BOD.PlanMoney:MigrateStoredCopper("12g 34s", 1000000) == 1000000, "unsupported string falls back")
expect(BOD.PlanMoney:MigrateStoredCopper(nil, 1000) == 1000, "missing setting falls back")

local budget = fields(8, 10, 20, 81020, "budget")
local profit = fields(0, 50, 5, 5005, "profit")
expect(budget.totalCopper ~= profit.totalCopper, "budget and profit remain separate")

print("plan money tests: PASS")
