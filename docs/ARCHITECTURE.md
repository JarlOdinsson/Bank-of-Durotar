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
- `SearchResults.lua` filters, sorts, and formats normalized in-memory result views without mutating source records.
- `SearchController.lua` owns the read-only player search state machine.
- `Probe.lua` owns the single-shot probe state machine and persists the latest diagnostic session.
- `UI.lua` builds the movable native diagnostic window.
- `Sidecar.lua` builds the player-facing Auction House search and browse sidecar.
- `SettingsPanel.lua` registers the addon options panel through the detected Classic-compatible settings API.
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

## Player-Facing Search Entry Point

Milestone `0.1A` implements the first player-facing expanded Auction House sidecar. The primary button is intentionally search-oriented because broad scan and deal detection are not implemented yet.

Button label:

```text
SEARCH MARKET
```

The button is visible near the top of the expanded sidecar. It displays search state:

- Ready.
- Waiting for query cooldown.
- Scanning.
- Completed.
- Failed.

Every search begins from a deliberate player click. The sidecar must not auto-query when the Auction House opens, must not create overlapping searches from repeated clicks, must respect `CanSendAuctionQuery` and verified throttling, and must not implement unattended or indefinite retry behavior.

`0.1A` performs one targeted read-only search for the entered item text. It does not call this a complete Auction House scan, does not auto-page, and does not imply profitability analysis exists before the Find Deals milestone.

Planned future scan modes:

- Quick Scan.
- Watchlist Only.
- Inventory Markets.
- Full Scan - Advanced.

Only scan modes supported by the current milestone and verified APIs may be active.

## Search State Machine

`SearchController.lua` uses a state machine separate from the diagnostic probe:

```text
IDLE
WAITING_FOR_AH
WAITING_FOR_QUERY_PERMISSION
QUERY_SENT
WAITING_FOR_RESULTS
RESULTS_RECEIVED
EMPTY_RESULTS
TIMED_OUT
FAILED
CANCELLED
```

The controller sends exactly one targeted legacy `QueryAuctionItems` call per deliberate player search. It waits for `CanSendAuctionQuery`, uses bounded timers, arms result handling on the next timer tick to reduce stale-event risk, and finalizes once. Duplicate `AUCTION_ITEM_LIST_UPDATE` events return immediately after the controller leaves `WAITING_FOR_RESULTS`.

Results are normalized through `AuctionAPI.lua`, stored in memory only, then filtered and sorted through `SearchResults.lua`. Full auction results are not persisted in SavedVariables.

`Sidecar.lua` displays results through a native `UIPanelScrollFrameTemplate` scroll frame. The visible list uses a bounded six-row frame pool; scrolling rebinds those row frames to filtered result indexes instead of creating one frame per result. The selected-listing details panel remains outside the scroll viewport, and rows are clipped to the result list area.

## Market History Retention Architecture

Future market-history storage should default to a 60-day retention window with bounded data at every tier.

Retention model:

- Days 0-7: detailed scan observations.
- Days 8-30: compact daily summaries.
- Days 31-60: compact daily low, median, high, average supply, and sample count.
- Older than 60 days: delete during weekly maintenance.

Maintenance must:

- Run at most once per week.
- Trigger from a normal safe event such as login or Auction House open.
- Avoid continuous timers.
- Avoid interrupting the player.
- Bound all stored data.
- Record last cleanup time.
- Preserve database migrations.
- Handle corrupt or partial records safely.

Future settings page:

```text
Esc -> Options -> AddOns -> Bank of Durotar -> Market Data
```

Planned settings:

- Retention: 30, 60, or 90 days.
- Default: 60 days.
- Database size.
- Last cleanup.
- Clear market history.
- Export market history.

Market-history collection is not part of Milestone `0.1A` unless explicitly assigned.

## SavedVariables

```lua
BankOfDurotarDB = {
    schemaVersion = 2,
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
        openWithAuctionHouse = true,
        showMinimapButton = true,
        dockToAuctionHouse = true,
        sidecarWidth = 390,
        sidecarCollapsed = false,
        sidecarPosition = {},
        lastSearchText = "Netherweave Cloth",
        selectedSort = "unitBuyout",
        filters = {},
        window = {},
    },
}
```

Missing fields are initialized without destroying existing data. Logs and events are bounded to the latest 100 entries. Only the latest probe session is retained.

Schema version `2` adds sidecar, settings, and search preference fields. It preserves diagnostics and minimap settings. Full auction results and market history are not persisted in `0.1A`.

## OAuth

Battle.net OAuth is for external applications. In-game WoW addons cannot make ordinary web requests or complete OAuth flows, so OAuth is irrelevant to this in-game diagnostic milestone.
