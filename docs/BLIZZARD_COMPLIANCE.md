# Blizzard Compliance Register

This is a living compliance register for Bank of Durotar.

## Official References

- WoW UI Add-On Development Policy: https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
- Blizzard End User License Agreement: https://www.blizzard.com/legal/fba4d00f-c7e4-4883-b8b9-1b4500a402ea/blizzard-end-user-license-agreement
- Classic UI compatibility notice: https://us.forums.blizzard.com/en/wow/t/user-interface-updates-in-classic/2325408
- Codex AGENTS.md documentation: https://developers.openai.com/codex/agent-configuration/agents-md

The live WoW client, its `/api` browser, and Blizzard FrameXML behavior are the final technical authority for available addon APIs.

## Approval Language

Do not describe Bank of Durotar as "Blizzard approved," endorsed, authorized, certified, or individually approved. Blizzard does not provide an individual addon approval or certification process.

Acceptable language:

- Blizzard-policy compliant.
- Designed to comply with Blizzard's addon policy.
- Requires live-client verification.

## Allowed Behavior

Bank of Durotar may:

- Read data exposed by Blizzard's addon API.
- Present and sort Auction House data.
- Calculate per-unit prices, fees, costs, margins, risk, and realized profit.
- Maintain bounded local market history.
- Recommend purchases, sales, quantities, and maximum prices.
- Stage actions where Blizzard permits it.
- Require the player to review and initiate each protected action.
- Use SavedVariables.
- Use native Blizzard UI controls.
- Use addon communication responsibly if later required and reviewed.

## Prohibited Behavior

Bank of Durotar must not:

- Perform unattended gameplay or unattended Auction House activity.
- Automatically buy, bid, post, or cancel without a fresh player hardware action when required.
- Simulate mouse clicks or keyboard input.
- Use auto-clickers, keyboard automation, macros, external input injection, or OS-level automation.
- Bypass protected functions, secure execution, taint restrictions, throttling, query cooldowns, or hardware-event requirements.
- Use external executables to control WoW.
- Read or write process memory.
- Inject code into the WoW client.
- Use screen scraping or computer vision to automate gameplay.
- Use ordinary HTTP requests from the addon.
- Store OAuth client secrets, API secrets, passwords, or Battle.net credentials.
- Obfuscate or conceal addon code.
- Include advertisements.
- Include paid, premium, subscriber-only, or donation-gated addon features.
- Sell access to addon functionality.
- Spam chat, auction queries, addon messages, or Blizzard services.

## Protected-Action Review Checklist

Before implementing any feature that can result in a purchase, bid, auction post, cancellation, mail action, vendor transaction, craft, or other protected game action:

- Identify the final protected function or game action.
- Verify whether a hardware event is required in the live client.
- Ensure the final action is directly tied to a visible player click or keypress.
- Avoid automatic retry.
- Avoid queued protected-action chains from one click unless the live client explicitly permits that exact behavior.
- Do not fall back to insecure execution when blocked.
- Show the player what action is required.
- Record uncertainty in this document.
- Stop and request live-client verification if legality or API behavior is unclear.

## Auction Query And Throttling Checklist

Auction queries must:

- Respect `CanSendAuctionQuery` or the verified equivalent.
- Respect query cooldowns and throttling.
- Avoid uncontrolled loops.
- Avoid `OnUpdate` polling when events or bounded timers work.
- Use explicit timeouts.
- Prevent stale events from completing newer requests.
- Prevent duplicate result events from duplicating observations.
- Avoid automatic hammer retries.
- Avoid full scans unless deliberately player-initiated and separately documented.
- Clearly show progress, cooldowns, pauses, and failures.

## Public, Free, Source-Visible Requirements

- Source code must remain readable and unobfuscated.
- Public releases must include the full functional addon code.
- GitHub and CurseForge releases must be free.
- No premium or paid feature branch may exist.
- No ads or solicitation may appear inside the addon.

## External Service Restrictions

The core addon must not require:

- OAuth.
- Battle.net API credentials.
- A website.
- A desktop companion.
- Cloud processing.
- Paid data.
- A subscription.

Any future external companion requires separate architecture and compliance review. It must never control the WoW client or enable unattended gameplay.

## Known Verified Client Facts

Milestone `0.0.1` live verification:

