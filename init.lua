-- mod-version:1 lite-xl 1.16
--
-- Base widget implementation for lite.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local View = require "core.view"
local DocView = require "core.docview"
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

---
---@alias widtget.button
---|>'"left"'
---| '"right"'

---
---A base widget
---@class widget @global
---@field public super widget
---@field public parent widget
---@field public position widget.position
---@field public size widget.position
---@field public childs table<integer,widget>
---@field public child_active widget
---@field public zindex integer
---@field public border widget.border
---@field public draggable boolean
---@field public font renderer.font
---@field public foreground_color RendererColor
---@field public background_color RendererColor
---@field private visible boolean
---@field private has_focus boolean
---@field private dragged boolean
---@field private tooltip string
---@field private label string
---@field private input_text boolean
---@field private textview widget
---@field private next_zindex integer
---@field private mouse widget.position
---@field private prev_position widget.position
---@field private prev_size widget.position
---@field private mouse_is_pressed boolean
---@field private mouse_is_hovering boolean
local Widget = View:extend()

---
---When no parent is given to the widget constructor it will automatically
---overwrite RootView methods to intercept system events.
---@param parent widget
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
  self.prev_position = {x = 0, y = 0}
  self.prev_size = {x = 0, y = 0}

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
        this:swap_active_child()
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

---Add a child widget, automatically assign a zindex if non set and sorts
---them in reverse order for better events matching.
---@param child widget
function Widget:add_child(child)
  if not child.zindex then
    child.zindex = self.next_zindex
  end

  table.insert(self.childs, child)
  table.sort(self.childs, function(t1, t2) return t1.zindex > t2.zindex end)

  self.next_zindex = self.next_zindex + 1
end

---Show the widget.
function Widget:show()
  if not self.parent then
    if self.size.x <= 0 or self.size.y <= 0 then
      self.size.x = self.prev_size.x
      self.size.y = self.prev_size.y
    end
    self.prev_size.x = 0
    self.prev_size.y = 0
  end
  self.visible = true
end

---Hide the widget.
function Widget:hide()
  self.visible = false
  -- we need to force size to zero on parent widget to properly hide it
  -- when used as a lite node, otherwise the reserved space of the node
  -- will stay visible and dragging will reveal empty space.
  if not self.parent then
    if self.size.x > 0 or self.size.y > 0 then
      -- we only do this once to prevent issues of consecutive hide calls
      if self.prev_size.x == 0 and self.prev_size.y == 0 then
        self.prev_size.x = self.size.x
        self.prev_size.y = self.size.y
      end
      self.size.x = 0
      self.size.y = 0
    end
  end
end

---Toggle visibility of widget.
function Widget:toggle_visible()
  if not self.visible then
    self:show()
  else
    self:hide()
  end
end

---Draw the widget configured border or custom one.
---@param x? number
---@param y? number
---@param w? number
---@param h? number
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

---Called by lite node system to properly resize the widget.
---@param axis string | "'x'" | "'y'"
---@param value number
function Widget:set_target_size(axis, value)
  if not self.visible then
    return false
  end
  self.size[axis] = value
  return true
end

---@param width integer
---@param height integer
function Widget:set_size(width, height)
  if not self.parent and not self.visible then
    self.prev_size.x = width
    self.prev_size.y = height
  else
    self.size.x = width
    self.size.y = height
  end
end

---Set the position of the widget and updates the child absolute coordinates
---@param x integer
---@param y integer
function Widget:set_position(x, y)
  self.position.x = x + self.border.width
  self.position.y = y + self.border.width

  if self.parent then
    self.position.rx = x
    self.position.ry = y

    -- add offset to properly scroll
    local ox, oy = self.parent:get_content_offset()
    self.position.x = ox + self.position.x
    self.position.y = oy + self.position.y
  end

  self.prev_position.x = self.position.x
  self.prev_position.y = self.position.y

  for _, child in pairs(self.childs) do
    child:set_position(child.position.rx, child.position.ry)
  end
end

---Get the relative position in relation to parent
---@return widget.position
function Widget:get_position()
  local position = { x = self.position.x, y = self.position.y }
  if self.parent then
    position.x = self.position.rx
    position.y = self.position.ry
  end
  return position
end

---Get width including borders.
---@return number
function Widget:get_width()
  return self.size.x + (self.border.width * 2)
end

---Get height including borders.
---@return number
function Widget:get_height()
  return self.size.y + (self.border.width * 2)
end

---Get the right x coordinate relative to parent
---@return number
function Widget:get_right()
  return self:get_position().x + self:get_width()
end

---Get the bottom y coordinate relative to parent
---@return number
function Widget:get_bottom()
  return self:get_position().y + self:get_height()
end

---Check if the given mouse coordinate is hovering the widget
---@param x number
---@param y number
---@return boolean
function Widget:mouse_on_top(x, y)
  return
    self.visible
    and
    x - self.border.width >= self.position.x
    and
    x - self.border.width <= self.position.x + self:get_width()
    and
    y - self.border.width >= self.position.y
    and
    y - self.border.width <= self.position.y + self:get_height()
end

---Mark a widget as having focus.
---TODO: Implement set focus system by pressing a key like tab?
function Widget:set_focus(has_focus)
  self.set_focus = has_focus
end

---Text displayed when the widget is hovered.
---@param tooltip string
function Widget:set_tooltip(tooltip)
  self.tooltip = tooltip
end

---A text label for the widget, not all widgets support this.
---@param text string
function Widget:set_label(text)
  self.label = text
end

---Used internally when dragging is activated.
---@param x number
---@param y number
function Widget:drag(x, y)
  self:set_position(x - self.position.dx, y - self.position.dy)
