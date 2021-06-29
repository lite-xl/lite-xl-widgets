--
-- Testing and example script.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local Widget = require "widget"
local Button = require "widget.button"
local CheckBox = require "widget.checkbox"
local Line = require "widget.line"
local Label = require "widget.label"
local TextBox = require "widget.textbox"

local function on_button_click(self)
  system.show_fatal_error("Clicked:", self.label)
end

---@type widget
local widget = Widget()
widget.size.x = 250
widget.size.y = 300
widget.position.x = 100
widget.draggable = true
widget.scrollable = true

---@type widget.label
local label = Label(widget, "Find and Replace")
label:set_position(10, 10)

---@type widget.line
local line = Line(widget)
line:set_position(0, label:get_bottom() + 10)

---@type widget.textbox
local findtext = TextBox(widget, "", "search...")
findtext:set_position(10, line:get_bottom() + 10)
findtext:set_tooltip("Text to search")

---@type widget.textbox
local replacetext = TextBox(widget, "", "replace...")
replacetext:set_position(10, findtext:get_bottom() + 10)
replacetext:set_tooltip("Text to replace")

---@type widget.button
local findprev = Button(widget, "Find Prev")
findprev:set_position(10, replacetext:get_bottom() + 10)
findprev:set_tooltip("Find backwards")

---@type widget.button
local findnext = Button(widget, "Find Next")
findnext:set_position(findprev:get_right() + 5, replacetext:get_bottom() + 10)
findnext:set_tooltip("Find forward")

---@type widget.button
local replace = Button(widget, "Replace All")
replace:set_position(10, findnext:get_bottom() + 10)
replace:set_tooltip("Replace all matching results")

---@type widget.line
local line_options = Line(widget)
line_options:set_position(0, replace:get_bottom() + 10)

---@type widget.checkbox
local insensitive = CheckBox(widget, "Insensitive")
insensitive:set_position(10, line_options:get_bottom() + 10)
insensitive:set_tooltip("Case insensitive search")
insensitive.on_checked = function(_, checked)
  core.log_quiet(tostring(checked))
end

---@type widget.checkbox
local regex = CheckBox(widget, "Regex")
regex:set_position(10, insensitive:get_bottom() + 10)
regex:set_tooltip("Treat search text as a regular expression")
regex.on_checked = function(_, checked)
  core.log_quiet(tostring(checked))
end

-- reposition items on scale changes
widget.update = function(self)
  if Widget.update(self) then
    label:set_position(10, 10)
    line:set_position(0, label:get_bottom() + 10)
    findtext:set_position(10, line:get_bottom() + 10)
    findtext.size.x = self.size.x - 20
    replacetext:set_position(10, findtext:get_bottom() + 10)
    replacetext.size.x = self.size.x - 20
    findprev:set_position(10, replacetext:get_bottom() + 10)
    findnext:set_position(findprev:get_right() + 5, replacetext:get_bottom() + 10)
    replace:set_position(10, findnext:get_bottom() + 10)
    line_options:set_position(0, replace:get_bottom() + 10)
    insensitive:set_position(10, line_options:get_bottom() + 10)
    regex:set_position(10, insensitive:get_bottom() + 10)
  end
end

widget:show()

-- You can also add the widget as a lite node
widget.border.width = 0
widget.draggable = false
widget.target_size = 250
local node = core.root_view:get_active_node()
node:split("right", widget, {x=true}, true)