- WoW version: `2.5.6`.
- Build: `68775`.
- Interface: `20506`.
- `WOW_PROJECT_ID`: `5`.
- `WOW_PROJECT_BURNING_CRUSADE_CLASSIC`: `5`.
- Auction House API family: legacy.
- `QueryAuctionItems` exists and works.
- `CanSendAuctionQuery` exists.
- `GetNumAuctionItems` exists.
- `GetAuctionItemInfo` exists.
- `GetAuctionItemLink` exists.
- `GetAuctionItemTimeLeft` exists.
- `PlaceAuctionBid` exists and was detection-only.
- `StartAuction` exists and was detection-only.
- `CancelAuction` exists and was detection-only.
- `C_AuctionHouse` does not exist.
- One manually initiated `Netherweave Cloth` search returned 50 results.
- 20 sample results were normalized successfully.
- No probe error occurred.
- Query readiness reported false immediately after completion due to the legacy query cooldown.
- The client emitted repeated `AUCTION_ITEM_LIST_UPDATE` events for the same query.

Milestone `0.1C` live posting probe:

- `Prepare Post Test` passed for one manually staged sell-slot item.
- `Prepare Final Click` passed.
- `Execute 1 Post Test` issued exactly one direct `StartAuction` call from the visible execute button.
- The client immediately displayed Blizzard's addon-disabled popup: `This addon has been disabled. You should install an updated version.`
- Bank of Durotar was disabled for the session.
- Treat this as a failed protected-action gate for direct addon posting.
- Direct `StartAuction` posting implementation is no-go.
- Do not retry direct `StartAuction` tests unless a separate compliance review explicitly reopens the question.

## Open Compliance Questions

- Exact hardware-event requirements for purchase, bid, post, and cancel workflows must be verified before Milestone `0.1` implementation.
- Full-scan availability, legacy `getAll` query behavior, completion conditions, cancellation behavior, duplicate event behavior, and safe use rules require Milestone `0.1D` live-client validation before production use.
- Deposit and fee APIs for future sell and profit features require live-client verification.
- Compliant posting research must investigate Blizzard-UI-assisted approaches only: the player uses Blizzard's own posting control, while Bank of Durotar may only read, prefill, or guide reviewed values where the live client permits it.
- Mail, vendor, crafting, and inventory actions require separate protected-action review before any related feature.

## Compliance Decision Log

| Date | Milestone | Decision | Rationale |
| --- | --- | --- | --- |
| 2026-07-24 | `0.0.1` | Diagnostic-only probe accepted for live testing. | One manually initiated targeted query; no buy, bid, post, or cancel calls; no unattended retries; no external service; live tested successfully on project ID `5` and interface `20506`. |
| 2026-07-25 | `0.1A` | Read-only sidecar search live-verified. | Manual targeted legacy search worked; sidecar docked correctly; bounded scrollable six-row result viewport worked; sorting, filtering, and row selection worked; no Lua error, blocked-action warning, or taint warning was observed. No full scan, auto-page, buy, bid, post, cancel, deal detection, market history, external service, or unattended retry. |
| 2026-07-25 | `0.1B` | Transaction workflows remain blocked pending live verification. | Planning only. Future buyout, posting, and cancellation workflows must use one visible player click for one reviewed action by default, revalidate stale data immediately before the protected call, never auto-retry, and never execute from timers, events, `OnUpdate`, login, AH open, search completion, or background queues. Bidding is recommended for exclusion from the first transaction release. |
| 2026-07-25 | `0.1C` | Developer-only transaction probe accepted for Stage A read-only live testing. | Disabled by default; requires phrase enablement; normal sidecar has no transaction controls; protected calls are isolated to final explicit developer buttons; no retry, queue, loop, bulk action, market history, profit logic, or deal detection. Transaction implementation remains no-go until live results are reviewed. |
| 2026-07-25 | `0.1C` | Direct protected posting is no-go. | A live `StartAuction` post probe prepared successfully, passed final validation, and issued exactly one direct protected call from a visible button. The client immediately disabled the addon. Posting implementation must not use direct addon `StartAuction`; future research is limited to compliant Blizzard-UI-assisted posting where the player uses Blizzard's own posting control. |
| 2026-07-25 | `0.3A` | Selling-price recommendation planning accepted as calculation-only architecture. | Automatic price calculation and editable field prefill are acceptable design goals when based on valid local data, but automatic posting remains prohibited. Future implementation must leave fields blank when data is unreliable, avoid guaranteed-profit language, require explicit player review, and treat posting as Blizzard-UI-assisted only unless a future compliance review proves another path safe. |
