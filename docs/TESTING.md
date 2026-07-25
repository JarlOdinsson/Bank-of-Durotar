# Testing

Run these tests in the live Classic Anniversary client. The addon cannot prove Auction House behavior outside the game.

## Manual Checklist

| Step | Expected Result | Observed Result |
| --- | --- | --- |
| Login away from an Auction House | Addon loads without Lua errors. | Passed: addon loaded without Lua error. |
| Run `/bod probe` away from the AH | Probe fails clearly with `FAILED`; no query is sent. | |
| Open the Auction House | `AUCTION_HOUSE_SHOW` appears in events. | |
| Run the default search probe | One targeted query is sent for `Netherweave Cloth`. | Passed: returned 50 results and 20 normalized samples. |
| Run a search likely to return zero results | Result event/count or timeout is recorded distinctly from API failure. | |
| Close the AH during a pending probe | Probe ends with `FAILED` and timers are invalidated. | |
| Attempt a second probe while active | Second request is ignored with a warning. | |
| Reload the UI | Latest report and bounded logs survive reload. | |
| Run `/bod clear` twice within 10 seconds | Stored diagnostics are cleared. | |
| Confirm missing APIs do not cause Lua errors | Unavailable APIs are shown as unavailable. | |
| Confirm no unattended repeated querying occurs | Only one query happens per manual probe. | Passed for the completed probe; client emitted repeated `AUCTION_ITEM_LIST_UPDATE` events for that one query. |
| Confirm no taint or blocked-action errors | No blocked purchase/post/bid/cancel actions occur. | |

## Anniversary Client Observations

| Observation | Value |
| --- | --- |
| `GetBuildInfo()` version | `2.5.6` |
| `GetBuildInfo()` build | `68775` |
| `GetBuildInfo()` build date | Verified live, exact date not reported in test notes. |
| `GetBuildInfo()` interface value | `20506` |
| `WOW_PROJECT_ID` | `5` |
| `WOW_PROJECT_CLASSIC` | Not reported in completed test notes. |
| `WOW_PROJECT_BURNING_CRUSADE_CLASSIC` | `5` |
| Detected Auction House API family | `legacy` |
| `CanSendAuctionQuery` available | Yes; returned true before probe and false immediately after completion due to legacy query cooldown. |
| `QueryAuctionItems` available | Yes; targeted search worked. |
| `GetNumAuctionItems` available | Yes. |
| `GetAuctionItemInfo` available | Yes. |
| `GetAuctionItemLink` available | Yes. |
| `GetAuctionItemTimeLeft` available | Yes. |
| `PlaceAuctionBid` available | Yes; detection only, not invoked. |
| `StartAuction` available | Yes; detection only, not invoked. |
| `CancelAuction` available | Yes; detection only, not invoked. |
| `C_AuctionHouse` available | No. |
| `GetAuctionItemInfo` field count/types | 20 sample results normalized successfully. |
| Result event for targeted query | `AUCTION_ITEM_LIST_UPDATE`; repeated events were emitted for the same query. |
| Default `Netherweave Cloth` probe | 50 results, 20 sampled results, no probe error. |
| Zero-result behavior | |
| Timeout behavior | |
| Lua errors observed | None during completed probe. |
| Taint or blocked-action errors observed | |

## Current Target

Bank of Durotar `0.1.0-alpha.2` targets the legacy Auction House API on project ID `5` and interface `20506`. Runtime detection remains in place because future Classic Anniversary patches may change interface values, project constants, or API availability.

## Milestone 0.1A Live-Test Checklist

These tests were completed in the live Classic Anniversary client before treating `0.1.0-alpha.1` as verified.

