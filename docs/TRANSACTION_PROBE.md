# Developer Transaction Probe

Milestone `0.1C` adds a developer-only diagnostic probe for live Auction House transaction verification. It is not normal buying, selling, cancelling, accounting, market history, deal detection, or profitability implementation.

## Scope

The probe targets the verified Classic Anniversary client:

- WoW `2.5.6`.
- Interface `20506`.
- `WOW_PROJECT_ID` `5`.
- Legacy Auction House API.

It investigates:

- Transaction capability availability.
- Owned-auction and bidder-auction field shapes.
- Blizzard auction sell-slot data.
- Deposit API behavior where exposed.
- Transaction-related event order.
- Hardware-event behavior for one buyout, one post, and one cancellation test.
- Taint, blocked-action, and forbidden-action behavior.

## Safety Warnings

The probe is explicitly dangerous compared with normal read-only search:

- It may spend gold.
- It may post an auction.
- It may cancel an owned auction.
- It must be used only with low-value test items.
- Every protected action requires explicit player clicks.
- No action retries automatically.
- No action queues in the background.
- No bulk behavior is supported.
- No transaction safety should be claimed until live testing is complete.

## Developer Enablement

The probe is disabled by default every session.

Open it with:

```text
/bod txprobe
```

or from:

```text
Esc -> Options -> AddOns -> Bank of Durotar -> Diagnostics -> Developer Transaction Probe
```

To enable the controls for the current session, type exactly:

```text
ENABLE TRANSACTION PROBE
```

Then click `Enable Probe`.

The enablement state is not persisted across reload or logout. Prepared transaction state is never persisted.

## Transaction Input Layout

The developer probe groups transaction inputs under `Selection / Transaction Inputs` so each field is tied to one action type:

- `Buyout Test` shows `Selected Browse Index` and helper text: `Uses the currently selected Bank of Durotar listing.`
- `Post Test` shows `Bidding Price`, `Buyout Price`, `Auction Duration`, stack size, and helper text: `Uses the item manually placed in Blizzard's sell slot.`
- `Cancel Test` shows `Owned Auction Index` and helper text: `Uses one selected owned auction.`

Prepare buttons are kept next to their matching section. Shared final controls still require `Prepare Final Click` followed by one explicit execute click.

The prepared transaction display uses consistent labels: `Type`, `Item`, `Stack`, `Selected index`, `Bid total`, `Buyout total`, `Duration`, `Deposit`, and `State`.

## Capability Inspection

Click `Inspect Capabilities` after enabling the probe.

The probe records availability and value type for expected globals including:

- `PlaceAuctionBid`.
- `StartAuction`.
- `CancelAuction`.
- `ClickAuctionSellItemButton`.
- `GetAuctionSellItemInfo`.
- `ClearCursor`.
- `PickupContainerItem`.
- `GetAuctionDeposit`.
- `GetAuctionItemInfo`.
- `GetAuctionItemLink`.
- `GetAuctionItemTimeLeft`.
- `GetNumAuctionItems`.
- `QueryAuctionItems`.
- `CanSendAuctionQuery`.
- `GetMoney`.

It also records additional present global functions whose names contain `Auction`. Capability inspection never invokes transaction functions.

## Owned-Auction Inspection

Click `Inspect Owned`.

The probe:

- Calls `GetNumAuctionItems("owner")`.
- Samples at most eight owner listings through read-only result APIs.
- Records field names and value types from the first sampled record.
- Records owner-list update events.
- Never calls `CancelAuction` during inspection.

## Bidder-Auction Inspection

Click `Inspect Bidder`.

The probe:

- Calls `GetNumAuctionItems("bidder")`.
- Samples at most eight bidder listings through read-only result APIs.
- Records field names and value types from the first sampled record.
- Records bidder-list update events.
- Never places a bid.

## Sell-Slot Inspection

Manually place one cheap item in Blizzard's normal auction sell slot, then click `Inspect Sell Slot`.

The probe:

- Calls `GetAuctionSellItemInfo` if available.
- Records item name, quantity, quality, and returned value types.
- Calls `GetAuctionDeposit` with the selected duration if available and records success or failure.
- Never calls `ClickAuctionSellItemButton`, `PickupContainerItem`, `ClearCursor`, or `StartAuction` during inspection.

## Buyout Test Procedure

Stage B uses one explicitly selected sidecar search result.

1. Enable the developer probe.
2. Open the Auction House.
3. Search for an extremely inexpensive auction in the normal sidecar.
4. Select one listing with a valid buyout.
5. Click `Prepare Buyout Test`.
6. Review the prepared item, source index, stack count, total buyout, unit buyout, seller, and money state.
7. Click `Prepare Final Click`.
8. Confirm the final button reads `Execute 1 Buyout Test`.
9. Click `Execute 1 Buyout Test` once.
10. Wait for result or timeout.
11. Export the diagnostic report.

The final click calls `PlaceAuctionBid` at most once. It aborts before the call if the result list refreshed, the listing changed, the Auction House closed, or money appears insufficient.

## Posting Test Procedure

Stage C uses one manually placed cheap sell-slot item.

Posting tests are blocked until the explicit denomination UI is live-verified. The old single-field price inputs were unsafe because bare numeric text reused the normal search money parser, where `22` means `22g`, not `22s` or `22c`.

Direct `StartAuction` testing is now blocked/no-go. A live probe prepared successfully, passed final click validation, issued exactly one direct `StartAuction` call from the visible execute button, and the client immediately disabled Bank of Durotar with Blizzard's addon-disabled popup. Do not retry this direct posting test unless a separate compliance review explicitly reopens it.

