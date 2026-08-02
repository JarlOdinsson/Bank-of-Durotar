# Bank of Durotar

Bank of Durotar `0.5.0-beta.1` is a small Auction House helper for WoW Classic Anniversary.

## What it does

1. Enter the Gold, Silver, and Copper you are willing to spend in Plan's Budget fields.
2. Open the Auction House and click `SCAN MARKET`.
3. Set the smallest profit worth pursuing with the separate Min Profit Gold, Silver, and Copper fields (10 silver by default), then review one featured best move and up to nine additional safe flips.
4. Open `Trades` for larger, evidence-backed commodity positions and explicitly track any position you accept.
5. Review up to three unbound items already in your bags and their suggested sell prices.
6. Open each profession window once, then review up to three profitable crafts.

The addon stores the latest market snapshot plus compact daily averages for up to 1,000 active items over 30 days. Repeated scans build the historical baseline used to judge buys and protect estimates from one-scan spikes. Plan remains the quick workflow. Trades uses stronger multi-day evidence, actual character gold, a reserve, controlled exposure, supported exit ranges, and low/normal profit ranges for exact stackable commodity listings. A recommendation becomes an open trade only when `Track Trade` is clicked. Purchase batches, listings, sales, closing, and abandonment are recorded manually; current market value is never called realized profit. The addon also learns successful and expired auctions whenever the mailbox is opened. Buying, selling, vending, crafting, and all protected actions remain manual.

## Commands

```text
/bod                 Open the addon
/bod scan            Scan the market
/bod buy             Show the Gold Plan
/bod trades          Show larger tracked trade opportunities
/bod sell            Show sell-price advice
/bod craft           Show profitable known crafts
/bod minimap show    Show the minimap button
/bod minimap hide    Hide the minimap button
/bod minimap reset   Reset its position
```

## Install

Copy the `BankOfDurotar` folder into the active Classic Anniversary `Interface/AddOns` directory, then run `/reload`.

## Live test

Open the Auction House and confirm:

- No scan starts automatically.
- `SCAN MARKET` starts exactly one scan or clearly shows Blizzard's cooldown.
- A completed scan opens `Gold Plan` with the saved budget.
- The plan shows no more than ten ranked buys and their combined cost never exceeds the budget.
- The first buy is visually featured and shows icon/name, exact quantity, owned count, maximum price, conservative profit, trust, main risk, and latest-scan wording.
- Guided mode changes with Auction House, scan, Plan, Craft, and Sell states and can always be turned off.
- Navigation reads `Plan | Trades | Craft | Sell Price`; Trades shows actual liquid gold, reserve, available/committed capital, one best trade, two secondary trades, open trades, and history.
- Tracking a trade performs no purchase. Multiple manual purchase batches produce a weighted cost basis, and manual partial sales preserve remaining basis.
- No individual suggested buy costs more than half the budget.
- Bag suggestions show no more than three unbound items with quantities and prices; single-item gear requires an exact variant match.
- Opening each profession teaches the addon its currently visible known recipes.
- `Craft for Profit` shows material cost, sell price, estimated profit, and margin.
- Empty or weak market data produces a clear no-safe-result message instead of a guess.
- `Sell Price` accepts a typed or shift-clicked item and returns a price or a clear no-data message.
- No Lua error, taint warning, disconnect, automatic purchase, or automatic listing occurs.

This beta targets the verified legacy Auction House API on Classic Anniversary interface `20506` (client 2.5.6). The scanner completed a live full-market scan on that client before the Trades work; the new `0.5.0-beta.1` Trades UI and lifecycle still require in-game validation.
