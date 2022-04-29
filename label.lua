--
-- Label Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "widget"

---@class widget.label : widget
local Label = Widget:extend()

function Label:new(parent, label)
  Label.super.new(self, parent)
  self.clickable = false
  self.border.width = 0
  self:set_label(label or "")
end

---@param text string|widget.styledtext
function Label:set_label(text)
  Label.super.set_label(self, text)

  if type(text) == "table" then
    self.size.x, self.size.y = self:draw_styled_text(text, 0, 0, true)
  else
    self.size.x = self.font:get_width(self.label)
    self.size.y = self.font:get_height()
  end

  if self.border.width > 0 then
    self.size.x = self.size.x + style.padding.x
    self.size.y = self.size.y + style.padding.y
  end
end

function Label:update()
  if not Label.super.update(self) then return false end

  -- update the size
  self:set_label(self.label)

  return true
end

function Label:draw()
  if not self:is_visible() then return false end

  self:draw_border()

  local px = self.border.width > 0 and (style.padding.x / 2) or 0
  local py = self.border.width > 0 and (style.padding.y / 2) or 0

  if type(self.label) == "table" then
    self:draw_styled_text(self.label, self.position.x, self.position.y)
  else
    renderer.draw_text(
      self.font,
      self.label,
      self.position.x + px,
      self.position.y + py,
      self.foreground_color or style.text
    )
  end

  return true
end


return Label

