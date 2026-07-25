# Bank of Durotar Agent Instructions

These instructions apply to the entire repository. They are standing rules for all future Codex work on Bank of Durotar.

Codex AGENTS.md reference: https://developers.openai.com/codex/agent-configuration/agents-md

## Required Reading Before Code Edits

Before editing code, read these files:

- `AGENTS.md`
- `docs/REQUIREMENTS.md`
- `docs/BLIZZARD_COMPLIANCE.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `docs/TASKS.md`
- `docs/TESTING.md`

## Product Mission

Bank of Durotar is a standalone Auction House addon for WoW Classic Anniversary.

Its primary objective is to help players make real gold through clear, responsible Auction House recommendations.

Its defining product qualities are:

- Extremely simple to use.
- Friendly to ordinary players.
- Clear recommendations instead of configuration complexity.
- Transparent calculations.
- No second Auction House addon required.
- No external application required.
- No subscription or account login required.
- No unattended operation.

Every feature must directly support at least one of these questions:

1. What should I buy?
2. What should I sell?
3. What is the maximum safe price?
4. How much should I buy or list?
5. Did I actually make gold?

Features that do not support the product mission should be deferred or rejected.

## Absolute Compliance Prohibitions

Bank of Durotar must never:

- Perform unattended gameplay.
- Perform unattended Auction House activity.
- Automatically buy auctions without a fresh player hardware action when the client requires one.
- Automatically bid without a fresh player hardware action when the client requires one.
- Automatically post auctions without a fresh player hardware action when the client requires one.
- Automatically cancel auctions without a fresh player hardware action when the client requires one.
- Simulate mouse clicks or keyboard input.
- Use auto-clickers, keyboard automation, macros, external input injection, or OS-level automation.
- Use hidden background automation.
- Continue purchasing, posting, bidding, or canceling while the player is absent.
- Attempt to bypass protected functions, secure execution, taint restrictions, throttling, query cooldowns, or hardware-event requirements.
- Circumvent Blizzard UI restrictions.
- Call protected functions from insecure or automatically triggered execution paths.
- Use external executables to control WoW.
- Read process memory.
- Write to process memory.
- Inject code into the WoW client.
- Use screen scraping or computer vision to automate gameplay.
- Use ordinary HTTP requests from the addon.
- Store OAuth client secrets, API secrets, passwords, or Battle.net credentials.
- Obfuscate or conceal addon code.
- Include advertisements.
- Include paid, premium, subscriber-only, or donation-gated addon features.
- Sell access to addon functionality.
- Spam chat, auction queries, addon messages, or Blizzard services.
- Knowingly create functionality that violates Blizzard's EULA, Terms, or UI Add-On Development Policy.

Do not call Bank of Durotar "Blizzard approved." Blizzard does not provide individual addon approval or certification. Use precise language such as "Blizzard-policy compliant," "designed to comply with Blizzard's addon policy," and "requires live-client verification."

## Safe Design Principles

The addon may:

- Read information exposed through Blizzard's addon API.
- Present and sort Auction House data.
- Calculate per-unit prices.
- Maintain local market history.
- Calculate costs, fees, margins, risk, and realized profit.
- Recommend purchases, sales, quantities, and maximum prices.
- Prepare or stage a player action where Blizzard permits it.
- Require the player to review and initiate each protected action.
- Use Blizzard-exposed SavedVariables.
- Use native addon communication channels responsibly if later required.
- Use normal Blizzard UI elements and documented or live-verified APIs.

Recommendations are allowed. Unattended execution is not.

## Hardware-Action Rule

For every feature that can result in a purchase, bid, auction post, auction cancellation, mail action, vendor transaction, craft, or other protected game action:

1. Determine whether Blizzard requires a hardware event.
2. Keep the final protected action directly tied to a visible player click or keypress.
3. Do not queue a series of protected actions that execute from one click unless the live client explicitly and lawfully permits that exact behavior.
4. Do not retry protected actions automatically.
5. Do not fall back to insecure execution when blocked.
6. Surface a clear message explaining what the player must click.
7. Record any uncertainty in `docs/BLIZZARD_COMPLIANCE.md`.
8. Stop implementation and request live-client verification when legality or API behavior is uncertain.

## Auction Query Rule

Auction queries must:

- Respect `CanSendAuctionQuery` or the verified equivalent.
- Respect throttling and cooldowns.
- Avoid uncontrolled loops.
- Avoid `OnUpdate` polling when events or bounded timers work.
- Use explicit timeouts.
- Prevent stale events from completing newer requests.
- Prevent duplicate result events from duplicating observations.
- Never automatically hammer retries.
- Never start a full scan without deliberate player initiation and documented validation.
- Clearly show scan progress, cooldowns, pauses, and failures.

## External Service Rule

The core addon must not require:

- OAuth.
- Battle.net API credentials.
- A website.
- A desktop companion.
- Cloud processing.
- Paid data.
- A subscription.

Any future external companion requires a separate architecture and compliance review. It must never control the WoW client or enable unattended gameplay.

## Public-Source Rule

Because Blizzard's policy requires addon code to remain visible and addons to be freely accessible:

- Source code must remain readable and unobfuscated.
- Public releases must include the full functional addon code.
- No premium or paid feature branch may exist.
- No ads or solicitation may appear inside the addon.
- The GitHub and CurseForge releases must be free.

## Coding Standards

- Lua compatible with the verified Classic Anniversary client.
- Current verified target:
  - WoW `2.5.6`.
  - Interface `20506`.
  - `WOW_PROJECT_ID` `5`.
  - Legacy Auction House API.
- Detect optional APIs at runtime.
- Never invent API behavior.
- Use one addon namespace: `local addonName, BOD = ...`.
- Avoid global namespace pollution.
- Keep modules small and focused.
- Keep state machines explicit.
- Validate all client/API data.
- Store money as integer copper.
- Bound logs and SavedVariables history.
- Use versioned database migrations.
- Handle nil values and partial auction data safely.
- No external libraries unless a documented architectural review demonstrates the need.
- No Ace3 or LibDBIcon by default.
- No giant all-in-one Lua files.
- No premature abstraction.
- No silent errors.
- No misleading profitability claims.

## Recommendation Integrity

Gold-making recommendations must:

- Clearly distinguish historical facts from estimates.
- Include Auction House cuts and deposits where data is available.
- Account for unsold inventory and lost deposits.
- Never promise guaranteed profit.
- Show data confidence.
- Avoid recommendations based on inadequate scan history.
- Explain why an item is recommended.
- Warn about volatility, liquidity, inventory exposure, and stale data.
- Prefer no recommendation over a fabricated or weak recommendation.
- Never call estimated inventory value "profit."
- Treat realized profit separately from unrealized inventory value.

## UX Standards

The normal player experience must not require formulas, scripts, or complex operations.

Primary language should be plain:

- Strong Buy.
- Good Buy.
- Risky.
- Too Expensive.
- Too Slow.
- Do Not Buy.
- Hold.
- Sell Now.

Advanced calculations may be available behind a "Why?" or details control.

Do not expose unnecessary technical diagnostics in the normal player workflow.

## Development Workflow

Before implementing any milestone:

1. Read all governance and architecture documents.
2. Inspect the current repository and git status.
3. Restate the exact assigned milestone.
4. Identify Blizzard-policy risks.
5. Identify protected functions and hardware-action requirements.
6. Identify APIs that require live-client verification.
7. Produce a small implementation plan.
8. Modify only the assigned scope.
9. Review the diff.
10. Run available static checks.
11. Update tests and documentation.
12. Provide an exact in-game test procedure.
13. Do not claim live verification until the user supplies live results.
14. Do not begin the next milestone automatically.
15. Leave the working tree ready for human review.

## Compliance Stop Condition

Codex must stop and ask for review rather than implement when:

- A feature may automate protected gameplay.
- A feature may bypass a hardware-action requirement.
- Blizzard policy applicability is unclear.
- An API's behavior is not verified.
- A requested feature may require an external executable.
- A requested feature may violate the UI Add-On Development Policy or EULA.
- A feature would conceal code, require payment, advertise, or create premium access.
- A requested operation may create account-ban risk.

When stopped, Codex must explain:

- The proposed behavior.
- The specific compliance concern.
- The relevant policy or technical restriction.
- A safer alternative, when one exists.

## Mandatory Completion Report

Every coding task must report:

- Files changed.
- Behavior added or changed.
- Protected functions touched.
- Auction APIs touched.
- Potential compliance risks.
- Live-client assumptions.
- Manual tests required.
- Documentation updated.
- Git status.
- Whether the change is safe to approve for live testing.
