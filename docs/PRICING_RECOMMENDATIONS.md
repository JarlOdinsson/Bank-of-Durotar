# Pricing Recommendations

This document plans the future Bank of Durotar automatic selling-price recommendation system. It is architecture and policy only; it does not implement recommendations, normal selling UI, market history, tooltip hooks, posting workflow, or protected transaction calls.

## Purpose

The pricing recommendation system should help a player choose a responsible auction bid and buyout after the player manually places an item in the Auction House sell slot.

Intended workflow:

1. Player manually places an item in Blizzard's auction sell slot.
2. Bank of Durotar reads the item, stack quantity, and available market data.
3. Bank of Durotar calculates a recommended unit and stack price.
4. Bank of Durotar pre-fills editable bid and buyout fields.
5. Player reviews or edits the recommendation.
6. Player explicitly clicks to post one auction.
7. No automatic posting occurs.

Use precise recommendation language:

- Recommended price.
- Suggested buyout.
- Estimated market value.
- Best supported price.
- Pricing confidence.

Never call a recommendation a perfect price, guaranteed profit, guaranteed sale price, or certain market value.

## Dependencies

Recommendation implementation is blocked until these dependencies exist and are verified:

- Milestone `0.1D` full-market scan probe verifies legacy full-scan behavior and snapshot completeness.
- Market-history schema, 60-day retention, compaction, and cleanup are implemented and tested.
- Item identity and variant keys are reliable enough to group equivalent auctions without merging unlike items.
- Current and historical unit-price data is trustworthy and bounded.
- Missing-data and stale-data behavior is approved.
- Deterministic pricing fixtures cover the algorithm.
- Protected posting workflow is live-verified and approved through the transaction boundary.

## Data Sources

The recommendation engine may use only valid data available to Bank of Durotar, in priority order:

1. Current completed market scan.
2. Recent local market-history observations.
3. Current targeted search results.
4. Player's own successful sale history, once accounting exists.
5. Vendor value and auction deposit only as safety floors or warnings.

Do not use invented prices, external websites, paid pricing data, OAuth, regional prices presented as realm-local facts, zero-buyout listings, malformed records, or partial scans presented as complete market snapshots.

## Missing-Data Behavior

When no valid pricing data exists:

- Leave bid and buyout fields blank.
- Display `No reliable market data available.`
- Offer a manual targeted search or player-initiated market scan.
- Do not guess a price.
- Do not silently use vendor value as auction value.

When data is stale:

- Display data age.
- Lower confidence.
- Warn the player.
- Require a refresh beyond the configured stale threshold.

## Freshness Policy

Provisional default freshness policy:

- `0-24 hours`: Fresh.
- `1-7 days`: Usable.
- `8-30 days`: Stale.
- Over `30 days`: Do not prefill by default.

These thresholds are future policy settings, not hard-coded final behavior.

## Unit-Price Normalization

All price comparisons must use unit buyout, regardless of auction stack size.

Examples:

- `1` item for `20s` equals `20s` each.
- `20` items for `3g` equals `15s` each.

Stack quantity is used only when calculating final stack bid and stack buyout.

Reject records with stack count `<= 0`, buyout `<= 0`, negative money values, unsafe integer overflow risk, missing item identity, or incomplete scan data where completeness is required.

All money remains integer copper internally.

## Price-Wall Algorithm

The initial algorithm should be conservative and deterministic:

1. Normalize valid listings to unit buyout.
2. Sort by unit buyout ascending.
3. Group similar unit prices into price levels.
4. For each level, calculate total quantity, listing count, percentage of current supply, and distance to the next level.
5. Compare each level against recent median and volatility when history exists.
6. Ignore or down-weight tiny outlier levels that represent insignificant quantity or abnormal deviation.
7. Select the first meaningful price wall.
8. Apply the selected undercut strategy.
9. Reject or warn if the result violates a safety floor.
10. Return no recommendation if evidence is inadequate.

The engine must not blindly undercut the absolute cheapest listing.

## Outlier Handling

Outlier handling should consider:

- Quantity available at the price.
- Number of listings at the price.
- Percentage of current supply.
- Gap to the next price level.
- Recent historical range.
- Price volatility.

