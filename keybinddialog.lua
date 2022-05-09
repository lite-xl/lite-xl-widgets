--
-- KeyBinding Dialog Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local keymap = require "core.keymap"
local style = require "core.style"
local Button = require "widget.button"
local Dialog = require "widget.dialog"
local Label = require "widget.label"

---@type widget.keybinddialog
local current_dialog = nil

---@class widget.keybinddialog : widget.dialog
---@field message widget.label
---@field binding widget.label
---@field mouse_intercept widget.label
---@field save widget.button
---@field reset widget.button
---@field cancel widget.button
local KeybindDialog = Dialog:extend()

---Constructor
function KeybindDialog:new()
  KeybindDialog.super.new(self, "Keybinding Selector")

  self.message = Label(self.panel, "Press a key combination")
  self.binding = Label(self.panel, "none")
  self.binding.border.width = 1

  self.mouse_intercept = Label(self.panel, "Grab mouse events here")
  self.mouse_intercept.border.width = 1
  self.mouse_intercept.clickable = true
  self.mouse_intercept:set_size(100, 100)
  function self.mouse_intercept:on_mouse_pressed(button, x, y, clicks)
    keymap.on_mouse_pressed(button, x, y, clicks)
    return true
  end
  function self.mouse_intercept:on_mouse_wheel(y)
    keymap.on_mouse_wheel(y)
    return true
  end
  function self.mouse_intercept:on_mouse_enter(...)
    Label.super.on_mouse_enter(self, ...)
    self.border.color = style.caret
  end
  function self.mouse_intercept:on_mouse_leave(...)
    Label.super.on_mouse_leave(self, ...)
    self.border.color = style.text
  end

  local this = self

  self.save = Button(self.panel, "Save")
  self.save:set_icon("S")
  function self.save:on_click()
    this:on_save(this.binding.label)
    this:on_close()
  end

  self.reset = Button(self.panel, "Reset")
  function self.reset:on_click()
    this:on_reset()
    this:on_close()
  end

  self.cancel = Button(self.panel, "Cancel")
  self.cancel:set_icon("C")
  function self.cancel:on_click()
    this:on_close()
  end
end

---Show the dialog and enable key interceptions
function KeybindDialog:show()
  current_dialog = self
  KeybindDialog.super.show(self)
end

---Hide the dialog and disable key interceptions
function KeybindDialog:hide()
  current_dialog = nil
  KeybindDialog.super.hide(self)
end

---Called when the user clicks on save
---@param binding string
function KeybindDialog:on_save(binding) end

---Called when the user clicks on reset
function KeybindDialog:on_reset() end

function KeybindDialog:update()
  if not KeybindDialog.super.update(self) then return false end

  self.message:set_position(style.padding.x/2, 0)
  self.binding:set_position(style.padding.x/2, self.message:get_bottom() + style.padding.y)
  self.mouse_intercept:set_position(style.padding.x/2, self.binding:get_bottom() + style.padding.y)

  self.save:set_position(
    style.padding.x/2,
    self.mouse_intercept:get_bottom() + style.padding.y
  )
  self.reset:set_position(
    self.save:get_right() + style.padding.x,
    self.mouse_intercept:get_bottom() + style.padding.y
  )
  self.cancel:set_position(
    self.reset:get_right() + style.padding.x,
    self.mouse_intercept:get_bottom() + style.padding.y
  )

  self.panel.size.x = self.panel:get_real_width() + style.padding.x
  self.panel.size.y = self.panel:get_real_height()
  self.size.x = self:get_real_width() - (style.padding.x / 2)
  self.size.y = self:get_real_height() + (style.padding.y / 2)

  self.mouse_intercept:set_size(
    self.size.x - style.padding.x - (self.mouse_intercept.border.width * 2),
    self.mouse_intercept.size.y
  )

  return true
end

--------------------------------------------------------------------------------
-- Intercept keymap events
--------------------------------------------------------------------------------

-- Same declarations as in core.keymap because modkey_map is not public
local macos = PLATFORM == "Mac OS X"
local modkeys_os = require("core.modkeys-" .. (macos and "macos" or "generic"))
local modkey_map = modkeys_os.map
local modkeys = modkeys_os.keys

---Copied from core.keymap because it is not public
local function key_to_stroke(k)
  local stroke = ""
  for _, mk in ipairs(modkeys) do
    if keymap.modkeys[mk] then
      stroke = stroke .. mk .. "+"
    end
  end
  return stroke .. k
end

local keymap_on_key_pressed = keymap.on_key_pressed
function keymap.on_key_pressed(k, ...)
  if current_dialog then
    local mk = modkey_map[k]
    if mk then
      keymap.modkeys[mk] = true
      -- work-around for windows where `altgr` is treated as `ctrl+alt`
      if mk == "altgr" then
        keymap.modkeys["ctrl"] = false
      end
      current_dialog.binding:set_label(key_to_stroke(""))
    else
      current_dialog.binding:set_label(key_to_stroke(k))
    end
    return true
  else
    return keymap_on_key_pressed(k, ...)
  end
end


return KeybindDialog

