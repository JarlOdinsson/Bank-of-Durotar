# Product Roadmap

## Delivered in 0.5.0-beta.3

- Dedicated exact-item Shop workflow with optional additional quantity and budget.
- Bounded seller-free acquisition depth, whole-stack cumulative cost, conservative stop, and price-cliff detection.
- Shared acquisition evaluator for Shop and Plan with explicit confidence/depth-adjusted capital efficiency.

## Delivered in 0.5.0-beta.2

- Scope-isolated latest-completed snapshot cache with migration and bounded retention.
- Atomic candidate validation preserving the previous snapshot after interrupted or invalid scans.
- Central Fresh, Recent, Aging, Stale, and Historical-only classifications.
- Cache age/coverage UI, exact completion tooltip, and manual refresh action.
- Separate short-lived targeted-item overlays for Sell and selected Trades.
- Recommendation source linkage and feature-specific age policies.

## Trades vertical slice — implemented, offline validated, in-game validation pending

The first Trades milestone now includes dedicated navigation/view, shared analysis, separate Quick Move and Trade policies, candidate routing, deterministic demand/confidence, capital modes, Best Trade plus two alternatives, explicit tracking, manual lifecycle actions, multiple purchase batches, weighted/remaining cost basis, manual partial sales, realized profit, bounded history, Trade Rules, freshness checks, tests, and documentation.

Later Trades work: use the new bounded acquisition ladder for supported multi-listing trade sizing, verify read-only owned-auction data, add optional reliable mailbox reconciliation, expose more than two history rows, and calibrate thresholds from live play. None of those are prerequisites for testing this conservative exact-listing vertical slice.

## Ranking method

The total score uses the requested weights:

- Expected gold-making value: 30%.
- Accuracy and trust improvement: 25%.
- Ease of use: 20%.
- Development effort: 15% (higher score means easier).
- Fit with the lightweight philosophy: 10%.

Scores are comparative planning estimates, not predicted profit.

## Ranked top 25

| Rank | Feature | Problem solved | Score | Complexity | Expected benefit | Main risk | Dependencies | Milestone |
| ---: | --- | --- | ---: | --- | --- | --- | --- | --- |
| 1 | Trust labels + hard gates | Numeric confidence implies unsupported precision. | 94 | Small | Safer decisions and stronger credibility. | Poor thresholds could hide good markets. | Reason-code cleanup; accuracy fixtures. | A |
| 2 | Relist-aware net profit | One expected deposit understates slow-item losses. | 92 | Small | Prevents margins that disappear after expiration. | Deposit assumptions require validation. | Duration/deposit fixtures. | B |
| 3 | Actual gold + emergency reserve | Entered budget can consume essential gold. | 91 | Small | Prevents overcommitment immediately. | Money API/version assumptions. | Read-only money API verification. | B |
| 4 | Owned-bag duplicate warning | Plan recommends buying stock already owned. | 90 | Small | Reduces dead inventory with current data. | Exact equipment identity. | Existing bag scan. | A |
| 5 | Supported sell range | One price target hides uncertainty. | 89 | Medium | Sizes buys from a defensible floor. | Range can still appear predictive. | Compact price buckets/history range. | B |
| 6 | Main-risk sentence | Players must interpret dense evidence. | 88 | Tiny | Fast, beginner-safe comprehension. | Wrong reason prioritization. | Trust reason codes. | A |
| 7 | Equal-day history weighting | Repeated same-day scans bias history. | 87 | Small | More stable reference prices. | Behavior changes versus old history. | History migration/test fixtures. | B |
| 8 | Best move card | Ten detailed rows overload new players. | 86 | Small | One obvious first action. | Top candidate must be trustworthy. | Trust model. | A |
| 9 | Stale-price purchase gate | Recommendation can expire before manual buy. | 85 | Tiny | Prevents price-chasing mistakes. | Text alone cannot verify live price. | Existing age/maximum price. | A |
| 10 | Absolute-profit floor | High-return copper trades waste time. | 84 | Tiny | Better practical recommendations. | One default may not fit all levels. | Existing economics. | A |
| 11 | Risk-adjusted per-item caps | Half-budget maximum is too large for risky items. | 83 | Small | Aligns spend with evidence. | Risk tier errors affect sizing. | Trust/risk labels; actual deployable gold. | B |
| 12 | `Why no safe buys?` | Empty states look broken. | 82 | Small | Teaches waiting and improves trust. | Requires reliable rejection aggregation. | Structured rejection reasons. | A |
| 13 | Behavioral economics tests | High-risk calculations have few fixtures. | 81 | Medium | Prevents silent profit regressions. | Test harness effort. | Lua/Python fixture design. | A/B |
| 14 | Volatility tier | Median hides unstable markets. | 80 | Medium | Blocks spike-driven buys. | Compact history growth. | Daily low/high/deviation schema. | B |
| 15 | Manual `I bought this` record | No purchase outcome or cost basis exists. | 79 | Medium | Starts committed-capital and realized-profit loop. | Manual entry may be inaccurate. | Cost-basis schema and confirmation UX. | C |
| 16 | Seller concentration | One seller can manufacture the visible market. | 78 | Medium | Better manipulation protection. | Seller fields may be incomplete. | Full-scan aggregation changes; live tests. | B |
| 17 | Sell/Hold/Vendor/Wait decision | Selling view always centers a price. | 77 | Small | Prevents bad timing and deposit burn. | Hold advice depends on volatility/history. | Trust/range model. | C |
| 18 | State-aware Guided mode | Static steps do not confirm progress. | 76 | Medium | Strongest onboarding improvement. | UI complexity and edge states. | Stable primary workflows. | A |
| 19 | Category concentration caps | Portfolio can be ten versions of one bet. | 75 | Medium | Protects against category crashes. | Broad categories may misclassify. | Item class/subclass persistence. | B |
| 20 | Purchase checklist | Players confuse unit and stack prices. | 74 | Tiny | Fewer wrong-stack/wrong-price mistakes. | UI crowding. | Existing buy fields. | A |
| 21 | Icons/tooltips on sell and craft | Text-only rows slow item recognition. | 73 | Tiny | Faster use with minimal bloat. | Item cache misses. | Item IDs in recommendation results. | A |
| 22 | Owned-auction awareness | Existing listings and self-undercuts are invisible. | 72 | Large | Major exposure and selling protection. | API/compliance/live-client uncertainty. | Read-only owned-auction probe. | C/Research |
| 23 | Craft opportunity-cost labels | Owned materials feel free. | 71 | Small | More honest craft profit. | Players may misunderstand market value. | Bag/bank counts and existing reagent pricing. | D |
| 24 | Player-clicked exact price recheck | Manual search may find a changed market. | 70 | Medium | Strong handoff protection. | Targeted query throttling and stale events. | Reverified targeted query controller. | C/Research |
| 25 | Realized-profit summary | Player cannot tell whether advice made gold. | 69 | Large | Creates product learning and compelling proof. | Matching buys, quantities, deposits, and mail is approximate. | Cost basis, outcome ledger, owned inventory. | C/Later |