Example: if `1` item is listed at `1s` and `200` items are listed at `20s` each, the `1s` listing should not force a `99c` recommendation.

## Undercut Strategies

Initial planned strategies:

### Match

Match the selected meaningful market price.

### Small Undercut

Undercut the selected meaningful wall by a small bounded amount.

Provisional rule:

- Under `1g`: undercut by `1c`.
- `1g-10g`: undercut by `1s`.
- Above `10g`: undercut by a small bounded amount.

Exact values remain provisional until deterministic tests and live market review.

### Hold Value

Use historical value and avoid joining an abnormal temporary price collapse.

The default should be simple and conservative; normal players should not need formula language.

## Historical Comparisons

Recommendations should compare current prices against:

- Last valid observation.
- Recent median.
- 7-day median.
- 30-day median.
- Current supply.
- Normal supply, when enough data exists.
- Price volatility.

The engine may recommend `Sell Now`, `Hold`, `Refresh Data`, or `No Recommendation`. It must not always manufacture a price.

## Bid-Price Policy

Initial recommendation: bid equals buyout for common materials and fast-moving items.

Rationale:

- It is simple and readable.
- It avoids confusing bid/buyout gaps.
- It reduces accidental low-bid listings.
- It supports immediate-sale Auction House behavior better than speculative bidding for common commodities.

Future settings may allow a lower bid percentage, but bid must never exceed buyout and must never silently become zero.

## Confidence Model

Player-facing confidence levels:

- High.
- Medium.
- Low.
- None.

Inputs:

- Data freshness.
- Number of scans.
- Sample count.
- Scan completeness.
- Price stability.
- Current supply.
- Agreement between current and historical prices.
- Player sale history, once available.

Example explanation:

```text
Recommended Buyout: 20s each
Confidence: High

Why?
- Full scan completed 18 minutes ago.
- 146 items currently listed.
- Seven-day median is 21s.
- Current meaningful price wall is 20s.
- Price has been stable.
```

## Price Floors

Future safety floors:

- Vendor value.
- Auction deposit.
- Known acquisition cost.
- Material opportunity cost.
- Crafting cost.
- Configured minimum profit.

Initial implementation should at minimum warn when expected net sale revenue is below vendor value, deposit risk is unusually high, recommended price is below known acquisition cost, or current market is far below recent history.

Do not claim acquisition-cost support exists until accounting is implemented.

## Quantity-Planning Roadmap

Future recommendations may include stack size, number of stacks, maximum quantity to list, and remaining inventory to hold.

Inputs may include:

- Current demand.
- Current supply.
- Historical sale velocity.
- Player's existing active auctions.
- Player's total known inventory.
- Deposit exposure.
- Market saturation risk.

Initial selling-price implementation may recommend price only before quantity intelligence is available.

## Selling UI Design

The normal selling UI must be separate from the developer transaction probe.

Planned normal-player display:

```text
Rage Potion
Stack: 1

Recommended Pricing

Bidding Price
[ 0 ] Gold [ 1 ] Silver [ 90 ] Copper

Buyout Price
[ 0 ] Gold [ 2 ] Silver [ 00 ] Copper

Auction Duration
(*) 12 Hours
( ) 24 Hours
( ) 48 Hours

Recommended buyout: 2s each
Current meaningful market price: 2s 05c
Recent median: 2s 10c
Confidence: Medium

[Why this price?]

[Post 1 Auction]
```

Requirements:

- Prefill denomination fields.
- Allow player edits.
- Clearly label every field.
- Recalculate stack totals.
- Changing values invalidates prepared transaction state.
- Player explicitly clicks to post.
- No automatic posting.
- No hidden queue.
- No automatic repost.
- No bulk posting from one click unless separately verified and approved.

## Explanation Panel

Every recommendation must provide a plain-language `Why?` explanation.

Examples:

- `The lowest listing contains only one item and was ignored as an outlier.`
- `This price matches the first meaningful market wall.`
- `Current supply is much higher than normal. Consider holding.`
- `Market data is 12 days old. Refresh before posting.`
- `No reliable market data is available.`

Avoid statistical jargon in the normal view unless expanded.

## Tooltip Valuation Integration

Future tooltip valuation should use the same pricing service.

