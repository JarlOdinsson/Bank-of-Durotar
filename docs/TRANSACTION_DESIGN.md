# Transaction Workflow Design

Milestone `0.1B` is planning, compliance review, and live-verification preparation only. It does not implement buying, bidding, posting, cancelling, mailbox handling, accounting, market history, deal detection, or profit logic.

## Scope

This document designs the safest future architecture for protected Auction House transaction workflows on the verified Classic Anniversary client:

- WoW `2.5.6`.
- Interface `20506`.
- `WOW_PROJECT_ID` `5`.
- Legacy Auction House API.

The planned workflows are:

- Buying one explicitly selected auction.
- Posting one explicitly reviewed auction.
- Cancelling one explicitly selected owned auction.
- Bidding decision and risk review.

No transaction workflow may be implemented until the go/no-go gates at the end of this document are satisfied.

## Verified Client Facts

Milestone `0.0.1` and `0.1A` verified:

- The client uses the legacy Auction House API family.
- `C_AuctionHouse` was not present.
- `QueryAuctionItems` exists and supports targeted read-only searches.
- `CanSendAuctionQuery` exists and must be respected.
- `GetNumAuctionItems`, `GetAuctionItemInfo`, `GetAuctionItemLink`, and `GetAuctionItemTimeLeft` exist for read-only result inspection.
- `PlaceAuctionBid`, `StartAuction`, and `CancelAuction` exist, but Bank of Durotar has never invoked them.
- The client may emit repeated `AUCTION_ITEM_LIST_UPDATE` events for one query.
- Result indexes can be refreshed by the client and must be treated as stale unless revalidated.

## Unknowns

The following require live-client verification before implementation:

- Exact `PlaceAuctionBid` signature and whether buyout uses `PlaceAuctionBid("list", index, buyoutTotal)`.
- Whether `PlaceAuctionBid`, `StartAuction`, and `CancelAuction` are protected in this client.
- Whether each protected action must be called directly from a fresh player hardware event.
- Whether one player click may perform exactly one action or whether any multi-action behavior is permitted.
- Success, failure, throttling, and refresh events for buy, bid, post, and cancel paths.
- Sell-slot APIs, item placement rules, stack handling, duration constants, and deposit APIs for posting.
- Owner-list fields and stable identity fields for owned auction cancellation.
- Whether calls outside a hardware event trigger taint, blocked-action messages, Lua errors, or silent failure.

Until verified otherwise, every transaction is treated as one player click for one explicitly reviewed action.

## Buying Architecture

Buying should be designed as a single-auction confirmation workflow.

Safe model:

1. Player searches manually.
2. Player selects one listing from the read-only sidecar.
3. Addon captures a review snapshot: list type, list index, item link or name, item ID if available, stack count, total buyout, unit buyout, seller, time left, and original query generation.
4. Addon displays a confirmation panel titled `BUY THIS AUCTION`.
5. Player clicks a visible button labeled `Buy 1 Auction`.
6. The click handler immediately revalidates the current list row against the review snapshot.
7. Only if the live row still matches does the future guarded implementation call the protected buy function.
8. The button disables after the click until the client responds.
9. Any failure requires another deliberate player click after the player reviews the updated state.

Default buyout assumption:

- Future implementation may use `PlaceAuctionBid` for buyout only after live verification confirms the signature and behavior.
- The planned call must be one selected list index and one reviewed price.
- No retry, fallback, or next-auction purchase may occur automatically.

Wrong-auction protections:

- Do not purchase from a sorted or filtered display index alone.
- Store the underlying Auction House list index separately from the visible row pool index.
- Re-read the live row immediately before purchase.
- Require matching item identity, stack count, and buyout.
- Treat missing seller, missing item link, changed price, changed stack count, or changed row as stale unless the player reviews again.
- Reject purchase if the Auction House is closed or the result list is refreshing.

Failure handling:

- If the auction disappears, show a stale-listing error and require refresh.
- If gold is insufficient, show a clear insufficient-funds error and require another click after review.
- If query cooldown or result refresh is active, disable the buy button until stable.
- If a protected-action or taint error occurs, stop transaction work and update the compliance register.

