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
- `TransactionProbe.lua` builds the disabled-by-default developer transaction probe.
- Future `PricingService.lua` will calculate selling-price recommendations only after scan, history, and transaction gates are satisfied.
- `SettingsPanel.lua` registers the addon options panel through the detected Classic-compatible settings API.
- `MinimapButton.lua` builds the native minimap access button and its small options menu.

## Verified Client Target

Milestone `0.0.1` targets the legacy Auction House API verified on Classic Anniversary project ID `5`, `WOW_PROJECT_BURNING_CRUSADE_CLASSIC` `5`, interface `20506`, WoW `2.5.6`, build `68775`.

The verified client exposes legacy Auction House globals including `QueryAuctionItems`, `CanSendAuctionQuery`, `GetNumAuctionItems`, `GetAuctionItemInfo`, `GetAuctionItemLink`, `GetAuctionItemTimeLeft`, `PlaceAuctionBid`, `StartAuction`, and `CancelAuction`. `C_AuctionHouse` was not present. Normal player workflows do not invoke transaction functions. Milestone `0.1C` isolates optional developer-only transaction test calls behind explicit probe controls.

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

## Protected Transaction Planning

Milestone `0.1B` documents future protected Auction House transaction workflows without implementing them. `docs/TRANSACTION_DESIGN.md` is the controlling design document for buying, bidding, posting, cancelling, stale-data protections, confirmation UX, live-test gates, and the proposed future `BOD.TransactionGuard` boundary.

The normal player architecture remains read-only. Normal transaction features may not call `PlaceAuctionBid`, `StartAuction`, or `CancelAuction` until live-client function signatures, hardware-event requirements, relevant events, one-click/one-action behavior, stale-index protections, and taint behavior are verified through the developer probe.

Live `0.1C` posting verification rejected direct addon invocation of `StartAuction`: the developer probe prepared and final-click validated one post, issued exactly one `StartAuction` call from the visible execute button, and the client immediately disabled Bank of Durotar with Blizzard's addon-disabled popup. Direct protected posting implementation is therefore no-go. Future posting research is limited to compliant Blizzard-UI-assisted approaches where the player uses Blizzard's own posting control and Bank of Durotar only reads, prefills, or guides reviewed values where the live client permits it.

The proposed future buyout/cancel boundary is strict: prepare a short-lived reviewed action, require a visible final player click, revalidate live data immediately before the protected call, execute at most one protected action where live verification permits it, and never retry or continue from timers, events, `OnUpdate`, login, AH open, search completion, or background queue processing. Posting is excluded from this direct-call model after the failed live `StartAuction` probe.

## Developer Transaction Probe

Milestone `0.1C` adds `TransactionProbe.lua`, a developer-only diagnostics module. It is not loaded into or referenced by the normal Auction House sidecar. Access is limited to `/bod txprobe` and the diagnostics/settings area.

The probe uses a session-only enablement phrase, `ENABLE TRANSACTION PROBE`, and remains disabled after reload or logout. Prepared transaction state is memory-only. SavedVariables schema version `3` stores the latest bounded transaction-probe diagnostic report, the latest protected attempt, and the latest terminal failure under `BankOfDurotarDB.diagnostics.transactionProbe`.

Protected transaction calls are isolated to final button click handlers in `TransactionProbe.lua`: `PlaceAuctionBid`, `StartAuction`, and `CancelAuction`. Timers only provide result timeouts and never invoke transaction functions. Event handlers record observations, clear stale state, mark results, or mark terminal failures; they do not invoke transaction functions.

## Player-Facing Search And Future Scan Entry Points

Milestone `0.1A` implements the first player-facing expanded Auction House sidecar with targeted item-name search and browsing. The existing targeted search field and `Search` button remain the supported browsing workflow.

The planned future primary scan button label is:

```text
SCAN MARKET
```

