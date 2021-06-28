--
-- Base widget implementation for lite.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local command = require "core.command"
local translate = require "core.doc.translate"
local keymap = require "core.keymap"
local View = require "core.view"
local RootView = require "core.rootview"

---
---Represents the border property of a widget.
---@class WidgetBorder
---@field public width number
---@field public color RendererColor
local WidgetBorder = {}

---
---Represents the border property of a widget.
---@class WidgetPosition
---@field public x number
---@field public y number
---@field public rx number
---@field public ry number
---@field public dx number
---@field public dy number
local WidgetPosition = {}

---A base widget
---@class Widget @global
---@field public super Widget
---@field public parent Widget
---@field public position WidgetPosition
---@field public size WidgetPosition
---@field public childs table<integer,Widget>
---@field public child_active Widget
---@field public zindex integer
---@field public border WidgetBorder
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
---@field private mouse_is_pressed boolean
---@field private mouse_is_hovering boolean
local Widget = View:extend()

local active_text_input = nil
local active_text_view = nil

function Widget:new(parent)
  Widget.super.new(self)

  self.parent = parent
  self.childs = {}
  self.child_active = nil
  self.zindex = 0
  self.border = {
    width = 1,
    color = style.text
  }
  self.foreground_color = style.text
  self.background_color = parent and style.background or style.background2
  self.visible = parent and true or false
  self.has_focus = false
  self.draggable = false
  self.dragged = false
  self.font = style.font
  self.tooltip = ""
  self.label = ""
  self.input_text = false

  self.mouse_is_pressed = false
  self.mouse_is_hovering = false

  self:set_position(0, 0)

  if parent then
    parent:add_child(self)
  else
    local this = self
    local root_view_on_mouse_pressed = RootView.on_mouse_pressed
    local root_view_on_mouse_released = RootView.on_mouse_released
    local root_view_on_mouse_moved = RootView.on_mouse_moved
    local root_view_on_mouse_wheel = RootView.on_mouse_wheel
    local root_view_update = RootView.update
    local root_view_draw = RootView.draw
    local root_view_on_text_input = RootView.on_text_input

    function RootView:on_mouse_pressed(...)
      if not this:on_mouse_pressed(...) then
        root_view_on_mouse_pressed(self, ...)
      end
    end

    function RootView:on_mouse_released(...)
      if not this:on_mouse_released(...) then
        root_view_on_mouse_released(self, ...)
      end
    end

    function RootView:on_mouse_moved(...)
      if not this:on_mouse_moved(...) then
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
---@param child Widget
function Widget:add_child(child)
  table.insert(self.childs, child)
  table.sort(self.childs, function(t1, t2) return t1.zindex < t2.zindex end)
end

function Widget:show() self.visible = true end

function Widget:hide() self.visible = false end

function Widget:draw_border(x, y, w, h)
  x = x or self.position.x
  y = y or self.position.y
  w = w or self.size.x
  h = h or self.size.y

  x = x - self.border.width
  y = y - self.border.width
  w = w + (self.border.width * 2)
  h = h + (self.border.width * 2)

  renderer.draw_rect(x, y, w + x % 1, h + y % 1, self.border.color)
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
---@return WidgetPosition
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
    self.mouse_is_pressed = true
    if self.draggable then
      self.position.dx = x - self.position.x
      self.position.dy = y - self.position.y
      system.set_cursor("hand")
    end
  else
    return false
  end

  Widget.super.on_mouse_pressed(self, button, x, y, clicks)

  for _, child in pairs(self.childs) do
    child:on_mouse_pressed(button, x, y, clicks)
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

  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) or child.mouse_is_pressed then
      child:on_mouse_released(button, x, y)
      if not self.dragged then
        if child.input_text then
          self:swap_active_child(child)
        end
        child:on_click(button, x, y)
      end
    end
  end

  self.dragged = false

  return true
end

function Widget:swap_active_child(child)
  if self.child_active then
    self.child_active:deactivate()
  end

  self.child_active = child

  if child then
    self.child_active:activate()
    active_text_view = child.textview
    core.set_active_view(child.textview)
    active_text_input = child.textview.doc
  else
    active_text_view = nil
    active_text_input = nil
  end
end

function Widget:on_click(button, x, y) end

function Widget:activate() end

function Widget:deactivate() end

function Widget:on_mouse_moved(x, y, dx, dy)
  if not self.visible then return false end

  local is_over = true

  if self:mouse_on_top(x, y) then
    if not self.mouse_is_hovering  then
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

  Widget.super.on_mouse_moved(self, x, y, dx, dy)

  if self.mouse_is_pressed and self.draggable then
    self:drag(x, y)
    self.dragged = true
    return true
  end

  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) or child.mouse_is_hovering then
      child:on_mouse_moved(x, y, dx, dy)
    end
  end

  return is_over
