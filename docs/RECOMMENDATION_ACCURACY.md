# Recommendation Accuracy

## Cached snapshot linkage

Every new Plan or Trade recommendation retains its source scan ID, source completion timestamp, observed unit price, maximum acceptable price, and generation timestamp. Sell also records when a targeted-item overlay supplied the actionable price. A newer full scan regenerates advice rather than relabeling an old recommendation. See `MARKET_CACHE.md` for exact freshness boundaries.

## Milestone A implementation

The production recommendation path now runs through `RecommendationPolicy.lua`. Candidates must pass freshness, positive-profit, configurable absolute-profit, maximum-price, vendor-value, conservative relisting, evidence, manipulation, and owned-bag exposure gates before they can appear. Passing candidates receive `Strong`, `Fair`, or `Speculative`; rejected candidates are `Avoid` internally and contribute a plain-language empty-state reason.

The default minimum conservative net profit is 10 silver. The normal UI ranks by trust before profit and never shows the old internal numeric score. The conservative result subtracts the Auction House cut plus one failed-listing deposit for strong personal sale history, or two otherwise. These are estimates from the latest completed scan, not promises or live prices.

## Trades accuracy model

Trades uses the lower of current median/weighted median and the seven-day median as its normal supported value. Qualification uses 95% of that value as the low exit and never relies on the optimistic exit. Deterministic demand needs repeated observation days, depth, stability, and non-poor personal outcomes; it is not labeled server sale volume. A single day cannot be Hot.

The compact snapshot lacks seller counts and a retained price ladder. The vertical slice therefore handles only stackable commodities and sizes against the exact cheapest listing instead of pretending all visible quantity is available at one price. See `docs/TRADE_SYSTEM.md` for exact gates and limitations.

## Current coverage matrix

| Factor | Current treatment | Assessment |
| --- | --- | --- |
| Current buy price | Exact cheapest eligible stack and total buyout. | Strong, but stale between scan and manual purchase. |
| Expected sell price | Minimum of supported current reference and seven-day median when history exists. | Conservative direction; still a point estimate rather than a range. |
| Auction House cut | Fixed 5% deducted. | Implemented. Must remain client-version verified. |
| Deposit cost | 30% of vendor value for an assumed 24-hour listing. | Approximate. Actual duration and API behavior are not represented. |
| Repeated relisting | Buy policy subtracts one failed-listing deposit with strong personal outcomes, otherwise two. | Conservative first pass; listing duration/rules still need live verification. |
| Stack size | Exact cheapest buy stack; caller-supplied sell stack. | Implemented, but no demand-aware stack sizing. |
| Sale volume | Personal sold/expired outcomes only. | Realm-wide volume is unavailable. Current listings are not sales. |
| Competing auctions | Listing and quantity counts. | Seller count and concentration are missing. |
| Price spread | Lowest, median, and weighted median during current scan. | Useful, but price levels/range are discarded after aggregation. |
| Historical stability | 7/30-day medians of daily averages. | No volatility, dispersion, trend, or intraday range. |
| Manipulation | Rejects a very low listing under a narrow condition. | Partial; cannot detect one-seller walls or multi-listing manipulation. |
| Extremely low volume | Minimum samples/confidence and personal-sale rejection. | Partial; the opportunity score still includes scarcity as a positive. |
| Vendor value | Sale economics and bag vendor comparison. | Implemented as a floor; should not be called liquid capital. |
| Material conversion | Craft reagent/output comparison. | Standard known recipes only. |
| Disenchant value | None. | Not supported. |
| Crafting value | Conservative reagent cost, output price/history, cut/deposit, cooldown, and 15% margin. | Implemented but lacks quantity/time/relisting analysis. |
| Available gold | User-entered budget. | Does not read actual money or enforce reserve. |
| Risk tolerance | Fixed thresholds. | Not supported. |
| Time horizon | None. | Not supported. |
| Inventory owned | Unbound carried bags are counted once per plan build, shown in buy rows, ranked below unowned stock, and block a buy at the full recommended-stack exposure. | Bank, mail, alts, and owned auctions are not included. Exact auction stacks are not split. |
| Existing player auctions | None. | Not supported. |

## Accuracy risks and corrections

