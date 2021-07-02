--
-- NoteBook example.
--

local core = require "core"
local command = require "core.command"
local style = require "core.style"
local NoteBook = require "widget.notebook"
local Button = require "widget.button"
local TextBox = require "widget.textbox"
local CheckBox = require "widget.checkbox"
local ListBox = require "widget.listbox"

---@type widget.notebook
local notebook = NoteBook()
notebook.size.x = 250
notebook.size.y = 300
notebook.border.width = 0

local log = notebook:add_pane("log", "Messages")
local build = notebook:add_pane("build", "Build")
local errors = notebook:add_pane("errors", "Errors")
local diagnostics = notebook:add_pane("diagnostics", "Diagnostics")

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

---@type widget.listbox
diagnostics.scrollable = false

local listbox = ListBox(diagnostics)
listbox.border.width = 0
listbox:enable_expand(true)

listbox:add_column("Severity")
listbox:add_column("Message")

listbox:add_row({
  style.icon_font, style.syntax.string, "!", style.font, style.text, " Error",
  ListBox.COLEND,
  "A message to display to the user."
})
listbox:add_row({
  style.icon_font, style.syntax.string, "!", style.font, style.text, " Error",
  ListBox.COLEND,
  "Another message to display to the user\nwith new line characters\nfor the win."
})
for num=1, 1000 do
  listbox:add_row({
    style.icon_font, style.syntax.string, "!", style.font, style.text, " Error",
    ListBox.COLEND,
    tostring(num),
    " Another message to display to the user\nwith new line characters\nfor the win."
  }, num)
end
listbox:add_row({
  style.icon_font, style.syntax.string, "!", style.font, style.text, " Error",
  ListBox.COLEND,
  "Final message to display."
})

listbox.on_row_click = function(self, idx, data)
  if data then
    system.show_fatal_error("Row Data", data)
  end
  self:remove_row(idx)
end

notebook:show()

-- You can add the widget as a lite node
local node = core.root_view:get_active_node()
node:split("down", notebook, {y=true}, true)

command.add(nil,{
  ["notebook-widget:toggle"] = function()
    notebook:toggle_visible()
  end
})
