-- mod-version:1 lite-xl 1.16
--
-- Testing initialization script.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

-- if true then
--   return
-- end

local core = require "core"
local Widget = require "widgets.base"
local WidgetButton = require "widgets.button"
local WidgetCheckBox = require "widgets.checkbox"
local WidgetTextBox = require "widgets.textbox"

local function on_button_click(self)
  system.show_fatal_error("Clicked:", self.label)
end

---@type Widget
local widget = Widget()
widget.size.x = 300
widget.size.y = 300
widget.position.x = 100
widget.draggable = true

---@type WidgetButton
local button = WidgetButton(widget, "Button1")
button:set_position(10, 10)
button:set_tooltip("Description 1")
button.on_click = on_button_click

---@type WidgetButton
local button2 = WidgetButton(widget, "Button2")
button2:set_position(10, button:get_bottom() + 10)
button2:set_tooltip("Description 2")
button2.on_click = on_button_click

---@type WidgetCheckBox
local checkbox = WidgetCheckBox(widget, "Some Checkbox")
checkbox:set_position(10, button2:get_bottom() + 10)
checkbox:set_tooltip("Description checkbox")
checkbox.on_checked = function(_, checked)
  core.log_quiet(tostring(checked))
end

---@type WidgetCheckBox
local textbox = WidgetTextBox(widget, "some text")
textbox:set_position(10, checkbox:get_bottom() + 10)
textbox:set_tooltip("Texbox")

widget:show()
