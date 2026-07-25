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

### 0.2: Local Market History

Status: pending and provisional.

High-level requirements:

- Store bounded local price observations.
- Preserve data integrity across reloads.
- Show confidence based on observation count and freshness.

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
