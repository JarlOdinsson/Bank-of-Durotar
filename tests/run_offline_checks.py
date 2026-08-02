from __future__ import annotations

import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(value: bool, label: str) -> None:
    if not value:
        raise AssertionError(label)


def median(values: list[int]) -> int | None:
    values = sorted(values)
    if not values:
        return None
    middle = (len(values) - 1) // 2
    if len(values) % 2:
        return values[middle]
    return (values[middle] + values[middle + 1]) // 2


def weighted_median(samples: list[tuple[int, int]]) -> int | None:
    samples = sorted(samples)
    total = sum(quantity for _, quantity in samples)
    threshold = (total + 1) // 2
    seen = 0
    for price, quantity in samples:
        seen += quantity
        if seen >= threshold:
            return price
    return None


def test_math() -> None:
    check(median([100, 200]) == 150, "even median")
    check(median([300, 100, 200]) == 200, "odd median")
    check(weighted_median([(100, 2), (150, 1), (200, 3)]) == 150, "weighted median")
    reference, current, quantity = 1000, 700, 3
    check(math.floor(reference * 0.85) == 850, "maximum buy price")
    check((math.floor(reference * 0.95) - current) * quantity == 750, "gain after cut")

    budget = 1000
    per_item_limit = budget // 2
    remaining = budget
    chosen: list[int] = []
    for cost in (400, 350, 300, 100):
        if len(chosen) >= 3:
            break
        if cost <= per_item_limit and cost <= remaining:
            chosen.append(cost)
            remaining -= cost
    check(chosen == [400, 350, 100], "three-buy greedy budget selection")
    check(sum(chosen) <= budget and max(chosen) <= per_item_limit, "buy plan budget caps")
    sale, reagent_cost = 1000, 700
    craft_profit = math.floor(sale * 0.95) - reagent_cost
    check(craft_profit == 250 and craft_profit / reagent_cost >= 0.15, "craft profit after auction cut")
    check(((100 * 2) + 160) // 3 == 120, "incremental daily market average")


def test_package() -> None:
    toc = read("BankOfDurotar.toc")
    loaded = [line.strip() for line in toc.splitlines() if line.strip().endswith(".lua")]
    check(len(loaded) == 12, "minimal module count")
    check(all((ROOT / path).is_file() for path in loaded), "TOC files exist")
    check("## Version: 0.4.0" in toc and 'BOD.version = "0.4.0"' in read("Core.lua"), "version alignment")

    source = "\n".join(read(path) for path in loaded)
    check("StartAuction(" not in source, "no posting calls")
    check("PlaceAuctionBid(" not in source, "no buying calls")
    check("CancelAuction(" not in source, "no cancellation calls")
    check(":Click(" not in source and "RunBinding" not in source, "no simulated input")
    for removed in ("TransactionProbe.lua", "Diagnostics.lua", "Probe.lua", "UI.lua", "SettingsPanel.lua", "SearchController.lua", "SearchResults.lua"):
        check(not (ROOT / removed).exists(), f"removed {removed}")


def test_workflow() -> None:
    core = read("Core.lua")
    market = read("MarketData.lua")
    pricing = read("PricingService.lua")
    opportunity = read("OpportunityService.lua")
    gold_plan = read("GoldPlan.lua")
    history = read("MarketHistory.lua")
    crafting = read("CraftingService.lua")
    sales = read("SalesHistory.lua")
    scan = read("FullScanProbe.lua")
    sidecar = read("Sidecar.lua")

    check('"AUCTION_ITEM_LIST_UPDATE"' in core, "result event registered")
    check("QueryAuctionItems" not in scan, "scanner uses API adapter")
    check('QueryAuctionItems, "", nil, nil, 0, nil, nil, true, false, nil' in read("AuctionAPI.lua"), "verified 2.5.6 full-scan signature")
    check("ITEM_QUALITY_COLORS[-1]" in read("AuctionAPI.lua"), "legacy get-all UI guard")
    check("bestListingStackCount" in market and "bestListingBuyoutTotal" in market, "exact cheapest stack sizing")
    check("MARKET_DATA_SCHEMA_VERSION = 3" in market, "compact market schema")
    check("db.currentByRealm[" not in market and "db.currentSnapshot = record" in market, "snapshot stored once")
    check("HISTORY_SCHEMA_VERSION = 3" in history, "daily history schema")
    check("MAX_TRACKED_ITEMS = 1000" in history and "RETENTION_DAYS = 30" in history, "bounded 30-day history")
    check("updateAverage" in history and "GetLearningStatus" in history, "market learning model")
    check("FindItemByText" in market, "typed and linked item lookup")
    check("FindExactItemByName" in market and "maxStack" in market, "safe scan item identity")
    check("GetInboxInvoiceInfo" in sales and "AUCTION_EXPIRED_MAIL_SUBJECT" in sales, "mailbox sale outcomes")
    check("MAX_TRACKED_ITEMS = 500" in sales and "mailboxCounts" in sales, "bounded deduplicated sale memory")
    check("ESTIMATED_AUCTION_CUT_RATE" in opportunity and "maximumSafeUnitPrice" in opportunity, "safe buy math")
    check("budgetCopper * 0.5" in gold_plan and "cost <= remaining" in gold_plan, "budget limits")
    check("BUY_LIMIT = 10" in gold_plan and "SELL_LIMIT = 3" in gold_plan, "ten-buy and three-sell limits")
    check("GetContainerItemInfo" in gold_plan and "isBound ~= true" in gold_plan, "bag item filtering")
    check('minimumConfidence = "MEDIUM"' in gold_plan, "safe plan confidence")
    check("GetTradeSkillItemLink" in crafting and "GetTradeSkillReagentItemLink" in crafting, "profession recipe capture")
    check("MINIMUM_MARGIN_RATE = 0.15" in crafting and "AUCTION_CUT_RATE = 0.05" in crafting, "conservative craft math")
    check("historicalOutput" in crafting and "historyPrice" in crafting, "craft history safeguards")
    check("MAX_RECIPES_PER_PROFESSION = 400" in crafting and "MAX_PROFESSION_SETS = 12" in crafting, "bounded recipe storage")
    check("IGNORED_LOW_OUTLIER" in pricing and "INVALID_QUANTITY" in pricing, "safe sell math")
    check("expectedDepositLoss" in pricing and "vendorValue" in pricing, "net sale economics")
    check("GetTradeSkillCooldown" in crafting, "craft cooldown handling")
    check("BUY These Auction Items" in sidecar and "SELL These Items From Your Bags" in sidecar, "explicit player actions")
    check("flipScore" in opportunity and "profitRate" in opportunity, "easy-flip ranking")
    check('"UIPanelScrollFrameTemplate"' in sidecar and "BUY_ROWS, SELL_ROWS, CRAFT_ROWS = 10, 3, 3" in sidecar, "scrollable ten-flip view")
    check("CRAFT These Items" in sidecar and "Materials:" in sidecar, "craft profit view")
    check("Market memory:" in sidecar and "daysObserved" in sidecar, "learning progress UI")
    check('SetScript("OnReceiveDrag"' in sidecar and "cursorItemLink" in sidecar, "sell item drop target")
    check('hooksecurefunc("HandleModifiedItemClick"' in sidecar and "IsShiftKeyDown" in sidecar, "sell item shift-click selection")
    check("1. CHOOSE THE ITEM" in sidecar and "3. USE THIS PRICE" in sidecar, "guided sell steps")
    check('guidedMode = false' in core and '"Guided: OFF"' in sidecar, "optional guided mode")
    check("GUIDE_STEPS" in sidecar and "SetGuideStep" in sidecar and '"Finish"' in sidecar, "guided walkthrough controls")
    check('SetView("PLAN")' in scan, "scan opens Gold Plan")


def main() -> None:
    test_math()
    test_package()
    test_workflow()
    print("offline checks: PASS")


if __name__ == "__main__":
    main()