When valid data exists, item tooltips may show:

```text
Bank of Durotar
Estimated market value: 20s each
Estimated stack value: 4g
Data age: 3 hours
Confidence: High
```

Rules:

- Show nothing when no valid data exists.
- Prefer recent median when enough samples exist.
- Otherwise use the last valid known unit price.
- Show data age.
- Suppress values beyond the stale threshold by default.
- Never label estimated inventory value as profit.

Tooltip hooks are not part of this planning task.

## Architecture

Future module:

```lua
BOD.PricingService
```

Suggested responsibility:

- Retrieve current and historical market observations.
- Validate data completeness and freshness.
- Normalize unit prices.
- Identify meaningful price walls.
- Detect outliers.
- Calculate recommended buyout.
- Calculate recommended bid.
- Calculate confidence.
- Return plain-language explanation codes.
- Return no recommendation when evidence is inadequate.

Potential interface:

```lua
BOD.PricingService:GetRecommendation(itemKey, stackCount, context)
```

Potential result:

```lua
{
    status = "RECOMMENDED",
    unitBuyout = 200,
    stackBuyout = 200,
    unitBid = 200,
    stackBid = 200,
    confidence = "MEDIUM",
    dataAge = 3600,
    source = "CURRENT_AND_HISTORY",
    reasonCodes = {
        "MEANINGFUL_PRICE_WALL",
        "RECENT_MEDIAN_SUPPORTS_PRICE",
    },
}
```

This interface is provisional and must be reviewed against implemented scan/history modules.

## Separation Of Concerns

Keep separate modules for:

- Market scanning.
- Market-history storage.
- Pricing recommendations.
- Selling UI.
- Protected transaction execution.
- Profit accounting.

The pricing engine must not directly call `StartAuction`, `PostAuction`, `PlaceAuctionBid`, or `CancelAuction`.

The selling UI may request a recommendation. Direct addon posting through `StartAuction` is no-go after live verification; future selling UI must be researched as a Blizzard-UI-assisted workflow where the player uses Blizzard's own posting control.

## Compliance Boundary

Automatic price calculation and prefilling are allowed design goals. Automatic posting is prohibited.

The system must:

- Calculate and display recommendations.
- Prefill editable fields.
- Require explicit player review.
- Require the player to use Blizzard's own posting control unless a future compliance review proves another path safe.
- Never post from a timer, event, scan completion, or background process.
- Never automatically retry.
- Never silently change a player-edited price after final review.
- Invalidate prepared state if market data or form values change.

## Test Matrix

Future deterministic fixtures must cover:

1. No data.
2. Only stale data.
3. One valid listing.
4. One extreme low outlier.
5. One extreme high outlier.
6. Clear meaningful price wall.
7. Multiple competing price walls.
8. Large market supply.
9. Low market supply.
10. Buyout below vendor value.
11. Current market far below history.
12. Current market far above history.
13. Stack-size normalization.
14. Bid greater than buyout rejection.
15. Integer-copper boundaries.
16. Partial scan rejection.
17. Edited-price invalidation.
18. Tooltip hidden with no data.
19. Tooltip value with fresh data.
20. Recommendation explanation accuracy.

## Go/No-Go Gates

Recommendation implementation is no-go until:

- Full-market scan behavior is live-verified.
- Snapshot completeness can be determined.
- Market-history schema is implemented and tested.
- 60-day retention and cleanup are implemented.
- Item identity and variant keys are reliable.
- Current and historical unit prices are trustworthy.
- Missing and stale data behavior is approved.
- Price-wall algorithm has deterministic tests.
- Integer-copper math is tested.
- Human approval is received.

## Open Questions

- What exact item identity fields are reliable for variants, suffixes, enchantments, charges, and stackable commodities on Interface `20506`?
- What completed-scan terminal condition is reliable for full-market scan snapshots?
- How many observations are enough for high confidence by item category?
- Which price-level grouping thresholds are appropriate for cheap materials versus expensive items?
- Which markets should default to `Match` rather than `Small Undercut`?
- How should sale velocity be inferred before accounting data exists?
- Which deposit-risk thresholds are understandable to normal players?
- When should stale data block prefill versus only lower confidence?
