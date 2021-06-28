--
-- TextBox widget re-using code from lite's DocView.
--
local core = require "core"
local config = require "core.config"
local style = require "core.style"
local Doc = require "core.doc"
local DocView = require "core.docview"
local View = require "core.view"
local Widget = require "widget"


---@class SingleLineDoc
local SingleLineDoc = Doc:extend()

function SingleLineDoc:insert(line, col, text)
  text = text:gsub("\n", "")
  SingleLineDoc.super.insert(self, line, col, text)
end

---@class TextView
local TextView = DocView:extend()

function TextView:new()
  TextView.super.new(self, SingleLineDoc())
  self.last_change_id = 0
  self.gutter_width = style.padding.x / 2
  self.hide_lines_gutter = true
  self.gutter_text_brightness = 0
  self.scrollable = true
  self.font = "font"
end

function TextView:get_name()
  return View.get_name(self)
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

function TextView:update()
  -- scroll to make caret visible and reset blink timer if it moved
  local line, col = self.doc:get_selection()
  if (line ~= self.last_line or col ~= self.last_col) and self.size.x > 0 then
    self:scroll_to_make_visible(line, col)
    core.blink_reset()
    self.last_line, self.last_col = line, col
  end

  -- update blink timer
  local T, t0 = config.blink_period, core.blink_start
  local ta, tb = core.blink_timer, system.get_time()
  if ((tb - t0) % T < T / 2) ~= ((ta - t0) % T < T / 2) then
    core.redraw = true
  end
  core.blink_timer = tb

  DocView.super.update(self)
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

function TextView:draw_line_body(idx, x, y)
  -- draw selection if it overlaps this line
  for lidx, line1, col1, line2, col2 in self.doc:get_selections(true) do
    if idx >= line1 and idx <= line2 then
      local text = self.doc.lines[idx]
      if line1 ~= idx then col1 = 1 end
      if line2 ~= idx then col2 = #text + 1 end
      local x1 = x + self:get_col_x_offset(idx, col1)
      local x2 = x + self:get_col_x_offset(idx, col2)
      local lh = self:get_line_height()
      renderer.draw_rect(x1, y, x2 - x1, lh, style.selection)
    end
  end
  for lidx, line1, col1, line2, col2 in self.doc:get_selections(true) do
    -- draw line highlight if caret is on this line
    if config.highlight_current_line and (line1 == line2 and col1 == col2)
    and line1 == idx then
      self:draw_line_highlight(x + self.scroll.x, y)
    end
  end

  -- draw line's text
  self:draw_line_text(idx, x, y)
end

function TextView:draw_overlay()
  local minline, maxline = self:get_visible_line_range()
  -- draw caret if it overlaps this line
  local T = config.blink_period
  for _, line, col in self.doc:get_selections() do
    if line >= minline and line <= maxline
    and (core.blink_timer - core.blink_start) % T < T / 2
    and system.window_has_focus() then
      local x, y = self:get_line_screen_position(line)
      self:draw_caret(x + self:get_col_x_offset(line, col), y)
    end
  end
end

function TextView:draw()
  self:draw_background(style.background)

  self:get_font():set_tab_size(config.indent_size)

  local minline, maxline = self:get_visible_line_range()
  local lh = self:get_line_height()

  local x, y = self:get_line_screen_position(minline)
  for i = minline, maxline do
    self:draw_line_gutter(i, self.position.x, y)
    y = y + lh
  end

  local gw = self:get_gutter_width()
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
---@field public textview TextView
local TextBox = Widget:extend()

function TextBox:new(parent, text)
  TextBox.super.new(self, parent)
  self.textview = TextView()
  self.size.x = 200 + (style.padding.x * 2)
  self.size.y = self.font:get_height() + (style.padding.y * 2)

  -- this widget is for text input
  self.input_text = true

  self:set_text(text or "")
end

--- Get the text displayed on the textbox.
---@return string
function TextBox:get_text()
  return self.textview:get_text()
end

--- Set the text displayed on the textbox.
---@param text string
---@param select boolean
function TextBox:set_text(text, select)
  self.textview:set_text(text, select)
end

--
-- Events
--

function TextBox:on_mouse_pressed(button, x, y, clicks)
  TextBox.super.on_mouse_pressed(self, button, x, y, clicks)
  self.textview:on_mouse_pressed(button, x, y, clicks)
end

function TextBox:on_mouse_released(button, x, y)
  TextBox.super.on_mouse_released(self, button, x, y)
  self.textview:on_mouse_released(button, x, y)
end

function TextBox:on_mouse_moved(x, y, dx, dy)
  TextBox.super.on_mouse_moved(self, x, y, dx, dy)
  self.textview:on_mouse_moved(x, y, dx, dy)
end

function TextBox:activate()
  self.border.color = style.caret
end

function TextBox:deactivate()
  self.border.color = style.text
end

function TextBox:on_text_input(text)
  TextBox.super.on_text_input(self, text)
  self.textview:on_text_input(text)
end

function TextBox:update()
  TextBox.super.update(self)
  self.textview:update()
  self.size.y = self.font:get_height() + (style.padding.y * 2)
end

function TextBox:draw()
  TextBox.super.draw(self)
  self.textview.position.x = self.position.x
  self.textview.position.y = self.position.y - (style.padding.y/2.5)
  self.textview.size.x = self.size.x
  self.textview.size.y = self.size.y - (style.padding.y * 2)

  renderer.set_clip_rect(
    self.position.x,
    self.position.y,
    self.size.x,
    self.size.y
  )
  self.textview:draw()
  if self.parent then
    renderer.set_clip_rect(
      self.parent.position.x,
      self.parent.position.y,
      self.parent.size.x,
      self.parent.size.y
    )
  else
    local w, h = system.get_window_size()
    renderer.set_clip_rect(0, 0, w, h)
  end
end


return TextBox