end

---Replaces current active child with a new one and calls the
---activate/deactivate events of the child. This is especially
---used to send text input events to widgets with input_text support.
---@param child? widget If nil deactivates current child
function Widget:swap_active_child(child)
  if self.parent then
    self.parent:swap_active_child(child)
  end

  if self.child_active then
    self.child_active:deactivate()
  end

  self.child_active = child

  if child then
    if
      not self.prev_view
      and
      getmetatable(core.active_view) == DocView
    then
      self.prev_view = core.active_view
    end
    self.child_active:activate()
    core.set_active_view(child.textview)
  elseif self.prev_view then
    -- return focus to previous docview
    core.set_active_view(self.prev_view)
    self.prev_view = nil
  end
end

---Calculates the scrollable size based on the bottom most widget.
---@return number
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

---Redirects any text input to active child with the input_text flag.
---@param text string
---@return boolean processed
function Widget:on_text_input(text)
  if not self.visible then return end

  Widget.super.on_text_input(self, text)

  if self.child_active then
    self.child_active:on_text_input(text)
    return true
  end

  return false
end

---Send mouse pressed events to hovered child or starts dragging if enabled.
---@param button widget.button
---@param x number
---@param y number
---@param clicks integer
---@return boolean processed
function Widget:on_mouse_pressed(button, x, y, clicks)
  if not self.visible then return end

  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_pressed(button, x, y, clicks)
      return true
    end
  end

  if self:mouse_on_top(x, y) then
    Widget.super.on_mouse_pressed(self, button, x, y, clicks)
    self.mouse_is_pressed = true
    if self.draggable and not self.child_active then
      self.position.dx = x - self.position.x
      self.position.dy = y - self.position.y
      system.set_cursor("hand")
    end
  else
    self:swap_active_child()
    return false
  end

  return true
end

---Send mouse released events to hovered child, ends dragging if enabled and
---emits on click events if applicable.
---@param button widget.button
---@param x number
---@param y number
---@return boolean processed
function Widget:on_mouse_released(button, x, y)
  if not self.visible then return end

  self:swap_active_child()

  if not self.dragged then
    for _, child in pairs(self.childs) do
      local mouse_on_top = child:mouse_on_top(x, y)
      if mouse_on_top or child.mouse_is_pressed then
        child:on_mouse_released(button, x, y)
        if child.input_text then
          self:swap_active_child(child)
        end
        if mouse_on_top then
          child:on_click(button, x, y)
        end
        return true
      end
    end
  end

  if not self:mouse_on_top(x, y) and not self.mouse_is_pressed then
    return false
  end

  Widget.super.on_mouse_released(self, button, x, y)

  if self.mouse_is_pressed then
    self.mouse_is_pressed = false
    if self.draggable then
      system.set_cursor("arrow")
    end
  end

  self.dragged = false

  return true
end

---Click event emitted on a succesful on_mouse_pressed
---and on_mouse_released events combo.
---@param button widget.button
---@param x number
---@param y number
function Widget:on_click(button, x, y) end

---Emitted to input_text widgets when clicked.
function Widget:activate() end

---Emitted to input_text widgets on lost focus.
function Widget:deactivate() end

---Besides the on_mouse_moved this event emits on_mouse_enter
---and on_mouse_leave for easy hover effects. Also, if the
---widget is scrollable and pressed this will drag it unless
---there is an active input_text child active.
---@param x number
---@param y number
---@param dx number
---@param dy number
function Widget:on_mouse_moved(x, y, dx, dy)
  if not self.visible then return end

  -- store latest mouse coordinates for usage on the on_mouse_wheel event.
  self.mouse.x = x
  self.mouse.y = y

  if not self.dragged then
    local hovered = nil
    for _, child in pairs(self.childs) do
      if
        not hovered
        and
        (child:mouse_on_top(x, y) or child.mouse_is_pressed)
      then
        hovered = child
      elseif child.mouse_is_hovering then
        child.mouse_is_hovering = false
        if #child.tooltip > 0 then
          core.status_view:remove_tooltip()
        end
        child:on_mouse_leave(x, y, dx, dy)
        system.set_cursor("arrow")
      end
    end

    if hovered then
      hovered:on_mouse_moved(x, y, dx, dy)
      return true;
    end
  end

  if self:mouse_on_top(x, y) or self.mouse_is_pressed or not self.parent then
    Widget.super.on_mouse_moved(self, x, y, dx, dy)
    if self.dragging_scrollbar then
      self.dragged = true
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
  else
    self.mouse_is_hovering = false
    is_over = false
  end

  if not self.child_active and self.mouse_is_pressed and self.draggable then
    self:drag(x, y)
    self.dragged = true
    return true
  end

  return is_over
end

---Emitted once when the mouse hovers the widget.
function Widget:on_mouse_enter(x, y, dx, dy)
  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_enter(x, y, dx, dy)
      break
    end
  end
end

---Emitted once when the mouse leaves the widget.
function Widget:on_mouse_leave(x, y, dx, dy)
  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_leave(x, y, dx, dy)
      break
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

  Widget.super.update(self)

  if
    #self.childs > 0
    and
    (
      self.position.x ~= self.prev_position.x
      or
      self.position.y ~= self.prev_position.y
    )
  then
    self:set_position(self.position.x, self.position.y)
  end

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
    core.push_clip_rect(
      self.position.x,
      self.position.y,
      self.size.x,
      self.size.y
    )
  end

  for i=#self.childs, 1, -1 do
    self.childs[i]:draw()
  end

  if #self.childs > 0 then
    core.pop_clip_rect()
  end

  if self.scrollable then
    self:draw_scrollbar()
  end

  return true
end


return Widget
