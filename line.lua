--
-- Line Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "widget"

---@class widget.line : widget
---@field public padding integer
local Line = Widget:extend()

---Constructor
---@param parent widget
---@param thickness integer
---@param padding number
function Line:new(parent, thickness, padding)
  Line.super.new(self, parent)
  self.size.y = thickness or 2
  self.padding = padding or (style.padding.x / 2)
end

---Set the thickness of the line
---@param thickness number
function Line:set_thickness(thickness)
  self.size.y  = thickness or 2
end

function Line:draw()
  if not self:is_visible() then return false end

  self.size.x = self.parent.size.x

  renderer.draw_rect(
    self.position.x + self.padding,
    self.position.y,
    self.size.x - (self.padding * 2),
    self.size.y,
    self.foreground_color or style.caret
  )

  return true
end


return Line

