# Trades System

## Cached-data policy

Trades uses the completed snapshot for the current market scope and defaults to a 12-hour maximum. Aging data over four hours halves allowed position capital; because Classic listings are indivisible, an exact stack that no longer fits is rejected. A targeted item check may verify entry price but never resets full-scan age. Existing tracked positions remain available with old or missing market data.

## Product roles

- **Plan** is the fast workflow. A **quick move** is a small, simple recommendation that does not need lifecycle tracking.
- **Best Move Now** is Plan's single clearest current action. It is not selected by percentage margin alone.
- **Trades** is the deliberate-capital workflow for supported stackable commodity positions.
- An **open trade** or **tracked trade** exists only after the player clicks `Track Trade`.
- **Estimated profit** is a forward-looking range after modeled fees. It is not realized profit.
- **Cost basis** is the recorded purchase cost allocated to remaining units.
- **Realized profit** uses recorded net sale revenue minus the allocated recorded purchase cost. Current listings are never substituted for revenue.

## Architecture

Trades reuses the existing completed market snapshot, compact 30-day daily history, personal mailbox outcomes, bag inventory, pricing economics, money formatting, and Sidecar patterns. It does not create another market database.

- `MarketAnalysis.lua`: shared supported value, exit range, stability, demand, confidence, ownership, and freshness.
- `QuickMovePolicy.lua`: Plan-oriented simplicity and exposure gates on top of the existing safety policy.
- `TradePolicy.lua`: trade qualification, capital modes, position size, profit range, risk, and ranking.
- `TradeService.lua`: candidate routing and the top three qualified trades.
- `TradeTracker.lua`: explicit lifecycle, purchase batches, remaining cost basis, manual sales, and bounded history.

## Supported market value and exit range

The current scan support is the lower of the current median and quantity-weighted median. When seven-day history exists, normal supported value is the lower of scan support and the seven-day median. This prevents a temporary current spike from raising the expected exit.

- Fast exit: 95% of the normal supported value.
- Normal exit: supported value.
- Optimistic exit: at most 103% of normal and never above the 30-day median when it exists.

Qualification uses the fast and normal values. The optimistic value never qualifies a trade. Daily price stability uses the range of compact daily average prices from the last seven days. The addon has no seller-count or complete price-ladder history, so it does not claim seller diversity, exact sale volume, or exact holding time.

## Demand

Demand labels describe repeated local evidence, not confirmed realm-wide sales:

- **Hot:** at least 8 observations across 5 days, typical quantity at least 20, typical listings at least 5, seven-day price range no more than 25% of supported value, and no poor personal-sale evidence.
- **Active:** at least 4 observations across 3 days, typical quantity at least 8, typical listings at least 3, range no more than 50%, and no poor personal-sale evidence.
- **Slow:** repeated evidence with very low typical supply/listings or a personal sale rate below 35% after at least three outcomes.
- **Unknown:** anything without enough evidence.

A single observation day can never be Hot.

## Confidence

- **Strong analysis:** no older than 6 hours, at least 8 observations over 5 days, at least 20 current samples and 5 listings, Hot/Active demand, and stability at or below 25%.
- **Fair analysis:** no older than 12 hours, at least 4 observations over 3 days, at least 10 samples and 3 listings, known demand, and stability at or below 50%.
- **Speculative:** weaker evidence. Hidden by default.
- **Avoid:** a hard qualification gate failed.

A qualified trade becomes Strong only when the analysis is Strong, demand is Hot, low-case profit is at least twice the active minimum, discount is at least 20%, and stability is strong.

## Separate policies and routing

Each stackable candidate is evaluated for quick-move and trade eligibility, producing `QUICK_ONLY`, `TRADE_ONLY`, `BOTH`, or `NEITHER`. A Plan recommendation never creates a tracked trade.

Quick Move prioritizes safety, an exact stack of at most 20 items, limited capital, non-slow demand, at most two modeled relists, low ownership exposure, and the existing minimum-profit policy. Plan caps one quick purchase at the smaller of half its budget and 20 gold.

Trade qualification requires valid current data, a supported exit, the mode's minimum discount and absolute low-case profit, positive profit after cut and modeled relists, sufficient demand/confidence/history, fresh data, available capital, and controlled owned exposure. An extreme discount of at least 55% is rejected when stability is missing or worse than 50%.

## Profit calculation

For the exact current cheapest listing:

```text
gross revenue = exit unit price × quantity
net revenue = gross revenue - 5% Auction House cut - modeled relisting deposits
profit = net revenue - purchase capital
```

The UI shows low-case profit from the fast exit and normal-case profit from the normal exit. All displayed money is derived from integer copper. A trade cannot qualify when low-case profit is non-positive or below the configured minimum.

## Capital modes

| Mode | Per trade | Total committed | Base minimum profit | Discount | Demand | Confidence |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| Conservative | 15% | 35% | 1g | 20% | Hot | Strong |
| Balanced | 25% | 50% | 50s | 15% | Active | Fair |
| Aggressive | 40% | 70% | 25s | 12% | Slow | Speculative |

Percentages apply to actual character gold after the emergency reserve. Explicit gold caps can only make the percentage limits smaller. Aggressive mode cannot bypass invalid data, unsupported exits, stale data, manipulation, non-positive low-case profit, or exposure limits.

## Position sizing limitation

The compact snapshot knows the exact cheapest listing's stack and total, but it does not retain a full price ladder. Therefore the first vertical slice recommends only the exact cheapest stack and does not assume every current unit is available at the lowest price. Owned bag inventory reduces remaining exposure capacity and can eliminate the purchase. Bank, mail, alts, guild bank, and posted auctions are not counted.

## Ranking

Qualified trades sort by:

1. Higher low-case absolute profit.
2. Stronger demand.
3. Higher normal profit.
4. Better low-case capital efficiency.
5. Higher confidence.
6. Better price stability.
7. Less owned inventory.
8. Lower required capital.
9. Item name/key for deterministic ties.

Percentage margin alone never leads ranking.

## Explicit lifecycle and cost basis

`Track Trade` creates `Watching`; it does not buy anything. The player manually records one or more purchase batches, each with quantity, unit cost, and timestamp. Total cost divided by total purchased quantity gives weighted average cost.

Manual states in the first vertical slice are Watching, Purchased, Listed, Partially Sold, Sold, Closed, and Abandoned. A partial sale allocates the same proportion of remaining cost basis to the sold quantity. Realized profit is recorded net revenue minus allocated cost. Remaining units retain the unallocated cost basis.

The sale form accepts net revenue. Gross revenue, Auction House cut, and deposits remain unknown unless reliable values are supplied; unknown does not mean zero. Automated mailbox-to-trade reconciliation is deferred.

## Freshness and manual action

Recommendations record scan ID, timestamp, observed price, and maximum buy price. Before Find or Track, the latest completed snapshot must be no older than 12 hours and its current known price must remain under the maximum. This is scan-time validation, not a live price claim.

Find Auctions only tells the player what to search for and the maximum price. All searching, buying, posting, confirmations, lifecycle changes, and sale recording remain deliberate player actions.
