# Roadmap

Later milestones depend on the verified findings from `0.0.1`. The completed live probe verified Classic Anniversary project ID `5`, interface `20506`, and the legacy Auction House API family. Future milestones should build on the legacy adapter unless a later live probe proves the client API changed.

- `0.0.1`: Auction API probe. Completed against WoW `2.5.6` build `68775`, interface `20506`, project ID `5`, legacy Auction House API.
- `0.1A`: Auction House sidecar scan entry point with a prominent `SCAN FOR DEALS` button. Early behavior may be a clearly labeled placeholder or current targeted/read-only workflow; it must not imply broad scan coverage or profitability analysis before those features exist.
- `0.1`: Standalone search, buy, sell, and owned-auction workflow.
- `0.2`: Local market history with bounded retention. Default 60 days, with detailed observations for days 0-7, compact summaries for days 8-30, compact low/median/high/average supply/sample count for days 31-60, and weekly cleanup of older records.
- `0.3`: Find Deals.
- `0.4`: Cost basis and realized-profit tracking.
- `0.5`: Sell My Stuff recommendations.
- `0.6`: Guided Daily Gold Plan.
- Later: account-wide inventory and profession profitability.
