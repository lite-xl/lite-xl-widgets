--
-- CheckBox Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "widget"

---@class widget.checkbox : widget
---@field private checked boolean
local CheckBox = Widget:extend()

function CheckBox:new(parent, label)
  CheckBox.super.new(self, parent)
  self.checked = false
  self:set_label(label or "")
end

function CheckBox:set_label(text)
  CheckBox.super.set_label(self, text)

  self.size.x = self.font:get_width(self.label) + (style.padding.x * 2)
  self.size.y = self.font:get_height() + (style.padding.y * 2)
end

function CheckBox:set_checked(checked)
  self.checked = checked
end

function CheckBox:on_mouse_enter(...)
  CheckBox.super.on_mouse_enter(self, ...)
  self.foreground_color = style.accent
  self.background_color = style.dim
  system.set_cursor("hand")
end

function CheckBox:on_mouse_leave(...)
  CheckBox.super.on_mouse_leave(self, ...)
  self.foreground_color = style.text
  self.background_color = style.background
  system.set_cursor("arrow")
end

function CheckBox:on_click()
  self.checked = not self.checked
  self:on_checked(self.checked)
end

function CheckBox:on_checked(checked) end

function CheckBox:update()
  CheckBox.super.update(self)

  --self:set_label(self.text)
end

function CheckBox:get_box_rect()
  local size = 1.6
  local fh = self.font:get_height() / size
  return
    self.position.x,
    self.position.y + (fh / (size * 2)),
    self.font:get_width("x") + 4,
    fh
end

function CheckBox:draw()
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


return CheckBox

