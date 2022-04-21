--
-- TextBox widget re-using code from lite's DocView.
--

local core = require "core"
local config = require "core.config"
local command = require "core.command"
local style = require "core.style"
local Doc = require "core.doc"
local DocView = require "core.docview"
local View = require "core.view"
local Widget = require "widget"


---@class widget.textbox.SingleLineDoc
local SingleLineDoc = Doc:extend()

function SingleLineDoc:insert(line, col, text)
  SingleLineDoc.super.insert(self, line, col, text:gsub("\n", ""))
end

---@class widget.textbox.TextView
local TextView = DocView:extend()

function TextView:new()
  TextView.super.new(self, SingleLineDoc())
  self.gutter_width = 0
  self.hide_lines_gutter = true
  self.gutter_text_brightness = 0
  self.scrollable = true
  self.font = "font"
  self.name = View.get_name(self)

  self.size.y = 0
  self.label = ""
end

function TextView:get_name()
  return self.name
end

function TextView:get_scrollable_size()
  return 0
end

function TextView:scroll_to_make_visible()
  -- no-op function to disable this functionality
end

function TextView:get_text()
  return self.doc:get_text(1, 1, 1, math.huge)
end

function TextView:set_text(text, select)
  self.doc:remove(1, 1, math.huge, math.huge)
  self.doc:text_input(text)
  if select then
    self.doc:set_selection(math.huge, math.huge, 1, 1)
  end
end

function TextView:get_gutter_width()
  return self.gutter_width
end

function TextView:draw_line_gutter(idx, x, y)
  if self.hide_lines_gutter then
    return
  end
  TextView.super.draw_line_gutter(self, idx, x, y)
end

function TextView:draw_line_highlight()
  -- no-op function to disable this functionality
end

-- Overwrite this function just to disable the core.push_clip_rect
function TextView:draw()
  self:draw_background(style.background)
  local _, indent_size = self.doc:get_indent_info()
  self:get_font():set_tab_size(indent_size)

  local minline, maxline = self:get_visible_line_range()
  local lh = self:get_line_height()

  local x, y = self:get_line_screen_position(minline)
  local gw, gpad = self:get_gutter_width()
  for i = minline, maxline do
    self:draw_line_gutter(i, self.position.x, y, gpad and gw - gpad or gw)
    y = y + lh
  end

  local pos = self.position
  x, y = self:get_line_screen_position(minline)
  for i = minline, maxline do
    self:draw_line_body(i, x, y)
    y = y + lh
  end
  self:draw_overlay()

  self:draw_scrollbar()
end

---@class widget.textbox : widget
---@field public textview widget.textbox.TextView
---@field public placeholder string
---@field private placeholder_active string
local TextBox = Widget:extend()

function TextBox:new(parent, text, placeholder)
  TextBox.super.new(self, parent)
  self.textview = TextView()
  self.textview.name = parent.name
  self.size.x = 200 + (style.padding.x * 2)
  self.textview.size.x = self.size.x
  self.size.y = self.font:get_height() + (style.padding.y * 2)
  self.placeholder = placeholder or ""
  self.placeholder_active = false
  -- this widget is for text input
  self.input_text = true
  self.cursor = "ibeam"
  self.active = false

  if text ~= "" then
    self.textview:set_text(text, select)
  else
    self.placeholder_active = true
    self.textview:set_text(self.placeholder)
  end

  local this = self

  function self.textview.doc:on_text_change(type)
    this:on_change(this:get_text())
  end

  -- more granular listening of text changing events
  local doc_raw_insert = self.textview.doc.raw_insert
  function self.textview.doc:raw_insert(...)
    doc_raw_insert(self, ...)
    this:on_text_change("insert", ...)
  end

  local doc_raw_remove = self.textview.doc.raw_remove
  function self.textview.doc:raw_remove(...)
    doc_raw_remove(self, ...)
    this:on_text_change("remove", ...)
  end
end

---@param width integer
---@param height integer Ignored on the textbox
function TextBox:set_size(width, height)
  TextBox.super.set_size(
    self,
    width,
    self.font:get_height() + (style.padding.y * 2)
  )
  self.textview.size.x = self.size.x
end

--- Get the text displayed on the textbox.
---@return string
function TextBox:get_text()
  if self.placeholder_active then
    return ""
  end
  return self.textview:get_text()
end

--- Set the text displayed on the textbox.
---@param text string
---@param select boolean
function TextBox:set_text(text, select)
  self.textview:set_text(text, select)
  self:on_change(text)
end

--
-- Events
--

function TextBox:on_mouse_pressed(button, x, y, clicks)
  if TextBox.super.on_mouse_pressed(self, button, x, y, clicks) then
    self.textview:on_mouse_pressed(button, x, y, clicks)
    command.perform("doc:set-cursor", x, y)
    if core.active_view ~= self.textview then
      self.textview:on_mouse_released(button, x, y)
    end
    return true
  end
  return false
end

function TextBox:on_mouse_released(button, x, y)
  if TextBox.super.on_mouse_released(self, button, x, y) then
    self.textview:on_mouse_released(button, x, y)
    return true
  end
  return false
end

function TextBox:on_mouse_moved(x, y, dx, dy)
  if TextBox.super.on_mouse_moved(self, x, y, dx, dy) then
    if self.active or core.active_view == self.textview then
      self.textview:on_mouse_moved(x, y, dx, dy)
      system.set_cursor("ibeam")
    end
    return true
  end
  return false
end

function TextBox:activate()
  self.hover_border = style.caret
  if self.placeholder_active then
    self:set_text("")
    self.placeholder_active = false
  end
  self.active = true
  system.set_cursor("ibeam")
end

function TextBox:deactivate()
  self.hover_border = nil
  if self:get_text() == "" then
    self:set_text(self.placeholder)
    self.placeholder_active = true
  end
  self.active = false
  system.set_cursor("arrow")
end

function TextBox:on_text_input(text)
  TextBox.super.on_text_input(self, text)
  self.textview:on_text_input(text)
  self:on_change(self:get_text())
end

---Event fired on any text change event.
---@param action string Can be "insert" or "remove",
---insert arguments (see Doc:raw_insert):
---  line, col, text, undo_stack, time
---remove arguments (see Doc:raw_remove):
---  line1, col1, line2, col2, undo_stack, time
function TextBox:on_text_change(action, ...) end

function TextBox:update()
  if not TextBox.super.update(self) then return false end

  self.textview:update()
  self.size.y = self.font:get_height() + (style.padding.y * 2)

  return true
end

function TextBox:draw()
  if not self:is_visible() then return false end

  self.border.color = self.hover_border or style.text
  TextBox.super.draw(self)
  self.textview.position.x = self.position.x + (style.padding.x / 2)
  self.textview.position.y = self.position.y - (style.padding.y/2.5)
  self.textview.size.x = self.size.x
  self.textview.size.y = self.size.y - (style.padding.y * 2)

  core.push_clip_rect(
    self.position.x,
    self.position.y,
    self.size.x,
    self.size.y
  )
  self.textview:draw()
  core.pop_clip_rect()

  return true
end


return TextBox

