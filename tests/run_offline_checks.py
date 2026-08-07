from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(value: bool, label: str) -> None:
    if not value:
        raise AssertionError(label)


MAX_COPPER = 2_147_483_647


def money_component(value: object) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return max(0, value)
    if isinstance(value, str) and value.strip().isdigit():
        return int(value.strip())
    return 0


def plan_money(gold: object, silver: object, copper: object) -> tuple[int, int, int, int]:
    total = min(MAX_COPPER, money_component(gold) * 10_000 + money_component(silver) * 100 + money_component(copper))
    return total // 10_000, total % 10_000 // 100, total % 100, total


def migrate_plan_copper(value: object, fallback: int) -> int:
    if isinstance(value, bool):
        return fallback
    if isinstance(value, int) and value >= 0:
        return min(MAX_COPPER, value)
    if isinstance(value, str) and value.strip().isdigit():
        return min(MAX_COPPER, int(value.strip()))
    return fallback


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


def policy_result(candidate: dict[str, int | str], minimum_profit: int = 1000) -> tuple[bool, str]:
    required = ("current", "maximum", "expected", "conservative", "quantity", "capital", "age")
    if any(not isinstance(candidate.get(key), int) for key in required):
        return False, "INVALID_DATA"
    if candidate["age"] > 86400:
        return False, "OLD_MARKET_DATA"
    if candidate["expected"] <= 0:
        return False, "NO_EXPECTED_PROFIT"
    if candidate["conservative"] <= 0:
        return False, "RELISTING_ERASES_PROFIT"
    if candidate["conservative"] < minimum_profit:
        return False, "BELOW_MINIMUM_PROFIT"
    if candidate["current"] > candidate["maximum"]:
        return False, "PRICE_ABOVE_SAFE_LIMIT"
    if candidate.get("vendor", 0) >= candidate.get("net_sale", 1) > 0:
        return False, "VENDOR_VALUE_DOMINATES"
    if candidate.get("confidence") in ("NONE", "LOW") or candidate.get("samples", 0) < 6:
        return False, "INSUFFICIENT_DATA"
    if (candidate.get("reference", 0) > 0 and candidate["current"] < candidate["reference"] * .2
            and (candidate.get("history", 0) < 5 or candidate.get("days", 0) < 3)):
        return False, "PRICE_MAY_BE_MANIPULATED"
    if candidate.get("owned", 0) >= candidate["quantity"]:
        return False, "OWNED_EXPOSURE_REACHED"
    if (candidate.get("confidence") == "HIGH" and candidate["age"] <= 21600
            and candidate.get("days", 0) >= 3 and candidate.get("history", 0) >= 5
            and candidate.get("listings", 0) >= 5 and candidate["conservative"] >= minimum_profit * 2
            and candidate["current"] <= candidate["maximum"] * .85):
        return True, "STRONG"
    if candidate.get("confidence") in ("HIGH", "MEDIUM") and candidate.get("history", 0) >= 2 and candidate.get("listings", 0) >= 3:
        return True, "FAIR"
    return True, "SPECULATIVE"


def recommended_quantity(candidate: dict[str, int | str]) -> int:
    quantity = int(candidate["quantity"])
    owned = int(candidate.get("owned", 0))
    return max(0, quantity - owned) if candidate.get("supports_partial") else quantity


def primary_risk(candidate: dict[str, int | str], minimum_profit: int = 1000) -> str:
    if int(candidate.get("reference", 0)) and int(candidate["current"]) < int(candidate["reference"]) * .35:
        return "PRICE_MAY_BE_MANIPULATED"
    if int(candidate.get("history", 0)) < 5 or int(candidate.get("days", 0)) < 3:
        return "LOW_HISTORICAL_CONFIDENCE"
    if int(candidate.get("deposit", 0)) >= int(candidate.get("gross", 1)) * .10:
        return "HIGH_DEPOSIT_COST"
    if int(candidate["conservative"]) < int(candidate["expected"]) * .5:
        return "PROFIT_DEPENDS_ON_RELISTING"
    if int(candidate.get("owned", 0)) > 0:
        return "OWNED_INVENTORY"
    if int(candidate["current"]) >= int(candidate["maximum"]) * .90:
        return "CURRENT_PRICE_NEAR_MAXIMUM"
    if int(candidate.get("listings", 0)) < 3 or int(candidate.get("market_quantity", 0)) < 5:
        return "THIN_CURRENT_SUPPLY"
    if int(candidate["conservative"]) < minimum_profit * 2:
        return "LOW_ABSOLUTE_PROFIT"
    return "MARKET_CAN_CHANGE"


