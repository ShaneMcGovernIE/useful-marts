-- Useful Marts: the mart's lists gain info and wrap-around.
--   SELL list: the per-item sell price (half the buy price, like the
--     engine's sell), next to the vanilla count ("xN") on the row.
--   BUY list: how many of that item are already in the bag ("×N in
--     bag"), next to the vanilla ¥ buy price on the row.
--   BUY and SELL lists wrap: Up on the first row goes to the last, and
--     Down on the last row goes to the first.
-- Unsellable items (key items, HMs, unknown ids) show no price, and the
-- bag and all other lists are untouched.
--
-- Implemented as a thin wrapper over src.ui.ListMenu: the mart lists are
-- the only ListMenus created with the titles "SELL" and "BUY"
-- (ShopMenu.lua), so the wrapper enriches those items in place, turns on
-- the engine's existing wrap option, and the draw patch renders the
-- extra line.  A mod-free boot never runs the wrapper.
local Font = require("src.render.Font")
local ListMenu = require("src.ui.ListMenu")

local vanillaNew = ListMenu.new
local vanillaDraw = ListMenu.draw

-- Pure builders (published as mod.exports.enrichSell / enrichBuy for
-- headless tests): each adds it.sub, the right-aligned second line.
-- data is the item def table (game.data); sell rules match the engine:
-- unsellable when the def is missing, a key item, or an HM.
local function enrichSell(items, data)
  for _, it in ipairs(items) do
    local def = data.items[it.value]
    if def and not def.keyItem and not it.value:find("^HM_") then
      it.sub = ("¥%d"):format(math.floor(def.price / 2))
    end
  end
  return items
end

-- BUY rows read the bag at draw time (a function sub) so the count stays
-- live: the buy list stays open while you buy, and Bag.add mutates
-- save.inventory in place, so a closure over the save gives the current
-- amount without rebuilding the list.
local function enrichBuy(items, game)
  local inv = game and game.save and game.save.inventory
  for _, it in ipairs(items) do
    it.sub = function()
      return ("×%d in bag"):format(inv and inv[it.value] or 0)
    end
  end
  return items
end

ListMenu.new = function(game, title, items, opts)
  opts = opts or {}
  local isMart = title == "SELL" or title == "BUY"
  if game and game.data and game.data.items then
    if title == "SELL" then
      enrichSell(items, game.data)
    elseif title == "BUY" then
      enrichBuy(items, game)
    end
    if isMart then
      opts.wrap = true
    end
  end
  return vanillaNew(game, title, items, opts)
end

-- The row pitch is 16px, so a sub line at y + 8 sits cleanly between the
-- label and the next row.  Right-aligned like the buy prices on the BUY
-- list, and drawn after the base frame so nothing covers it.
ListMenu.draw = function(self)
  vanillaDraw(self)
  love.graphics.setColor(0, 0, 0, 1)
  for row = 1, self.rows do
    local item = self.items[self.scroll + row]
    if not item then break end
    -- sub may be a function (BUY rows) so the line is evaluated fresh
    -- every frame; a string (SELL rows) is drawn as-is
    local sub = item.sub
    if type(sub) == "function" then sub = sub() end
    if sub then
      Font.draw(sub, 160 - 8 - Font.width(sub), 8 + row * 16 + 8)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return function(mod)
  mod.exports = { enrichSell = enrichSell, enrichBuy = enrichBuy }
end
