# Useful Marts Engine Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Useful Marts on the current Gen 1 Recomp shop UI and close the reviewed compatibility, lifecycle, test, manifest, and release-gate issues.

**Architecture:** Keep the engine-private access in one idempotent constructor adapter in `main.lua`. Detect both legacy titled lists and current untitled item-box lists, attach drawing only to identified shop instances, and leave the engine's native price/quantity rendering intact. Use the public `ui.list_menu` hook for wrapping when available, while retaining the adapter only for the row data and legacy/current draw compatibility the current API does not expose.

**Tech Stack:** Lua/LuaJIT, LÖVE 2D engine modules, Gen 1 Recomp API 2 manifests, Python `tools/modkit.py`, GitHub Actions.

**Spec:** `docs/superpowers/specs/useful-marts-compatibility.md`

## Global Constraints

- Keep API 2 and avoid ROM-derived content.
- Target `games: ["gen1"]` explicitly.
- Preserve legacy full-screen shop-list support and add current `itemBox` support.
- Do not modify unrelated engine files or generated data.
- Run tests before claiming completion and distinguish static/ROM-free validation from in-game verification.

---

### Task 1: Add current-engine regression coverage

**Files:**
- Modify: `tests/useful_marts_test.lua`

**Interfaces:**
- Consumes: `tests.modkit`, `tests.modkit.fixtures`, current `src.ui.ShopMenu`, and the mod exports.
- Produces: assertions for current `title=nil`/`itemBox=true` lists, native price/count preservation, extra shop text, CANCEL exclusion, legacy behavior, and repeat loading.

- [x] **Step 1: Replace generated-data loading with the ROM-free fixture and allow an explicit mod path**

Use `T.fixtures.fresh()` and select `arg[1]` when supplied, defaulting to `mods/useful_marts` so the same test runs from the engine checkout and from the installed mod layout.

- [x] **Step 2: Add a current ShopMenu integration test**

Drive BUY and SELL through `ShopMenu.new`, `menu:update`, and the test stack. Assert `title == nil`, `itemBox == true`, `wrap == true`, native `price`/`right` fields remain present, and drawing emits both native and mod-owned display text.

- [x] **Step 3: Add edge-row and reload assertions**

Assert key/HM/unknown rows and CANCEL have no added price/count, then load the mod a second time and assert one shop draw produces one copy of each added value.

- [x] **Step 4: Run the test before changing production code**

Run:

```sh
cd /Users/shanemcgovern/dev/gen1recomp-dev
luajit /Users/shanemcgovern/dev/useful-marts-main/tests/useful_marts_test.lua /Users/shanemcgovern/dev/useful-marts-main
```

Expected: FAIL because the current implementation still depends on the removed BUY/SELL title contract or passes incompatible row data to the current renderer.

### Task 2: Replace the global draw patch with an idempotent shop-instance adapter

**Files:**
- Modify: `main.lua`

**Interfaces:**
- Consumes: legacy `ListMenu.new(game, title, items, opts)` and current `ListMenu.new(game, nil, items, opts)` contracts.
- Produces: an idempotent `ListMenu.new` adapter, per-shop-instance draw wrappers, compact current item-box extras, legacy full-screen extras, and exported pure builders.

- [x] **Step 1: Add a single classification helper**

Classify in this order: explicit `opts.kind` values `shop_buy`/`shop_sell`, legacy titles, current SELL's `onSelectKey`, current BUY rows with `price`, and current SELL rows with `right`. Ignore CANCEL when inspecting rows.

- [x] **Step 2: Add an idempotent module marker**

Store the original constructor and draw function under a private `ListMenu` marker. If the marker already exists during hot reload, update its current callbacks instead of wrapping the wrapper again.

- [x] **Step 3: Keep native row fields and store only private mod metadata for item boxes**

For current item boxes, leave `price` and `right` untouched and store the added sell price or BUY marker in private fields. For legacy lists, keep the existing `sub` behavior so the older renderer remains supported.

- [x] **Step 4: Attach drawing only to classified shop instances**

Call the original draw once. For current item boxes, draw a compact `×N` under the item name for BUY or the sell price under the item name for SELL. For legacy lists, retain the existing full-screen right-aligned secondary line. Do not replace `ListMenu.draw` globally.

- [x] **Step 5: Make stale wrappers inert when loader state is available**

Have the marker check `game.mods.mods.useful_marts` and require `state == "loaded"` before applying behavior. Keep a test fallback for headless stubs with no loader object.

### Task 3: Update metadata and documentation

**Files:**
- Modify: `manifest.json`
- Modify: `mod.card`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the compatibility specification and current UI behavior.
- Produces: explicit Gen 1 scope, capped engine range, accurate compact current-layout documentation, and a release note.

- [x] **Step 1: Declare Gen 1 and cap the engine range**

Add `"games": ["gen1"]` and change the engine range to `">=0.0.0-0 <0.3.0"` in both manifest metadata locations.

- [x] **Step 2: Document current item-box presentation**

Describe the current compact `×N` BUY count and SELL price placement while retaining the legacy behavior description where applicable.

- [x] **Step 3: Add a changelog entry**

Record the engine compatibility repair, row-rendering fix, idempotent hot-reload behavior, and test/release validation improvements.

### Task 4: Add release validation gates

**Files:**
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: current upstream engine `tools/modkit.py`, fixture data, and the test path argument from Task 1.
- Produces: a release job that fails before packaging when lint, strict validation, or the regression test fails.

- [x] **Step 1: Check out the engine validation sources**

Use `actions/checkout@v4` for `bryanthaboi/gen1recomp`, ref `dev`, into `.modkit-engine`, with sparse paths for `src`, `tests`, and `tools/modkit.py`.

- [x] **Step 2: Install LuaJIT and run validation**

Run `modkit lint`, strict fixture validation, and the Lua regression test before the packaging step.

- [x] **Step 3: Keep packaging after validation**

Leave the existing reproducible archive and version checks in place so only validated source reaches the release step.

### Task 5: Verify all changed behavior

**Files:**
- Inspect: `main.lua`, `manifest.json`, `mod.card`, `tests/useful_marts_test.lua`, `.github/workflows/release.yml`

**Interfaces:**
- Consumes: all implementation tasks.
- Produces: fresh command evidence and a final compatibility report.

- [x] **Step 1: Run the focused regression test**

Run the test from Task 1 and require zero failures.

- [x] **Step 2: Run syntax, lint, strict validation, and packaging checks**

Run:

```sh
luajit -b /Users/shanemcgovern/dev/useful-marts-main/main.lua /private/tmp/useful_marts_main.luac
python3 /Users/shanemcgovern/dev/gen1recomp-dev/tools/modkit.py lint /Users/shanemcgovern/dev/useful-marts-main --repo /Users/shanemcgovern/dev/gen1recomp-dev
python3 /Users/shanemcgovern/dev/gen1recomp-dev/tools/modkit.py validate /Users/shanemcgovern/dev/useful-marts-main --strict --base fixture --repo /Users/shanemcgovern/dev/gen1recomp-dev
python3 /Users/shanemcgovern/dev/gen1recomp-dev/tools/modkit.py pack /Users/shanemcgovern/dev/useful-marts-main --output /private/tmp/useful_marts_verified.zip --repo /Users/shanemcgovern/dev/gen1recomp-dev
```

- [x] **Step 3: Inspect the final diff and status**

Confirm only the planned mod files and plan/spec documentation changed, with no edits to the unrelated engine worktree.
