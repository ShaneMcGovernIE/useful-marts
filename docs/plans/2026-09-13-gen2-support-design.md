# Useful Marts: Gen 2 Support Design

**Date:** 2026-09-13
**Author:** Shane McGovern / Antigravity
**Status:** Approved

## Overview
Expand Useful Marts to provide dual-generation support for Pokémon Gen 1 (Red, Blue, Yellow) and Gen 2 (Gold, Silver, Crystal). The mod enhances mart BUY and SELL lists with inventory counts and sell prices while adding list wrap-around, without replacing native engine menus or UI widgets.

## Requirements & Constraints
1. **Dual-Generation Scope**: Manifest specifies `"games": ["gen1", "gen2"]` with API 2.
2. **Gen 2 BUY List Enhancement** (`MartMenu`):
   - Draw live bag inventory count (`×N`) directly beneath the item name at tile `(LIST_X, ty + 1)`.
   - Wrap cursor at the ends: Up from first row jumps to CANCEL; Down from CANCEL jumps to first row.
   - Works across all mart types (Standard, Herb Shop, Bargain Shop, Pharmacy).
3. **Gen 2 SELL List Enhancement** (`PackMenu` in Mart Sell Flow):
   - When entering sell mode via `MartMenu:enterSell`, tag the pack instance.
   - In `PackMenu:drawList`, draw per-item sell price (`¥N`, `math.floor(def.price / 2)`) at tile `(listX, ty + 1)` under the item name.
   - Respect vanilla unsellable rules: key items, HMs, and items with missing/non-numeric prices show no sell price.
   - Standard overworld Pack menu opened outside marts remains completely vanilla.
4. **Idempotence & Safety**:
   - Patch hooks installed on module load under private markers with hot-reload guard.
   - Inactive when mod is disabled in loader.
5. **Quality & Validation**:
   - Automated unit tests covering both Gen 1 and Gen 2 mart paths.
   - Clean passes on `tools/modkit.py validate --strict`, `lint`, and `gen2check`.

## Architecture & Module Interfaces
- `main.lua`:
  - Retains existing Gen 1 `ListMenu` adapter for Gen 1.
  - Adds Gen 2 adapter checking `pcall(require, "src.ui.gen2.MartMenu")` and `pcall(require, "src.ui.gen2.PackMenu")`.
  - Wraps `MartMenu.updateBuy`, `MartMenu.drawBuyList`, and `MartMenu.enterSell`.
  - Wraps `PackMenu.drawList`.
  - Exports pure helper functions for testing: `sellPrice`, `enrichSell`, `enrichBuy`.
- `manifest.json`:
  - `"games": ["gen1", "gen2"]`
  - Version bump to 1.1.0
  - `"game_version": ">=0.0.0-0 <2.0.0"`
- `tests/useful_marts_test.lua`:
  - Full suite testing Gen 1 ShopMenu and Gen 2 MartMenu + PackMenu.
