# Roadmap

Later milestones depend on the verified findings from `0.0.1`. The completed live probe verified Classic Anniversary project ID `5`, interface `20506`, and the legacy Auction House API family. Future milestones should build on the legacy adapter unless a later live probe proves the client API changed.

- `0.0.1`: Auction API probe. Completed against WoW `2.5.6` build `68775`, interface `20506`, project ID `5`, legacy Auction House API.
- `0.1A`: Read-only Auction House sidecar search and browse. Complete and live-verified as `0.1.0-alpha.1`. The supported current workflow is targeted item-name `Search`; the planned future primary full-market action is `SCAN MARKET`.
- `0.1B`: Protected Auction House transaction workflow planning. Documentation-only compliance design for future buyout, posting, and cancellation workflows; no transaction code.
- `0.1C`: Developer-only Auction House transaction probe. Implemented as `0.1.0-alpha.2`, partially live-verified. Direct `StartAuction` posting failed: one visible execute click issued exactly one direct call and the client disabled the addon. Direct posting is no-go; future posting research must be Blizzard-UI-assisted only.
- `0.1D`: Full Market Scan Probe. Pending and required before market-history collection; verifies legacy `getAll` query behavior, cooldowns, completion, duplicate events, cancellation, memory impact, and snapshot completeness without adding production full-scan behavior.
- `0.1`: Standalone search, buy, sell, and owned-auction workflow.
- `0.2`: Local market history with bounded retention. Default 60 days, with detailed observations for days 0-7, compact summaries for days 8-30, compact low/median/high/average supply/sample count for days 31-60, and weekly cleanup of older records.
- `0.3`: Find Deals.
- `0.3A`: Selling-price recommendations. Planned and blocked; designs `BOD.PricingService`, meaningful price-wall logic, confidence, and editable selling-form prefill without automatic posting.
- `0.4`: Cost basis and realized-profit tracking.
- `0.5`: Sell My Stuff recommendations.
- `0.6`: Guided Daily Gold Plan.
- Later: account-wide inventory and profession profitability.
