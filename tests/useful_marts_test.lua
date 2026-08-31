-- Standalone from the engine checkout:
--   luajit /path/to/mod/tests/useful_marts_test.lua useful-marts-main ..
-- Loads the mod through the real headless loader, then checks the pure
-- enrich builders and the actual ShopMenu -> ListMenu path used by the
-- current engine (untitled item boxes with native price/count fields).
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.fresh()
local MOD_PATH = (arg and arg[1]) or "mods/useful_marts"
local MOD_ROOT = arg and arg[2]

love = require("tests.love_stub")
local calls = {}
local FontStub = {
  BORDER = { tl = 1, tr = 2, bl = 3, br = 4, h = 5, v = 6 },
  DEFAULT_BORDER = { tl = 1, tr = 2, bl = 3, br = 4, h = 5, v = 6 },
  draw = function(text, x, y) calls[#calls + 1] = { "draw", text, x, y } end,
  drawCode = function(code, x, y) calls[#calls + 1] = { "code", code, x, y } end,
  drawBox = function(tx, ty, tw, th) calls[#calls + 1] = { "box", tx, ty, tw, th } end,
  width = function(text) return #tostring(text) * 8 end,
  split = function(text)
    local out = {}
    for i = 1, #tostring(text) do out[i] = i end
    return out
  end,
  encode = function() return {} end,
  spansFitting = function(spans) return #spans end,
  advanceOf = function() return 8 end,
}
package.loaded["src.render.Font"] = FontStub

local run = T.sdk.loadMod(MOD_PATH, { data = Data, root = MOD_ROOT })
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

-- ---------- current ShopMenu integration ----------

local ShopMenu = require("src.ui.ShopMenu")

local function gameWith(inventory, bagOrder)
  local pressed
  local game = {
    data = Data,
    save = { money = 3000, inventory = inventory, bagOrder = bagOrder },
    input = {
      wasPressed = function(_, button) return pressed == button end,
      isDown = function() return false end,
    },
    stack = {
      states = {},
      push = function(self, state) self.states[#self.states + 1] = state end,
      pop = function(self) table.remove(self.states) end,
      top = function(self) return self.states[#self.states] end,
    },
  }
  function game.press(button) pressed = button end
  return game
end

local buyGame = gameWith({ FIX_POTION = 3 }, { "FIX_POTION" })
local buyMenu = ShopMenu.new(buyGame, { "FIX_POTION", "FIX_BALL" }, function() end)
buyGame.stack:push(buyMenu)
buyMenu.index = 1
buyGame.press("a")
buyMenu:update(1 / 60)
buyGame.press(nil)
local buyList = buyGame.stack:top()
T.eq(buyList.title, nil, "current BUY list has no title")
T.eq(buyList.itemBox, true, "current BUY list uses the item box")
T.eq(buyList.wrap, true, "current BUY list wraps")
T.eq(buyList.items[1].price, "¥300", "native BUY price survives")
T.eq(buyList.items[1].sub, nil, "current BUY rows do not pass a callback as sub")
calls = {}
buyList:draw()
local function drawn(text)
  for _, call in ipairs(calls) do
    if call[1] == "draw" and call[2] == text then return call end
  end
end
T.check(drawn("¥300") ~= nil, "current BUY draw keeps the native price")
T.check(drawn("×3") ~= nil, "current BUY draw adds the live bag count")
buyGame.save.inventory.FIX_POTION = 7
calls = {}
buyList:draw()
T.check(drawn("×7") ~= nil, "current BUY draw reads the live inventory")
T.check(drawn("×3") == nil, "current BUY draw does not retain a stale count")
T.eq(buyList.items[#buyList.items].sub, nil, "BUY CANCEL has no added sub line")

Data.items.FIX_KEY = {
  id = "FIX_KEY", index = 6, name = "FIX KEY", price = 0, keyItem = true,
}
local sellGame = gameWith({ FIX_POTION = 3, FIX_KEY = 1 },
                          { "FIX_POTION", "FIX_KEY" })
local sellMenu = ShopMenu.new(sellGame, { "FIX_POTION" }, function() end)
sellGame.stack:push(sellMenu)
sellMenu.index = 2
sellGame.press("a")
sellMenu:update(1 / 60)
sellGame.press(nil)
local sellList = sellGame.stack:top()
T.eq(sellList.title, nil, "current SELL list has no title")
T.eq(sellList.itemBox, true, "current SELL list uses the item box")
T.eq(sellList.wrap, true, "current SELL list wraps")
T.eq(sellList.items[1].right, "x3", "native SELL quantity survives")
T.eq(sellList.items[2].right, nil, "key-item quantity stays hidden")
calls = {}
sellList:draw()
T.check(drawn("¥150") ~= nil, "current SELL draw adds the sell price")
T.check(drawn("CANCEL") ~= nil, "current SELL draw keeps CANCEL")
T.eq(sellList.items[#sellList.items].sub, nil, "SELL CANCEL has no added sub line")

-- SELECT swapping rebuilds the SELL rows inside ShopMenu without calling
-- ListMenu.new again; the added price must survive that rebuild too.
sellList.index = 1
sellList.onSelectKey(sellList.items[1], sellList)
sellList.index = 2
sellList.onSelectKey(sellList.items[2], sellList)
T.eq(sellList.items[1].value, "FIX_KEY", "SELL SELECT swaps the bag order")
calls = {}
sellList:draw()
T.check(drawn("¥150") ~= nil, "SELL price survives SELECT row rebuild")

-- A hot reload can retain the shared ListMenu module after this mod is
-- disabled or failed; the old adapter must not stay active in that state.
local disabledItems = {
  { value = "FIX_POTION", label = "FIX POTION", price = "¥300" },
}
local disabledGame = gameWith({ FIX_POTION = 3 }, {})
disabledGame.mods = {
  mods = { useful_marts = { enabled = false, state = "disabled" } },
}
local disabledList = ListMenu.new(disabledGame, nil, disabledItems, {
  itemBox = true, dialogue = true, money = function() return 0 end,
})
T.eq(disabledList.wrap, nil, "disabled mod leaves current list vanilla")
T.eq(disabledItems[1]._usefulMartsBuy, nil,
  "disabled mod leaves current rows unmodified")

-- The legacy full-screen contract remains supported for older engines.
local legacySell = { { value = "FIX_POTION", label = "FIX POTION", right = "x3" } }
local legacy = require("src.ui.ListMenu").new({ data = Data }, "SELL", legacySell, {})
T.eq(legacy.wrap, true, "legacy SELL list wraps")
T.eq(legacySell[1].sub, "¥150", "legacy SELL still gets a secondary line")

-- Loading the mod twice must not wrap the shared constructor twice.
run.release()
local listMenuModule = require("src.ui.ListMenu")
local constructorBeforeReload = listMenuModule.new
local drawBeforeReload = listMenuModule.draw
local modFile = MOD_ROOT and (MOD_ROOT .. "/" .. MOD_PATH .. "/main.lua")
  or (MOD_PATH .. "/main.lua")
local secondEntry = assert(loadfile(modFile))
local secondRun = secondEntry()
secondRun({ hooks = { wrap = function() end }, exports = {} })
T.eq(listMenuModule.new, constructorBeforeReload,
  "reloading does not wrap the shared constructor twice")
T.eq(listMenuModule.draw, drawBeforeReload,
  "reloading does not replace the shared draw function")
local reloadItems = { { value = "FIX_POTION", label = "FIX POTION", price = "¥300" } }
local reloadGame = gameWith({ FIX_POTION = 2 }, {})
local reloadList = require("src.ui.ListMenu").new(reloadGame, nil, reloadItems,
  { itemBox = true, dialogue = true, money = function() return 0 end })
calls = {}
reloadList:draw()
local seenCount = 0
for _, call in ipairs(calls) do
  if call[1] == "draw" and call[2] == "×2" then seenCount = seenCount + 1 end
end
T.eq(seenCount, 1, "reloading does not duplicate the added count")

run.release()
T.finish("useful_marts")
