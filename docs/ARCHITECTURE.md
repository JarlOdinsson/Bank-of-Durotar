# Architecture

Bank of Durotar uses the standard addon loading pattern:

```lua
local addonName, BOD = ...
```

`BOD` is the private shared namespace. The only intentionally global value is the SavedVariables table, `BankOfDurotarDB`.

## Modules

- `Core.lua` initializes SavedVariables, slash commands, bounded logging, shared formatting helpers, and event dispatch.
- `Diagnostics.lua` records observed events, detects client constants and API availability, and builds the copyable plain-text report.
- `AuctionAPI.lua` is the compatibility boundary around Auction House functions.
- `Probe.lua` owns the single-shot probe state machine and persists the latest diagnostic session.
- `UI.lua` builds the movable native diagnostic window.
- `MinimapButton.lua` builds the native minimap access button and its small options menu.

## Verified Client Target

Milestone `0.0.1` targets the legacy Auction House API verified on Classic Anniversary project ID `5`, `WOW_PROJECT_BURNING_CRUSADE_CLASSIC` `5`, interface `20506`, WoW `2.5.6`, build `68775`.

The verified client exposes legacy Auction House globals including `QueryAuctionItems`, `CanSendAuctionQuery`, `GetNumAuctionItems`, `GetAuctionItemInfo`, `GetAuctionItemLink`, `GetAuctionItemTimeLeft`, `PlaceAuctionBid`, `StartAuction`, and `CancelAuction`. `C_AuctionHouse` was not present. Transaction functions are detection-only in this milestone and are never invoked.

## Probe State Machine

```text
IDLE
WAITING_FOR_AH
WAITING_FOR_QUERY_PERMISSION
QUERY_SENT
WAITING_FOR_RESULTS
RESULTS_RECEIVED
TIMED_OUT
FAILED
```

The probe starts only from an inactive state. It requires the Auction House to be open, waits for query permission with a bounded `C_Timer.After` loop, sends one targeted query, arms result handling on the next timer tick to avoid stale queued events, waits for the result event, samples at most 20 list results, then terminates.

Timers are invalidated with a monotonically increasing token. Stale callbacks from an older probe cannot complete a newer probe.

The verified client emitted repeated `AUCTION_ITEM_LIST_UPDATE` events for the same targeted query. Duplicate events cannot finalize the same probe twice because `CompleteFromResults()` returns unless the probe is active and exactly in `WAITING_FOR_RESULTS`; `Finish()` immediately sets `active` to `false`, advances the token, and moves the state to a terminal value.

## Event Flow

`Core.lua` registers relevant Auction House and lifecycle events defensively and dispatches them to modules. `Diagnostics.lua` records the bounded event sequence. `AuctionAPI.lua` tracks Auction House open and closed state. `Probe.lua` completes on `AUCTION_ITEM_LIST_UPDATE` only when waiting for results, and fails if the Auction House closes mid-probe.

## API Adapter Boundary

Only `AuctionAPI.lua` calls Auction House globals such as `QueryAuctionItems`, `CanSendAuctionQuery`, `GetNumAuctionItems`, and `GetAuctionItemInfo`. Other modules ask the adapter for capabilities, query readiness, query submission, counts, and normalized result samples.

For `0.0.1`, legacy Auction House querying is implemented. The live verified Anniversary client uses this legacy family. `C_AuctionHouse` is detected and reported if present in a future client, but modern search behavior is not treated as interchangeable with legacy Classic behavior.

No purchase, bid, post, or cancellation function is invoked.

## SavedVariables

```lua
BankOfDurotarDB = {
    schemaVersion = 1,
    diagnostics = {
        logs = {},
        events = {},
        latestSession = nil,
    },
    settings = {
        debug = false,
        redactIdentity = false,
        searchText = "Netherweave Cloth",
        minimap = {
            hidden = false,
            angle = 225,
        },
        window = {},
    },
}
```

Missing fields are initialized without destroying existing data. Logs and events are bounded to the latest 100 entries. Only the latest probe session is retained.

## OAuth

Battle.net OAuth is for external applications. In-game WoW addons cannot make ordinary web requests or complete OAuth flows, so OAuth is irrelevant to this in-game diagnostic milestone.
