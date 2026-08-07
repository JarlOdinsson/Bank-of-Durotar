# Feature Backlog

## How to read this backlog

Every idea is evaluated against the current 0.5.0-beta.3 implementation. `False confidence` rates the danger of misleading the player if implemented poorly. `Bloat` rates pressure against the lightweight product philosophy.

## Recommendation accuracy

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RA1 Trust labels | A numeric flip score looks calibrated. After scanning, the row says `Strong`, `Fair`, `Speculative`, or `Avoid`, with one reason. | Communicates evidence without fake precision. | Existing age/samples/history/economics; new stability/concentration later. Local calculation. | Small | Very high | Low | Low | Build next |
| RA2 Supported sell range | One target price hides uncertainty. A buy row shows conservative floor–supported ceiling and sizes from the floor. | Prevents purchases that work only at an optimistic point price. | Current price buckets plus historical range; bounded schema addition. | Medium | Very high | Moderate | Low | Near-term |
| RA3 Equal-day history weighting | Repeated scans today can dominate older days. Historical reference weights distinct days equally while retaining scan count as evidence. | Reduces time-of-day and scan-frequency bias. | Existing daily rows; no API concern. | Small | High | Low | Low | Build next |
| RA4 Volatility tier | A wildly swinging item can look stable at its median. Expanded detail says Stable/Variable/Wild and downgrades trust. | Protects against catching a temporary spike. | Daily low/high or robust dispersion; schema migration. | Medium | Very high | Low | Low | Near-term |
| RA5 Seller concentration | One seller may control most supply. Row warns `One seller controls 82%`. | Detects a major manipulation/exit-risk pattern. | Owner names already exposed per listing; retain only counts/shares, not raw names. | Medium | High | Moderate | Low | Near-term |

## Profit protection

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PP1 Relist scenarios | Apparent profit disappears after expirations. Tooltip shows net after 0/1/2/3 failed listings. | Makes deposit risk concrete and bounded. | Vendor value, verified duration/deposit, purchase cost. Calculation-only. | Small | Very high | Low | Low | Build next |
| PP2 Absolute-profit floor | A 50% return can be only 4 copper. Candidate must clear both margin and meaningful copper profit. | Avoids wasting time and list slots. | Existing economics; optional level-aware default. | Tiny | High | Low | Low | Build next |
| PP3 Stale-price hard gate | The cheapest stack vanishes before purchase. Recommendation prominently says `Verify price is at or below X`; stale rows become Wait. | Prevents the most common manual handoff loss. | Snapshot age now; targeted recheck later. | Tiny | Very high | Low | Low | Build next |
| PP4 Manipulation warning | A large gap or concentrated seller can inflate expected resale. Candidate changes to Avoid with plain reason. | Blocks trap markets instead of merely lowering rank. | Price buckets, seller share, historical range. | Medium | Very high | Low | Low | Near-term |
| PP5 Stop-relisting rule | Player keeps paying deposits on an item that expires. After a bounded number/outcome pattern, advise Hold or Vendor. | Stops sunk-cost deposit leakage. | Cost basis, expiration count, vendor value. Mail read is feasible; exact item matching needs tests. | Medium | High | Moderate | Low | Near-term |

## Buying workflow

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BW1 Best move card | Ten rows overwhelm a beginner. The safest top candidate is expanded; others are collapsed below. | Shrinks the first decision and highlights the hard price limit. | Existing ranked candidates. | Small | Very high | Low | Low | Build next |
| BW2 Find this item | Player retypes a name and may choose the wrong variant. A deliberate button prepares an exact targeted search; player still buys manually. | Reduces clicks and identity mistakes. | Exact item link/string; targeted legacy query must be reverified and throttled. | Medium | Very high | Low | Moderate | Research |
| BW3 Purchase checklist | Player forgets stack/limit. Expanded row shows exact icon/name, quantity, and `Do not pay more than`. | Prevents wrong-stack and unit/total confusion. | Existing fields. | Tiny | High | Low | Low | Build next |
| BW4 Mark as bought | Addon does not know the purchase happened. Player clicks `I bought this`, confirms quantity/cost, and remaining plan updates. | Enables exposure and later realized profit without protected calls. | Manual entry/confirmation; bags can corroborate but not prove cost. | Medium | Very high | Moderate | Low | Near-term |
| BW5 Price-change recheck | A recommendation can be minutes old. Before acting, player clicks `Check again`; addon returns Still safe/Price changed. | Prevents buying after the edge disappears. | Targeted query, deliberate click, cooldown handling; no automatic buy. | Medium | Very high | Low | Moderate | Research |

