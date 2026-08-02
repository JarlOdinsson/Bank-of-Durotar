# Bank of Durotar Rules

Keep this addon small and focused on three tasks: scan the Auction House, show conservative buy opportunities, and recommend manual sell prices.

- Target WoW Classic Anniversary interface `20506` and the verified legacy Auction House API.
- Never automate buying, bidding, posting, cancelling, clicks, keys, or unattended scans.
- Every scan must start from a deliberate player click and respect `CanSendAuctionQuery`/`canQueryAll`.
- Store only compact bounded local data. Never persist raw auction listings.
- Use integer copper, validate all API data, and prefer no recommendation over weak advice.
- Keep normal UI language simple. Buying and selling stay in Blizzard's UI.
- Before code edits, read this file and `README.md`; run `python tests/run_offline_checks.py` afterward.
- Do not add dependencies, external services, subscriptions, advertisements, or developer-only probe systems.
