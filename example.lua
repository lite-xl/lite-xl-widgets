--
-- Testing and example script.
-- @copyright Jefferson Gonzalez
-- @license MIT
--
local core = require "core"
local Widget = require "widget"
local Button = require "widget.button"
local CheckBox = require "widget.checkbox"
local TextBox = require "widget.textbox"

local function on_button_click(self)
  system.show_fatal_error("Clicked:", self.label)
end

---@type widget
local widget = Widget()
widget.size.x = 300
widget.size.y = 300
widget.position.x = 100
widget.draggable = true

---@type widget.button
local button = Button(widget, "Button1")
button:set_position(10, 10)
button:set_tooltip("Description 1")
button.on_click = on_button_click

---@type widget.button
local button2 = Button(widget, "Button2")
button2:set_position(10, button:get_bottom() + 10)
button2:set_tooltip("Description 2")
button2.on_click = on_button_click

---@type widget.button
local button3 = Button(widget, "Button2")
button3:set_position(button:get_right() + 10, 10)
button3:set_tooltip("Description 2")
button3.on_click = on_button_click

---@type widget.checkbox
local checkbox = CheckBox(widget, "Some Checkbox")
checkbox:set_position(10, button2:get_bottom() + 10)
checkbox:set_tooltip("Description checkbox")
checkbox.on_checked = function(_, checked)
  core.log_quiet(tostring(checked))
end

---@type widget.textbox
local textbox = TextBox(widget, "some text")
textbox:set_position(10, checkbox:get_bottom() + 10)
textbox:set_tooltip("Texbox")

-- reposition items on scale changes
widget.update = function(self)
  if Widget.update(self) then
    button2:set_position(10, button:get_bottom() + 10)
    button3:set_position(button:get_right() + 10, 10)
    checkbox:set_position(10, button2:get_bottom() + 10)
    textbox:set_position(10, checkbox:get_bottom() + 10)
  end
end

widget:show()
