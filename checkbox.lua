--
-- CheckBox Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "widgets.base"

---@class WidgetCheckBox : Widget
---@field private checked boolean
local WidgetCheckBox = Widget:extend()

function WidgetCheckBox:new(parent, label)
  WidgetCheckBox.super.new(self, parent)
  self.checked = false
  self:set_label(label or "")
end

function WidgetCheckBox:set_label(text)
  WidgetCheckBox.super.set_label(self, text)

  self.size.x = self.font:get_width(self.label) + (style.padding.x * 2)
  self.size.y = self.font:get_height() + (style.padding.y * 2)
end

function WidgetCheckBox:set_checked(checked)
  self.checked = checked
end

function WidgetCheckBox:on_mouse_enter(...)
  WidgetCheckBox.super.on_mouse_enter(self, ...)
  self.foreground_color = style.accent
  self.background_color = style.dim
  system.set_cursor("hand")
end

function WidgetCheckBox:on_mouse_leave(...)
  WidgetCheckBox.super.on_mouse_leave(self, ...)
  self.foreground_color = style.text
  self.background_color = style.background
  system.set_cursor("arrow")
end

function WidgetCheckBox:on_click()
  self.checked = not self.checked
  self:on_checked(self.checked)
end

function WidgetCheckBox:on_checked(checked) end

function WidgetCheckBox:update()
  WidgetCheckBox.super.update(self)

  --self:set_label(self.text)
end

function WidgetCheckBox:get_box_rect()
  local size = 1.6
  local fh = self.font:get_height() / size
  return
    self.position.x,
    self.position.y + (fh / (size * 2)),
    self.font:get_width("x") + 4,
    fh
end

function WidgetCheckBox:draw()
  local bx, by, bw, bh = self:get_box_rect()

  self:draw_border(bx, by, bw, bh)

  renderer.draw_rect(bx, by, bw, bh, self.background_color)

  if self.checked then
    renderer.draw_rect(bx + 2, by + 2, bw-4, bh-4, style.caret)
  end

  renderer.draw_text(
    self.font,
    self.label,
    self.position.x + bw + 10,
    self.position.y,
    self.foreground_color
  )
end


return WidgetCheckBox
