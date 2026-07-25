# Product Requirements

## Product Mission

Bank of Durotar is a standalone Auction House addon for WoW Classic Anniversary. Its primary objective is to help ordinary players make real gold through clear, responsible Auction House recommendations while remaining designed to comply with Blizzard's addon policy.

## User Problem

Players want to make gold through the Auction House but often lack the time, confidence, or spreadsheet skills to identify safe buys, profitable sales, and actual realized profit. Existing workflows can be complex, addon-dependent, or focused on raw data instead of clear action.

## Target Users

- Ordinary Classic Anniversary players who want simple Auction House guidance.
- Players who do not want a second Auction House addon.
- Players who want local, in-game tools without websites, subscriptions, OAuth, or account login.
- Developers and testers verifying live-client Auction House API behavior.

## Core UX Principles

- Use plain recommendations over complex configuration.
- Show the reason behind a recommendation through a "Why?" or details control.
- Keep the primary workflow understandable without formulas.
- Distinguish facts, estimates, and uncertainty.
- Avoid normal-player screens that feel like diagnostics.
- Require deliberate player review and action for protected game operations.

## Functional Requirements By Roadmap Milestone

### 0.0.1: Auction API Probe

Status: complete.

Requirements:

- Detect client build, interface, project constants, and Auction House API family.
- Detect relevant Auction House globals and namespaces.
- Run one manually initiated targeted Auction House query.
- Respect `CanSendAuctionQuery`.
- Avoid full scans.
- Capture bounded result samples.
- Produce a copyable diagnostic report.
- Persist only the latest diagnostic session plus bounded logs/events.

Verified live target:

- WoW `2.5.6`.
- Build `68775`.
- Interface `20506`.
- `WOW_PROJECT_ID` `5`.
- `WOW_PROJECT_BURNING_CRUSADE_CLASSIC` `5`.
- Legacy Auction House API.

### 0.1: Standalone Search, Buy, Sell, And Owned-Auction Workflow

Status: pending. Details are provisional and require compliance review before implementation.

High-level requirements:

- Provide a standalone Auction House search workflow.
- Provide player-reviewed buy workflow support.
- Provide player-reviewed sell workflow support.
- Display owned auctions.
- Add a safe query queue that respects cooldowns.
- Complete protected-action and hardware-event review before coding purchase, bid, post, or cancel paths.
- Require live-client verification.

### 0.1B: Protected Transaction Workflow Planning

Status: planned and documentation-only. No transaction behavior is implemented.

Requirements:

- Document buying, bidding, posting, and cancelling workflows separately.
- Treat `PlaceAuctionBid`, `StartAuction`, and `CancelAuction` as detected but unverified for invocation.
- Require one visible player click for one explicitly reviewed transaction unless the live client later proves a safer permitted behavior.
- Exclude bidding from the first transaction release unless later evidence shows clear product value and safe hardware-event behavior.
- Design stale-index protections before implementation.
- Design a reusable protected-action boundary before implementation.
- Design confirmation UX with clear one-action wording.
- Define live-client verification tests with low-value items.
- Keep implementation blocked until function signatures, events, hardware-event behavior, one-click/one-action behavior, stale-data protections, taint behavior, compliance review, human approval, manual test plan, and rollback plan are complete.
- Do not implement buying, bidding, posting, cancelling, mailbox handling, accounting, market history, deal detection, or profit logic in this milestone.

### 0.1A: Search Sidecar Entry Point

Status: complete and live-verified. This is a player-facing search and browse milestone, not a Find Deals implementation.

Requirements:

- Add a highly visible primary sidecar button labeled `SEARCH MARKET` for this alpha.
- Use wide, high-contrast, WoW-native red/gold styling.
- Keep the button visible near the top of the expanded Auction House sidecar.
- Display state clearly: Ready, Waiting for query cooldown, Scanning, Completed, Failed.
- Start only from a deliberate player click.
- Never auto-start when the Auction House opens.
- Prevent repeated clicks from creating overlapping scans.
- Respect `CanSendAuctionQuery` and verified throttling.
- Avoid unattended retries and indefinite retry behavior.
- Use accurate temporary wording for the single targeted/read-only search.
- Never describe a single-item targeted search as a complete Auction House scan.
- Never imply profitability analysis exists before the Find Deals milestone is implemented.
- Show normalized listings with icon, name, stack count, total buyout, unit buyout, bid detail, seller, time remaining, quality coloring, and no-buyout status.
- Support sorting by lowest unit buyout, lowest total buyout, stack size, time remaining, and item name.
- Support simple filters for buyout-only, minimum stack size, and maximum unit price.
- Show selected listing details and protected-action placeholder text.
- Keep the result list confined to the sidecar viewport with a bounded native scroll-frame row pool.

