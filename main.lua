-- Useful Marts: add shop information without replacing the engine's list UI.
--
-- The engine had two shop-list contracts over its lifetime:
--   * legacy full-screen lists titled "BUY" / "SELL";
--   * current item-box lists with no title, item.price for BUY, item.right for
--     SELL, and a real CANCEL row.
--
-- The current public ui.list_menu hook exposes navigation options, but not
-- shop rows or their renderer.  The small private adapter below is therefore
-- kept in one place, is installed only once per process, and decorates only
-- lists it can positively classify as shops.
local Font = require("src.render.Font")
local ListMenu = require("src.ui.ListMenu")

local MOD_ID = "useful_marts"
local PATCH_KEY = "__useful_marts_patch"
local INSTANCE_KEY = "_useful_marts_kind"

local ITEM_NAME_X = 48
local ITEM_TOP_Y = 32
local ITEM_INFO_X = 48

local function itemBoxOptions(opts)
  return type(opts) == "table" and opts.itemBox == true
end

local function kindFromTitle(title)
  if title == "BUY" then return "buy" end
  if title == "SELL" then return "sell" end
  return nil
end

-- Current ShopMenu passes title=nil.  Its callbacks and row fields are the
-- only available discriminator until the engine exposes a shop-row hook.
local function classify(title, items, opts)
  opts = opts or {}
  local explicit = opts.kind
  if explicit == "shop_buy" or explicit == "BUY" then return "buy" end
  if explicit == "shop_sell" or explicit == "SELL" then return "sell" end

  local titled = kindFromTitle(title)
  if titled then return titled end

  -- The current SELL list owns the SELECT swap callback, including the
  -- all-key-item case where no row has a quantity field.
  if itemBoxOptions(opts) and opts.dialogue and opts.money
      and opts.onSelectKey then
    return "sell"
  end

  -- Field-based inference is only safe for the current untitled contract.
  -- Other legacy menus commonly use `right` for their own secondary text.
  if title == nil and itemBoxOptions(opts) then
    local hasPrice, hasRight = false, false
    for _, item in ipairs(items or {}) do
      if not item.cancel then
        if item.price ~= nil then hasPrice = true end
        if item.right ~= nil then hasRight = true end
      end
    end
    if hasPrice and not hasRight then return "buy" end
    if hasRight and not hasPrice then return "sell" end
  end

  -- A BUY list containing only its CANCEL terminator still has the shop-only
  -- dialogue/money shape, whereas other item boxes do not.
  if itemBoxOptions(opts) and opts.dialogue and opts.money then
    return "buy"
  end
  return nil
end

local function sellPrice(def)
  if not def or def.keyItem or type(def.price) ~= "number" then return nil end
  return ("¥%d"):format(math.floor(def.price / 2))
end

local function isItemValue(item)
  return item and not item.cancel and type(item.value) == "string"
end

-- Pure builders remain exported for headless tests.  The itemBox form stores
-- private metadata instead of putting callbacks into item.sub: the current
-- native renderer expects item.sub to already be a string.
local function enrichSell(items, data, opts)
  local itemBox = itemBoxOptions(opts)
  local definitions = data and data.items
  for _, item in ipairs(items or {}) do
    item._usefulMartsSellPrice = nil
    if isItemValue(item) then
      local price = sellPrice(definitions and definitions[item.value])
      if price then
        if itemBox then
          item._usefulMartsSellPrice = price
          item.sub = nil
        else
          item.sub = price
        end
      else
        -- Do not retain another mod's or an earlier build's stale price on an
        -- unsellable/key/HM/unknown row.
        item.sub = nil
      end
    else
      item.sub = nil
    end
  end
  return items
end

local function enrichBuy(items, game, opts)
  local itemBox = itemBoxOptions(opts)
  for _, item in ipairs(items or {}) do
    item._usefulMartsBuy = nil
    if isItemValue(item) then
      if itemBox then
        item._usefulMartsBuy = true
        item.sub = nil
      else
        item.sub = function()
          local inventory = game and game.save and game.save.inventory
          local count = inventory and tonumber(inventory[item.value]) or 0
          return ("×%d in bag"):format(math.floor(count))
        end
      end
    else
      item.sub = nil
    end
  end
  return items
end

local function loaderState(game)
  local loader = game and game.mods
  local mods = loader and loader.mods
  if type(mods) ~= "table" then return nil end
  local mod = mods[MOD_ID]
  if not mod then return false end
  return mod.enabled ~= false and mod.state == "loaded"
end

local function currentItemText(self, item, kind)
  if kind == "buy" and item._usefulMartsBuy then
    local inventory = self.game and self.game.save and self.game.save.inventory
    local count = inventory and tonumber(inventory[item.value]) or 0
    return ("×%d"):format(math.floor(count))
  end
  if kind == "sell" then return item._usefulMartsSellPrice end
  return nil
end

local function drawExtras(self, kind, vanillaDraw)
  -- ShopMenu's SELECT swap rebuilds SELL rows in place instead of calling
  -- ListMenu.new, so refresh the private price metadata before drawing.
  if self.itemBox and kind == "sell" then
    enrichSell(self.items, self.game and self.game.data, { itemBox = true })
  end
  vanillaDraw(self)
  love.graphics.setColor(0, 0, 0, 1)
  for row = 1, self.rows do
    local item = self.items[self.scroll + row]
    if not item then break end

    local text
    if self.itemBox then
      text = currentItemText(self, item, kind)
      if text then
        -- The current item box already uses the right side for native price or
        -- quantity.  The added value sits under the item name on that same
        -- secondary row, so both values remain visible without overlap.
        Font.draw(text, ITEM_INFO_X,
          ITEM_TOP_Y + (row - 1) * 16 + 8)
      end
    else
      text = item.sub
      if type(text) == "function" then text = text() end
      if text then
        Font.draw(text, 160 - 8 - Font.width(text), 8 + row * 16 + 8)
      end
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local patch = ListMenu[PATCH_KEY]
if not patch then
  patch = {
    vanillaNew = ListMenu.new,
    vanillaDraw = ListMenu.draw,
    active = false,
  }

  patch.drawShop = function(self, kind)
    drawExtras(self, kind, patch.vanillaDraw)
  end

  patch.wrapper = function(game, title, items, opts)
    local options = opts or {}
    local kind = classify(title, items, options)
    local state = loaderState(game)
    if not kind or (state == false) or (state == nil and not patch.active) then
      return patch.vanillaNew(game, title, items, opts)
    end

    options.wrap = true
    options.kind = options.kind or ("shop_" .. kind)
    if kind == "sell" then
      enrichSell(items, game and game.data, options)
    else
      enrichBuy(items, game, options)
    end

    local list = patch.vanillaNew(game, title, items, options)
    list[INSTANCE_KEY] = kind
    list.draw = function(self)
      patch.drawShop(self, self[INSTANCE_KEY])
    end
    return list
  end

  ListMenu[PATCH_KEY] = patch
  ListMenu.new = patch.wrapper
end

-- Re-executing the entry on F5 updates the existing marker rather than
-- wrapping ListMenu.new or ListMenu.draw a second time.
patch.active = true

return function(mod)
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("ui.list_menu", function(next, opts, ctx)
      opts = next(opts, ctx) or opts
      local kind = ctx and ctx.kind
      if kind == "shop_buy" or kind == "shop_sell" then
        opts.wrap = true
      end
      return opts
    end)
  end
  mod.exports = { enrichSell = enrichSell, enrichBuy = enrichBuy }
end
