--
-- Button Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "widget"

---@class widget.button : widget
---@field public padding widget.position
local Button = Widget:extend()

function Button:new(parent, label)
  Button.super.new(self, parent)

  self.padding = {
    x = style.padding.x,
    y = style.padding.y
  }

  self:set_label(label or "")
end

function Button:set_label(text)
  Button.super.set_label(self, text)

  self.size.x = self.font:get_width(self.label) + (self.padding.x * 2)
  self.size.y = self.font:get_height() + (self.padding.y * 2)
end

function Button:on_mouse_enter(...)
  Button.super.on_mouse_enter(self, ...)
  self.foreground_color = style.accent
  self.background_color = style.dim
  system.set_cursor("hand")
end

function Button:on_mouse_leave(...)
  Button.super.on_mouse_leave(self, ...)
  self.foreground_color = style.text
  self.background_color = style.background
  system.set_cursor("arrow")
end

function Button:update()
  Button.super.update(self)
  -- update size
  self:set_label(self.label)
end

function Button:draw()
  Button.super.draw(self)

  renderer.draw_text(
    self.font,
    self.label,
    self.position.x + self.padding.x,
    self.position.y + self.padding.y,
    self.foreground_color
  )
end


return Button