| Issue | Risk and example | Recommended correction | Required data | Classic API feasibility | Complexity |
| --- | --- | --- | --- | --- | --- |
| Supply presented as demand | Twenty listings may be twenty unsold auctions, yet market depth raises flip ease. | Rename the signal to market evidence; make personal outcomes the only observed-sale input; never label demand `Strong` from listings alone. | Current listing/quantity counts; personal mail outcomes. | Available now. | Small |
| Precise `flipScore` | `73/100` implies calibrated probability without ground truth. | Replace normal-view score with `Strong`, `Fair`, `Speculative`, or `Avoid`; keep factor details in tooltip. | Existing factors plus new stability/concentration fields. | Available locally; calibration remains empirical. | Small |
| One-point sell target | A target of 1g 90s hides that plausible results may span 1g 65s–1g 95s. | Return a supported sell range: conservative floor, central target, optimistic cap. Size purchases using the floor. | Current price levels and historical low/median/high. | Feasible if compact ranges are retained. | Medium |
| Repeated relists omitted | A 20s theoretical profit can vanish after three 10s lost deposits. | Show net profit after one, two, and three failed attempts; reject if conservative scenario is non-positive for slow/speculative items. | Vendor value, duration, personal expiration rate, chosen scenario. | Calculation-only; duration rules require live verification. | Small |
| Hard-coded deposit duration | Player posts for 12 or 48 hours while model assumes 24. | Make duration explicit in the recommendation context and verify duration multipliers. | Duration selection and verified deposit calculation. | Read-only calculation feasible; exact rates need in-game fixtures. | Medium |
| Same-day scan overweighting | Ten scans today and one scan yesterday can dominate the historical median. | Weight days equally for stability/reference; retain scan count separately as evidence. | Existing daily rows. | Fully local. | Small |
| No volatility | An item alternating between 1g and 3g can show a 2g median and appear safe. | Store daily low/high or robust deviation; reject/penalize wide ranges. | Compact daily min/max or deviation. | Fully local; schema migration required. | Medium |
| No seller concentration | One player can post 80% of supply and shape the median. | Count distinct normalized seller names during scan; store count and largest visible seller share in compact snapshot/history. | Owner/full-owner per listing. | `GetAuctionItemInfo` currently provides owner; feasible, privacy-local. | Medium |
| Price levels discarded | A single 1g listing followed by 50 at 3g is materially different from a smooth spread. | Persist a tiny bounded set of the lowest meaningful price buckets or summary percentiles. | Per-scan `priceLevels`, quantity per level. | Already collected transiently; feasible with bounded storage. | Medium |
| Cheapest stack disappears | Player sees a recommendation, searches later, and the safe stack is gone. | Add a player-clicked targeted recheck or explicit `Verify price ≤ X before buying` gate. | Fresh targeted query result. | Requires verified targeted-query reintroduction and deliberate click; no automatic purchase. | Medium |
| Greedy portfolio selection | The first expensive candidate can crowd out several safer, more profitable choices. | Optimize a small candidate set for risk-adjusted profit under budget and concentration caps. | Candidate cost, conservative profit, trust tier, category. | Fully local. | Medium |
| No absolute-profit floor | A high percentage on a 10c investment can rank despite negligible gold value. | Require both minimum return rate and a level-aware/configurable absolute profit floor. | Existing cost/profit. | Fully local. | Tiny |
| Sparse personal history | Three outcomes can swing sale rate from 33% to 67%. | Apply Bayesian shrinkage toward an explicitly conservative prior; show `limited personal history`. | Sold/expired counts. | Fully local. | Small |
| Mail outcome ambiguity | Identical invoice fingerprints and mailbox removal/reappearance can misattribute counts. | Persist bounded processed outcome IDs where possible; test identical simultaneous mail; show history as approximate. | Mail indices, invoice fields, timestamps if available. | API-limited; requires live fixtures. | Medium |
| Equipment variant fallback | Partial-name lookup can select an unintended variant when exact link data is unavailable. | Never use partial-name matching for single-stack equipment recommendations; require exact item-string identity. | Item link/string and max stack. | Feasible with current data. | Small |
| Craft output quantity assumptions | A craft output may be sold in different stacks or multiple auctions. | Calculate per-craft output and a conservative sale plan; apply deposits per intended auction. | Output count, max stack, suggested stack. | Mostly local. | Medium |
| Reagent opportunity cost | Owned reagents can look free to players even though the addon prices them at market; vendor reagents may be missing. | Clearly label market-value cost; distinguish vendor, owned, and Auction House sourcing without treating owned as zero. | Bag/bank counts, vendor prices, market prices. | Bags feasible; bank only while accessible; vendor catalogs need scoped capture. | Medium |
| History survivorship bias | Only the top 1,000 current high-sample items remain; rare items vanish from history. | Prefer retention by a mix of sample count, player relevance, inventory, recipes, and watchlist. | Current candidates plus relevance flags. | Fully local. | Medium |
| Snapshot completion heuristic | A two-second quiet period may finalize partial data under latency or client changes. | Add completeness diagnostics, stable result-count checks, and live regression protocol; mark uncertain scans unusable. | Event times and repeated result counts. | Feasible but requires live validation. | Medium |
| Scan age thresholds too broad | A 20-hour snapshot may be dangerous for volatile items but allowed as fresh. | Combine age with item volatility: volatile items expire sooner. | Snapshot age and volatility tier. | Fully local after volatility exists. | Small |
| Deposit formula as certainty | The calculated deposit may be wrong for category/duration/client behavior. | Label it estimated until live fixture tests confirm exact values; keep a conservative buffer. | Verified test auctions or Blizzard UI readouts. | Read-only inspection may be possible; direct posting remains no-go. | Small |

