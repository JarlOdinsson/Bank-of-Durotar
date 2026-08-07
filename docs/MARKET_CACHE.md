# Persistent Market Cache

Bank of Durotar keeps three separate data layers:

1. Historical daily observations describe how an item behaved over time.
2. The latest completed full-market snapshot describes the market when the last successful scan finished.
3. A targeted-item overlay records a recent player-requested check for one item without changing the full-scan timestamp.

## Scope isolation and size

Snapshots are keyed by project/client, region, normalized realm, and faction Auction House scope. A Horde snapshot is not loaded for Alliance, and another realm or project receives a separate entry. The verified Anniversary legacy API does not expose a reliable neutral-house identifier, so the current target convention uses faction scope rather than guessing.

At most four market scopes are retained. Each keeps one completed snapshot and at most 100 targeted overlays. An overlay expires after 15 minutes. Raw auction rows are never saved; compact daily history remains separate.

## Atomic replacement

A new snapshot is built separately. It is accepted only when the player-started get-all query completed, every reported result index was processed, timestamps/counts/items are structurally valid, and the scope still matches. A structurally completed empty market is valid.

Cancellation, Auction House closure, timeout, API failure, incomplete processing, malformed records, or a scope change discards the candidate. The prior completed snapshot remains available. History updates only after the replacement commits.

## Freshness

Freshness starts at successful completion, never scan start.

| Label | Exact age |
|---|---:|
| Fresh | less than 1 hour |
| Recent | 1 hour through 4 hours |
| Aging | over 4 through 12 hours |
| Stale | over 12 through 24 hours |
| Historical only | over 24 hours |

The sidecar shows friendly age and coverage. `Scan Details` shows the exact completion timestamp and identifies the data as cached, not live.

## Workflow policy

- Plan uses a matching cache through 24 hours, while confidence drops and aging becomes a primary risk.
- Trades defaults to 12 hours. After four hours its capital allowance is halved; indivisible stacks that no longer fit are rejected. Existing tracked trades remain visible.
- Craft keeps cached comparisons, but Aging/Stale results are preliminary rather than currently actionable.
- Sell requires a targeted check after the configured maximum age, one hour by default.
- Historical sales, trade accounting, and journal-like records do not require a current scan.

## Targeted checks and clearing

`Check Current Item` and Trade's `Find Auctions` issue a player-requested legacy name query. Only the selected item enters the overlay. The item check never changes full-market completion or coverage.

Defaults reuse cache, retain per-scope snapshots, show status, and never run a full scan automatically on Auction House open. Preference fields for future automatic behavior do not bypass Classic's player-action and throttle requirements.

Use `/bod cache` for status. Use `/bod cache clear`, then `/bod cache clear confirm`, to remove snapshots and overlays while preserving history and Trades. A malformed scope cache is removed without a fatal error and produces one rebuild notice.
