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

Bank of Durotar `0.1.0-alpha.1` targets the legacy Auction House API on project ID `5` and interface `20506`. Runtime detection remains in place because future Classic Anniversary patches may change interface values, project constants, or API availability.

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
