# Bank of Durotar

Bank of Durotar `0.4.0` is a small Auction House helper for WoW Classic Anniversary.

## What it does

1. Enter the amount of gold you are willing to spend.
2. Open the Auction House and click `SCAN MARKET`.
3. Review up to ten ranked items to flip that fit the budget.
4. Review up to three unbound items already in your bags and their suggested sell prices.
5. Open each profession window once, then review up to three profitable crafts.

The addon stores the latest market snapshot plus compact daily averages for up to 1,000 active items over 30 days. Repeated scans build the historical baseline used to judge buys and protect craft estimates from one-scan price spikes. It also learns successful and expired auctions whenever you open your mailbox, then uses that personal sale rate to demote items that do not sell for you. The UI shows scans learned, days observed, and tracked items without exposing database details. Each buy suggestion is one exact cheapest stack. The scrollable list ranks up to ten candidates by estimated flip ease using price confidence, repeated observations, current market depth, return on gold spent, and personal sold-versus-expired history. No single buy can use more than half the budget, and the whole plan cannot exceed the budget. Craft estimates use conservative material prices, known cooldown availability, and require at least a 15% estimated margin. Estimates include the 5% Auction House cut, expected deposit losses, and vendor-value comparisons, but future prices can never be guaranteed. Buying, selling, vending, and crafting remain manual.

## Commands

```text
/bod                 Open the addon
/bod scan            Scan the market
/bod buy             Show the Gold Plan
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
- No individual suggested buy costs more than half the budget.
- Bag suggestions show no more than three unbound items with quantities and prices; single-item gear requires an exact variant match.
- Opening each profession teaches the addon its currently visible known recipes.
- `Craft for Profit` shows material cost, sell price, estimated profit, and margin.
- Empty or weak market data produces a clear no-safe-result message instead of a guess.
- `Sell Price` accepts a typed or shift-clicked item and returns a price or a clear no-data message.
- No Lua error, taint warning, disconnect, automatic purchase, or automatic listing occurs.

This release targets the verified legacy Auction House API on Classic Anniversary interface `20506` (client 2.5.6). The scanner has completed a live full-market scan on that client. Version `0.4.0` keeps the compact daily market history and adds bounded personal mailbox outcome history.