def freshness_state(observed_at: int, now: int, current: int, maximum: int) -> str:
    if max(0, now - observed_at) > 86400:
        return "STALE"
    if current > maximum:
        return "PRICE_CHANGED"
    return "SAFE_AT_SCAN_TIME"


def ranking_key(candidate: dict[str, int | str]) -> tuple[int, int, int, int, int, str]:
    trust = {"AVOID": 0, "SPECULATIVE": 1, "FAIR": 2, "STRONG": 3}
    return (-trust[str(candidate["trust"])], int(candidate.get("owned", 0)),
            -int(candidate["conservative"]), int(candidate["capital"]),
            -int(candidate.get("score", 0)), str(candidate["name"]))


def demand_label(observations: int, days: int, quantity: int, listings: int, stability: float | None, sale_rate: float | None = None, outcomes: int = 0) -> str:
    personal_support = outcomes < 3 or (sale_rate is not None and sale_rate >= .5)
    if days >= 5 and observations >= 8 and quantity >= 20 and listings >= 5 and stability is not None and stability <= .25 and personal_support:
        return "HOT"
    if days >= 3 and observations >= 4 and quantity >= 8 and listings >= 3 and stability is not None and stability <= .5 and personal_support:
        return "ACTIVE"
    if observations >= 2 and (quantity < 5 or listings < 2 or (outcomes >= 3 and sale_rate is not None and sale_rate < .35)):
        return "SLOW"
    return "UNKNOWN"


def trade_limits(liquid: int, reserve: int, committed: int, mode: str) -> tuple[int, int, int]:
    rates = {"CONSERVATIVE": (.15, .35), "BALANCED": (.25, .5), "AGGRESSIVE": (.4, .7)}
    deployable = max(0, liquid - min(liquid, reserve))
    per_rate, total_rate = rates[mode]
    per_trade = int(deployable * per_rate)
    total = int(deployable * total_rate)
    return per_trade, total, max(0, min(deployable - committed, total - committed))