| Step | Expected Result | Observed Result |
| --- | --- | --- |
| Open Market away from AH with `/bod market` | Sidecar can open safely without querying; search reports AH required. | |
| Search away from AH | Search ends in `FAILED` or waiting-for-AH messaging; no query is sent. | |
| Open Orgrimmar AH | Sidecar appears if `Open with Auction House` is enabled. | |
| Sidecar docking | Sidecar attaches to right edge of Blizzard AH frame without replacing, resizing, or hiding it. | Passed: sidecar docked correctly beside the Auction House. |
| Collapse/expand | Collapse hides sidecar content; expand restores controls and results. | |
| Fallback standalone mode | Disabling dock mode or opening away from AH uses movable standalone frame safely. | |
| Search `Linen Cloth` | One targeted legacy query is sent from a player click. | Passed: targeted legacy search worked and returned 50 results. |
| Loading state | Status shows Waiting for query cooldown or Scanning as appropriate. | |
| Results | Current result page is normalized and displayed. | Passed: result rows rendered correctly. |
| Scrollable result viewport | Rows remain clipped inside the sidecar result box with no rows below the panel. | Passed: rows were confined to the viewport and stayed inside the sidecar. |
| Mouse-wheel scrolling | Mouse wheel scrolls through filtered results larger than the visible row pool. | Passed: mouse-wheel scrolling worked. |
| Scrollbar | Vertical scrollbar scrolls through filtered results larger than the visible row pool. | Passed: scrollbar worked. |
| Bounded row pool | Result list reuses six visible rows instead of creating one row per result. | Passed: six reusable rows remained inside the sidecar. |
| Unit-price math | Total buyout and unit buyout are correct integer-copper calculations; no divide-by-zero occurs. | |
| No-buyout handling | Listings without buyout clearly show no-buyout status and bid detail. | |
| Sorting: unit buyout | Valid buyout listings sort by lowest unit buyout. | Passed: sorting continued to work. |
| Sorting: total buyout | Listings sort by lowest total buyout. | |
| Sorting: stack size | Larger stacks sort first. | |
| Sorting: time remaining | Lower time-left buckets sort first. | |
| Sorting: item name | Names sort alphabetically. | |
| Buyout-only filter | No-buyout listings are hidden. | Passed: filtering continued to work. |
| Minimum stack filter | Smaller stacks are hidden. | |
| Maximum unit price filter | Listings above the entered unit price are hidden. | |
| Empty result search | State becomes `EMPTY_RESULTS` or Completed with zero results; no Lua error occurs. | |
| Cooldown behavior | Repeated search during query cooldown waits with bounded timeout and does not hammer retries. | |
| Closing AH during search | Search becomes `CANCELLED`; timers are invalidated. | |
| Duplicate `AUCTION_ITEM_LIST_UPDATE` events | Search finalizes once and does not duplicate observations. | |
| Settings persistence | Open-with-AH, dock mode, width, collapse state, sort, filters, and last search persist after reload. | |
| Minimap persistence | Minimap visibility and position persist after reload. | |
| Diagnostics access from Options | Addon options page appears under the Classic addon options path and shows diagnostics. | |
| Reload behavior | Addon loads without Lua errors and preserves settings. | |
| Row selection after scrolling | Selected listing remains the correct underlying auction record after scrolling. | Passed: row selection remained correct after scrolling. |
| Lua errors | No Lua error popup occurs. | Passed: no Lua error was observed during this test. |
| Taint | No taint warning occurs. | Passed: no taint warning was observed during this test. |
| Blocked actions | No blocked-action warning occurs. | Passed: no blocked-action warning was observed during this test. |
| Protected transaction functions | `PlaceAuctionBid`, `StartAuction`, and `CancelAuction` are never invoked. | Passed by static review and live observation: no blocked-action or taint warning occurred. |
| Actual pagination behavior | No automatic pagination occurs; record whether Blizzard shows more pages for the same query. | |

## Milestone 0.1A Results Template

```text
WoW version:
Build:
Interface:
Project ID:
Auction House frame detected:
Docked sidecar worked:
Standalone fallback worked:
Settings API used:
Search text:
Query readiness before search:
Query cooldown behavior:
Result event:
Duplicate result events observed:
Result count:
Rows displayed:
No-buyout listings observed:
Sorts verified:
Filters verified:
Selected listing detail verified:
Pagination observed:
Lua errors:
Taint or blocked-action warnings:
Protected transaction calls observed:
Notes:
```

## Milestone 0.1B Transaction Verification Plan

`0.1B` is planning only. These tests are required before any buy, bid, post, or cancel implementation.

Preparation:

- Use a low-risk test character and accept that a small amount of gold may be lost.
- Use one cheap vendor item, one inexpensive stackable trade good, and one owned auction posted at an intentionally safe price.
- Disable other Auction House addons if they interfere with event attribution.
- Stop immediately if any Lua error, taint warning, blocked-action warning, or unexpected transaction occurs.

Read-only discovery:

| Step | Expected Result | Observed Result |
| --- | --- | --- |
| Detect `PlaceAuctionBid`, `StartAuction`, and `CancelAuction` | Functions are present or reported unavailable without invoking them. | |
| Identify candidate sell-slot APIs | Sell-slot, duration, and deposit-related APIs are listed without posting. | |
| Inspect list, bidder, and owner fields | Relevant fields are captured read-only. | |
| Register transaction-related events | Candidate events are observed without executing transactions. | |
| Verify protected status safely | Calls outside hardware events are tested only with a safe invalid/no-op context if live review confirms no transaction can occur. | |

Low-risk action verification after explicit human confirmation:

