# Profit and Capital Protection

## Objective

Protect the player from losing usable gold to bad margins, deposits, duplicate inventory, slow markets, and excessive concentration. The model must recommend and warn only. It must never buy, post, cancel, vendor, mail, or craft automatically.

## Current protection

Bank of Durotar already provides meaningful safeguards:

- Integer-copper validation and overflow checks.
- Complete-snapshot requirement.
- Minimum 10% buy margin and 15% craft margin.
- Estimated 5% Auction House cut.
- Estimated deposit loss using personal expiry history when at least three outcomes exist.
- Rejection of personal markets below 25% sale rate after at least three outcomes.
- User-entered total budget.
- Maximum half of the budget in one buy.
- Greedy combined plan that never exceeds the budget.
- Medium-or-better confidence requirement.
- Exact cheapest-stack cost and unbound bag filtering.
- Vendor comparison for bag items.
- Configurable minimum conservative profit, defaulting to 10 silver.
- One/two-failed-listing deposit model before a flip is considered actionable.
- Hard rejection when conservative profit is zero/negative or below the player's floor.
- Owned carried-bag stock lowers rank and blocks another full-stack recommendation when exposure is already met.
- Trust-first ordering so a higher raw-profit `Fair` item cannot outrank a `Strong` item.

These controls are useful, but they treat the entered budget as the full risk pool. Owned awareness currently covers unbound items in carried bags only; it does not include bank, mail, alts, or the player's active auctions. Because Classic auctions are bought as exact listings, the addon does not invent an unavailable partial-stack purchase.

## Trades capital protection implemented

Trades reads actual character money, subtracts the configured emergency reserve, subtracts remaining recorded cost basis already committed to open trades, then applies per-trade and total-commitment percentages. Conservative/Balanced/Aggressive modes use 15%/25%/40% per-trade and 35%/50%/70% total caps. Explicit gold caps can only reduce those mode limits.

Low-case profit must remain positive and above the active trade minimum after the 5% cut and modeled relisting deposits. Owned bag quantity reduces exposure capacity. Multiple recorded purchases cannot exceed the tracked maximum safe position. Aggressive mode cannot bypass data validity, supported-exit, freshness, manipulation, or positive low-case-profit gates.

## Proposed capital-protection model

### 1. Establish usable liquid gold

```text
Current character money
- emergency reserve
- known committed purchase cost not yet recovered
- optional profession reserve
= maximum deployable gold
```

Read current character money through the appropriate Classic money API when the player opens the plan. Keep the manual budget as a lower cap. Never add bag vendor value, expected auction value, or posted-auction value to liquid gold.

Suggested reserve defaults:

- Conservative: keep 35% of current money or a minimum player-selected floor.
- Balanced: keep 20%.
- Aggressive: keep 10%.

The normal UI should describe these as `Keep in your bags`, not risk jargon.

### 2. Track committed capital

Committed capital includes known acquisition cost of:

- Flips marked as purchased and still in bags/bank/mail.
- Items currently posted by the player, when owned-auction reads are safely available.
- Expired items awaiting relist.
- Craft materials acquired for a tracked craft plan.

Do not use current market valuation as committed capital. Use known cost basis; if unknown, show `Unknown existing exposure` and lower the safe recommendation.

### 3. Assign a simple risk tier

Risk tier is separate from trust:

- **Low risk:** Strong trust, stable price, multiple sellers, positive after two relists, common stackable item.
- **Moderate:** Fair/Strong trust, positive after one relist, no concentration warning.
- **High:** Speculative, volatile, sparse, equipment variant, high deposit, or no personal history.
- **Avoid:** hard gate from the trust model or negative conservative economics.

### 4. Cap exposure

Default per-item caps as percentages of deployable gold:

| Risk | Recommended purchase cap | Absolute maximum cap |
| --- | ---: | ---: |
| Low | 12% | 20% |
| Moderate | 7% | 12% |
| High | 3% | 5% |
| Avoid | 0% | 0% |

Category caps prevent ten recommendations from being the same underlying bet:

- One market category: 30% of deployable gold.
- One profession-dependent market: 20% unless the player knows that profession.
- Equipment/non-stackable variants: 10% combined.
- Unknown-cost inventory plus new high-risk buys: 10% combined.

The exact categories should remain broad—trade goods, consumables, recipes, equipment, and other—so the addon does not become a taxonomy project.

### 5. Size the purchase

For each candidate:

```text
recommended quantity = minimum of:
  quantity available at or below maximum safe unit price
  risk-adjusted per-item capital cap / unit price
  remaining category cap / unit price
  remaining deployable gold / unit price
  conservative market absorption cap
```

