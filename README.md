# Bank of Durotar

Bank of Durotar `0.5.0-beta.3` is a small Auction House helper for WoW Classic Anniversary.

## What it does

1. Enter the Gold, Silver, and Copper you are willing to spend in Plan's Budget fields.
2. Open the Auction House. Bank of Durotar immediately reuses the newest valid scan for the current market, or offers `SCAN MARKET` when no cache exists.
3. Set the smallest profit worth pursuing with the separate Min Profit Gold, Silver, and Copper fields (10 silver by default), then review one featured best move and up to nine additional safe flips.
4. Open `Shop`, choose an exact item, and optionally enter an additional quantity and budget. Shop shows the whole-stack purchase path, cumulative weighted cost, conservative stop, and any price cliff from the saved scan.
5. Open `Trades` for larger, evidence-backed commodity positions and explicitly track any position you accept.
6. Review up to three unbound items already in your bags and their suggested sell prices.
7. Open each profession window once, then review up to three profitable crafts.

The addon stores the latest market snapshot plus compact daily averages for up to 1,000 active items over 30 days. Repeated scans build the historical baseline used to judge buys and protect estimates from one-scan spikes. Plan remains the quick workflow. Trades uses stronger multi-day evidence, actual character gold, a reserve, controlled exposure, supported exit ranges, and low/normal profit ranges for exact stackable commodity listings. A recommendation becomes an open trade only when `Track Trade` is clicked. Purchase batches, listings, sales, closing, and abandonment are recorded manually; current market value is never called realized profit. The addon also learns successful and expired auctions whenever the mailbox is opened. Buying, selling, vending, crafting, and all protected actions remain manual.

Shop and Plan share the same acquisition evaluator. It considers whole auction stacks, cumulative cost, conservative resale friction, evidence quality, and available depth. Shop's target is the additional quantity to purchase—not total desired ownership—and its optional budget is a hard spending limit. It recommends stopping before an unsafe price or a price cliff. These are saved-scan estimates, never live listings or guaranteed profit.

The latest successful scan is reused after reopening the Auction House, `/reload`, or logout when the project, region, realm, and faction market scope match. A replacement scan is committed atomically, so cancellation, timeout, invalid data, or closing the Auction House cannot destroy the previous completed snapshot. The sidecar labels cache age and coverage; cached data is never described as live. Refreshes remain manual. Sell Price and selected Trades can run a player-clicked current-item check without pretending the whole market was refreshed.

Freshness is explicit:

- **Fresh:** less than 1 hour old
- **Recent:** 1–4 hours old
- **Aging:** over 4–12 hours old
- **Stale:** over 12–24 hours old
- **Historical only:** over 24 hours old

Plan lowers confidence as data ages. Trades defaults to a stricter 12-hour limit and halves allowed position exposure after four hours. Sell Price requires a targeted current-item check after its configured age limit. Existing tracked Trades and historical records remain available even when market data is old.

## Commands

```text
/bod                 Open the addon
/bod scan            Scan the market
/bod buy             Show the Gold Plan
/bod shop            Evaluate one exact item from the saved scan
/bod trades          Show larger tracked trade opportunities
/bod sell            Show sell-price advice
/bod craft           Show profitable known crafts
/bod minimap show    Show the minimap button
/bod minimap hide    Hide the minimap button
/bod minimap reset   Reset its position
/bod cache           Show cached scan status
/bod cache clear     Begin cache-clear confirmation
```

## Install

Copy the `BankOfDurotar` folder into the active Classic Anniversary `Interface/AddOns` directory, then run `/reload`. After upgrading to beta.3, run one fresh player-clicked market scan to populate Shop's bounded listing depth; an older cached scan remains usable but contains only its cheapest known stack.

## Repository workflow

Use one canonical working copy for development and Git publishing. Treat any game AddOns folder or separate build folder as a deployment destination only: copy outward from the canonical repository and never copy deployment files back over development. This avoids losing commits, tests, or documentation.

To publish with GitHub Desktop:

1. Add the canonical repository with **File → Add local repository**.
2. Confirm the intended feature branch is selected.
3. Confirm the Changes tab is empty after the local commit.
4. Click **Push origin**.
5. Create a pull request from the feature branch into `main`.
6. After merging, select `main` in any secondary clone and use **Fetch origin**, then **Pull origin**.

Do not commit generated archives, unrelated folders, SavedVariables, or accidental terminal-output files.

## Architecture and safety

- `MarketCache.lua` owns scope isolation, cache migration, freshness labels, bounded retention, and targeted overlays.
- `MarketData.lua` owns compact scan aggregation and atomic completed-snapshot replacement.
- `AcquisitionEvaluator.lua` owns bounded whole-stack acquisition sizing used by both Plan and Shop.
- `RecommendationPolicy.lua`, `QuickMovePolicy.lua`, and `TradePolicy.lua` keep quick recommendations separate from larger tracked positions.
- `PlanMoney.lua` keeps Plan money settings in normalized integer copper.
- `TargetedScan.lua` performs only player-requested item checks and never marks the full market as refreshed.

Bank of Durotar does not automate buying, bidding, posting, cancellation, crafting, confirmation dialogs, or simulated clicks. Every protected Auction House action remains under player control.

## Live test

Open the Auction House and confirm:

- No scan starts automatically.
- Reopening the Auction House or running `/reload` immediately restores a valid matching cached scan.
- Cache status shows age, auction count, item count, coverage, and an exact completion timestamp under `Scan Details`.
- A canceled, interrupted, or invalid refresh continues using the previous completed scan.
- Data from another realm or faction is not reused.
- `SCAN MARKET` starts exactly one scan or clearly shows Blizzard's cooldown.
- The first completed beta.3 scan populates bounded Shop depth; an older cached scan explicitly asks for a fresh scan instead of inventing missing listings.
- A completed scan opens `Gold Plan` with the saved budget.
- The plan shows no more than ten ranked buys and their combined cost never exceeds the budget.
- The first buy is visually featured and shows icon/name, exact quantity, owned count, maximum price, conservative profit, trust, main risk, and latest-scan wording.
- Guided mode changes with Auction House, scan, Plan, Craft, and Sell states and can always be turned off.
- Navigation reads `Plan | Shop | Trades | Craft | Sell`; Trades shows actual liquid gold, reserve, available/committed capital, one best trade, two secondary trades, open trades, and history.
- Shop accepts an exact typed name, Shift-clicked link, or dragged item; target means additional quantity to buy, not desired total ownership.
- Shop shows no more than 12 seller-free stack/price groups, honors whole stacks and the optional budget, and warns when an older snapshot lacks depth.
- Tracking a trade performs no purchase. Multiple manual purchase batches produce a weighted cost basis, and manual partial sales preserve remaining basis.
- No individual suggested buy costs more than half the budget.
- Bag suggestions show no more than three unbound items with quantities and prices; single-item gear requires an exact variant match.
- Opening each profession teaches the addon its currently visible known recipes.
- `Craft for Profit` shows material cost, sell price, estimated profit, and margin.
- Empty or weak market data produces a clear no-safe-result message instead of a guess.
- `Sell Price` accepts a typed or shift-clicked item and returns a price or a clear no-data message.
- An old Sell Price recommendation requests `Check Current Item`; that targeted check does not alter the full-scan timestamp.
- No Lua error, taint warning, disconnect, automatic purchase, or automatic listing occurs.

This beta targets the verified legacy Auction House API on Classic Anniversary interface `20506` (client 2.5.6). The scanner completed a live full-market scan on that client before the Trades work; the `0.5.0-beta.3` Shop depth, cache, targeted checks, Trades UI, and lifecycle still require in-game validation.
