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

## Milestone 0.1B: Protected Transaction Workflow Planning

Status: documentation-only planning. Do not implement transaction behavior until explicitly assigned after go/no-go gates pass.

- [x] Document verified client facts for transaction planning.
- [x] Document unknown function signatures and event requirements.
- [x] Design default one-click/one-action buyout model.
- [x] Recommend excluding bidding from the first transaction release.
- [x] Design default one-click/one-action posting model.
- [x] Design default one-click/one-action cancellation model.
- [x] Define future `BOD.TransactionGuard` invariants.
- [x] Define confirmation UX requirements.
- [x] Define stale-data protections.
- [x] Define low-risk live-test matrix.
- [x] Keep implementation go/no-go status blocked.
- [ ] Live-verify transaction function signatures.
- [ ] Live-verify hardware-event behavior.
- [ ] Live-verify transaction events and taint behavior.
- [ ] Obtain human approval for implementation.

## Milestone 0.1A: Sidecar Search Entry Point

Status: complete and live-verified.

- [x] Add prominent `SEARCH MARKET` button near the top of the expanded Auction House sidecar.
- [x] Use WoW-native frame, font, border, and button templates.
- [x] Display Ready, Waiting for query cooldown, Scanning, Completed, and Failed states.
- [x] Require a deliberate player click for every search start.
- [x] Prevent overlapping searches from repeated clicks.
- [x] Respect `CanSendAuctionQuery` and verified throttling.
- [x] Do not auto-query when the Auction House opens.
- [x] Do not implement unattended or indefinite retry behavior.
- [x] Use accurate targeted-read-only wording.
- [x] Do not imply profitability analysis before Find Deals exists.
- [x] Add sorting, filtering, and listing inspection.
- [x] Keep result rows confined to a scrollable viewport with a bounded six-row pool.
- [x] Add settings panel access for normal options and diagnostics.
- [x] Live-test 0.1A in the Classic Anniversary client.
- [x] Plan future scan modes: Quick Scan, Watchlist Only, Inventory Markets, Full Scan - Advanced.

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