## Proposed trust model

### Player-facing output

Use four labels, not a numeric probability:

- **Strong** — fresh, repeatable pricing with enough independent evidence and no major warning.
- **Fair** — usable evidence, but one meaningful uncertainty remains.
- **Speculative** — thin, volatile, concentrated, stale, or unsupported by personal outcomes.
- **Avoid** — missing/expired data, suspicious manipulation, negative conservative profit, excessive exposure, or repeatedly poor personal outcomes.

The label answers `How much should I trust this recommendation?`; it does not claim a sale probability.

### Gating before scoring

Return `Avoid` or no recommendation before combining factors when any hard gate applies:

- No complete snapshot or snapshot beyond the item-specific expiry limit.
- Invalid item identity, stack, money, or overflow risk.
- No buyout, unsupported equipment variant, or ambiguous match.
- Conservative resale floor does not cover purchase, 5% cut, and selected relist-loss scenario.
- Current price is above the maximum safe price.
- One item/category/portfolio exposure exceeds its capital limit.
- At least five personal outcomes with a very poor smoothed sale rate, unless the user explicitly opens advanced detail.
- Strong manipulation/concentration warning with insufficient independent history.

### Evidence factors

Factors should produce internal bands, not a displayed 0–100 score:

1. **Freshness (high weight):** compare age with volatility-aware limits. Missing age is fatal.
2. **Historical breadth (high):** distinct days matters more than repeated scans on one day.
3. **Price consistency (high):** current meaningful wall, historical median/range, and trend should broadly agree.
4. **Independent market evidence (high):** listing count, quantity, distinct sellers, and largest-seller share.
5. **Conservative economics (high):** profit remains positive after cut and appropriate relist-loss scenario.
6. **Personal outcomes (medium/high when sufficient):** smoothed sold/expired history, ideally segmented by stack/price behavior.
7. **Market depth (medium):** enough supply to establish price, explicitly not treated as demand.
8. **Data quality (medium):** rejected record ratio, missing links/info, and scan completeness diagnostics.

Recommended label mapping:

- **Strong:** no warnings; fresh; at least three distinct days; stable range; multiple sellers; positive two-relist scenario; Medium/High sample evidence.
- **Fair:** no hard gate; fresh/usable; at least two days or strong current independent evidence; positive one-relist scenario.
- **Speculative:** one-day evidence, sparse sellers, high volatility, stale-but-usable data, no personal evidence, or only the zero/one-relist case remains profitable.
- **Avoid:** any hard gate.

Missing data always moves the result down; it never receives neutral credit. An unknown personal sale rate is `unknown`, not 50%. Unknown seller concentration is `unknown`, not diversified.

### UI communication

Normal row:

```text
Ghost Mushroom
Buy up to: 18 at 1g 42s each
Expected sell range: 1g 78s–1g 95s
Estimated net profit: 5g 61s
Trust: Fair · Main risk: only 1 day of history
```

Expanded detail or tooltip:

- Scan age.
- Distinct observed days and total scans.
- Current listings/quantity and seller concentration when available.
- Historical range/volatility.
- Profit after 0/1/2 failed listings.
- Personal sold/expired evidence.
- Exact reason for the trust label.

Never display a percentage chance of sale unless it is explicitly `your personal observed rate` with sample count. Never call listing count `demand`. Never use more decimal precision than the inputs support.

## Reference and sell-range model

1. Identify a current meaningful price wall from bounded price buckets, not only the absolute lowest/median.
2. Build an equal-day-weighted historical center and robust range from recent daily summaries.
3. Set the conservative sell floor to the lower supported value after excluding invalid manipulation states.
4. Set the central target near the supported wall, capped by stable history.
5. Set the optimistic cap only when current/historical evidence supports it; never use it for purchase sizing.
6. Calculate maximum safe purchase and profit from the conservative floor.
7. Apply cut, deposit, relist scenario, and capital rules.
8. Return no recommendation when a defensible range cannot be formed.

## Test requirements

Add deterministic behavioral fixtures for:

- Trust label boundaries and missing-factor downgrades.
- Same-day scan weighting versus distinct-day weighting.
- Stable, trending, and volatile histories.
- One-seller and multi-seller price walls.
- Tiny low outlier, bulk low wall, and manipulated median.
- Zero, one, two, and three relist scenarios.
- Personal outcomes at 0, 1, 3, 5, and 20 samples.
- Exact equipment variants and ambiguous name matching.
- Portfolio selection where greedy ranking is suboptimal.
- Stale candidate recheck and disappeared cheapest stack.
- Craft outputs split across auctions.
- Snapshot rejected-record/completeness thresholds.

Until these fixtures exist, trust wording should become more conservative rather than more prominent.
