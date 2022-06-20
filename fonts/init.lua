local core = require "core"
local common = require "core.common"
local FontCache = require "widget.fonts.cache"

---@class widget.fonts
---@fields public cache FontCache
local Fonts = {}

---@type widget.fonts.cache
local fontcache = FontCache()

Fonts.cache = fontcache

local fonts = {}

---Generate the list of fonts displayed on the CommandView.
---@param monospaced? boolean Only display fonts detected as monospaced.
local function generate_fonts(monospaced)
  if not fontcache.monospaced then monospaced = false end
  fonts = {}
  for idx, f in ipairs(fontcache.fonts) do
    if not monospaced or (monospaced and f.monospace) then
      table.insert(fonts, f.fullname .. "||" .. idx)
    end
  end
end

---Helper function to split a string by a given delimeter.
local function split(s, delimeter, delimeter_pattern)
  if not delimeter_pattern then
    delimeter_pattern = delimeter
  end

  local result = {};
  for match in (s..delimeter):gmatch("(.-)"..delimeter_pattern) do
    table.insert(result, match);
  end
  return result;
end

---Launch the commandview and let the user select a font.
---@param callback fun(name:string, path:string)
---@param monospaced? boolean
function Fonts.show_picker(callback, monospaced)
  if fontcache.building or fontcache.searching_monospaced then
    monospaced = false
  end

  if not fontcache.building then
    generate_fonts(monospaced)
  end

  core.command_view:enter("Select Font", {
    submit = function(text, item)
      callback(item.text, item.info)
    end,
    suggest = function(text)
      if fontcache.building then
        generate_fonts(monospaced)
      end
      local res = common.fuzzy_match(fonts, text)
      for i, name in ipairs(res) do
        local font_info = split(name, "||")
        local id = tonumber(font_info[2])
        local font_data = fontcache.fonts[id]
        res[i] = {
          text = font_data.fullname,
          info = font_data.path,
          id = id
        }
      end
      return res
    end
  })
end


return Fonts