## Selling workflow

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SW1 Sell/Hold/Vendor decision | A price is shown even when waiting is smarter. First output is an action word, then the price if supported. | Prevents forced selling into a collapse. | Current/history/vendor/economics. | Small | Very high | Low | Low | Build next |
| SW2 Stack-size advisor | Player lists 20 when buyers commonly want 5. Recommend a small bounded set of stack plans. | Can improve sale convenience and reduce deposits/saturation. | Current stack distributions are not persisted; personal outcomes by stack needed. API shows listing stacks. | Large | High | High | Moderate | Research |
| SW3 Duration and deposit guide | Player does not know 12/24/48-hour tradeoff. Show recommended duration and estimated deposit. | Makes relist risk visible at posting time. | Verified Classic duration/deposit behavior; manual choice only. | Medium | High | Moderate | Low | Near-term |
| SW4 Existing-auction warning | Player posts more while the same item is already listed. Show owned quantity and avoid self-undercutting. | Reduces saturation and tied-up deposits. | Read-only owner-auction API requires renewed live verification. | Large | Very high | Low | Moderate | Research |
| SW5 Relist assistant | Expired mail returns and player does not know whether to try again. Show Relist/Hold/Vendor based on current data and attempts. | Closes the loss-control loop. | Expiration history, cost basis, fresh scan, vendor value. | Medium | Very high | Moderate | Low | Near-term |

## Market awareness

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| MA1 Supply versus normal | `18 listed` means little alone. Tooltip says `18 now; usually 45`. | Makes temporary scarcity/saturation understandable. | Existing current and typical quantity. | Tiny | High | Low | Low | Build next |
| MA2 Plain price trend | Player cannot tell rising from one-day spike. Show Rising/Flat/Falling only with adequate distinct days. | Helps timing without charts. | Equal-day history medians and minimum-day gate. | Small | High | Moderate | Low | Near-term |
| MA3 Main-risk sentence | Dense statistics require interpretation. Each row names one risk: stale, volatile, concentrated, thin history, high deposit. | Turns data into an actionable warning. | Trust factor reason codes. | Tiny | Very high | Low | Low | Build next |
| MA4 Watchlist-only quick check | Full scans are cooldown-bound. Player deliberately checks a small saved list when full scan is unavailable. | Maintains awareness with less waiting. | Targeted legacy searches, bounded queue, one deliberate initiation, throttling review. | Large | High | Moderate | Moderate | Research |
| MA5 Market health tooltip | Advanced users want evidence without clutter. Hover shows range, supply, sellers, age, days, outcomes. | Preserves simple rows while exposing auditability. | Existing/new trust factors. | Small | High | Low | Low | Near-term |

## Capital management

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CM1 Read current money | Player guesses a budget. Plan shows current gold, reserve, and safe-to-spend cap. | Grounds recommendations in actual liquidity. | Classic player-money API; read-only. | Small | Very high | Low | Low | Build next |
| CM2 Emergency reserve | New player spends mount/repair gold. Safe/Balanced/Bold keeps 35/20/10%. | Prevents catastrophic overcommitment with one understandable setting. | Current money and chosen mode. | Small | Very high | Low | Low | Build next |
| CM3 Risk-adjusted item caps | Half-budget cap is too large for speculative items. Cap becomes 3–20% by risk. | Aligns exposure with evidence quality. | Trust/risk tier and deployable gold. | Small | Very high | Low | Low | Build next |
| CM4 Category concentration | Ten cloth flips are one market bet. Limit broad categories and explain when capped. | Protects against a category-wide price fall. | Item class/subclass retained from scan. | Medium | High | Moderate | Low | Near-term |
| CM5 Committed-capital ledger | Plan ignores previously bought, posted, or expired stock. Show percentage already tied up. | Prevents stacking new risk on old inventory. | Manual purchase records, inventory, owned auctions when available. | Large | Very high | Moderate | Moderate | Later |