## Bidding Decision

Bidding should be excluded from the first transaction release.

Rationale:

- Bids are easy to misunderstand and can lock gold without providing immediate inventory.
- Minimum bid, increment, outbid, and time-left behavior increase accidental-action risk.
- Bidding complicates the normal-player product without directly improving the initial gold-making workflow.
- Buyout-only workflows are easier to explain, verify, and constrain to one click per action.

Recommendation:

- Initial transaction implementation should support buyout purchases only, not bids.
- Bidding may be reconsidered later only if live tests prove the hardware-event behavior and product value is clear.
- If bidding is ever added, it must use its own confirmation panel and never share ambiguous `Buy` wording.

## Posting Architecture

Posting should be designed as a one-auction confirmation workflow.

Safe model:

1. Player chooses or places one item through Blizzard-supported item selection or sell-slot behavior.
2. Addon reads only verified item, stack, duration, price, and deposit fields.
3. Addon displays a confirmation panel titled `POST THIS AUCTION`.
4. Player clicks `Post 1 Auction`.
5. The click handler immediately revalidates item identity, count, price, duration, and deposit.
6. Only if the live posting context still matches does the future guarded implementation call `StartAuction`.
7. The button disables until client success or failure events are observed.
8. Any next posting requires another deliberate click.

Default posting assumption:

- One visible player click posts one auction.
- Repeated stacks require repeated player clicks unless the live client explicitly proves a different behavior is both lawful and safe.
- No hidden posting queue is allowed.
- No automatic relisting is allowed.

Posting protections:

- Do not move items into a sell slot automatically unless live verification proves it is allowed and non-protected.
- Do not consume partially changing stacks without revalidation.
- Verify item link or item ID, stack count, stack size, number of stacks, duration, start price, buyout price, and deposit immediately before calling `StartAuction`.
- Reject posting if the Auction House is closed, inventory changed, sell slot changed, or deposit funds appear insufficient.
- Track multisell events only for diagnostics and state resolution; never use them to drive hidden follow-up posts.

## Cancelling Architecture

Cancelling should be designed as a one-owned-auction confirmation workflow.

Safe model:

1. Player opens owned auctions.
2. Player selects one owned auction.
3. Addon captures a review snapshot: owner list index, item identity, stack count, bid/buyout/listed price, time left, and deposit if available.
4. Addon displays a confirmation panel titled `CANCEL THIS AUCTION`.
5. Player clicks `Cancel 1 Auction`.
6. The click handler immediately revalidates the current owned-auction row against the review snapshot.
7. Only if the current row still matches does the future guarded implementation call `CancelAuction`.
8. The button disables until client response.
9. Any additional cancellation requires another deliberate player click.

Default cancelling assumption:

- One visible player click cancels one explicitly selected owned auction.
- Mass-cancel behavior is excluded.
- Cancellation must not be driven by undercut scans, timers, or background queues.

Cancellation protections:

- Do not cancel by visible sorted row index alone.
- Re-read the owner list index immediately before cancellation.
- Reject if item identity, quantity, bid/buyout, or listing state differs from the reviewed snapshot.
- Explain deposit loss clearly when deposit data is available.
- Require refresh when the owner list updates.

## Protected-Action Boundary

A future `BOD.TransactionGuard` module may be introduced only after live verification.

Intended interface:

```lua
BOD.TransactionGuard:Prepare(action)
BOD.TransactionGuard:Clear(reason)
BOD.TransactionGuard:CanExecute(actionID)
BOD.TransactionGuard:ExecuteFromClick(actionID)
```

The prepared action should contain:

- `actionID`: short-lived identifier.
- `actionType`: `BUYOUT`, `POST`, or `CANCEL`.
- `createdAt`: timestamp.
- `expiresAt`: short timeout.
- `reviewSnapshot`: player-visible data shown in confirmation.
- `revalidate`: function that reads the live client state and returns true only on exact match.
- `execute`: function that invokes exactly one protected client function.

