# Bank of Durotar

Bank of Durotar `0.1.0-alpha.1` is a standalone World of Warcraft Classic Anniversary Auction House addon. This alpha adds a read-only player-facing search and browse sidecar for the verified legacy Auction House API.

It does not recommend trades, calculate profit, buy auctions, post auctions, bid, cancel auctions, collect market history, or run unattended scans.

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

Milestone `0.1A` is implemented and live-verified. It adds read-only targeted search, sorting, filtering, listing inspection, and a docked scrollable sidecar.

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
/bod market
```

`/bod` toggles the diagnostic window. `/bod market` toggles the player-facing sidecar. `/bod probe` runs exactly one targeted diagnostic Auction House query after confirming that the Auction House is open and query permission is available. `/bod clear` must be run twice within 10 seconds to clear stored diagnostics.

The minimap button opens the sidecar with left-click and opens options with right-click. Drag it around the minimap edge to reposition it. Use `/bod minimap hide` or `/bod minimap show` to control visibility, and `/bod minimap reset` to restore its default position.

`/bod market` opens the player-facing Auction House sidecar. When the Auction House is open and docking is enabled, the sidecar attaches to the right edge of the Auction House frame. The primary alpha action is `SEARCH MARKET`, which performs one manually initiated targeted search.

## Searching The Market

1. Open the Auction House.
2. Confirm the Bank of Durotar sidecar appears, or run `/bod market`.
3. Enter an item name.
4. Click `SEARCH MARKET` or `Search`.
5. Wait for Ready, Waiting for query cooldown, Scanning, Completed, or Failed status.
6. Sort or filter the current result page.
7. Select a listing to inspect details.

This milestone does not add a Buy button. The sidecar displays: `Purchasing will be added after protected-action verification.`

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
- `0.1A` search reads only the current targeted result page. It does not auto-page or perform a full Auction House scan.
- `0.1A` does not include Find Deals, profitability analysis, or market-history collection.

## Development And Compliance

Future work is governed by the repository instructions and compliance documents:

- [AGENTS.md](AGENTS.md)
- [Product requirements](docs/REQUIREMENTS.md)
- [Blizzard compliance register](docs/BLIZZARD_COMPLIANCE.md)
- [Development workflow](docs/DEVELOPMENT_WORKFLOW.md)
- [Milestone tasks](docs/TASKS.md)

Bank of Durotar is designed to comply with Blizzard's addon policy. Blizzard does not provide individual addon endorsement, authorization, certification, or approval. Live-client verification is required for client API behavior.

## Policy

This addon is designed to respect Blizzard's UI Add-On Development Policy:

https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534