## Inventory and bank integration

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| IB1 Owned-bag warning on buys | Player buys 20 more while 40 sit in bags. Row says `You own 40—sell those first`. | Immediate duplicate-purchase protection. | Existing bag scan and exact identity. | Small | Very high | Low | Low | Build next |
| IB2 Bank snapshot | Bags are clear but bank holds stock. Capture a bounded count when the bank is open and label age. | Improves exposure estimates without background access. | Bank container APIs/events vary by client; only scan while accessible. | Medium | High | Moderate | Low | Near-term |
| IB3 Mail inventory snapshot | Expired/mailed inventory is forgotten. Capture attachment counts when mailbox opens. | Prevents buying while stock waits in mail. | Mail item links/counts; read-only, bounded fingerprints. | Medium | High | Moderate | Low | Near-term |
| IB4 Reserved-material flag | Craft materials get recommended for sale. Player marks an item `Keep for crafting`. | Avoids cannibalizing a planned craft. | Small local watch/reserve table. | Small | Moderate | Low | Low | Later |
| IB5 Account-wide inventory | Alt banks hide exposure. Merge per-character snapshots locally after each character logs in. | Better duplicate suppression for alt-heavy players. | SavedVariables character labels; data is stale until login/open-bank. | Large | High | Moderate | Moderate | Later |

## Profession opportunities

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PF1 Craft quantity sizing | A recipe is profitable per craft but ten outputs may not sell. Recommend a bounded count based on exposure and typical supply. | Prevents overcrafting. | Output trust, inventory, capital caps; demand remains inferred. | Medium | High | High | Low | Near-term |
| PF2 Owned versus market-value reagents | New players think owned materials are free. Row says `Uses owned items worth X`. | Teaches opportunity cost and honest profit. | Bag/bank counts plus market/vendor values. | Small | High | Low | Low | Build next |
| PF3 Vendor-reagent support | Recipes are skipped or overpriced when a reagent is vendor-supplied. Capture a small verified vendor-price source/floor. | Corrects common craft costs. | `GetItemInfo` vendor sell value is not vendor buy cost; vendor UI capture or curated local table needs review. | Medium | High | Moderate | Moderate | Research |
| PF4 Lightweight transformations | Smelting, cloth/leather conversion, and alchemy cooldowns are recipes already visible. Label them as transformations and show input→output. | Reuses current recipe capture without a full suite. | Existing profession recipe APIs and cooldown fields. | Small | High | Low | Low | Near-term |
| PF5 Disenchant research | Player wants buy-to-disenchant value. First research whether deterministic Classic disenchant tables can be maintained safely. | Could expose valuable conversion opportunities. | Expansion-specific loot tables not provided reliably by AH APIs; maintenance-heavy. | Large | High | High | High | Research |

## New-player guidance

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| NG1 State-aware Guided mode | Static guide advances even if nothing happened. It highlights Budget, waits for Apply, then Scan, then the best row. | Teaches by doing and reduces misclicks. | Current UI state and scan events. | Medium | Very high | Low | Low | Near-term |
| NG2 Jargon-free tooltips | Player does not know return/confidence/listings. Hover explains each in one sentence. | Builds intuition without cluttering rows. | Static copy and reason codes. | Tiny | High | Low | Low | Build next |
| NG3 `Why not?` messages | Empty results look broken. Show `No safe buys because prices are too high` or `Need more history`. | Builds trust in waiting. | Rejection counters/reason aggregation. | Small | Very high | Low | Low | Build next |
| NG4 Safe defaults | New player should not configure formulas. Guided mode defaults to reserve, Strong/Fair only, and conservative relists. | Prevents dangerous setup choices. | Mode presets. | Tiny | High | Low | Low | Build next |
| NG5 First-week learning meter | One scan cannot support history. Show `Learning day 1 of 3` and limit advice until mature. | Sets expectations and prevents overtrust. | Existing scan/day counts. | Tiny | High | Low | Low | Build next |