## Protected-Action Invariants

Future transaction code must:

- Require a visible player click for final execution.
- Execute at most one protected auction action per click.
- Revalidate all auction or item data immediately before the protected call.
- Reject stale selections.
- Reject execution when the Auction House is closed.
- Reject execution while the relevant list is refreshing.
- Reject execution when current data differs from reviewed data.
- Disable the action button after click until the client responds.
- Never auto-retry.
- Never maintain a hidden indefinite queue.
- Store only bounded audit records.
- Surface clear player-facing errors.
- Never fall back to insecure execution.

Future transaction code must never invoke a protected action from:

- Timers.
- Event handlers.
- `OnUpdate`.
- Login.
- Auction House open.
- Search completion.
- Background queue processing.
- Minimap menu actions that are not the explicit final confirmation button.

## Confirmation UX

Buying confirmation:

```text
BUY THIS AUCTION

Bolt of Linen Cloth
6 items
4s 38c total
73c each

Seller: Example
Time left: Very Long

[Buy 1 Auction]
```

Posting confirmation:

```text
POST THIS AUCTION

Netherweave Cloth
20 items

Price per item: 15s
Stack price: 3g
Duration: 12 hours
Deposit: 18s

[Post 1 Auction]
```

Cancelling confirmation:

```text
CANCEL THIS AUCTION

Netherweave Cloth
20 items
Listed at: 3g
Deposit already paid: 18s

[Cancel 1 Auction]
```

UX rules:

- No `Buy All`, `Post All`, or `Cancel All` wording.
- No hidden quantity.
- No automatic follow-up action.
- Failure requires another deliberate click.
- Button text must name one action and one auction.
- The confirmation must show enough information for a normal player to catch mistakes.

## Stale-Data Protections

All future transaction workflows must treat Auction House indexes as volatile.

Required stale-data checks:

- Store the underlying Blizzard list index at review time.
- Store item link or item ID when available.
- Store item name as a fallback only.
- Store stack count, buyout, bid, seller or owner when available, and time left.
- Store the search or owner-list generation if the module tracks one.
- Re-read the current list row immediately before action execution.
- Reject if any required reviewed field differs.
- Reject if the selected listing no longer exists.
- Reject if the result event fires after confirmation but before execution.
- Clear prepared actions on Auction House close, reload, search refresh, owner-list refresh, inventory change, or timeout.

## Error Handling

Errors should be explicit and non-spammy:

- `Auction changed. Refresh and review again.`
- `Auction House is closed.`
- `Listing is no longer available.`
- `Price changed. Review again before buying.`
- `Item stack changed. Review again before posting.`
- `Insufficient gold for this action.`
- `Action blocked by the client. Transaction features require review.`
- `Transaction API behavior is unverified on this client.`

Audit logs should be bounded and should not store full market history.

## Event Mapping

Candidate events to verify:

| Area | Candidate Events | Purpose |
| --- | --- | --- |
| Buy/bid list | `AUCTION_ITEM_LIST_UPDATE`, `UI_ERROR_MESSAGE` | Detect refreshes, failures, stale list state, and client errors. |
| Owned auctions | `AUCTION_OWNED_LIST_UPDATE`, `UI_ERROR_MESSAGE` | Detect owned-list refreshes and cancellation results. |
| Posting | `AUCTION_MULTISELL_START`, `AUCTION_MULTISELL_UPDATE`, `AUCTION_MULTISELL_FAILURE`, `UI_ERROR_MESSAGE` | Detect post progress, multisell behavior, and failures. |
| Inventory | `BAG_UPDATE`, `BAG_UPDATE_DELAYED`, `ITEM_LOCK_CHANGED` | Detect stack changes and item locks before posting. |
| Money | `PLAYER_MONEY` | Detect gold changes after purchases, bids, deposits, and cancellations. |
| Auction House lifecycle | `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED` | Clear stale prepared actions and prevent execution while closed. |

Candidate functions and fields to verify:

