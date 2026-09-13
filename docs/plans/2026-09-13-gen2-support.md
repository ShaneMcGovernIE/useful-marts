# Gen 2 Support Implementation Plan

> **For Antigravity:** REQUIRED WORKFLOW: Use `.agent/workflows/execute-plan.md` to execute this plan in single-flow mode.

**Goal:** Add full Gen 2 (Gold, Silver, Crystal) support to Useful Marts, providing live bag counts on BUY, per-item sell prices on SELL, and list wrap-around, while keeping Gen 1 support 100% intact.

**Architecture:** Use targeted idempotent module method patching in `main.lua` for `src.ui.gen2.MartMenu` and `src.ui.gen2.PackMenu`, guarded by `loaderState(game)` and reload markers. Preserve all vanilla Gen 2 engine dialogues and layouts, and maintain pure builder exports for headless unit tests.

**Tech Stack:** Lua/LuaJIT, LÖVE 2D engine modules, Gen 1/Gen 2 Recomp API 2, Python `tools/modkit.py`.

---

### Task 1: Add Gen 2 Test Coverage

**Files:**
- Modify: `tests/useful_marts_test.lua`

**Step 1: Write failing Gen 2 tests**
Add assertions for:
- `MartMenu` BUY list wrapping at the ends (Up on index 1 jumps to CANCEL, Down on CANCEL jumps to 1).
- `MartMenu` BUY list drawing the live inventory count (`×N`) under the item name.
- `MartMenu` BUY list updating the count live when inventory changes.
- `MartMenu` SELL flow tagging the opened `Gen2PackMenu` and displaying the sell price (`¥N`) under sellable items.
- Unsellable items (key items, HMs, zero/missing prices) not showing a sell price in `Gen2PackMenu`.
- Overworld `Gen2PackMenu` (not opened from `enterSell`) not showing sell prices.
- Hot reloading the mod without duplicate hooks or duplicate text.

**Step 2: Run test to verify it fails on Gen 2**
Run:
```bash
luajit /Users/shanemcgovern/dev/useful-marts-main/tests/useful_marts_test.lua useful-marts-main /Users/shanemcgovern/dev
```
Expected: FAIL because `main.lua` does not yet patch Gen 2 `MartMenu` or `PackMenu`.

---

### Task 2: Implement Gen 2 Support in main.lua

**Files:**
- Modify: `main.lua`

**Step 1: Add Gen 2 module loading and helper functions**
- Attempt `pcall(require, "src.ui.gen2.MartMenu")` and `pcall(require, "src.ui.gen2.PackMenu")`.
- Implement `sellPriceGen2(items, itemId)` that excludes `canToss == false`, `keyItem == true`, `^HM_`, and non-numeric prices.

**Step 2: Install idempotent Gen 2 MartMenu patch**
- Store original methods under `MartMenu.__useful_marts_patch`.
- Wrap `updateBuy` to add wrap-around for index 1 (Up jumps to `total`) and `total` (Down jumps to 1).
- Wrap `drawBuyList` to draw `×N` under each visible entry at tile `(LIST_X, ty + 1)` using `Chrome.print`.
- Wrap `enterSell` to stamp `self.pack._usefulMartsSell = true`.

**Step 3: Install idempotent Gen 2 PackMenu patch**
- Store original `drawList` under `PackMenu.__useful_marts_patch`.
- Wrap `drawList` to draw `¥N` at tile `(listX, ty + 1)` when `self._usefulMartsSell` is true.

**Step 4: Run test to verify it passes**
Run:
```bash
luajit /Users/shanemcgovern/dev/useful-marts-main/tests/useful_marts_test.lua useful-marts-main /Users/shanemcgovern/dev
```
Expected: PASS (all Gen 1 and Gen 2 checks pass).

**Step 5: Commit**
```bash
git add main.lua tests/useful_marts_test.lua
git commit -m "feat: add Gen 2 MartMenu and PackMenu support"
```

---

### Task 3: Metadata, Documentation, and Final Validation

**Files:**
- Modify: `manifest.json`
- Modify: `mod.card`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Step 1: Update manifest.json and mod.card**
- Set `games: ["gen1", "gen2"]`.
- Set `version: "1.1.0"`.
- Set `game_version: ">=0.0.0-0 <2.0.0"`.
- Sync `mod.card` metadata with `manifest.json`.

**Step 2: Update README.md and CHANGELOG.md**
- Note dual-generation support (Gen 1 Red/Blue/Yellow and Gen 2 Gold/Silver/Crystal).
- Add changelog entry for v1.1.0.

**Step 3: Run validation tooling**
Run:
```bash
cd /Users/shanemcgovern/dev/gen1recomp
python3 tools/modkit.py validate /Users/shanemcgovern/dev/useful-marts-main --strict
python3 tools/modkit.py lint /Users/shanemcgovern/dev/useful-marts-main
python3 tools/modkit.py gen2check /Users/shanemcgovern/dev/useful-marts-main
```
Expected:
- `validate`: OK
- `lint`: OK
- `gen2check`: PASS (0 errors)

**Step 4: Commit**
```bash
git add manifest.json mod.card README.md CHANGELOG.md
git commit -m "chore: bump version to 1.1.0 and update docs for Gen 2"
```