Planned future scan modes:

- Quick Scan.
- Watchlist Only.
- Inventory Markets.
- Full Scan - Advanced.

Only behavior supported by the assigned milestone and verified APIs may be active.

### 0.2: Local Market History

Status: pending and provisional.

High-level requirements:

- Store bounded local price observations.
- Preserve data integrity across reloads.
- Show confidence based on observation count and freshness.
- Default to a 60-day retention window.
- Retain days 0-7 as detailed scan observations.
- Compact days 8-30 into daily summaries.
- Compact days 31-60 into daily low, median, high, average supply, and sample count.
- Delete records older than the active retention window during weekly maintenance.
- Run maintenance at most once per week from a safe event such as login or Auction House open.
- Avoid continuous timers and player interruption.
- Record last cleanup time.
- Handle corrupt or partial records safely.
- Preserve versioned database migrations.
- Plan a future `Esc -> Options -> AddOns -> Bank of Durotar -> Market Data` settings page with retention, database size, last cleanup, clear history, and export history controls.

### 0.3: Find Deals

Status: pending and provisional.

High-level requirements:

- Recommend likely underpriced auctions only when local data confidence is sufficient.
- Show maximum safe price, expected costs, risk, and reasoning.

### 0.4: Cost Basis And Realized Profit

Status: pending and provisional.

High-level requirements:

- Track actual acquisition cost where available.
- Track fees, deposits, and sale proceeds where available.
- Treat realized profit separately from inventory value.

### 0.5: Sell My Stuff Recommendations

Status: pending and provisional.

High-level requirements:

- Recommend what to list, hold, vendor, or avoid listing.
- Consider liquidity, deposits, and stale prices.

### 0.6: Guided Daily Gold Plan

Status: pending and provisional.

High-level requirements:

- Provide a short, understandable plan using verified prior data.
- Avoid guaranteed-profit claims.

## Non-Functional Requirements

- Addon must load without other Auction House addons.
- Addon must not require external executables, websites, subscriptions, account login, OAuth, API keys, or cloud processing.
- Code must remain readable and unobfuscated.
- SavedVariables growth must be bounded.
- UI must remain responsive and readable.
- Errors must be visible enough for diagnosis without spamming chat.

## Data Integrity Requirements

- Store money internally as integer copper.
- Distinguish historical facts from estimates.
- Track data confidence and freshness.
- Handle nil and partial Auction House data safely.
- Never fabricate missing API fields or market values.
- Prefer no recommendation over a weak or misleading recommendation.
- Bound market-history storage by retention window and compaction tier.
- Delete expired market-history records only through safe, bounded maintenance.

## Security And Compliance Requirements

- Follow the WoW UI Add-On Development Policy: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
- Follow the Blizzard End User License Agreement: https://www.blizzard.com/legal/fba4d00f-c7e4-4883-b8b9-1b4500a402ea/blizzard-end-user-license-agreement
- Treat the live WoW client, `/api` browser, and Blizzard FrameXML behavior as the final technical authority.
- Do not automate protected gameplay or Auction House actions.
- Do not simulate user input or use external control.
- Do not hide code, add ads, or create paid feature gates.

## Accessibility And Readability Requirements

- Use clear labels and normal Blizzard UI controls.
- Avoid dense technical terms in normal player workflows.
- Make recommendation status readable at a glance.
- Keep advanced details optional.
- Avoid chat spam.

## Explicit Exclusions

- No Milestone `0.1` behavior is included in `0.0.1`.
- No market-history collection is included in Milestone `0.1A` unless explicitly assigned.
- No buying, bidding, posting, cancellation, deal detection, price history, or profitability analysis is included in Milestone `0.1A`.
- No external companion application.
- No web service dependency.
- No OAuth or Battle.net API credentials.
- No unattended purchases, bids, posts, cancellations, mail actions, vendor actions, crafting, or gameplay.
- No guaranteed-profit claims.
- No premium, paid, subscriber-only, donation-gated, or advertisement-supported features.

## Acceptance Criteria

- Each milestone has a scoped task definition.
- Compliance risks are identified before implementation.
- Protected functions and hardware-action requirements are reviewed before use.
- Runtime detection remains in place for optional or uncertain APIs.
- Documentation and manual test steps are updated with each behavior change.
- Live verification is recorded only after the user supplies live-client results.

## Definition Of Done

A milestone is done when:

- Scope is implemented and reviewed.
- Static checks available in the environment are run.
- No known addon policy issue remains unresolved.
- Documentation is updated.
- Manual live-client test steps are provided.
- Live-client results are recorded when available.
- Git status is reported.
- The next milestone has not been started automatically.
