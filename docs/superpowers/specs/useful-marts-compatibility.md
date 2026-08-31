# Useful Marts Compatibility Specification

## Goal

Restore Useful Marts on the current Gen 1 Recomp shop UI while preserving support for the older full-screen shop-list contract.

## Required behavior

1. BUY and SELL are detected from the current shop row/options contract when the list title is nil, while the legacy `BUY`/`SELL` title contract remains supported.
2. BUY keeps the engine's native price and adds a compact live bag count without passing a function to the native item-box renderer.
3. SELL keeps the engine's native quantity and adds the per-item sell price without pricing key items, HMs, unknown ids, or CANCEL.
4. Both shop list variants wrap at the ends.
5. Non-shop ListMenus are not modified at draw time.
6. Re-loading the mod does not stack constructor or draw wrappers, and a disabled/failed mod does not activate a stale wrapper when the loader state is available.
7. The manifest explicitly targets Gen 1 and caps the compatibility range below the next engine API line.
8. The test suite exercises the current ShopMenu -> ListMenu path, current item-box drawing, legacy lists, edge rows, and repeated loading.
9. The release workflow runs ROM-free lint, strict fixture validation, and the mod regression test before packaging.

## Constraints

- Keep API 2 and avoid ROM-derived content.
- Use the existing `engine_internals` permission only for the narrowly isolated compatibility adapter required by the current engine, because the current public `ui.list_menu` hook does not expose shop rows or rendering.
- Do not change unrelated engine files or generated data.
