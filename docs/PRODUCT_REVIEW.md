# Bank of Durotar Product Review

## Implemented product split

Plan/Best Move Now remains the beginner workflow for one small, sensible next action. Trades is a separate deliberate-capital workspace for larger stackable commodity positions that justify multi-day evidence and explicit lifecycle tracking. A candidate can qualify for either, both, or neither at different policy limits. Temporary Plan output never becomes a tracked trade.

Trades deliberately resembles a lightweight Auction House desk rather than a brokerage dashboard: actual gold, reserve, committed capital, one primary trade, two alternatives, open records, and history. It avoids charts, fabricated volume, exact time-to-sale predictions, and guaranteed-return language.

## Executive assessment

Bank of Durotar 0.5.0-beta.1 is a working, calculation-only Auction House advisor for WoW Classic Anniversary. Its strongest product decision is restraint: a player deliberately starts one full-market scan, the addon stores bounded local data, and all buying, posting, vending, crafting, and trade tracking remain manual. It covers the core scan → quick moves or larger trades → bag-sale suggestions → craft suggestions loop.

The largest gap is not missing breadth. It is the distance between what the recommendation UI appears to know and what the Classic API actually reveals. The addon observes listings, not realm-wide completed sales. It has a small personal sold/expired sample from mailbox invoices, but no broad sale velocity, seller count, current owned auctions, cost basis, bank/mail inventory, or repeated-relisting model. The next product phase should improve trust, purchase sizing, and outcome tracking before adding more markets or automation.

## Current architecture

The `.toc` loads 12 production modules in dependency order:

| Module | Current responsibility |
| --- | --- |
| `Core.lua` | Saved-variable defaults/migration, event fan-out, slash commands, money formatting, error reporting. |
| `AuctionAPI.lua` | Legacy Auction House detection, query readiness, full-scan call, and normalized listing reads. |
| `MarketData.lua` | In-memory scan aggregation and one compact current snapshot per realm/faction/project. |
| `MarketHistory.lua` | Bounded 30-day daily averages for up to 1,000 high-sample items. |
| `SalesHistory.lua` | Bounded personal sold/expired outcomes learned from mailbox contents. |
| `PricingService.lua` | Sale-price recommendation, freshness/confidence, low-outlier handling, cut/deposit/vendor economics. |
| `OpportunityService.lua` | Buy-candidate filtering, reference price, estimated upside, confidence, and flip/ease ranking. |
| `GoldPlan.lua` | Budget-constrained selection of up to ten buys and three bag-sale candidates. |
| `CraftingService.lua` | Captures visible known recipes and ranks up to three profitable crafts. |
| `FullScanProbe.lua` | Player-initiated full-scan state machine, cooldown polling, timeouts, chunked result processing. |
| `Sidecar.lua` | Dockable Plan/Craft/Sell UI, guided walkthrough, item drop/shift-click selection, scrollable flips. |
| `MinimapButton.lua` | Movable launcher and two-action quick menu. |

The boundaries are generally good. Data acquisition, storage, calculations, workflow composition, and presentation are separate. `PricingService` does not perform transactions, and production code contains no calls that buy, post, cancel, simulate input, or chain protected actions.

## Saved-variable structure

`BankOfDurotarDB` uses top-level schema version 11:

- `marketData` schema 3: a single `currentSnapshot` plus its ID.
- `scan` schema 1: last full query, last completion, and last availability state.
- `history` schema 3: realm key, item daily rows, scan-day counts, totals, and cleanup metadata.
- `crafting` schema 1: up to 12 character/profession sets, each capped at 400 recipes.
- `salesHistory` schema 1: up to 500 personal outcome records plus mailbox fingerprints.
- `settings`: minimap state, docking/open behavior, active view, Guided mode, budget, and window position.

Storage is deliberately compact. Raw auctions are retained only while processing a scan; the persisted snapshot contains per-item aggregates. History retains daily average median price, quantity, and listing count for 30 days. This protects SavedVariables size but permanently discards seller identities, price-level distribution, minimum-stack availability beyond the single cheapest stack, and intraday volatility.

## What works now

### Data and scanning

- Detects the verified legacy Auction House API on Classic Anniversary interface 20506.
- Requires a deliberate click for every full scan.
- Checks `CanSendAuctionQuery`/`canQueryAll`, prevents overlap, supports cancellation, and shows cooldown state.
- Uses token checks, explicit timeouts, a two-second quiet window, and 500-record processing chunks.
- Rejects missing identity, invalid stack/buyout, malformed numbers, and integer-overflow risks.
- Separates stackable items by item ID and single-item equipment by full item string when available.
- Persists only a completed snapshot and preserves the previous snapshot after failed/cancelled scans.

### Recommendations

