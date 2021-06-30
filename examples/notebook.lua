--
-- NoteBook example.
--

local core = require "core"
local command = require "core.command"
local NoteBook = require "widget.notebook"
local Button = require "widget.button"
local TextBox = require "widget.textbox"
local CheckBox = require "widget.checkbox"

---@type widget.notebook
local notebook = NoteBook()
notebook.size.x = 250
notebook.size.y = 300
notebook.border.width = 0

local log = notebook:add_pane("log", "Messages")
local build = notebook:add_pane("build", "Build")
local errors = notebook:add_pane("errors", "Errors")
local other = notebook:add_pane("other", "other")

notebook:set_pane_icon("log", "i")
notebook:set_pane_icon("build", "P")
notebook:set_pane_icon("errors", "!")

---@type widget.textbox
local textbox = TextBox(log, "", "placeholder...")
textbox:set_position(10, 20)

---@type widget.checkbox
local checkbox = CheckBox(build, "Child checkbox")
checkbox:set_position(10, 20)

---@type widget.button
local button = Button(errors, "A test button")
button:set_position(10, 20)
button.on_click = function()
  system.show_fatal_error("Message", "Hello World")
end

---@type widget.checkbox
local checkbox2 = CheckBox(errors, "Child checkbox2")
checkbox2:set_position(10, button:get_bottom() + 30)

notebook:show()

-- You can add the widget as a lite node
local node = core.root_view:get_active_node()
node:split("down", notebook, {y=true}, true)

command.add(nil,{
  ["notebook-widget:toggle"] = function()
    notebook:toggle_visible()
  end
})
