--
-- Basic listbox example.
--

local core = require "core"
local style = require "core.style"
local Widget = require "widget"
local Button = require "widget.button"
local ListBox = require "widget.listbox"

---@type widget
local widget = Widget()
widget.size.x = 400
widget.size.y = 150
widget.position.x = 100
widget.draggable = true
widget.scrollable = true

widget:centered()

---@type widget.listbox
local listbox = ListBox(widget)


listbox:add_row({
  style.icon_font, style.syntax.string, "!", style.font, style.text, " Error",
  ListBox.COLEND,
  "A message."
})
listbox:add_row({
  "Good",
  ListBox.COLEND,
  "Hi!."
})
listbox:add_row({
  "More",
  ListBox.COLEND,
  "Final message."
})

listbox.on_row_click = function(self, idx, data)
  system.show_fatal_error("Clicked a row", idx)
end

listbox.update = function(self)
  ListBox.super.update(self)
  self:set_position(0, 0)
  self:set_size(self.parent:get_width() - 2, self.parent:get_height() - 2)
  self.largest_row = self.parent:get_width() - 2
end

widget:show()
