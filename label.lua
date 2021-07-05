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
end

function Label:update()
  if not Label.super.update(self) then return end
  -- update the size
  self:set_label(self.label)
end

function Label:draw()
  if
    not self.visible or (self.parent and not self.parent.visible)
  then
    return
  end

  if type(self.label) == "table" then
    self:draw_styled_text(self.label, self.position.x, self.position.y)
  else
    renderer.draw_text(
      self.font,
      self.label,
      self.position.x,
      self.position.y,
      self.foreground_color or style.text
    )
  end
end


return Label

