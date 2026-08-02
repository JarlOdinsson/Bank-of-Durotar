# User Experience Review

## Milestone A implementation snapshot

The Plan tab now leads with one `Best Move Now` card. It shows an icon and item name, `Buy up to`, owned bag quantity when present, a maximum unit buy price, conservative expected net profit, a plain trust label, one main risk, and whether the price is only safe in the latest scan. Ranks 2–10 remain in `More Safe Flips` so the first decision is visually dominant.

Guided mode is now an optional state machine rather than a fixed slideshow. It gives one next action for: Auction House closed, scan required, scan running, stale data, best-move review, owned-stock warning, sell-item selection, sell-price use, craft review, or waiting. `Exit` always turns it off. It never scans, searches, buys, posts, or crafts automatically.

The minimum-profit field is beside the gold budget. `Apply` saves both. The empty state explains the dominant rejection reason and explicitly treats waiting as valid.

Buy, bag-sale, and craft suggestions now show item icons. Hover help explains trust, maximum price, price confidence, conservative material value, Auction House costs, manual action, and unsold-item risk without exposing the internal numeric score.

## Trades view implementation

Top navigation is now `Plan | Trades | Craft | Sell Price`. Trades uses the existing visual language and a single scrolling workspace: Trading Capital, Best Trade, two More Trades, up to five Open Trades, manual lifecycle controls, and two recent history rows. A separate Trade Rules surface keeps advanced capital and evidence settings out of Plan.

`Find Auctions` provides the item name and maximum price but performs no query or purchase. `Track Trade` explicitly creates a Watching record. More Trades and Open Trades are selected by clicking their rows. Purchase and sale forms use quantities plus unit/net silver to keep manual accounting compact. Reset Trade Data requires a second confirmation click and preserves market history, mailbox outcomes, and general settings.

## Usability goal

A player with no Auction House intuition should understand the next safe action without knowing terms such as median, spread, capital exposure, price wall, or liquidity. Bank of Durotar should make the decision smaller, not merely present more calculations.

## Immediate-answer audit

| Player question | Current answer | Gap |
| --- | --- | --- |
| What should I buy? | One featured best move with icon/name, then scrollable ranks 2–10. | Implemented; in-game layout validation pending. |
| Why should I buy it? | Trust label plus one deterministic main risk. | Implemented first pass; calibration needs real play data. |
| How many should I buy? | Exact cheapest stack quantity. | This is available quantity, not a demand/capital-sized recommended quantity. |
| Likely profit? | Estimated total upside after modeled costs. | No sell range or relist scenario; `Profit` can look certain. |
| What could go wrong? | One row-specific main risk plus a latest-scan warning. | Implemented. |
| How quickly might it sell? | Personal sold ratio sometimes. | No supported time-to-sale; listing count must not masquerade as demand. |
| How much gold is tied up? | Stack cost and plan total. | No percentage of actual liquid gold or existing exposure. |
| Do I already own some? | Buy rows show carried-bag quantity; full-stack exposure blocks another recommendation. | Bank/mail/alts/owned auctions remain out of scope. |
| Enough data? | Scans, confidence, market-memory summary. | Distinct days, volatility, seller diversity, and scan age are not visible per item. |
| What next? | State-aware Guided mode gives exactly one current action and can be exited at any time. | Control highlighting remains a later enhancement. |

## Current screen review

### Global header and scan

What the player sees: addon title, `Guided: ON/OFF`, `Scan Market`, and multi-line scan/cooldown status.

Friction:

- The first-time player must infer that scanning is step zero for every useful recommendation.
- Cooldown language explains the system but not the next action (`Come back when this reaches Ready`).
- `Cancel Scan` shares the primary button but cancellation consequences are not explained.
- Timestamp formatting is technical and longer than relative age.

Recommended hierarchy:

1. Primary state: `Ready to scan`, `Scanning`, `Prices updated 12m ago`, or `Scan available in about 6m`.
2. One primary button.
3. Technical timestamps only in tooltip.

### Plan tab

What the player sees: budget input, plan totals, market-memory counts, a scrollable top-ten flip list, three bag-sale cards, and a disclaimer.

Friction:

