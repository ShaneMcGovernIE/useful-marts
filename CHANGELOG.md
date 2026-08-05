# Changelog

## [1.0.1] - 2026-08-05

### Fixed

- The mart ListMenu wrapper no longer crashes when called with no options
  table (the engine's own `ListMenu.new` is nil-safe; the wrapper wasn't).
- `enrichBuy` no longer crashes when invoked with a nil game.
- BUY/SELL detection is hardened against a stub data table with no items.

### Changed

- The duplicated BUY/SELL title check was hoisted into an `isMart` helper.

## [1.0.0] - 2026-08-02

### Added

- Renamed from Sell Prices to Useful Marts; now lives at
  github.com/ShaneMcGovernIE/useful-marts.
- The mart's BUY and SELL lists wrap: Up on the first row jumps to the
  last, Down on the last row jumps to the first.

### Changed

- The mart's BUY list shows, under each item name, how many of that item
  are already in the bag ("×N in bag"), next to the vanilla ¥ buy price.
  The count is read at draw time, so it updates immediately after buying.
- The mart's SELL list shows each item's per-item sell price (half the buy
  price, right-aligned) on a second line under the item name, next to the
  existing "xN" count.
- Key items, HMs and unknown item ids show no price, matching the vanilla
  unsellable rules.
