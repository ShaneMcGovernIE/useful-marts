-- Standalone: luajit mods/useful_marts/tests/useful_marts_test.lua
-- Loads the mod through the real headless loader, then checks the pure
-- enrich builders (sell price = half buy price; key items, HMs and unknown
-- ids get no price; buy rows show the bag count) and the ListMenu wrapper
-- (SELL/BUY lists enriched in place and wrapping, other titles untouched).
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local run = T.sdk.loadMod("mods/useful_marts", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")

local enrichSell = run.loader.exports.useful_marts.enrichSell
local enrichBuy = run.loader.exports.useful_marts.enrichBuy
T.check(type(enrichSell) == "function" and type(enrichBuy) == "function",
  "both enrich builders are published for tests")

-- ---------- sell builder ----------

-- FIX_POTION (300) -> ¥150, FIX_BALL (200) -> ¥100, FIX_TM (3000) -> ¥1500
local items = {
  { value = "FIX_POTION", label = "FIX POTION", right = "x3" },
  { value = "FIX_BALL", label = "FIX BALL", right = "x1" },
  { value = "FIX_TM", label = "FIX TM01", right = "x2" },
}
enrichSell(items, Data)
T.eq(items[1].sub, "¥150", "potion sells for half of 300")
T.eq(items[2].sub, "¥100", "ball sells for half of 200")
T.eq(items[3].sub, "¥1500", "TM sells for half of 3000")
T.eq(items[1].right, "x3", "the count survives enrichment")

-- key items, HMs and unknown ids get no sub line
local unsellable = {
  { value = "FIX_BADGE_1", label = "FIX BADGE 1", right = "x1" },
  { value = "HM_01", label = "HM01 CUT", right = "x1" },
  { value = "NO_SUCH_ITEM", label = "?", right = "x1" },
}
local custom = { items = {
  FIX_BADGE_1 = { id = "FIX_BADGE_1", name = "FIX BADGE 1", price = 0, keyItem = true },
} }
enrichSell(unsellable, custom)
T.eq(unsellable[1].sub, nil, "key item has no price")
T.eq(unsellable[2].sub, nil, "HM has no price")
T.eq(unsellable[3].sub, nil, "unknown id has no price")

-- a zero-price sellable item still gets its (¥0) line
local freebie = { { value = "FIX_BALL", label = "FIX BALL", right = "x1" } }
enrichSell(freebie, { items = { FIX_BALL = { id = "FIX_BALL", price = 0 } } })
T.eq(freebie[1].sub, "¥0", "zero-price item shows ¥0")

-- ---------- buy builder ----------

local game = { save = { inventory = { FIX_POTION = 5, FIX_BALL = 0 } } }
local buyItems = {
  { value = "FIX_POTION", label = "FIX POTION", right = "¥300" },
  { value = "FIX_BALL", label = "FIX BALL", right = "¥200" },
  { value = "FIX_TM", label = "FIX TM01", right = "¥3000" },
}
enrichBuy(buyItems, game)
T.check(type(buyItems[1].sub) == "function", "buy sub is live (a function)")
T.eq(buyItems[1].sub(), "×5 in bag", "buy row shows the bag count")
T.eq(buyItems[2].sub(), "×0 in bag", "an unowned item shows ×0")
T.eq(buyItems[3].sub(), "×0 in bag", "an item not in the bag shows ×0")
T.eq(buyItems[1].right, "¥300", "the buy price survives enrichment")

-- the count follows the save even after the list was built: Bag.add
-- mutates save.inventory in place, so the closure sees the new amount
game.save.inventory.FIX_POTION = 7
T.eq(buyItems[1].sub(), "×7 in bag", "the count updates after a purchase")

enrichBuy(buyItems, { save = nil })
T.eq(buyItems[1].sub(), "×0 in bag", "a missing save still shows ×0")

enrichBuy(buyItems, nil)
T.eq(buyItems[1].sub(), "×0 in bag", "a nil game still shows ×0, no crash")

-- ---------- ListMenu wrapper ----------

local ListMenu = require("src.ui.ListMenu")
local sellItems = {
  { value = "FIX_POTION", label = "FIX POTION", right = "x4" },
}
local list = ListMenu.new({ data = Data }, "SELL", sellItems, {})
T.check(list ~= nil, "SELL list constructs")
T.eq(sellItems[1].sub, "¥150", "SELL items are enriched in place")
T.eq(list.wrap, true, "SELL list wraps at the ends")

local wrappedBuy = {
  { value = "FIX_POTION", label = "FIX POTION", right = "¥300" },
}
local bagged = { data = Data, save = { inventory = { FIX_POTION = 2 } } }
local buyList = ListMenu.new(bagged, "BUY", wrappedBuy, {})
T.eq(wrappedBuy[1].sub(), "×2 in bag", "BUY items are enriched in place")
T.eq(buyList.wrap, true, "BUY list wraps at the ends")

local untouched = {
  { value = "FIX_POTION", label = "FIX POTION", right = "x4" },
}
local other = ListMenu.new({ data = Data }, "ITEMS", untouched, {})
T.eq(untouched[1].sub, nil, "other list titles are left alone")
T.eq(other.wrap, nil, "other lists keep their vanilla wrap setting")
T.eq(sellItems[1].sub, "¥150", "SELL sub stays a plain string")

local nilOpts = { value = "FIX_POTION", label = "FIX POTION", right = "x1" }
local noOpts = ListMenu.new({ data = Data }, "SELL", { nilOpts }, nil)
T.check(noOpts ~= nil, "nil opts constructs without crashing")
T.eq(nilOpts.sub, "¥150", "nil opts still enriches SELL items")
T.eq(noOpts.wrap, true, "nil opts still enables wrap")

run.release()
T.finish("useful_marts")
