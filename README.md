# Bank of Durotar

Bank of Durotar `0.0.1` is a standalone World of Warcraft Classic Anniversary diagnostic addon. This milestone probes which Auction House APIs, events, result fields, and client constants are available in the live client.

It does not recommend trades, calculate profit, buy auctions, post auctions, bid, cancel auctions, or run unattended scans.

## Installation

Copy the `BankOfDurotar` folder to:

```text
World of Warcraft/_classic_era_/Interface/AddOns/BankOfDurotar/
```

The Anniversary installation path may differ on a given machine. Verify the active game folder in the Battle.net launcher before installing.

The `.toc` currently uses `## Interface: 20506`, based on live Classic Anniversary client verification from WoW `2.5.6` build `68775`. Update it after a client patch if WoW marks the addon out of date.

## Verified Client Target

Milestone `0.0.1` was verified in a live Classic Anniversary client reporting WoW `2.5.6`, build `68775`, interface `20506`, `WOW_PROJECT_ID` `5`, and `WOW_PROJECT_BURNING_CRUSADE_CLASSIC` `5`.

Bank of Durotar currently targets the legacy Auction House API on project ID `5`. The verified API family is `legacy`: `QueryAuctionItems`, `CanSendAuctionQuery`, `GetNumAuctionItems`, `GetAuctionItemInfo`, `GetAuctionItemLink`, and `GetAuctionItemTimeLeft` exist and worked during the probe. `C_AuctionHouse` was not present in the verified client.

## Commands

```text
/bod
/bod help
/bod show
/bod hide
/bod probe
/bod status
/bod debug
/bod clear
/bod minimap
/bod minimap show
/bod minimap hide
/bod minimap reset
```

`/bod` toggles the diagnostic window. `/bod probe` runs exactly one targeted Auction House query after confirming that the Auction House is open and query permission is available. `/bod clear` must be run twice within 10 seconds to clear stored diagnostics.

The minimap button opens the diagnostic window with left-click and opens options with right-click. Drag it around the minimap edge to reposition it. Use `/bod minimap hide` or `/bod minimap show` to control visibility, and `/bod minimap reset` to restore its default position.

## Running The Probe

1. Log in and open the Auction House.
2. Run `/bod show`.
3. Change the search text if needed. The default is `Netherweave Cloth`.
4. Click `Probe`, use the minimap menu's `Run Probe`, or run `/bod probe`.
5. Wait for `RESULTS_RECEIVED`, `TIMED_OUT`, or `FAILED`.
6. Click `Export Report`, then copy the highlighted report text.

A zero-result search is still useful if the result event and result count are captured.

## Known Limitations

- Modern `C_AuctionHouse` search is detected but not implemented as a query path in this milestone.
- The addon intentionally avoids `getAll` scans and repeated automatic queries.
- Result fields vary by client; missing values are recorded as unavailable rather than invented.
- The legacy client can emit repeated `AUCTION_ITEM_LIST_UPDATE` events for one query; the probe finalizes only once.

## Policy

This addon is designed to respect Blizzard's UI Add-On Development Policy:

https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