| Step | Expected Result | Observed Result |
| --- | --- | --- |
| Buy one intentionally cheap auction from a visible `Buy 1 Auction` click | Exactly one auction is purchased or a clear client failure occurs; no retry. | |
| Direct post through addon `StartAuction` | No longer allowed. The live probe already failed and disabled the addon. | Failed/no-go; do not retry. |
| Blizzard-UI-assisted posting research | Future research only; player must use Blizzard's own posting control. | |
| Cancel one owned test auction from a visible `Cancel 1 Auction` click | Exactly one auction is cancelled or a clear client failure occurs; no mass-cancel. | |
| Refresh list between review and click | Guard rejects stale data before any protected call. | |
| Close the AH before click | Guard rejects because the Auction House is closed. | |
| Observe taint and blocked-action behavior | No taint or blocked-action warning occurs. Any warning blocks implementation. | |

Go/no-go status: no-go for transaction implementation until all required signatures, events, hardware-event behavior, one-click/one-action behavior, stale-index protections, taint behavior, compliance review, human approval, manual test plan, and rollback plan are complete.

## Milestone 0.1C Developer Transaction Probe Live-Test Sequence

`0.1C` is developer-only live verification. Do not use valuable items. Do not continue if a blocked-action, forbidden-action, taint warning, unexpected transaction, or Lua error occurs.

### Stage A - Read-Only

| Step | Expected Result | Observed Result |
| --- | --- | --- |
| Run `/bod txprobe` | Developer transaction probe opens; normal sidecar remains unchanged. | |
| Enter `ENABLE TRANSACTION PROBE` and click `Enable Probe` | Probe enables for this session only. | |
| Open AH | Probe records AH-related events without starting a transaction. | |
| Click `Inspect Capabilities` | Capability list records transaction, sell-slot, deposit, and auction read APIs without invoking protected calls. | |
| Click `Inspect Owned` | Owner count and bounded owner sample fields are recorded without calling `CancelAuction`. | |
| Click `Inspect Bidder` | Bidder count and bounded bidder sample fields are recorded without bidding. | |
| Manually place a cheap item in Blizzard's sell slot | Item placement is manual only. | |
| Click `Inspect Sell Slot` | Sell-slot and deposit observations are recorded without calling `StartAuction`. | |
| Export report from diagnostics | Transaction-probe section includes capabilities, samples, sell-slot info, events, and state. | |
| Inspect transaction input layout | `Buyout Test`, `Post Test`, and `Cancel Test` headings are visible and grouped under `Selection / Transaction Inputs`. | |
| Inspect buyout controls | `Selected Browse Index` is visible with helper text `Uses the currently selected Bank of Durotar listing.` | |
| Inspect post controls | `Bidding Price`, `Buyout Price`, and `Auction Duration` labels are visible with stacked gold/silver/copper rows. | |
| Inspect cancel controls | `Owned Auction Index` is visible with helper text `Uses one selected owned auction.` | |

### Stage B - Buyout

| Step | Expected Result | Observed Result |
| --- | --- | --- |
| Search for an extremely inexpensive auction | Normal sidecar returns read-only listings. | |
| Select one low-value auction with buyout | Selected listing data is visible. | |
| Click `Prepare Buyout Test` | Probe records one source result index and identifying fields. | |
| Click `Prepare Final Click` | Probe revalidates the listing and final button becomes `Execute 1 Buyout Test`. | |
| Click `Execute 1 Buyout Test` once | `PlaceAuctionBid` is called at most once from that click; no retry or follow-up purchase occurs. | |
| Wait for result or timeout | Events, money change, UI errors, and state are recorded. | |
| Export report | Report shows function arguments and terminal state. | |

### Stage C - Post

Direct posting remains blocked/no-go. A failed pretest showed the old single-field input could interpret bare numbers as gold, and the later direct `StartAuction` live probe disabled the addon after one visible execute click. Do not continue direct posting tests; keep the following checks only as historical validation and future UI-safety reference.

