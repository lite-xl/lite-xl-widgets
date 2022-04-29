--
-- Dialog object that serves as base to implement other dialogs.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local Widget = require "widget"
local Button = require "widget.button"
local Label = require "widget.label"

---@class widget.dialog : widget
---@field private title widget.label
---@field private panel widget
---@field private message widget.label
---@field private buttons widget.button[]
local Dialog = Widget:extend()

---Constructor
---@param title string
function Dialog:new(title)
  Dialog.super.new(self)

  self.draggable = true
  self.scrollable = false

  -- minimum width and height
  self.size.mx = 300
  self.size.my = 150

  self.title = Label(self, "")
  self.close = Button(self, "")
  self.close:set_icon("X")
  self.close.border.width = 0
  self.close:toggle_background(false)
  self.close.padding.x = 4
  self.close.padding.y = 0
  self.panel = Widget(self)
  self.panel.border.width = 0
  self.panel.scrollable = true

  local this = self

  function self.close:on_click()
    this:on_close()
    this:hide()
  end

  self:set_title(title or "")
end

---Returns the widget where you can add child widgets to this dialog.
---@return widget
function Dialog:get_panel()
  return self.panel
end

---Change the message box title.
---@param text string|widget.styledtext
function Dialog:set_title(text)
  self.title:set_label(text)
end

---Calculate the MessageBox size, centers it relative to screen and shows it.
function Dialog:show()
  Dialog.super.show(self)
  self:update()
  self:centered()
end

---Called when the user clicks one of the buttons in the message box.
function Dialog:on_close()
  self:hide()
end

function Dialog:update()
  if not Dialog.super.update(self) then return false end

  local width = math.max(
    self.title:get_width() + (style.padding.x * 3) + self.close:get_width(),
    self.size.mx,
    self.size.x
  )

  local height = math.max(
    self.title:get_height() + (style.padding.y * 3),
    self.size.my,
    self.size.y
  )

  self:set_size(width, height)

  self.title:set_position(
    style.padding.x / 2,
    style.padding.y / 2
  )

  self.close:set_position(
    self.size.x - self.close.size.x - (style.padding.x / 2),
    style.padding.y / 2
  )

  self.panel:set_position(
    0,
    self.title:get_bottom() + (style.padding.y / 2)
  )

  self.panel:set_size(
    self.size.x - (self.panel.border.width * 2),
    self.size.y - self.title.size.y - style.padding.y
      - (self.panel.border.width * 2)
  )

  return true
end

---We overwrite default draw function to draw the title background.
function Dialog:draw()
  if not self:is_visible() then return false end

  Dialog.super.draw(self)

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

  -- draw the title background
  renderer.draw_rect(
    self.position.x,
    self.position.y,
    self.size.x, self.title:get_height() + style.padding.y,
    style.selection
  )

  for i=#self.childs, 1, -1 do
    self.childs[i]:draw()
  end

  if #self.childs > 0 then
    core.pop_clip_rect()
  end

  return true
end


return Dialog