end

function Widget:on_mouse_enter(x, y, dx, dy)
  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_enter(x, y, dx, dy)
    end
  end
end

function Widget:on_mouse_leave(x, y, dx, dy)
  for _, child in pairs(self.childs) do
    if child:mouse_on_top(x, y) then
      child:on_mouse_leave(x, y, dx, dy)
    end
  end
end

function Widget:on_mouse_wheel(y)
  if not self.visible then return end

  Widget.super.on_mouse_wheel(self.parent or self, y)

  for _, child in pairs(self.childs) do
    child:on_mouse_wheel(y)
  end

  return false
end

function Widget:update()
  if not self.visible then return end

  Widget.super.update(self.parent or self)

  for _, child in pairs(self.childs) do
    child:update()
  end
end

function Widget:draw()
  if not self.visible then return end

  Widget.super.draw(self)

  self:draw_border()
  self:draw_background(self.background_color)

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
end

local function dv()
  return active_text_view
end

local function doc()
  return active_text_input
end

local function cut_or_copy(delete)
  local full_text = ""
  for idx, line1, col1, line2, col2 in doc():get_selections() do
    if line1 ~= line2 or col1 ~= col2 then
      local text = doc():get_text(line1, col1, line2, col2)
      if delete then
        doc():delete_to_cursor(idx, 0)
      end
      full_text = full_text == "" and text or (full_text .. "\n" .. text)
      doc().cursor_clipboard[idx] = text
    else
      doc().cursor_clipboard[idx] = ""
    end
  end
  system.set_clipboard(full_text)
end

-- command.add(doc, {
--   ["widget:move-to-previous-char"] = function()
--     for idx, line1, col1, line2, col2 in doc():get_selections(true) do
--       if line1 ~= line2 or col1 ~= col2 then
--         doc():set_selections(idx, line1, col1)
--       end
--     end
--     doc():move_to(translate.previous_char)
--   end,

--   ["widget:move-to-next-char"] = function()
--     for idx, line1, col1, line2, col2 in doc():get_selections(true) do
--       if line1 ~= line2 or col1 ~= col2 then
--         doc():set_selections(idx, line2, col2)
--       end
--     end
--     doc():move_to(translate.next_char)
--   end,

--   ["widtget:select-to-previous-char"] = function()
--     doc():select_to(translate.previous_char, dv())
--   end,

--   ["widtget:select-to-next-char"] = function()
--     doc():select_to(translate.next_car, dv())
--   end,

--   ["widget:delete"] = function()
--     for idx, line1, col1, line2, col2 in doc():get_selections() do
--       if line1 == line2 and col1 == col2 and doc().lines[line1]:find("^%s*$", col1) then
--         doc():remove(line1, col1, line1, math.huge)
--       end
--       doc():delete_to_cursor(idx, translate.next_char)
--     end
--   end,

--   ["widget:backspace"] = function()
--     for idx, line1, col1, line2, col2 in doc():get_selections() do
--       if line1 == line2 and col1 == col2 then
--         local text = doc():get_text(line1, 1, line1, col1)
--         doc():delete_to_cursor(idx, 0, -1)
--         return
--       end
--       doc():delete_to_cursor(idx, translate.previous_char)
--     end
--   end,

--   ["widget:enter"] = function()
--     return
--   end,

--   ["widget:select-all"] = function()
--     doc():set_selection(1, 1, math.huge, math.huge)
--   end,

--   ["widget:undo"] = function()
--     doc():undo()
--   end,

--   ["widget:redo"] = function()
--     doc():redo()
--   end,

--   ["widget:cut"] = function()
--     cut_or_copy(true)
--   end,

--   ["widget:copy"] = function()
--     cut_or_copy(false)
--   end,

--   ["widget:paste"] = function()
--     for idx, line1, col1, line2, col2 in doc():get_selections() do
--       local value = doc().cursor_clipboard[idx] or system.get_clipboard()
--       doc():text_input(value:gsub("\r", ""), idx)
--     end
--   end,

-- })

-- keymap.add {
--   ["left"]        =    "widget:move-to-previous-char",
--   ["right"]       =    "widget:move-to-next-char",
--   ["enter"]       =    "widget:enter",
--   ["shift+left"]  =    "widget:select-to-previous-char",
--   ["shift+right"] =    "widget:select-to-next-char",
--   ["delete"]      =    "widget:delete",
--   ["backspace"]   =    "widget:backspace",
--   ["ctrl+a"]      =    "widget:select-all",
--   ["ctrl+z"]      =    "widget:undo",
--   ["ctrl+y"]      =    "widget:redo",
--   ["ctrl+x"]      =    "widget:cut",
--   ["ctrl+c"]      =    "widget:copy",
--   ["ctrl+v"]      =    "widget:paste",
-- }

return Widget