| Step | Expected Result | Observed Result |
| --- | --- | --- |
| Manually place one cheap item in sell slot | The addon does not move the item. | |
| Enter bid `Gold=0`, `Silver=1`, `Copper=0` | Bid preview shows `Bid total: 1s 00c`. | |
| Enter buyout `Gold=0`, `Silver=2`, `Copper=0` | Buyout preview shows `Buyout total: 2s 00c`. | |
| Enter `Silver=100` in either price row | `Prepare Post Test` rejects the value; it is not normalized into gold. | |
| Enter `Copper=100` in either price row | `Prepare Post Test` rejects the value; it is not normalized into silver. | |
| Enter buyout below bid | `Prepare Post Test` rejects before preparing a transaction. | |
| Clear any price field | `Prepare Post Test` rejects the blank field. | |
| Edit any price field after `Prepare Post Test` | `PREPARED` is invalidated and final execution remains disabled. | |
| Edit any price field after `Prepare Final Click` | `READY_FOR_FINAL_CLICK` is invalidated and final execution becomes disabled. | |
| Open a fresh probe session | `12 Hours` is selected by default. | |
| Select `12 Hours` | Only `12 Hours` is selected; prepared API duration value is `1`. | |
| Select `24 Hours` | Only `24 Hours` is selected; prepared API duration value is `2`. | |
| Select `48 Hours` | Only `48 Hours` is selected; prepared API duration value is `3`. | |
| Edit duration after `Prepare Post Test` | `PREPARED` is invalidated and final execution remains disabled. | |
| Edit duration after `Prepare Final Click` | `READY_FOR_FINAL_CLICK` is invalidated and final execution becomes disabled. | |
| Enter stack size and one stack | Values are visible before preparation. | |
| Click `Prepare Post Test` | Probe reads sell-slot data and prepares one auction only. | |
| Review prepared post snapshot | Snapshot shows `Type`, `Item`, `Stack`, `Selected index`, `Bid total`, `Buyout total`, `Duration`, `Deposit`, and `State`. | |
| Click `Prepare Final Click` | Probe revalidates item and quantity; final button becomes `Execute 1 Post Test`. | |
| Click `Execute 1 Post Test` once | `StartAuction` is called at most once from that click; no repost or multiple-stack loop occurs. | Failed live: exactly one direct call was issued, then Blizzard immediately disabled the addon. |
| Wait for owned-auction update, UI error, or timeout | Events, bag changes, money changes, multisell events, and state are recorded. | Failed live: addon-disabled popup occurred immediately. Event classification may be `ADDON_ACTION_FORBIDDEN`, `ADDON_ACTION_BLOCKED`, or client disable before addon code could record the terminal event. |
| Export report | Report shows function arguments and terminal state. | Updated probe stores latest protected attempt and latest terminal failure under `BankOfDurotarDB.diagnostics.transactionProbe` when technically possible. |

Stage C direct `StartAuction` status: no-go. Do not retry direct addon posting. Future posting tests must be redesigned around compliant Blizzard-UI-assisted workflows where the player uses Blizzard's own posting control.

### Stage D - Cancel

| Step | Expected Result | Observed Result |
| --- | --- | --- |
| Refresh owned auctions | Owner list is current. | |
| Click `Inspect Owned` | Owner count and sample fields are recorded. | |
| Enter one owner-list index | One low-value owned auction is selected for the probe. | |
| Click `Prepare Cancel Test` | Probe records owner index and identifying fields. | |
| Click `Prepare Final Click` | Probe revalidates the owned listing; final button becomes `Execute 1 Cancel Test`. | |
| Click `Execute 1 Cancel Test` once | `CancelAuction` is called at most once from that click; no mass-cancel occurs. | |
| Wait for owner-list update, UI error, or timeout | Events and state are recorded. | |
| Export report | Report shows function argument and terminal state. | |

Each stage is optional and may be run independently. Stage A is the first approval target.

## Future Pricing Recommendation Test Matrix

Selling-price recommendations are planned only in `docs/PRICING_RECOMMENDATIONS.md`; no recommendation engine exists yet. Future implementation must include deterministic fixtures before live approval.

Required pricing fixtures:

| Case | Expected Result |
| --- | --- |
| No data | No bid or buyout prefill; show `No reliable market data available.` |
| Only stale data | No default prefill beyond stale threshold; show data age and refresh warning. |
| One valid listing | Recommendation is low confidence and explains limited sample size. |
| One extreme low outlier | Outlier is ignored or down-weighted when not a meaningful price wall. |
| One extreme high outlier | Outlier does not inflate estimated market value. |
| Clear meaningful price wall | Recommendation targets the first meaningful wall according to strategy. |
| Multiple competing price walls | Recommendation chooses a deterministic wall and explanation. |
| Large market supply | Confidence accounts for current supply and price stability. |
| Low market supply | Confidence lowers or returns no recommendation when evidence is weak. |
| Buyout below vendor value | Warning is shown and recommendation respects safety-floor policy. |
| Current market far below history | Engine may recommend Hold, Refresh Data, or No Recommendation. |
| Current market far above history | Confidence and explanation reflect abnormal market movement. |
| Stack-size normalization | Unit prices compare correctly across different stack sizes. |
| Bid greater than buyout | Recommendation is rejected. |
| Integer-copper boundaries | No overflow, floating-point money, or malformed totals occur. |
| Partial scan rejection | Partial snapshots are excluded from normal market-history calculations. |
| Edited-price invalidation | Prepared transaction state clears when form values change. |
| Tooltip hidden with no data | No tooltip valuation appears. |
| Tooltip value with fresh data | Tooltip shows estimated value, data age, and confidence. |
| Explanation accuracy | `Why?` text matches the selected recommendation reasons. |

Go/no-go status: no-go for pricing recommendation implementation until full-market scan behavior, snapshot completeness, market-history schema, 60-day retention, item identity keys, deterministic pricing tests, integer-copper math, and protected posting gates are complete.
