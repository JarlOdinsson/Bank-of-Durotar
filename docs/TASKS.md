# Tasks

This checklist tracks milestone status. It is not permission to begin the next milestone.

## Milestone 0.0.1: Auction API Probe

Status: complete.

- [x] Create standalone addon scaffold.
- [x] Add runtime client and project detection.
- [x] Add Auction House API detection.
- [x] Add legacy Auction House adapter.
- [x] Add one manually initiated targeted query probe.
- [x] Respect `CanSendAuctionQuery`.
- [x] Avoid full scans.
- [x] Sample at most 20 results.
- [x] Add bounded logging and event recording.
- [x] Add copyable diagnostic report.
- [x] Add movable diagnostic UI.
- [x] Add native minimap button.
- [x] Add initial documentation.
- [x] Live-test on Classic Anniversary project ID `5`, interface `20506`.
- [x] Record live-client findings.

## Milestone 0.1: Standalone Search, Buy, Sell, And Owned Auctions

Status: pending. Do not implement until explicitly assigned.

- [ ] Search workflow.
- [ ] Buy workflow.
- [ ] Sell workflow.
- [ ] Owned auctions.
- [ ] Query queue.
- [ ] Protected-action compliance review.
- [ ] Live testing.
- [ ] Documentation.
- [ ] Release gate.

## Milestone 0.1A: Sidecar Scan Entry Point

Status: pending. Do not implement until explicitly assigned.

- [ ] Add prominent `SCAN FOR DEALS` button near the top of the expanded Auction House sidecar.
- [ ] Use wide, high-contrast, WoW-native red/gold styling.
- [ ] Display Ready, Waiting for query cooldown, Scanning, Completed, and Failed states.
- [ ] Require a deliberate player click for every scan start.
- [ ] Prevent overlapping scans from repeated clicks.
- [ ] Respect `CanSendAuctionQuery` and verified throttling.
- [ ] Do not auto-scan when the Auction House opens.
- [ ] Do not implement unattended or indefinite retry behavior.
- [ ] Use accurate placeholder or targeted-read-only wording if broad scan behavior is not implemented.
- [ ] Do not imply profitability analysis before Find Deals exists.
- [ ] Plan future scan modes: Quick Scan, Watchlist Only, Inventory Markets, Full Scan - Advanced.

## Milestone 0.2: Local Market History

Status: pending.

- [ ] Define bounded local observation storage.
- [ ] Define confidence and freshness rules.
- [ ] Default retention to 60 days.
- [ ] Keep days 0-7 as detailed scan observations.
- [ ] Compact days 8-30 into daily summaries.
- [ ] Compact days 31-60 into daily low, median, high, average supply, and sample count.
- [ ] Delete records older than the configured retention window during weekly maintenance.
- [ ] Run maintenance at most once per week from a safe event such as login or Auction House open.
- [ ] Avoid continuous timers.
- [ ] Record last cleanup time.
- [ ] Handle corrupt or partial records safely.
- [ ] Preserve database migrations.
- [ ] Plan future Market Data options page with retention, database size, last cleanup, clear history, and export history controls.
- [ ] Complete compliance and data-integrity review.

## Milestone 0.3: Find Deals

Status: pending.

- [ ] Define recommendation thresholds.
- [ ] Define risk and liquidity labels.
- [ ] Complete recommendation-integrity review.

## Milestone 0.4: Cost Basis And Realized-Profit Tracking

Status: pending.

- [ ] Define realized-profit model.
- [ ] Define inventory-value separation.
- [ ] Verify fee and deposit data sources.

## Milestone 0.5: Sell My Stuff Recommendations

Status: pending.

- [ ] Define sell, hold, vendor, and do-not-list guidance.
- [ ] Define stale-data and lost-deposit warnings.

## Milestone 0.6: Guided Daily Gold Plan

Status: pending.

- [ ] Define daily recommendation summary.
- [ ] Define confidence and risk display.

## Later

Status: pending.

- [ ] Account-wide inventory.
- [ ] Profession profitability.