- Normalizes all market comparisons to unit buyout.
- Uses current medians/weighted medians and, with enough observations, a conservative seven-day historical median.
- Includes the 5% Auction House cut and an estimated deposit loss.
- Rejects no-buyout records, insufficient samples, stale/expired data, weak confidence, unsafe margins, and poor personal sale history.
- Suggests one exact cheapest stack per buy, limits one item to half the budget, and keeps the combined plan within the entered budget.
- Provides a scrollable top-ten flip list with item name, icon, stack cost, target, estimated profit, return, listings, scans, and personal outcomes when known.
- Inspects unbound bag inventory and recommends Auction House or vendor disposition.
- Captures known recipes when a profession is opened and estimates profitable crafts using conservative reagent prices.

### User experience

- Opens alongside the Auction House when configured and falls back to a movable standalone window.
- Offers Plan, Craft, and Sell Price views.
- Supports typed, dragged, or shift-clicked sell-item selection.
- Includes an optional eight-step Guided mode.
- Provides slash commands and a movable minimap button.
- Keeps all actual purchases, posts, vending, and crafting in Blizzard's UI.

## Present but incomplete

| Area | What exists | What is incomplete |
| --- | --- | --- |
| Flip ease | A 0–100 `flipScore` combining confidence, observations, listing/quantity depth, return, and personal outcomes. | Supply is not demand; the precise number overstates what the data can prove. No seller count, sale time, volatility, or market-wide sales exists. |
| Price wall | A low listing can be ignored when it is below 70% of median in a market with at least four listings. | Persisted data has no price levels after scan aggregation, so the engine cannot identify a genuine wall or manipulation cluster. |
| History | 7/30-day weighted medians of daily averages, quantity, and listings. | No low/high/range, volatility, trend, seller diversity, time-of-day context, or category context. Cleanup exists but is not called by production events. |
| Deposit risk | Deposit estimated as 30% of vendor value for a 24-hour listing, multiplied by estimated failure rate. | Duration is not selected; faction/neutral rules are not represented; repeated relists and lost deposits are not modeled. |
| Personal sales | Mailbox invoices learn sold and expired counts. | No acquisition cost, quantity, duration, number of relists, time to sale, active auctions, or realized profit. Identical mailbox fingerprints are approximate. |
| Capital plan | Entered budget, half-budget per item cap, greedy portfolio selection. | Not connected to current money; no reserve, inventory exposure, category concentration, risk-adjusted cap, or already-posted capital. |
| Bag selling | Reads bags 0–4, excludes explicitly bound items, chooses auction vs vendor. | No bank, mail, reagent bank equivalent, alts, reserved materials, active auctions, or optimal stack count. |
| Crafting | Captures known visible recipes, reagent costs, output price, cooldown, budget, and personal sale penalty. | No vendor-only reagents, owned-material opportunity cost view, craftable quantity, inventory reservations, transformations without standard recipes, or recipe freshness warning. |
| Guided mode | Eight Back/Next explanations that navigate views. | It explains rather than verifies completion; it does not react to scan/budget/item state or point to the exact next control. |
| Tests | Offline package/source checks plus Lua fixtures for aggregation and cooldown calculation. | Most economics, opportunity ranking, history, mailbox deduplication, crafting, migrations, UI state, and full scan lifecycle lack behavioral fixtures. |

## Planned but not implemented

These remain useful ideas from the earlier roadmap, but are not current features:

- Cost basis and realized-profit tracking.
- Account-wide inventory.
- Existing owned-auction awareness.
- Risk/liquidity labels backed by a defensible trust model.
- Sell/hold/relist decisions and stack-size planning.
- Tooltip market valuation outside the recommendation rows.
- Market-data maintenance/status controls.
- Disenchant and non-recipe transformation opportunities.
- Blizzard-UI-assisted search/posting research.

Full-market scanning, bounded market history, deal recommendations, selling-price recommendations, bag suggestions, crafting profitability, and the Guided Gold Plan were listed as future milestones in older documents but are implemented now. They must not be proposed as new features.

## Retired or no longer relevant

- The old six-row targeted-search sidecar and its search/filter/sort controller were removed.
- Developer diagnostics, API probes, settings panel, and transaction probe were removed from the production package.
- Direct addon posting through `StartAuction` is a permanent no-go unless a new compliance review explicitly reopens it. A live test caused Blizzard to disable the addon for the session.
- The old proposed 60-day detailed/compacted history was replaced by a smaller 30-day daily-average model.
- Modern `C_AuctionHouse` support is detected but not implemented and is outside the current Classic Anniversary target.

## Current player workflow and friction