## Quality of life

| ID / feature | Exact player problem and example workflow | Why it helps | Data required / Classic API concerns | Complexity | Value | False confidence | Bloat | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| QL1 Icons everywhere | Bag-sale and craft rows are slower to recognize. Add item icons and WoW tooltips like flip rows. | Faster visual matching. | Item IDs and cached item info. | Tiny | High | Low | Low | Build next |
| QL2 Relative scan age | Full timestamps are hard to parse. Show `Updated 18m ago`; exact timestamp on hover. | Faster freshness judgment. | Existing timestamps. | Tiny | Moderate | Low | Low | Build next |
| QL3 Preserve scroll/selection | Refreshes can move the player's place. Keep selected row and valid scroll position after non-material updates. | Reduces accidental row switching. | UI state only. | Small | Moderate | Low | Low | Near-term |
| QL4 Explain disabled controls | A disabled scan button feels broken. Nearby text says cooldown, AH closed, or processing. | Reduces confusion/support burden. | Existing state machine. | Tiny | High | Low | Low | Build next |
| QL5 Data-health panel | Player needs a compact way to see snapshot age, tracked days, storage health, and reset corrupted data. | Improves reliability without a large settings suite. | Existing DB metadata and bounded clear actions. | Small | Moderate | Low | Low | Later |

## Disproportionate-value shortlist by effort

### Ten tiny improvements

1. PP2 Absolute-profit floor.
2. PP3 Stale-price hard gate copy.
3. BW3 Purchase checklist.
4. MA1 Supply versus normal.
5. MA3 Main-risk sentence.
6. NG2 Jargon-free tooltips.
7. NG4 Safe defaults.
8. NG5 First-week learning meter.
9. QL1 Icons everywhere.
10. QL4 Explain disabled controls.

### Ten small improvements

1. RA1 Trust labels.
2. RA3 Equal-day history weighting.
3. PP1 Relist scenarios.
4. BW1 Best move card.
5. SW1 Sell/Hold/Vendor decision.
6. MA2 Plain price trend.
7. CM1 Read current money.
8. CM2 Emergency reserve.
9. CM3 Risk-adjusted caps.
10. IB1 Owned-bag warning.

### Five medium improvements

1. RA2 Supported sell range.
2. RA4 Volatility tier.
3. RA5 Seller concentration.
4. BW4 Mark as bought/cost basis seed.
5. NG1 State-aware Guided mode.

### Three larger strategic improvements

1. CM5 Committed-capital ledger and realized-profit loop.
2. SW4 Read-only owned-auction awareness.
3. MA4 Bounded watchlist/targeted quick checks.

## Transformation scope decision

- **Possible with current APIs/local data:** standard captured recipes, smelting, normal cloth/leather/alchemy transformations exposed as recipes, cooldown-aware transformations, market-value reagent costing.
- **Requires additional recipe/inventory work:** craft quantity, bank-held reagents, vendor-buy reagents, character/account recipe freshness.
- **Requires user-entered or captured auxiliary data:** nonstandard conversion ratios not exposed as recipes, vendor purchase prices if no safe API source is available.
- **Probably too complex:** full profession optimizer, leveling paths, shopping route, multi-step dependency graph, region-wide recipe database.

## Backlog guardrail

No item in this backlog authorizes protected transactions. All query work must remain player-initiated, bounded, and throttled. All purchase/post/cancel/vendor/craft actions remain manual in Blizzard's UI.
