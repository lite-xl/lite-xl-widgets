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
  self:set_label(label or "")
end

function Label:set_label(text)
  Label.super.set_label(self, text)

  self.size.x = self.font:get_width(self.label)
  self.size.y = self.font:get_height()
end

function Label:update()
  Label.super.update(self)
  -- update the size
  self:set_label(self.label)
end

function Label:draw()
  renderer.draw_text(
    self.font,
    self.label,
    self.position.x,
    self.position.y,
    self.foreground_color or style.text
  )
end


return Label

