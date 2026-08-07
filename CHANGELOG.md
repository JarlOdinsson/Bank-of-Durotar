# Changelog

## 0.5.0-beta.3 — Shop and acquisition depth

- Added a dedicated `Shop` view for exact typed, Shift-clicked, or dragged item selection.
- Added optional additional-buy quantity and budget controls with whole-stack selection and cumulative weighted cost.
- Persisted at most 12 seller-free stack/total price groups per item; raw listings and seller identities are still not stored.
- Added conservative fair value, safe ceiling, price-cliff detection, owned-bag quantity, freshness warnings, and explicit weak-evidence states.
- Added one shared acquisition evaluator used by both Shop and Plan, including capital-efficiency ranking inputs based on conservative margin, evidence, and market depth.
- Preserved old cached snapshots through an explicit cheapest-stack fallback that asks for a fresh scan to obtain depth.
- Added deterministic Lua/Python coverage for target sizing, budgets, weighted averages, cliff detection, weak evidence, old-cache fallback, and bounded aggregation.

## 0.5.0-beta.2 — Persistent market cache

- Added one compact latest-completed snapshot per bounded project/region/realm/faction market scope.
- Migrated the prior single-snapshot schema without crossing market boundaries.
- Added atomic completion validation so interrupted or invalid refreshes preserve the prior snapshot.
- Added deterministic freshness labels, coverage counts, and exact completion details.
- Added cached-data reuse on Auction House reopen, `/reload`, and logout without automatic full scans.
- Added player-clicked targeted item checks for Sell and selected Trades as a separate expiring overlay.
- Added recommendation source linkage, feature-specific aging rules, cache commands, tests, and documentation.

## 0.5.0-beta.1 — Milestone A and Trades vertical slice

### Plan money controls

- Replaced the ambiguous Budget and Min Profit fields with separate Gold, Silver, and Copper inputs.
- Added integer-copper decoding, overflow normalization, safe invalid-input handling, keyboard navigation, and denomination tooltips.
- Preserved existing copper-denominated settings and kept Plan limits independent from Trades capital rules.
- Added deterministic conversion, migration, reopening, separation, and overflow tests.

### Trades vertical slice

- Added `Plan | Trades | Craft | Sell Price` navigation without replacing Plan or Best Move Now.
- Added shared supported-value, exit-range, stability, deterministic demand, confidence, ownership, and freshness analysis.
- Added separate Quick Move and Trade policies plus four-way candidate routing.
- Added actual-character-gold trading capital, emergency reserve, committed capital, Conservative/Balanced/Aggressive modes, and editable Trade Rules.
- Added one Best Trade, two secondary opportunities, profit/return ranges, demand/confidence labels, main risk, and explicit empty states.
- Added explicit Track, Mark Purchased, Mark Listed, Record Sale, Close, and Abandon actions. None perform Auction House transactions.
- Added multiple purchase batches, weighted average cost, partial-sale cost allocation, remaining basis, realized profit, and bounded trade history.
- Added deterministic Trade policy/tracker fixtures and detailed trade-system documentation.

- Replaced the normal-view numeric flip score with `Strong`, `Fair`, `Speculative`, and hard `Avoid` decisions.
- Added deterministic safety gates for stale or malformed data, non-positive and below-minimum profit, unsafe prices, misleading vendor economics, weak evidence, manipulation risk, relisting loss, and excessive owned bag exposure.
- Added a configurable minimum expected profit, defaulting to 10 silver.
- Ranked safe opportunities by trust first, then bag exposure, conservative net profit, capital required, internal score, and a stable name tie-break.
- Added a featured `Best Move Now` card with item icon/name, exact listing quantity, owned count, maximum unit price, conservative net profit, trust label, one main risk, and scan freshness language.
- Kept ranks 2–10 in the scrollable `More Safe Flips` list and retained three bag-sale suggestions.
- Added item icons and plain-language hover help to buy, bag-sale, and craft suggestions.
- Corrected the craft note to reflect that expected deposit loss is already included in its profit estimate.
- Changed Guided mode into a dismissible, state-aware next-action helper instead of a fixed tutorial sequence.
- Limited the minimap button's cursor-position updates to the brief time it is actively being dragged.
- Added deterministic recommendation-policy fixtures and expanded the offline checks.

Offline checks pass. In-game Classic Anniversary validation is still required before release; this changelog does not claim the UI or API behavior has been live-tested for Milestone A.
