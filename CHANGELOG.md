## 0.1.0-alpha.2

- Added Milestone 0.1B protected transaction workflow planning documentation and go/no-go gates.
- Added disabled-by-default developer transaction probe for live API verification.
- Added session-only enablement phrase `ENABLE TRANSACTION PROBE`.
- Added read-only transaction capability, owner-list, bidder-list, and sell-slot inspection.
- Added guarded one-click developer test paths for one buyout, one post, and one cancellation.
- Added transaction-probe reporting, event recording, and blocked-action handling.
- Added persistent transaction-probe records for the latest protected attempt and latest terminal failure.
- Replaced ambiguous developer post-test price inputs with explicit gold, silver, and copper fields plus validation previews.
- Replaced developer post-test free-form duration input with explicit 12/24/48-hour single-select controls mapped to legacy duration values.
- Grouped developer transaction-probe inputs by Buyout Test, Post Test, and Cancel Test with explicit field labels.
- Planned future `SCAN MARKET` full-market scan behavior and Milestone 0.1D without adding production scan code.
- Planned future selling-price recommendations, pricing confidence, price-wall logic, and editable selling-form prefill without implementing recommendation code.
- Documented live direct `StartAuction` failure: one visible execute click issued exactly one call and the client disabled the addon; direct protected posting is no-go.
- Documented Stage A read-only testing and optional Stage B/C/D low-risk transaction tests.

## 0.1.0-alpha.1

- Added read-only player-facing Auction House sidecar.
- Added manual targeted market search using the verified legacy Auction House API.
- Added listing normalization, sorting, filtering, selection details, and a bounded scrollable result list with six reusable row frames.
- Added settings panel compatibility for addon options and diagnostics access.
- Added SavedVariables schema version 2 for sidecar and search preferences.
- Documented 0.1A as implemented and live-verified after successful Classic Anniversary testing.

## 0.0.1

- Added runtime client and Auction House API detection.
- Added controlled targeted-query probe for the legacy Auction House API.
- Added bounded diagnostic event and log capture.
- Added copyable diagnostic report.
- Added native minimap button with draggable position, options menu, and visibility commands.
- Added initial SavedVariables schema.
- Added documentation for architecture, testing, and roadmap.
- Added permanent project governance and Blizzard-compliance documentation.