The market absorption cap must be modest because sales velocity is unknown. Until personal outcomes exist, do not recommend buying more than a small fraction of typical observed quantity. Do not infer that high supply means high demand.

### 6. Show the decision simply

```text
Recommended purchase: 12
Maximum safe purchase: 20
Spend now: 17g 04s
Gold committed after purchase: 18%
Keep in your bags: 40g
Risk: Moderate
```

Advanced detail should show which limit bound the result: budget, item risk, category exposure, existing inventory, or market absorption.

## Profit scenarios

Every buy/craft recommendation should calculate at least:

- **Best supported:** sells near central target on first listing.
- **Expected:** conservative sell floor with expected deposit loss.
- **Bad but plausible:** conservative floor after one or two failed listings, based on risk tier.

Normal UI should show one conservative estimated net profit plus `Main risk`. Expanded detail can show all scenarios.

Reject the opportunity when:

- Expected net profit is non-positive.
- Low-risk items fail the one-relist case.
- Moderate/high-risk items fail their configured conservative scenario.
- Absolute profit is too small to justify likely deposits and player effort.
- Current price changed above the maximum safe price.

## Relisting model

Current expected deposit loss is approximately one deposit multiplied by a failure rate. Replace it with a bounded scenario model:

```text
net after N failures = supported gross sale
                     - Auction House cut
                     - (N × deposit)
                     - purchase cost
```

Use personal expiration history only to select the displayed default scenario; do not treat a sparse observed rate as a calibrated probability. Suggested defaults:

- Strong trust + good personal history: show one-failure case.
- Fair or unknown personal history: show two-failure case.
- Speculative: show three-failure case or reject if deposit is material.

Duration must be explicit before calling a deposit estimate authoritative. Until exact Classic rates are validated, label the amount `Estimated deposit risk` and include a safety buffer.

## Duplicate and dead-inventory protection

Before recommending a buy, subtract or warn for:

- Exact item quantity already in bags.
- Known quantity in an open bank.
- Mail attachments when safely readable at the mailbox.
- Expired auctions waiting in mail.
- Existing owned auctions when the Auction House exposes them safely.
- Materials reserved by the player for a known craft plan.

Default behavior:

- If owned quantity already meets the recommended quantity: `Sell what you own first`.
- If total exposure exceeds maximum: `Do not buy more`.
- If ownership is only partially known: `Inventory incomplete` and lower the cap.
- Never value vendor-priced inventory as immediately available gold.

## Existing-auction protection

Read-only owned-auction awareness would provide high value if live API behavior is reverified:

- Count exact item/variant already posted.
- Sum known acquisition cost, not asking price, when available.
- Detect self-undercutting and duplicate stacks.
- Warn when too much quantity is already listed.
- Recommend wait/reprice/relist, but keep cancellation/posting manual in Blizzard's UI.

Direct `CancelAuction` and `StartAuction` integration is not part of this model.

## Conservative modes

Offer only three modes; avoid formula settings:

| Mode | Reserve | Allowed trust | Relist scenario | Exposure |
| --- | --- | --- | --- | --- |
| Safe | 35% | Strong only | Two failures | Lowest caps |
| Balanced | 20% | Strong/Fair | One to two failures | Default caps |
| Bold | 10% | Strong/Fair; Speculative shown with warning | One failure | Higher caps, still bounded |

Guided mode should default to Safe or Balanced. `Bold` must never bypass Avoid gates.

## High-value protection backlog

1. Replace numeric flip score with trust/risk labels.
2. Show maximum safe unit price as the most prominent buy boundary.
3. Add an absolute-profit floor.
4. Add one/two/three-relist scenarios.
5. Read current character money and preserve a reserve.
6. Suppress duplicate buys using bag quantity.
7. Add manual `Bought` tracking and cost basis.
8. Add category concentration caps.
9. Add owned-auction awareness after read-only API validation.
10. Report realized profit from matched purchase/outcome records.

## Validation plan

- Deterministic copper fixtures for cut, deposit, and 0–3 failed listings.
- Boundary tests for reserve, per-item cap, category cap, and total budget.
- Cases with unknown, partial, and complete inventory.
- Duplicate exact variants versus same-name equipment.
- Portfolio cases where multiple small candidates beat one large candidate.
- Personal history with tiny and mature samples.
- Vendor-value separation from liquid gold.
- Manual in-game comparison of displayed deposit estimates against Blizzard's UI at supported durations.
- Read-only owned-auction API verification before using that data.

## Non-goals

- Automatic buying, bidding, posting, cancelling, vending, mailing, or crafting.
- Treating market value as cash.
- Guaranteed sale probabilities.
- Unlimited configuration of formulas.
- Cross-realm external price feeds.
- A full accounting or inventory-suite replacement.