- Budget, planned spend, remaining spend, memory status, ten ranking rows, and bag sales compete for attention.
- Each flip row is three dense lines with cost, target, profit, return, listings, scans, and confidence/outcomes.
- `Flip score 73/100` is cognitively easy but epistemically unsafe.
- `Sell near` is a point estimate.
- No exact `Do this next` instruction or row expansion.
- The scrollbar can hide how many safe results exist.
- Buy and bag-sale tasks are different mental jobs but share the same visual priority.

Recommended hierarchy:

```text
Best move now

[icon] Ghost Mushroom                         Trust: Fair
Buy: 12 at no more than 1g 42s each
Sell range: 1g 78s–1g 95s each
Net profit after fees: about 5g 61s
Main risk: only 2 days of price history

[Find this item]
[Why this recommendation?]
```

Then show `More safe flips (4)` as a compact list. Put bag-sale suggestions in a secondary section or direct the player to Sell Price after the buy task.

### Sell Price tab

What the player sees: a three-step flow, large drag target, typed-name fallback, stack quantity, and manual Blizzard posting instructions.

Strengths:

- This is the clearest current workflow.
- Drag and shift-click are implemented rather than merely mentioned.
- The output tells the player exactly where to type the price.

Friction:

- Quantity must be typed even when a bag stack was dragged.
- The recommendation is a single price rather than a range/decision (`Sell now`, `Hold`, `Vendor`).
- No posting duration or deposit-risk explanation.
- No icon/tooltip in the final result area beyond the drop target.
- `Create Auction` wording must match the actual Classic Blizzard button in live testing.

Recommended next version:

- Autofill dragged stack quantity when safely obtainable.
- Output `Sell now`, `Hold`, `Vendor`, or `Scan first` before showing numbers.
- Show stack bid/buyout, unit price, duration, and main risk.
- Keep current step-by-step manual instructions.

### Craft tab

What the player sees: setup instructions, status/memory text, and up to three dense craft rows.

Friction:

- Players do not know which professions have been learned or when recipes became stale.
- Rows lack output icons and exact craft count recommendation.
- Materials, sale, profit, margin, profession, confidence, and scans compete equally.
- Owned materials are not distinguished from market-value opportunity cost.

Recommended hierarchy:

```text
[icon] Greater Fire Protection Potion
Craft: 5
Spend/consume materials worth: 12g 40s
Sell range: 3g 10s–3g 35s each
Estimated net profit: 3g 05s
Trust: Fair · Main risk: output price is volatile
```

Keep reagent breakdown and owner/profession in expanded detail.

### Guided mode

What the player sees: an optional eight-step panel with Back/Next/Finish and automatic tab navigation.

Friction:

- Steps are static; the guide does not know whether the budget was applied, scan completed, item selected, or action performed.
- It can say `next` while the required state is missing.
- The instruction panel consumes height without highlighting the referenced control.

Recommended evolution:

- Convert static steps to state-aware next actions.
- Highlight one relevant control with a glow/arrow.
- Disable `Next` only when doing so is helpful and explain why.
- Allow `Skip` and `Exit Guided` at all times.
- Celebrate completion quietly; do not use popups for routine actions.

## Full workflow friction

### 1. Open Auction House

- **Decision:** whether to scan or use old data.
- **Missing:** simple freshness verdict.
- **Bad outcome:** relying on old data.
- **Simplify:** `Prices are 18h old—scan before buying.`
- **Addon-owned:** yes.

### 2. Choose capital

- **Decision:** amount safe to risk.
- **Missing:** actual money, reserve, existing commitments.
- **Bad outcome:** spending repair/training/mount gold.
- **Simplify:** show `You have`, `Keep`, and `Safe to spend` with three modes.
- **Addon-owned:** yes, calculation/read-only.

### 3. Scan

- **Decision:** wait/cancel.
- **Missing:** expected duration and trustworthy completion explanation.
- **Bad outcome:** partial or stale snapshot treated as complete.
- **Simplify:** single progress sentence and conservative failure recovery.
- **Addon-owned:** yes.

### 4. Select a recommendation

- **Decision:** which item balances profit and risk.
- **Missing:** sell range, main risk, owned quantity, exposure, seller diversity.
- **Bad outcome:** high-margin dead inventory or manipulated price.
- **Simplify:** feature one best move; reveal the rest progressively.
- **Addon-owned:** yes.