The `Auction Duration` control uses explicit single-select choices. The UI displays human-readable hours, but the legacy `StartAuction` call receives duration index values:

| UI choice | Legacy `StartAuction` duration value |
| --- | --- |
| `12 Hours` | `1` |
| `24 Hours` | `2` |
| `48 Hours` | `3` |

The default is `12 Hours`. Duration selection is session-only and prepared duration state is not persisted across reload.

1. Enable the developer probe.
2. Open the Auction House.
3. Manually place one cheap item in Blizzard's normal auction sell slot.
4. Enter `Bidding Price` as separate `Gold`, `Silver`, and `Copper` whole-number fields.
5. Enter `Buyout Price` as separate `Gold`, `Silver`, and `Copper` whole-number fields.
6. Confirm the read-only previews show the intended totals before preparing, for example `Bid total: 1s 00c` and `Buyout total: 2s 00c`.
7. Select one auction duration: `12 Hours`, `24 Hours`, or `48 Hours`.
8. Enter stack size and `1` stack.
9. Click `Inspect Sell Slot`.
10. Click `Prepare Post Test`.
11. Review item, stack, bid total, buyout total, duration, and deposit if available.
12. Click `Prepare Final Click`.
13. Confirm the final button reads `Execute 1 Post Test`.
14. Click `Execute 1 Post Test` once.
15. Wait for owned-auction update, multisell event, UI error, or timeout.
16. Export the diagnostic report.

The final click called `StartAuction` at most once during live verification. That direct call path is now classified as failed/no-go. The probe does not automate item placement and does not support multiple stacks.

## Cancellation Test Procedure

Stage D uses one explicitly selected owned-auction index.

1. Enable the developer probe.
2. Open the Auction House.
3. Refresh owned auctions through the Blizzard UI as needed.
4. Click `Inspect Owned`.
5. Enter the owner-list index for one low-value owned auction.
6. Click `Prepare Cancel Test`.
7. Review the item and listing data.
8. Click `Prepare Final Click`.
9. Confirm the final button reads `Execute 1 Cancel Test`.
10. Click `Execute 1 Cancel Test` once.
11. Wait for owner-list update, UI error, or timeout.
12. Export the diagnostic report.

The final click calls `CancelAuction` at most once. The probe does not mass cancel.

## Expected Events

The probe records bounded event history for:

- `AUCTION_ITEM_LIST_UPDATE`.
- `AUCTION_OWNED_LIST_UPDATE`.
- `AUCTION_BIDDER_LIST_UPDATE`.
- `AUCTION_MULTISELL_START`.
- `AUCTION_MULTISELL_UPDATE`.
- `AUCTION_MULTISELL_FAILURE`.
- `CHAT_MSG_SYSTEM`.
- `UI_ERROR_MESSAGE`.
- `BAG_UPDATE`.
- `BAG_UPDATE_DELAYED`.
- `ITEM_LOCK_CHANGED`.
- `PLAYER_MONEY`.
- `AUCTION_HOUSE_CLOSED`.
- `PLAYER_LOGOUT`.
- `ADDON_ACTION_BLOCKED`.
- `ADDON_ACTION_FORBIDDEN`.

System chat message content is redacted in the transaction-probe event log.

## Taint And Blocked-Action Handling

If `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` fires:

- The probe marks the state `FAILED`.
- The probe marks the session blocked.
- Developer enablement is disabled for the current session.
- The prepared action is no longer executable.
- No retry is attempted.
- The diagnostic report records the addon name and function name when available.
- SavedVariables records `lastProtectedAttempt` and `lastTerminalFailure` under `BankOfDurotarDB.diagnostics.transactionProbe` when technically possible.

Player-facing message:

```text
The live client rejected the direct protected call. Do not retry. Reload and inspect diagnostics.
```

## Rollback Steps

If anything unexpected occurs:

1. Stop testing immediately.
2. Do not click any remaining execute button.
3. Close the Auction House.
4. Reload the UI.
5. Export or copy the report if possible.
6. Remove or revert the test commit if the behavior is unsafe.
7. Keep transaction implementation blocked until the compliance register is updated.

## Exact Report Fields

The diagnostic report includes:

- Probe enabled/disabled state.
- Probe state.
- Blocked state.
- Client version, build, interface, and project ID.
- Transaction function availability.
- Sell-slot function availability.
- Deposit support result.
- Owned and bidder sample counts.
- Owned and bidder field names and value types.
- Relevant event sequence.
- Prepared transaction type.
- Prepared listing or item snapshot field types.
- Function called and argument types.
- Latest protected attempt.
- Latest terminal failure.
- Money before and after.
- UI error, blocked-action, forbidden-action, and timeout state.

## Go/No-Go Interpretation

Stage A read-only testing may be approved before any transaction action testing.

Transaction implementation remains no-go until:

- Function signatures are confirmed.
- Required events are confirmed.
- Hardware-event behavior is live-tested.
- One-click/one-action behavior is confirmed.
- Stale-index protections are verified.
- No taint or blocked-action behavior is observed.
- Compliance register is updated.
- Human approval is received.
- Rollback plan is accepted.

Direct `StartAuction` posting is no-go regardless of the remaining gates. Future posting research must investigate only compliant Blizzard-UI-assisted approaches where the player uses Blizzard's own posting control and Bank of Durotar only reads, prefills, or guides values where permitted.