## Best-of selections

- **Best immediate fix:** replace numeric flip score with trust label plus main risk.
- **Best tiny feature:** absolute-profit floor.
- **Best one-night improvement:** purchase checklist plus stale maximum-price warning.
- **Best weekend feature:** actual gold, reserve, and risk-adjusted purchase caps.
- **Best accuracy improvement:** supported sell range backed by volatility-aware history.
- **Best interface improvement:** one expanded `Best move now` card.
- **Best profit-protection feature:** relist-aware net profit.
- **Best feature for new players:** state-aware Guided mode.
- **Best profession feature:** owned-material opportunity-cost labels and bounded craft quantity.
- **Best feature to advertise publicly:** `Shows what to buy, the most you should pay, the likely selling range, and the main risk—without automating the Auction House.`
- **Most tempting feature to reject:** automated buying/posting queues.

## Dangerous ideas: rejection list

| Idea to reject | Why |
| --- | --- |
| Automatic buying or bidding | Protected/action-policy risk, stale-index danger, and removes deliberate player review. |
| Direct `StartAuction` posting | Live test caused Blizzard to disable the addon; permanent no-go without a new compliance decision. |
| Automatic cancellation/reposting | Protected behavior, encourages churn, and can multiply deposit loss. |
| One-click bulk transaction queues | One click must not trigger chains of purchases/posts/cancels; high error and compliance risk. |
| Bid sniping timers | Unattended behavior, false precision, and contrary to the simple advisory mission. |
| Continuous/background scanning | Violates deliberate-scan philosophy, stresses throttling, and increases stale-event bugs. |
| Automated page traversal as a full-scan substitute | Unverified, query-heavy, fragile, and unnecessary while verified get-all exists. |
| Realm-wide sale probability percentages | The API does not expose completed market sales; presenting a probability would be fabricated precision. |
| AI price forecasts | No sufficient training/ground-truth data; adds opacity and false confidence. |
| Market-control/pump recommendations | Encourages manipulation and exposes beginners to concentrated risk. |
| External paid price feeds or subscriptions | Conflicts with product rules, privacy, maintenance, and local-realm truth. |
| Desktop companion or screen scraping | External automation/security/compliance burden and unnecessary bloat. |
| Full TradeSkillMaster/Auctionator replacement | Duplicates mature suites and destroys the focused value proposition. |
| Unbounded raw-auction history | SavedVariables/memory/performance cost; creates a data warehouse instead of an advisor. |
| Automatic mailbox collection, vending, mailing, or crafting | Protected gameplay automation and scope expansion. |
| Hard-coded disenchant-profit engine without verified tables | Expansion/version maintenance and outcome-range uncertainty create misleading advice. |
| Cross-version modern/legacy abstraction now | Current target is verified legacy Anniversary; speculative compatibility would dilute testing. |
| Social/crowdsourced price exchange | Manipulation, poisoning, privacy, synchronization, and maintenance risk exceed product value. |
| Arbitrary formula/settings editor | Pushes responsibility back to beginners and turns the addon into a spreadsheet. |
| Guaranteed-profit or `guaranteed sale` language | Factually unsupported and harmful to inexperienced players. |