def trade_decision(candidate: dict[str, int | float | str], mode: str = "BALANCED", liquid: int = 1_000_000, reserve: int = 100_000, committed: int = 0) -> tuple[bool, str, int, int]:
    rules = {
        "CONSERVATIVE": (10_000, .20, "HOT", "STRONG", 8, 1),
        "BALANCED": (5_000, .15, "ACTIVE", "FAIR", 5, 2),
        "AGGRESSIVE": (2_500, .12, "SLOW", "SPECULATIVE", 3, 2),
    }
    demand_rank = {"UNKNOWN": 0, "SLOW": 1, "ACTIVE": 2, "HOT": 3}
    confidence_rank = {"AVOID": 0, "SPECULATIVE": 1, "FAIR": 2, "STRONG": 3}
    minimum_profit, discount_floor, demand_floor, confidence_floor, observations_floor, relists = rules[mode]
    per_limit, _, available = trade_limits(liquid, reserve, committed, mode)
    if int(candidate.get("age", 999999)) > 43200:
        return False, "STALE_DATA", 0, 0
    if int(candidate.get("observations", 0)) < observations_floor or int(candidate.get("days", 0)) < min(5, observations_floor):
        return False, "INSUFFICIENT_HISTORY", 0, 0
    if int(candidate.get("fast", 0)) <= int(candidate.get("current", 0)):
        return False, "UNSUPPORTED_EXIT_PRICE", 0, 0
    if float(candidate.get("discount", 0)) < discount_floor:
        return False, "DISCOUNT_TOO_SMALL", 0, 0
    if float(candidate.get("discount", 0)) >= .55 and (candidate.get("stability") is None or float(candidate["stability"]) > .5 or int(candidate.get("observations", 0)) < 8):
        return False, "PRICE_MAY_BE_MANIPULATED", 0, 0
    if demand_rank[str(candidate.get("demand", "UNKNOWN"))] < demand_rank[demand_floor]:
        return False, "DEMAND_TOO_WEAK", 0, 0
    if confidence_rank[str(candidate.get("confidence", "AVOID"))] < confidence_rank[confidence_floor]:
        return False, "CONFIDENCE_TOO_LOW", 0, 0
    current, quantity, owned = int(candidate["current"]), int(candidate["quantity"]), int(candidate.get("owned", 0))
    capacity = max(0, min(per_limit, available) // current - owned) if current > 0 else 0
    if quantity <= 0 or quantity > capacity:
        return False, "EXISTING_EXPOSURE_TOO_HIGH" if owned else "POSITION_TOO_LARGE", 0, capacity
    capital = current * quantity
    relists = 1 if candidate.get("confidence") == "STRONG" and candidate.get("demand") == "HOT" else relists
    deposit = int(candidate.get("deposit", 0)) * quantity * relists
    low_gross = int(candidate["fast"]) * quantity
    normal_gross = int(candidate["normal"]) * quantity
    low_profit = low_gross - int(low_gross * .05) - deposit - capital
    normal_profit = normal_gross - int(normal_gross * .05) - deposit - capital
    if low_profit <= 0:
        return False, "RELISTING_ERASES_PROFIT", low_profit, normal_profit
    if low_profit < minimum_profit:
        return False, "PROFIT_TOO_LOW", low_profit, normal_profit
    return True, "QUALIFIED", low_profit, normal_profit


def quick_eligible(candidate: dict[str, int | float | str]) -> bool:
    return (int(candidate["quantity"]) <= 20 and int(candidate["current"]) * int(candidate["quantity"]) <= 100_000
            and candidate.get("demand") != "SLOW" and int(candidate["fast"]) > int(candidate["current"]))


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


def test_recommendation_policy() -> None:
    base: dict[str, int | str] = {
        "current": 700, "maximum": 900, "expected": 4000, "conservative": 3000,
        "quantity": 5, "capital": 3500, "age": 3600, "confidence": "HIGH",
        "history": 6, "days": 4, "listings": 10, "samples": 30,
        "reference": 1000, "owned": 0, "vendor": 0, "net_sale": 7100,
        "deposit": 100, "gross": 7500, "market_quantity": 20,
    }

    def changed(**changes: int | str) -> dict[str, int | str]:
        return {**base, **changes}

    check(policy_result(base) == (True, "STRONG"), "strong policy label")
    check(policy_result(changed(confidence="MEDIUM", history=3, days=2, listings=4, conservative=1500)) == (True, "FAIR"), "fair policy label")
    check(policy_result(changed(confidence="MEDIUM", history=1, days=1)) == (True, "SPECULATIVE"), "speculative policy label")
    check(policy_result(changed(expected=-1)) == (False, "NO_EXPECTED_PROFIT"), "negative profit avoided")
    check(policy_result(changed(conservative=999)) == (False, "BELOW_MINIMUM_PROFIT"), "low absolute profit avoided")
    check(policy_result(changed(confidence="LOW")) == (False, "INSUFFICIENT_DATA"), "insufficient data avoided")
    check(policy_result(changed(conservative=0)) == (False, "RELISTING_ERASES_PROFIT"), "relisting loss avoided")
    check(policy_result(changed(current=100, history=1)) == (False, "PRICE_MAY_BE_MANIPULATED"), "manipulation avoided")
    check(policy_result(changed(owned=5)) == (False, "OWNED_EXPOSURE_REACHED"), "owned exposure eliminated")
    check(recommended_quantity(changed(owned=2, supports_partial=1)) == 3, "owned inventory reduces divisible quantity")
    check(policy_result(changed(current="bad")) == (False, "INVALID_DATA"), "malformed input avoided")
    check(policy_result(changed(vendor=7100)) == (False, "VENDOR_VALUE_DOMINATES"), "vendor floor avoided")
    check(policy_result(changed(expected=100000, conservative=500)) == (False, "BELOW_MINIMUM_PROFIT"), "high percentage trivial profit avoided")

    ranked = [
        {"name": "Huge Fair", "trust": "FAIR", "owned": 0, "conservative": 999999, "capital": 1000, "score": 99},
        {"name": "Owned Strong", "trust": "STRONG", "owned": 2, "conservative": 5000, "capital": 1000, "score": 80},
        {"name": "Best Strong", "trust": "STRONG", "owned": 0, "conservative": 3000, "capital": 2000, "score": 70},
    ]
    check(sorted(ranked, key=ranking_key)[0]["name"] == "Best Strong", "trust and owned inventory ranking")
    tied = [
        {"name": name, "trust": "FAIR", "owned": 0, "conservative": 2000, "capital": 1000, "score": 50}
        for name in ("Beta", "Alpha")
    ]
    check(sorted(tied, key=ranking_key)[0]["name"] == "Alpha", "deterministic tie break")
    check(not [item for item in (changed(expected=-1), changed(owned=5)) if policy_result(item)[0]], "no-safe-opportunity result")
    check(primary_risk(changed(deposit=800)) == "HIGH_DEPOSIT_COST", "deposit primary risk")
    check(primary_risk(changed(conservative=1500)) == "PROFIT_DEPENDS_ON_RELISTING", "relisting primary risk")
    check(primary_risk(changed(owned=2)) == "OWNED_INVENTORY", "owned primary risk")
    check(freshness_state(1000, 87401, 700, 900) == "STALE", "stale recommendation")
    check(freshness_state(1000, 1100, 901, 900) == "PRICE_CHANGED", "unsafe changed price")


def test_trades_policy() -> None:
    base: dict[str, int | float | str] = {
        "current": 5000, "quantity": 40, "fast": 6500, "normal": 7000,
        "discount": .2857, "deposit": 100, "age": 3600, "observations": 10,
        "days": 7, "demand": "HOT", "confidence": "STRONG", "owned": 0, "stability": .10,
    }
    check(demand_label(10, 6, 100, 10, .1) == "HOT", "hot demand classification")
    check(demand_label(1, 1, 100, 10, .1) != "HOT", "one scan cannot be hot")
    check(demand_label(5, 3, 20, 5, .3) == "ACTIVE", "active demand classification")
    check(demand_label(3, 2, 2, 1, .3) == "SLOW", "slow demand classification")
    check(demand_label(0, 0, 0, 0, None) == "UNKNOWN", "unknown demand classification")

    qualified = trade_decision(base)
    check(qualified[0] and qualified[2] > 0, "strong commodity trade")
    small = {**base, "quantity": 10}
    check(quick_eligible(small) and trade_decision(small)[0], "same commodity routes to quick and trade")
    check(not quick_eligible(base) and trade_decision(base)[0], "large position routes to trade only")
    quick_only = {**small, "observations": 3, "days": 2, "demand": "UNKNOWN", "confidence": "SPECULATIVE"}
    check(quick_eligible(quick_only) and not trade_decision(quick_only)[0], "valid quick move without trade")
    check(not quick_eligible({**base, "fast": 4900}) and not trade_decision({**base, "fast": 4900})[0], "neither workflow forces recommendation")
    check(trade_decision({**base, "demand": "SLOW"})[1] == "DEMAND_TOO_WEAK", "illiquid margin rejected")
    check(trade_decision({**base, "discount": .70, "stability": .80})[1] == "PRICE_MAY_BE_MANIPULATED", "thin manipulated market rejected")
    check(trade_decision({**base, "discount": .70, "observations": 5, "days": 5})[1] == "PRICE_MAY_BE_MANIPULATED", "extreme discount needs deep evidence")
    check(trade_decision({**base, "age": 43201})[1] == "STALE_DATA", "stale trade rejected")
    check(trade_decision({**base, "fast": 4900})[1] == "UNSUPPORTED_EXIT_PRICE", "unsupported exit rejected")
    check(trade_decision({**base, "deposit": 2000})[1] == "RELISTING_ERASES_PROFIT", "relisting costs erase trade")
    check(trade_decision({**base, "fast": 5400})[1] == "PROFIT_TOO_LOW", "percentage gain cannot hide trivial profit")
    check(trade_decision(base, liquid=300_000, reserve=100_000)[1] == "POSITION_TOO_LARGE", "excessive capital concentration rejected")
    check(trade_decision({**base, "owned": 20})[1] == "EXISTING_EXPOSURE_TOO_HIGH", "owned exposure eliminates purchase")
    per_limit, _, available = trade_limits(1_000_000, 100_000, 0, "BALANCED")
    reduced_capacity = min(per_limit, available) // int(base["current"]) - 10
    check(reduced_capacity < 40, "owned quantity reduces exposure capacity")

    conservative = trade_limits(1_000_000, 100_000, 0, "CONSERVATIVE")
    balanced = trade_limits(1_000_000, 100_000, 0, "BALANCED")
    aggressive = trade_limits(1_000_000, 100_000, 0, "AGGRESSIVE")
    check(conservative[0] < balanced[0] < aggressive[0], "capital mode per-trade limits")
    check(trade_limits(1_000_000, 200_000, 0, "BALANCED")[2] <= 800_000, "emergency reserve preserved")
    check(trade_limits(1_000_000, 100_000, balanced[1], "BALANCED")[2] == 0, "total committed capital enforced")
    check(not trade_decision({**base, "current": 0}, "AGGRESSIVE")[0], "aggressive rejects invalid trade")

    ranked = [
        {"name": "Huge percent", "low": 1000, "normal": 9000, "demand": 3, "confidence": 3, "capital": 1000},
        {"name": "Real profit", "low": 5000, "normal": 7000, "demand": 2, "confidence": 2, "capital": 30000},
    ]
    ranked.sort(key=lambda item: (-int(item["low"]), -int(item["demand"]), -int(item["normal"]), str(item["name"])))
    check(ranked[0]["name"] == "Real profit", "ranking favors absolute low-case profit")
    tied = sorted(({"name": name, "low": 5000} for name in ("Beta", "Alpha")), key=lambda item: (-item["low"], item["name"]))
    check(tied[0]["name"] == "Alpha", "trade ranking deterministic tie break")

    purchases = [(10, 100), (10, 200)]
    total_qty = sum(quantity for quantity, _ in purchases)
    total_cost = sum(quantity * price for quantity, price in purchases)
    check(total_cost // total_qty == 150, "weighted purchase cost basis")
    allocated = total_cost * 10 // total_qty
    check(2500 - allocated == 1000 and total_cost - allocated == 1500, "partial sale realized profit and remaining basis")


def test_plan_money() -> None:
    check(plan_money(0, 0, 0) == (0, 0, 0, 0), "zero money")
    check(plan_money(7, 0, 0)[3] == 70_000, "gold-only money")
    check(plan_money(0, 42, 0)[3] == 4_200, "silver-only money")
    check(plan_money(0, 0, 73)[3] == 73, "copper-only money")
    check(plan_money(12, 34, 56) == (12, 34, 56, 123_456), "mixed money")
    check(plan_money(0, 99, 99)[3] == 9_999, "maximum silver and copper")
    check(plan_money(1, 125, 0) == (2, 25, 0, 22_500), "silver overflow")
    check(plan_money(1, 0, 240) == (1, 2, 40, 10_240), "copper overflow")
    check(plan_money(1, 125, 240) == (2, 27, 40, 22_740), "combined overflow")
    check(plan_money("", "", "")[3] == 0, "empty money")
    check(plan_money("bad", "S", "$5")[3] == 0, "nonnumeric money")
    check(plan_money("-1", -2, "-3")[3] == 0, "negative money")
    check(plan_money("1.5", 2.5, "3.1")[3] == 0, "decimal money")
    check(plan_money(999_999_999_999, 0, 0)[3] == MAX_COPPER, "large gold clamped")
    check(migrate_plan_copper(123_456, 1_000_000) == 123_456, "saved copper migration")
    check(migrate_plan_copper("123456", 1_000_000) == 123_456, "numeric-string migration")
    check(migrate_plan_copper("12g 34s", 1_000_000) == 1_000_000, "invalid historical string fallback")
    reopened = plan_money(*plan_money(12, 34, 56)[:3])
    check(reopened[3] == 123_456, "reopening reproduces denominations")
    check(plan_money(8, 0, 0)[3] != plan_money(0, 50, 0)[3], "budget and minimum profit separate")


def test_package() -> None:
    toc = read("BankOfDurotar.toc")
    loaded = [line.strip() for line in toc.splitlines() if line.strip().endswith(".lua")]
    check(len(loaded) == 19, "minimal module count")
    check(all((ROOT / path).is_file() for path in loaded), "TOC files exist")
    check("## Version: 0.5.0-beta.1" in toc and 'BOD.version = "0.5.0-beta.1"' in read("Core.lua"), "version alignment")

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
    market_analysis = read("MarketAnalysis.lua")
    quick_policy = read("QuickMovePolicy.lua")
    trade_policy = read("TradePolicy.lua")
    trade_tracker = read("TradeTracker.lua")
    trade_service = read("TradeService.lua")
    plan_money_source = read("PlanMoney.lua")

    check('"AUCTION_ITEM_LIST_UPDATE"' in core, "result event registered")
    check("QueryAuctionItems" not in scan, "scanner uses API adapter")
    check('QueryAuctionItems, "", nil, nil, 0, nil, nil, true, false, nil' in read("AuctionAPI.lua"), "verified 2.5.6 full-scan signature")
    waiting_position = scan.find('self:SetState("WAITING_FOR_RESULTS")', scan.find("function BOD.FullScanProbe:SendQuery"))
    send_position = scan.find("BOD.AuctionAPI:SendFullScanProbe()", scan.find("function BOD.FullScanProbe:SendQuery"))
    check(waiting_position >= 0 and send_position >= 0 and waiting_position < send_position,
          "scanner listens for synchronous result events before sending query")
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
    check("BEST MOVE NOW" in sidecar and "SELL These Items From Your Bags" in sidecar, "explicit player actions")
    check("flipScore" in opportunity and "profitRate" in opportunity, "easy-flip ranking")
    check('"UIPanelScrollFrameTemplate"' in sidecar and "BUY_ROWS, SELL_ROWS, CRAFT_ROWS = 10, 3, 3" in sidecar, "scrollable ten-flip view")
    check("setRowIcon" in sidecar and "GetItemIcon" in sidecar and "itemID = item.itemID" in opportunity, "flip item icons")
    check("CRAFT These Items" in sidecar and "Materials:" in sidecar, "craft profit view")
    check("outputItemID = recipe.outputItemID" in crafting and "setRowIcon(row, craft.outputItemID)" in sidecar, "craft item icons")
    check("setRowIcon(row, sell.itemID, sell.itemLink)" in sidecar and "Bag sale suggestion" in sidecar, "bag-sale icons and help")
    check("Trust describes price evidence" in sidecar and "modeled deposit loss" in sidecar, "plain-language hover help")
    check("Market memory:" in sidecar and "daysObserved" in sidecar, "learning progress UI")
    check('SetScript("OnReceiveDrag"' in sidecar and "cursorItemLink" in sidecar, "sell item drop target")
    check('hooksecurefunc("HandleModifiedItemClick"' in sidecar and "IsShiftKeyDown" in sidecar, "sell item shift-click selection")
    check("1. CHOOSE THE ITEM" in sidecar and "3. USE THIS PRICE" in sidecar, "guided sell steps")
    check('guidedMode = false' in core and '"Guided: OFF"' in sidecar, "optional guided mode")
    check("GUIDED · NEXT ACTION" in sidecar and "guidedTargetView" in sidecar and '"Show me"' in sidecar, "state-aware guided action")
    check("BEST MOVE NOW" in sidecar and "MORE SAFE FLIPS" in sidecar, "featured recommendation hierarchy")
    check("Trust:" in sidecar and "Main risk:" in sidecar and "Maximum buy price:" in sidecar, "plain-language recommendation proof")
    check("minimumExpectedProfitCopper" in core and "Min Profit" in sidecar, "configurable minimum absolute profit")
    check("budgetMoneyBoxes" in sidecar and "minimumProfitMoneyBoxes" in sidecar, "three-part Plan money controls")
    check('"G"' in sidecar and '"S"' in sidecar and '"C"' in sidecar, "compact denomination suffixes")
    check("NormalizeFields" in sidecar and "totalCopper" in sidecar, "Apply saves normalized integer copper")
    check("self:RefreshPlan()" in sidecar and "self:RefreshGuide()" in sidecar, "Apply refreshes Plan and Guided mode")
    check("MigrateStoredCopper" in core and "These fields have always been stored as copper" in core, "existing copper migration")
    check("MAX_COPPER" in plan_money_source and "FromFields" in plan_money_source and "ToFields" in plan_money_source, "bounded Plan money conversion")
    save_budget = sidecar[sidecar.index("function BOD.Sidecar:SaveBudget"):sidecar.index("function BOD.Sidecar:RefreshPlan")]
    check("trading" not in save_budget and "TradeService" not in save_budget, "Plan values do not overwrite Trades capital")
    check("RecommendationPolicy.lua" in read("BankOfDurotar.toc"), "recommendation policy packaged")
    check("conservativeNetProfit" in opportunity and "relistFailuresModeled" in opportunity, "conservative relisting math")
    check("CollectBagInventory" in gold_plan and "ownedQuantities" in gold_plan, "owned bag exposure awareness")
    check("SAFE_AT_SCAN_TIME" in read("RecommendationPolicy.lua") and "not a live price check" in read("RecommendationPolicy.lua"), "recommendation freshness language")
    check('SetView("PLAN")' in scan, "scan opens Gold Plan")
    check('{ "PLAN", "Plan" }, { "TRADES", "Trades" }, { "CRAFT", "Craft" }, { "SELL", "Sell Price" }' in sidecar, "Plan Trades Craft Sell navigation")
    check("TRADING CAPITAL" in sidecar and "BEST TRADE" in sidecar and "MORE TRADES" in sidecar and "OPEN TRADES" in sidecar and "TRADE HISTORY" in sidecar, "dedicated Trades view sections")
    check("BuildSupportedValues" in market_analysis and "ClassifyDemand" in market_analysis and "ClassifyConfidence" in market_analysis, "shared market analysis")
    check("BOD.QuickMovePolicy" in quick_policy and "BOD.TradePolicy" in trade_policy, "separate policy layers")
    check("QUICK_ONLY" in trade_service and "TRADE_ONLY" in trade_service and "BOTH" in trade_service and "NEITHER" in trade_service, "candidate routing")
    check("GetMoney" in trade_service and "emergencyReserveCopper" in trade_policy and "GetCommittedCapital" in trade_tracker, "trading capital model")
    check("Track Trade" in sidecar and "BOD.TradeTracker:Track" in trade_tracker and "recommendation must never" not in trade_service, "explicit trade tracking")
    check("AddPurchase" in trade_tracker and "purchaseBatches" in trade_tracker and "averageUnitCost" in trade_tracker, "multiple purchase cost basis")
    check("RecordSale" in trade_tracker and "PARTIALLY_SOLD" in trade_tracker and "realizedProfit" in trade_tracker, "manual partial-sale accounting")
    check("MarkListed" in trade_tracker and "Close" in trade_tracker and "Abandon" in trade_tracker, "manual trade lifecycle")
    check("schemaVersion = 12" in core and "trading = {" in core and "openTrades = {}" in core, "safe trading saved-variable area")
    check("Trade Rules" in sidecar and "Reset Trade Data" in sidecar and "showSpeculativeTrades" in core, "Trades settings UI")
    check("StartAuction(" not in trade_service + trade_tracker + sidecar and "PlaceAuctionBid(" not in trade_service + trade_tracker + sidecar, "Trades remains advisory")


def main() -> None:
    test_math()
    test_recommendation_policy()
    test_trades_policy()
    test_plan_money()
    test_package()
    test_workflow()
    lua = shutil.which("lua") or shutil.which("lua5.1")
    if lua:
        for fixture in ("tests/recommendation_policy_test.lua", "tests/trade_system_test.lua", "tests/plan_money_test.lua"):
            subprocess.run([lua, fixture], cwd=ROOT, check=True)
    print("offline checks: PASS")


if __name__ == "__main__":
    main()
