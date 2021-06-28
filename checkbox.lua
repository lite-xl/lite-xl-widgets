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

  local bx, by, bw, bh = self:get_box_rect()

  self.size.x = self.font:get_width(self.label) + bw + (style.padding.x / 2)
  self.size.y = self.font:get_height()
end

function CheckBox:set_checked(checked)
  self.checked = checked
end

function CheckBox:on_mouse_enter(...)
  CheckBox.super.on_mouse_enter(self, ...)
  self.hover_text = style.accent
  self.hover_back = style.dim
  system.set_cursor("hand")
end

function CheckBox:on_mouse_leave(...)
  CheckBox.super.on_mouse_leave(self, ...)
  self.hover_text = nil
  self.hover_back = nil
  system.set_cursor("arrow")
end

function CheckBox:on_click()
  self.checked = not self.checked
  self:on_checked(self.checked)
end

function CheckBox:on_checked(checked) end

function CheckBox:update()
  CheckBox.super.update(self)

  -- update size
  self:set_label(self.label)
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

  renderer.draw_rect(
    bx, by, bw, bh,
    self.hover_back or self.background_color or style.background
  )

  if self.checked then
    renderer.draw_rect(bx + 2, by + 2, bw-4, bh-4, style.caret)
  end

  renderer.draw_text(
    self.font,
    self.label,
    self.position.x + bw + (style.padding.x / 2),
    self.position.y,
    self.hover_text or self.foreground_color or style.text
  )
end


return CheckBox