## Milestone A — Immediate polish

**Implementation status (2026-08-02): code complete; offline checks pass; in-game validation pending.**

Implemented in this milestone:

- Trust-first policy with `Strong`, `Fair`, `Speculative`, and hard `Avoid` results.
- One deterministic main-risk reason and explanatory empty state.
- Configurable 10-silver default absolute-profit floor and conservative one/two-relist model.
- Bag-owned exposure shown, ranked down, and excluded when the player already owns the full recommended stack.
- Featured `Best Move Now` card plus scrollable ranks 2–10.
- State-aware, dismissible Guided next action.
- Deterministic Lua fixtures and always-run offline policy cases.

Buy, bag-sale, and craft rows now include item icons and concise hover help. Their final positioning and tooltip behavior still require in-game layout/taint validation.

### Scope

- Replace normal-view numeric flip score with Strong/Fair/Speculative/Avoid.
- Add one main-risk sentence and better empty-state rejection reasons.
- Add absolute-profit floor and prominent `Do not pay more than` wording.
- Add owned-bag duplicate warnings.
- Feature one `Best move now` card; keep the rest collapsed/scrollable.
- Add sell/craft icons and jargon tooltips.
- Make Guided mode state-aware for budget, scan, and item-selection steps.
- Add behavioral fixtures for existing opportunity/pricing calculations before changing thresholds.

### Likely files/modules

`OpportunityService.lua`, `GoldPlan.lua`, `Sidecar.lua`, `PricingService.lua`, `tests/`, README, and the planning docs.

### Risks

Threshold changes may reduce the number of visible recommendations. That is acceptable if explanations are clear. UI work can overflow low-resolution layouts and requires Classic template testing.

### Validation

- Deterministic fixtures for trust gates, absolute profit, duplicate bags, and reason priority.
- Existing offline suite.
- In-game 1024×768 or comparable low-height layout test.
- New-player task test without verbal coaching.

### In-game testing required

Item icons/tooltips, guided highlights/state changes, bag identity, scroll/expansion behavior, and disabled-state copy.

### Explicit non-goals

No schema-heavy market history, targeted query, transaction, bank, owned-auction, or cost-basis work.

### Completion criteria

Every recommendation answers action, exact item/quantity, maximum price, conservative profit, trust, main risk, and next manual step in five lines or fewer. Empty results explain why waiting is correct.

Code/offline result: met. Live completion remains blocked on the in-game checks listed above.

## Milestone B — Better recommendations

### Scope

- Equal-day historical reference.
- Compact historical range/volatility.
- Bounded current price buckets and seller-concentration summaries.
- Supported sell ranges.
- Relist-aware economics.
- Actual current gold, emergency reserve, risk-adjusted item caps, and category caps.
- Portfolio selection using conservative profit and exposure rather than pure greedy rank.

### Likely files/modules

`MarketData.lua`, `MarketHistory.lua`, `AuctionAPI.lua`, `PricingService.lua`, `OpportunityService.lua`, `GoldPlan.lua`, `Core.lua`, `Sidecar.lua`, migrations, and tests.

### Risks

SavedVariables growth, migration errors, incomplete owner data, category misclassification, and deposit-duration assumptions.

### Validation

- Schema migration fixtures from current version.
- Stable/volatile/manipulated market fixtures.
- Seller concentration and price-bucket fixtures.
- 0–3 relist economics and portfolio optimization cases.
- SavedVariables size and full-scan frame-time measurements.

