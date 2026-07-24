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

Bank of Durotar `0.0.1` targets the legacy Auction House API on project ID `5` and interface `20506`. Runtime detection remains in place because future Classic Anniversary patches may change interface values, project constants, or API availability.
