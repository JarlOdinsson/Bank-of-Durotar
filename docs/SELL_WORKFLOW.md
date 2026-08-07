# Sell Workflow

Sell separates cached context from a current item check.

1. Choose an item and stack quantity.
2. A recent completed scan initializes the calculation.
3. Once that scan exceeds the Sell maximum age, the cached unit price is context only and `Check Current Item` is required.
4. The player-clicked targeted query aggregates only matching results.
5. The recommendation records full scan ID/completion, targeted validation time, observed price, generation time, and recommended price.
6. Posting remains manual.

The targeted overlay expires after 15 minutes and never makes another item or the full market appear fresh. When no current buyout listings are found, the addon does not present an old lowest listing as current.

The verified Classic legacy API requires the Auction House to be open, query cooldown permission, and a player click. It cannot provide an invisible background price guarantee.