### In-game testing required

Owner field availability, scan memory/time, deposit estimates against Blizzard UI, money API, history migration, and conservative-range behavior on several real markets.

### Explicit non-goals

No global sale velocity, automatic transactions, detailed charts, or external prices.

### Completion criteria

No buy is recommended unless its conservative range covers cut and tier-appropriate relist loss within actual deployable gold and concentration caps. Trust labels cite defensible evidence.

## Milestone C — Better selling

### Scope

- Sell/Hold/Vendor/Wait decisions.
- Manual `I bought this` cost-basis record.
- Bounded committed-capital ledger.
- Expiration/relist recommendations.
- Read-only bank/mail snapshots.
- Research and, only if verified, read-only owned-auction awareness and deliberate exact-item rechecks.
- Realized-profit matching where evidence is sufficient; otherwise label as estimate.

### Likely files/modules

New small accounting/inventory modules may be justified; also `SalesHistory.lua`, `GoldPlan.lua`, `PricingService.lua`, `AuctionAPI.lua`, `Sidecar.lua`, `Core.lua`, tests, and migrations.

### Risks

Ambiguous mail matching, stale bank/alt data, manual cost entry errors, protected-action temptation, and scope growth.

### Validation

- Outcome matching fixtures with identical mail.
- Exact variant and partial inventory cases.
- Repeated expiration and vendor-floor cases.
- Read-only API probes separated from normal UI until approved.

### In-game testing required

Mailbox invoices/attachments, bank availability, owned-auction reads, targeted query cooldown/stale events, and full manual posting workflow.

### Explicit non-goals

No direct posting, cancellation, buyout, automatic mail, or full accounting suite.

### Completion criteria

The addon can state known acquisition cost, current committed exposure, recommended disposition, and realized/estimated outcome without performing a protected action or pretending unknown costs are known.

## Milestone D — Profession opportunities

### Scope

- Icons and simpler craft cards.
- Owned-material market-value labeling.
- Bounded craft quantity and capital sizing.
- Recipe freshness/character status.
- Lightweight transformation labeling for recipes already exposed by the profession API.
- Research vendor reagent capture and disenchant feasibility separately.

### Likely files/modules

`CraftingService.lua`, inventory/accounting components from C, `PricingService.lua`, `GoldPlan.lua`, `Sidecar.lua`, and tests.

### Risks

Overstated output demand, incorrect vendor buy prices, stale recipe sets, multi-output/stack assumptions, and expanding into a full crafting suite.

### Validation

Fixtures for owned versus market-value reagents, cooldowns, output counts, missing reagents, multiple characters, and conservative quantity caps.

### In-game testing required

Representative professions, vendor reagents, cooldown recipes, multi-output crafts, closed/open bank differences, and recipe refresh behavior.

### Explicit non-goals

No leveling guides, dependency graph optimizer, shopping route, automatic crafting, or maintained global recipe/disenchant database.

### Completion criteria

Craft advice states quantity, material opportunity cost, supported sell range, conservative net profit, trust, and main risk for recipes the addon actually knows.

## Milestone E — Public release readiness

### Scope

- Consolidate current docs and changelog.
- Version/schema alignment and upgrade notes.
- Expanded deterministic tests and manual live-test matrix.
- Low-resolution UI, reload/login, corrupt-data, realm/faction-switch, and long-session checks.
- Package verification and reproducible release checklist.
- Lightweight opt-in feedback template asking whether recommendations sold, expired, or confused users.

### Likely files/modules

README, `.toc`, changelog/release docs, tests, packaging script/checks, and only production fixes found by validation.

### Risks

Documentation drifting from implementation, stale release archive, untested migrations, and overclaiming profitability/compliance.

### Validation

Offline suite, Lua behavioral fixtures, package-content checks, clean-install and upgrade tests, live Classic Anniversary checklist, and novice usability session.

### In-game testing required

Clean saved variables, upgrade from 0.4.0, scan cooldown, full recommendation loop, mailbox outcomes, profession capture, UI at multiple scales, and taint/error monitoring.

### Explicit non-goals

No new market engines during the release-hardening window.

### Completion criteria

The packaged addon matches versioned source, every advertised feature is tested, limitations are explicit, no protected transaction call exists, and a novice can complete the core loop without external instructions.

## Recommended next milestone

Finish Milestone A's in-game validation, then begin Milestone B. Validate the low-resolution layout, item icons/tooltips, state transitions, exact-stack language, bag identity, and scan freshness before treating Milestone A as release-ready.