| Area | Candidate API | Verification Need |
| --- | --- | --- |
| Buying | `PlaceAuctionBid` | Signature, buyout behavior, hardware-event requirement, errors. |
| Bidding | `PlaceAuctionBid` | Bid behavior, minimum increments, whether product should expose bidding. |
| Posting | `StartAuction` | Signature, sell-slot dependency, durations, deposit behavior, multisell behavior. |
| Cancelling | `CancelAuction` | Signature, owner-list index, hardware-event requirement, stale-index behavior. |
| Deposit | Unknown legacy API or result field | Whether deposit can be read before posting/cancelling. |
| Sell slot | Unknown legacy API set | How the selected item is staged for `StartAuction`. |

## Live-Test Matrix

The transaction probe plan is developer-only and must not execute real transactions automatically.

Preparation:

- Use a low-level test character with a small, acceptable amount of gold at risk.
- Use one cheap vendor item.
- Use one inexpensive stackable trade good.
- Use one owned auction posted at an intentionally safe price.
- Disable other Auction House addons if they interfere with event attribution.
- Record `/eventtrace` or equivalent observations when possible.

Read-only discovery:

| Test | Expected Result |
| --- | --- |
| Detect `PlaceAuctionBid`, `StartAuction`, `CancelAuction` types | Functions exist or are reported unavailable without error. |
| Detect sell-slot and deposit-related globals | Candidate APIs are listed for manual review only. |
| Register candidate events | Events are observed without triggering transactions. |
| Inspect owner auction fields | Owned auction fields are captured read-only. |
| Inspect bidder/list fields | Bid/list fields are captured read-only. |
| Test protected status outside hardware event with a deliberately invalid/no-op context if safe | Client behavior is recorded without causing a real transaction. |

Low-risk action verification, only after explicit human confirmation:

| Workflow | Test | Expected Result |
| --- | --- | --- |
| Buyout | Buy one intentionally cheap auction with a visible `Buy 1 Auction` click | Exactly one auction is purchased or a clear client failure occurs; no retry. |
| Posting | Post one cheap item with a visible `Post 1 Auction` click | Exactly one auction is posted or a clear client failure occurs; no hidden follow-up. |
| Cancelling | Cancel one owned test auction with a visible `Cancel 1 Auction` click | Exactly one owned auction is cancelled or a clear client failure occurs; no mass-cancel. |
| Failure | Attempt action after refreshing list before click | Guard rejects stale data before protected call. |
| Closure | Close AH before confirmation click | Guard rejects because AH is closed. |
| Taint | Watch for blocked-action or taint warnings | Any warning blocks implementation until reviewed. |

Gold-loss minimization:

- Use vendor-value or near-vendor-value items.
- Avoid rare, high-volume, or volatile markets.
- Never test on valuable auctions.
- Stop after one transaction per workflow.

## Explicit Prohibited Behaviors

Transaction features must not:

- Buy, bid, post, or cancel automatically.
- Execute more than one protected action from one click unless live-client behavior is explicitly proven lawful and safe, and human approval is given.
- Queue purchases, posts, bids, or cancellations.
- Retry after failure without another deliberate click.
- Continue after the player closes the Auction House.
- Execute from timers, events, `OnUpdate`, login, AH open, or search completion.
- Hide transaction quantities.
- Use ambiguous bulk wording.
- Treat detected functions as permission to ship transaction features.
- Implement mailbox handling, accounting, market history, deal detection, or profitability logic as part of `0.1B`.

## Go/No-Go Gates For Implementation

Transaction implementation is no-go until all are true:

- Function signatures are confirmed on WoW `2.5.6` / Interface `20506`.
- Required events are confirmed.
- Hardware-event behavior is live-tested.
- One-click/one-action behavior is confirmed.
- Stale-index protections are designed and reviewed.
- No taint or blocked-action behavior is observed.
- Compliance register is updated.
- Human approval is received.
- A low-risk manual test procedure exists.
- Rollback plan exists.

Current status: no-go for transaction implementation.