`SCAN MARKET` is reserved for a future player-initiated full Auction House market scan that records a bounded market snapshot. It must not be wired to the existing single-item targeted search workflow, and it must not imply deal recommendations before historical data and Find Deals are implemented and live-verified.

The future scan button should be large, native-styled, and visible near the top of the expanded sidecar. The sidecar must retain a separate targeted item search field and `Search` button.

Future scan status values:

- Ready.
- Cooldown.
- Starting.
- Scanning.
- Processing results.
- Completed.
- Cancelled.
- Failed.

Every scan begins from a deliberate player click. The sidecar must not auto-scan on login, reload, Auction House open, or a timer; must not create overlapping scans; must allow the player to cancel an active scan; must respect `CanSendAuctionQuery` and verified throttling; and must not implement unattended or indefinite retry behavior.

`0.1A` performs one targeted read-only search for the entered item text. It does not call this a complete Auction House scan, does not auto-page, and does not imply profitability analysis exists before the Find Deals milestone.

Milestone `0.1D` must verify legacy full-scan behavior before production use. It must verify `QueryAuctionItems` `getAll` signature, cooldown behavior, completion events, result count, partial item data, duplicate event behavior, scan duration, cancellation behavior, memory impact, and snapshot completeness criteria. Production code must not add `getAll=true` until that probe is complete and approved. Automatic page traversal is not an acceptable substitute unless separately verified and approved.

Future scan progress should include a progress bar, auctions processed, unique items observed, elapsed time, and last successful scan time. Numerical percentages may only be displayed when the client exposes a reliable total, using `processedRecords / totalRecords`; otherwise the progress bar must be indeterminate and show processed-record count only.

Planned future scan modes:

- Quick Scan.
- Watchlist Only.
- Inventory Markets.
- Full Scan - Advanced.

Only scan modes supported by the current milestone and verified APIs may be active.

Future snapshots must record completeness and reject partial snapshots from normal market-history calculations. Duplicate `AUCTION_ITEM_LIST_UPDATE` events must not duplicate observations. Stored observations must be bounded and compatible with the 60-day retention architecture; Bank of Durotar must not store every raw auction listing for 60 days. Useful future per-item aggregates include lowest valid unit buyout, median unit buyout, high or percentile value where useful, total quantity, listing count, observation timestamp, and sample count.

## Pricing Recommendation Architecture

Future selling-price recommendations are planned in `docs/PRICING_RECOMMENDATIONS.md`. The planned `BOD.PricingService` is a read-only calculation boundary: it retrieves current and historical observations, validates freshness and completeness, normalizes unit prices, identifies meaningful price walls, calculates bid and buyout recommendations, assigns confidence, and returns explanation codes.

`BOD.PricingService` must not call `StartAuction`, `PostAuction`, `PlaceAuctionBid`, or `CancelAuction`. A future normal selling UI may request a recommendation and prefill editable denomination fields where the client permits it, but direct addon posting through `StartAuction` is no-go after live verification. Future posting must be researched as a Blizzard-UI-assisted flow where the player uses Blizzard's own posting control.

Recommendation implementation is blocked until Milestone `0.1D`, market-history schema and 60-day retention, item identity keys, deterministic pricing tests, and protected posting gates are complete.

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
    schemaVersion = 3,
    diagnostics = {
        logs = {},
        events = {},
        latestSession = nil,
        transactionProbe = {
            latestReport = nil,
            lastProtectedAttempt = nil,
            lastTerminalFailure = nil,
        },
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

Schema version `2` adds sidecar, settings, and search preference fields. Schema version `3` adds bounded transaction-probe diagnostic storage: latest report, latest protected attempt, and latest terminal failure. It preserves diagnostics and minimap settings. Full auction results, armed transactions, developer enablement, prepared indexes, and market history are not persisted in `0.1C`.

## OAuth

Battle.net OAuth is for external applications. In-game WoW addons cannot make ordinary web requests or complete OAuth flows, so OAuth is irrelevant to this in-game diagnostic milestone.
