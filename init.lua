-- mod-version:1 lite-xl 1.16
--
-- Base widget implementation for lite.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local View = require "core.view"
local RootView = require "core.rootview"

---
---Represents the border of a widget.
---@class widget.border
---@field public width number
---@field public color RendererColor
local WidgetBorder = {}

---
---Represents the position of a widget.
---@class widget.position
---@field public x number Real X
---@field public y number Real y
---@field public rx number Relative X
---@field public ry number Relative Y
---@field public dx number Dragging initial x position
---@field public dy number Dragging initial y position
local WidgetPosition = {}

---A base widget
---@class widget @global
---@field public super widget
---@field public parent widget
---@field public position widget.position
---@field public size widget.position
---@field public childs table<integer,widget>
---@field public child_active widget
---@field public zindex integer
---@field private next_zindex integer
---@field public border widget.border
---@field public foreground_color RendererColor
---@field public background_color RendererColor
---@field public visible boolean
---@field private has_focus boolean
---@field private draggable boolean
---@field private dragged boolean
---@field private font renderer.font
---@field private tooltip string
---@field private label string
---@field private input_text boolean
---@field private textview widget
---@field private mouse widget.position
---@field private mouse_is_pressed boolean
---@field private mouse_is_hovering boolean
local Widget = View:extend()

function Widget:new(parent)
  Widget.super.new(self)

  self.parent = parent
  self.childs = {}
  self.child_active = nil
  self.zindex = nil
  self.next_zindex = 1
  self.border = {
    width = 1,
    color = nil
  }
  self.foreground_color = nil
  self.background_color = nil
  self.visible = parent and true or false
  self.has_focus = false
  self.draggable = false
  self.dragged = false
  self.font = style.font
  self.tooltip = ""
  self.label = ""
  self.input_text = false
  self.textview = nil
  self.mouse = {x = 0, y = 0}

  self.mouse_is_pressed = false
  self.mouse_is_hovering = false

  self:set_position(0, 0)

  if parent then
    parent:add_child(self)
  else
    local this = self
    local mouse_pressed_outside = false -- used to allow proper node resizing
    local root_view_on_mouse_pressed = RootView.on_mouse_pressed
    local root_view_on_mouse_released = RootView.on_mouse_released
    local root_view_on_mouse_moved = RootView.on_mouse_moved
    local root_view_on_mouse_wheel = RootView.on_mouse_wheel
    local root_view_update = RootView.update
    local root_view_draw = RootView.draw
    local root_view_on_text_input = RootView.on_text_input

    function RootView:on_mouse_pressed(button, x, y, clicks)
      mouse_pressed_outside = not this:mouse_on_top(x, y)
      if
        mouse_pressed_outside
        or
        not this:on_mouse_pressed(button, x, y, clicks)
      then
        root_view_on_mouse_pressed(self, button, x, y, clicks)
      end
    end

    function RootView:on_mouse_released(...)
      if mouse_pressed_outside or not this:on_mouse_released(...) then
        root_view_on_mouse_released(self, ...)
        mouse_pressed_outside = false
      end
    end

    function RootView:on_mouse_moved(...)
      if mouse_pressed_outside or not this:on_mouse_moved(...) then
        root_view_on_mouse_moved(self, ...)
      end
    end

    function RootView:on_mouse_wheel(...)
      if not this:on_mouse_wheel(...) then
        root_view_on_mouse_wheel(self, ...)
      end
    end

    function RootView:on_text_input(...)
      if not this:on_text_input(...) then
        root_view_on_text_input(self, ...)
      end
    end

    function RootView:update()
      root_view_update(self)
      this:update()
    end

    function RootView:draw()
      root_view_draw(self)
      if this.visible then
        core.root_view:defer_draw(this.draw, this)
      end
    end
  end
end

---Add a child widget.
---@param child widget
function Widget:add_child(child)
  if not child.zindex then
    child.zindex = self.next_zindex
  end

  table.insert(self.childs, child)
  table.sort(self.childs, function(t1, t2) return t1.zindex < t2.zindex end)

  self.next_zindex = self.next_zindex + 1
end

function Widget:show() self.visible = true end

function Widget:hide() self.visible = false end

function Widget:draw_border(x, y, w, h)
  if self.border.width <= 0 then return end

  x = x or self.position.x
  y = y or self.position.y
  w = w or self.size.x
  h = h or self.size.y

  x = x - self.border.width
  y = y - self.border.width
  w = w + (self.border.width * 2)
  h = h + (self.border.width * 2)

  renderer.draw_rect(
    x, y, w + x % 1, h + y % 1,
    self.border.color or style.text
  )
end

function Widget:set_target_size(axis, value)
  self.size[axis] = value
  return true
end

function Widget:set_position(x, y)
  self.position.x = x + self.border.width
  self.position.y = y + self.border.width

  if self.parent then
    self.position.rx = x
    self.position.ry = y

    self.position.x = self.position.x + self.parent.position.x

    self.position.y = self.position.y + self.parent.position.y
  end

  for _, child in pairs(self.childs) do
    child:set_position(child.position.rx, child.position.ry)
  end
end

---Get the relative position in relation to parent
---@return widget.position
function Widget:get_position()
  local position = { x = self.position.x, y = self.position.y }
  if self.parent then
    position.x = math.abs(position.x - self.parent.position.x)
    position.y = math.abs(position.y - self.parent.position.y)
  end
  return position
end

function Widget:get_width()
  return self.size.x + (self.border.width * 2)
end

function Widget:get_height()
  return self.size.y + (self.border.width * 2)
end