1. **Open the Auction House.** The sidecar opens and shows a scan button. Friction: a new player may not understand why a scan is required or why Blizzard's cooldown can disable it.
2. **Enter a budget.** The player types a gold amount. Friction: this is not actual liquid gold and does not preserve an emergency reserve or count existing exposure.
3. **Run a full scan.** One click starts a scan; the UI waits for events and processes results. Friction: the cooldown estimate is provisional; a quiet window may mark an incomplete result set complete if client behavior changes.
4. **Review the top flips.** The player sees a ranked list. Friction: `Flip score 0–100` looks more certain than the available supply-only market data supports; no expected sell range, volatility, concentration, or time-to-sale estimate is shown.
5. **Find the auction manually.** The player searches in Blizzard's UI and locates a stack. Friction: the recommendation can become stale between scan and purchase; the player can select the wrong suffix, stack, or a newly overpriced listing.
6. **Purchase manually.** The addon does not know that the purchase occurred. Friction: no cost basis, duplicate-purchase prevention, remaining-capital update, or post-buy instructions.
7. **Relist or use the item.** Sell Price offers an exact manual price. Friction: no current owned-auction check, stack-size choice, duration advice, or relisting-loss scenario.
8. **Collect mail later.** Sold/expired outcomes are learned when the mailbox opens. Friction: gross/net values are not tied to the original purchase, stack quantity, number of attempts, or time held.
9. **Evaluate profitability.** The UI can improve future sale-rate penalties but cannot report realized flip profit. The player must remember acquisition cost and deposits.

## Where profit can be overstated

- One expected deposit loss is not the same as two or three failed relists.
- A listing-rich market can still have weak demand; current supply is not sales velocity.
- Current median can be manipulated by one seller with many auctions because seller identity is discarded.
- Daily averages hide intraday spikes and price range.
- A seven-day median built from repeated same-day scans can overweight one day.
- The cheapest exact stack may be an isolated outlier or may disappear before the player buys it.
- `resaleTargetUnitPrice` is a supported reference, not a guaranteed executable sale price.
- Personal sale rate is sparse and can mix different quantities, durations, and pricing decisions.
- Deposit uses a hard-coded 24-hour approximation and does not verify the actual posting duration.
- Craft profit assumes all reagents are acquired at conservative market value and all output sells as one planned stack; it does not value time, recipe scarcity, or multiple relists.
- Vendor-priced inventory is correctly compared as a floor but must never be counted as liquid gold until actually vendored.

## Performance-sensitive paths

- Full scans call `GetAuctionItemInfo`, `GetAuctionItemLink`, optional time-left, and `GetItemInfo` for every listing. Chunking limits frame stalls, but all per-item unit prices and weighted samples are held until finalization and sorted to compute medians.
- `MarketData:GetCurrentItemByItemID`, `GetBestCurrentItemByItemID`, and name searches scan all snapshot items linearly. Craft recommendation evaluation can repeat those scans for every output and reagent.
- `GoldPlan:GetBagSellCandidates` walks every bag slot on each Plan refresh. Bag/item-info events can trigger frequent refreshes.
- `CraftingService:GetRecommendations` walks all captured recipes and repeatedly requests market/history/pricing summaries.
- `Sidecar:Refresh` rebuilds Plan, Craft, and Sell only for the active view, which helps, but scan/cooldown events can still refresh frequently.
- Market history cleanup is implemented but has no observed production caller.

## Classic API assumptions and constraints

- Target: WoW Classic Anniversary 2.5.6, interface 20506, project ID 5, legacy Auction House API.
- Verified legacy globals include `QueryAuctionItems`, `CanSendAuctionQuery`, `GetNumAuctionItems`, `GetAuctionItemInfo`, `GetAuctionItemLink`, and `GetAuctionItemTimeLeft`.
- Full scan uses `QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)` and relies on `canQueryAll` plus repeated `AUCTION_ITEM_LIST_UPDATE` events.
- A 900-second cooldown is an estimate; the server-reported `canQueryAll` is authoritative.
- Direct posting is no-go. No proposed roadmap item may depend on automatic buying, posting, cancelling, simulated clicks, background transactions, or external data/services.
- The client exposes listings, not global completed-sale volume. Any demand or time-to-sale label must be inferred and visibly qualified.

## Existing validation

- `tests/run_offline_checks.py` checks package composition, prohibited transaction calls, key source invariants, basic math, and feature presence.
- `tests/market_data_test.lua` checks aggregation, medians, item identity, rejection counters, snapshot replacement, and failed-scan preservation.
- `tests/full_scan_cooldown_test.lua` checks readiness/cooldown state math, malformed saved state, and single cooldown polling.
- The README contains a manual live-test checklist.
- The release archive contains only the 12 production Lua files and `.toc`; it excludes README/tests/docs.

The offline suite is useful as a guardrail, but many checks are string-presence assertions rather than behavior tests. The highest-risk calculations need deterministic Lua fixtures before their output should be made more prominent.

## Five biggest weaknesses

1. The UI expresses flip ease more precisely than the data warrants.
2. No cost basis or realized-profit loop connects recommendations to actual outcomes.
3. Capital protection ignores actual money, current inventory exposure, owned auctions, categories, and reserves.
4. Deposit/relisting risk is approximate and can materially overstate profit on slow items.
5. The manual recommendation-to-purchase handoff allows stale-price and wrong-item mistakes.

## Product direction

Keep the three primary jobs: scan, recommend safe opportunities, and guide manual action. Add trust and capital protection before adding breadth. Every normal row should answer what to do, how much, likely net benefit, risk, evidence strength, and the next manual action. Advanced evidence belongs in hover/expanded detail. The addon should prefer `Wait` or `Avoid` over manufacturing an opportunity.