### 5. Find and buy

- **Decision:** exact variant/stack and maximum acceptable price.
- **Missing:** fresh verification and exact search handoff.
- **Bad outcome:** wrong suffix, wrong stack math, price changed.
- **Clicks:** manual name search, sorting, matching, purchase.
- **Simplify:** player-clicked `Find this item`, persistent maximum-price banner, final visual checklist.
- **Addon-owned:** search assistance and guidance yes; purchasing no.

### 6. Relist

- **Decision:** price, quantity, stack, duration.
- **Missing:** stack/duration plan, current own auctions, relist scenarios.
- **Bad outcome:** deposit burn, self-undercut, saturated market.
- **Simplify:** one posting recipe with exact manual fields.
- **Addon-owned:** recommendations yes; protected post no.

### 7. Collect mail

- **Decision:** relist, hold, vendor, or accept outcome.
- **Missing:** original cost and number of attempts.
- **Bad outcome:** repeatedly relisting an unprofitable item.
- **Simplify:** `Sold: estimated realized profit` or `Expired twice: stop listing`.
- **Addon-owned:** outcome/accounting yes; mail actions no.

### 8. Learn

- **Decision:** repeat the market or avoid it.
- **Missing:** recommendation-versus-outcome comparison.
- **Bad outcome:** trusting a systematically poor market.
- **Simplify:** short weekly report with wins, losses, and markets to avoid.
- **Addon-owned:** yes, bounded/local.

## Recommended normal-view information hierarchy

1. **Action:** Buy, Sell, Craft, Wait, Vendor, or Avoid.
2. **Item identity:** icon, exact name/variant, quantity.
3. **Hard boundary:** maximum buy price or exact posting fields.
4. **Conservative outcome:** sell range and estimated net profit after fees.
5. **Trust and main risk:** one word plus one sentence.
6. **Capital effect:** spend and committed percentage.
7. **Next action:** one button or one manual instruction.
8. **Advanced evidence:** tooltip/expansion only.

Avoid showing score, listings, scans, confidence, return, target, and personal outcomes all at equal visual weight.

## New-player language guide

Prefer:

- `How much you can safely spend`
- `Do not pay more than`
- `Likely selling range`
- `Profit after Auction House fees`
- `We need more price history`
- `This item may take several tries to sell`
- `You already own enough—sell those first`

Avoid in the normal view:

- Liquidity
- Capital exposure
- Weighted median
- Price wall
- Opportunity score
- Absorption
- Bayesian rate

Those concepts can appear in developer documentation or advanced explanations translated into plain language.

## Accessibility and cognitive-load rules

- Do not rely on red/green alone; pair color with words/icons.
- Keep one primary action per state.
- Keep normal recommendation cards to five essential lines or fewer.
- Use consistent positions for quantity, maximum price, profit, trust, and next action.
- Preserve item icons and normal WoW tooltips.
- Use relative data age in normal view.
- Hide empty rows and unavailable advanced fields.
- Every disabled control needs a nearby reason.
- `Avoid` must be visually stronger than a tempting profit number.
- Guided mode must always be dismissible.

## Highest-value interface changes

1. Replace numeric flip score with trust label and main risk.
2. Feature one `Best move now` card above the remaining list.
3. Add a player-clicked `Find this item` handoff after API verification.
4. Show supported sell range instead of one target.
5. Add owned quantity and `Sell yours first` warning.
6. Make Guided mode state-aware and highlight one control.
7. Add icons/tooltips to bag-sale and craft rows.
8. Add `Why?` expansion with evidence details.
9. Show actual safe-to-spend gold and reserve.
10. Convert sell output into `Sell now/Hold/Vendor/Scan first` decisions.

## UX validation

In-game tests should recruit at least one player unfamiliar with Auction House addons. Give no verbal instruction and ask them to:

1. Set aside repair gold.
2. Scan safely.
3. Identify the best recommended flip.
4. State the maximum acceptable purchase price.
5. Explain the main risk.
6. Find the exact auction without buying the wrong variant.
7. Price one bag item.
8. Explain what to do after an expiration.

Completion criteria: the player completes each task, can state why the recommendation is uncertain, and never interprets estimated profit as guaranteed.