function Widget:get_right()
  return self:get_position().x + self:get_width()
end

function Widget:get_bottom()
  return self:get_position().y + self:get_height()
end

function Widget:mouse_on_top(x, y)
  return
    x - self.border.width >= self.position.x
    and
    x - self.border.width <= self.position.x + self:get_width()
    and
    y - self.border.width >= self.position.y
    and
    y - self.border.width <= self.position.y + self:get_height()
end

function Widget:set_focus(has_focus)
  self.set_focus = has_focus
end

function Widget:set_tooltip(tooltip)
  self.tooltip = tooltip
end

function Widget:set_label(text)
  self.label = text
end

function Widget:drag(x, y)
  self:set_position(x - self.position.dx, y - self.position.dy)
end

function Widget:swap_active_child(child)
  if self.child_active then
    self.child_active:deactivate()
  end

  self.child_active = child

  if child then
    self.child_active:activate()
    core.set_active_view(child.textview)
  end
end

function Widget:get_scrollable_size()
  local bottom_position = self.size.y
  for _, child in pairs(self.childs) do
    bottom_position = math.max(bottom_position, child:get_bottom())
  end
  return bottom_position
end

--
-- Events
--

function Widget:on_text_input(text)
  if not self.visible then return end

  Widget.super.on_text_input(self, text)

  if self.child_active then
    self.child_active:on_text_input(text)
    return true
  end

  return false
end

function Widget:on_mouse_pressed(button, x, y, clicks)
  if not self.visible then return end

  if self:mouse_on_top(x, y) then
    if Widget.super.on_mouse_pressed(self, button, x, y, clicks) then
      return true
    end
    self.mouse_is_pressed = true
    if self.draggable then
      self.position.dx = x - self.position.x
      self.position.dy = y - self.position.y
      system.set_cursor("hand")
    end
  else
    self:swap_active_child()
    return false
  end

  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_pressed(button, x, y, clicks)
      return true
    end
  end

  return true
end

function Widget:on_mouse_released(button, x, y)
  if not self.visible then return end

  if self.mouse_is_pressed then
    self.mouse_is_pressed = false
    if self.draggable then
      system.set_cursor("arrow")
    end
  end

  if not self:mouse_on_top(x, y) then
    return false
  end

  Widget.super.on_mouse_released(self, button, x, y)

  self:swap_active_child()

  if not self.dragged then
    for _, child in pairs(self.childs) do
      if child:mouse_on_top(x, y) or child.mouse_is_pressed then
        child:on_mouse_released(button, x, y)
        if child.input_text then
          self:swap_active_child(child)
        end
        child:on_click(button, x, y)
        return true
      end
    end
  end

  self.dragged = false

  return true
end

function Widget:on_click(button, x, y) end

function Widget:activate() end

function Widget:deactivate() end

function Widget:on_mouse_moved(x, y, dx, dy)
  self.mouse.x = x
  self.mouse.y = y

  if self.visible then
    Widget.super.on_mouse_moved(self, x, y, dx, dy)
    if self.dragging_scrollbar then
      return true
    end
  else
    return
  end

  local is_over = true

  if self:mouse_on_top(x, y) then
    if not self.mouse_is_hovering  then
      system.set_cursor("arrow")
      self.mouse_is_hovering = true
      if #self.tooltip > 0 then
        core.status_view:show_tooltip(self.tooltip)
      end
      self:on_mouse_enter(x, y, dx, dy)
    end
  elseif not self.mouse_is_pressed or not self.draggable then
    if self.mouse_is_hovering then
      self.mouse_is_hovering = false
      if #self.tooltip > 0 then
        core.status_view:remove_tooltip()
      end
      self:on_mouse_leave(x, y, dx, dy)
    end
    is_over = false
  end

  if self.mouse_is_pressed and self.draggable then
    self:drag(x, y)
    self.dragged = true
    return true
  end

  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) or child.mouse_is_hovering then
      child:on_mouse_moved(x, y, dx, dy)
      break
    end
  end

  return is_over
end

function Widget:on_mouse_enter(x, y, dx, dy)
  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_enter(x, y, dx, dy)
      return
    end
  end
end

function Widget:on_mouse_leave(x, y, dx, dy)
  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_leave(x, y, dx, dy)
      return
    end
  end
end

function Widget:on_mouse_wheel(y)
  if
    not self.visible
    or
    not self:mouse_on_top(self.mouse.x, self.mouse.y)
  then
    return
  end

  for _, child in pairs(self.childs) do
    if child:mouse_on_top(self.mouse.x, self.mouse.y) then
      if child:on_mouse_wheel(y) then
        return true
      end
    end
  end

  if self.scrollable then
    Widget.super.on_mouse_wheel(self, y)
    return true
  end

  return false
end

function Widget:update()
  if not self.visible then return end

  Widget.super.update(self.parent or self)

  for _, child in pairs(self.childs) do
    child:update()
  end

  return true
end

function Widget:draw()
  if not self.visible then return end

  Widget.super.draw(self)

  self:draw_border()

  if self.background_color then
    self:draw_background(self.background_color)
  else
    self:draw_background(
      self.parent and style.background or style.background2
    )
  end

  if #self.childs > 0 then
    renderer.set_clip_rect(
      self.position.x,
      self.position.y,
      self.size.x,
      self.size.y
    )
  end

  for _, child in pairs(self.childs) do
    child:draw()
  end

  if #self.childs > 0 then
    local w, h = system.get_window_size()
    renderer.set_clip_rect(0, 0, w, h)
  end

  if self.scrollable then
    self:draw_scrollbar()
  end

  return true
end


return Widget
