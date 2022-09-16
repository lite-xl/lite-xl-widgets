local core = require "core"
local common = require "core.common"
local Widget = require "widget"
local Button = require "widget.button"
local Label = require "widget.label"

---@class widget.filepicker : widget
---@field public pick_mode integer
---@field public filters table<integer,string>
---@field private file widget.label
---@field private textbox widget.textbox
---@field private button widget.button
local FilePicker = Widget:extend()

---Operation modes for the file picker.
FilePicker.mode = {
  ---Opens file browser the selected file does not has to exist.
  FILE = 1,
  ---Opens file browser the selected file has to exist.
  FILE_EXISTS = 2,
  ---Opens directory browser the selected directory does not has to exist.
  DIRECTORY = 4,
  ---Opens directory browser the selected directory has to exist.
  DIRECTORY_EXISTS = 8
}

local function suggest_directory(text)
  text = common.home_expand(text)
  return common.home_encode_list(common.dir_path_suggest(text))
end

local function check_directory_path(path)
  local abs_path = system.absolute_path(path)
  local info = abs_path and system.get_file_info(abs_path)
  if not info or info.type ~= 'dir' then return nil end
  return abs_path
end

---@alias widget.filepicker.modes
---| `FilePicker.mode.FILE`
---| `FilePicker.mode.FILE_EXISTS`
---| `FilePicker.mode.DIRECTORY`
---| `FilePicker.mode.DIRECTORY_EXISTS`

---Constructor
---@param parent widget
---@param path? string
function FilePicker:new(parent, path)
  FilePicker.super.new(self, parent)

  local this = self

  self.filters = {}
  self.border.width = 0
  self.pick_mode = FilePicker.mode.FILE

  self.file = Label(self, path or "")
  self.file.clickable = true
  self.file:set_border_width(1)
  function self.file:on_click(button)
    if button == "left" then
      this:show_picker()
    end
  end

  self.button = Button(self, "")
  self.button:set_icon("D")
  self.button:set_tooltip("open file browser")
  function self.button:on_click(button)
    if button == "left" then
      this:show_picker()
    end
  end

  local label_width = self.file:get_width()
  if label_width <= 10 then
    label_width = 200 + (self.file.border.width * 2)
    self.file:set_size(200, self.button:get_height() - self.button.border.width * 2)
  end

  self:set_size(
    label_width + self.button:get_width(),
    math.max(self.file:get_height(), self.button:get_height())
  )
end

function FilePicker:set_size(width, height)
  FilePicker.super.set_size(self, width, height)

  self.file:set_position(0, 0)
  self.file:set_size(
    self:get_width() - self.button:get_width(),
    self.button:get_height()
  )

  self.button:set_position(self.file:get_right(), 0)

  self.size.y = self.button:get_height()
end

function FilePicker:add_filter(pattern)
  table.insert(self.filters, pattern)
end

function FilePicker:clear_filters()
  self.filters = {}
end

---@param mode widget.filepicker.modes | string
function FilePicker:set_mode(mode)
  if type(mode) == "string" then
    ---@type integer
    local intmode = FilePicker.mode[mode:upper()]
    self.pick_mode = intmode
  else
    self.pick_mode = mode
  end
end

---Set the full path including directory and filename.
---@param path string
function FilePicker:set_path(path)
  self.file.label = path or ""
end

---Get the full path including directory and filename.
---@return string | nil
function FilePicker:get_path()
  if self.file.label ~= "" then
    return self.file.label
  end
  return nil
end

---Set the filename part only.
---@param name string
function FilePicker:set_filename(name)
  local dir_part = common.dirname(self.file.label)
  if dir_part then
    self.file.label = dir_part .. "/" .. name
  else
    self.file.label = name
  end
end

---Get the filename part only.
---@return string | nil
function FilePicker:get_filename()
  local dir_part = common.dirname(self.file.label)
  if dir_part then
    local filename = self.file.label:gsub(dir_part .. "/", "", 1)
    return filename
  elseif self.file.label ~= "" then
    return self.file.label
  end
  return nil
end

---Set the directory part only.
---@param dir string
function FilePicker:set_directory(dir)
  local filename = self:get_filename()
  if filename then
    self.file.label = dir:gsub("[\\/]$", "") .. "/" .. filename
  else
    self.file.label = dir:gsub("[\\/]$", "")
  end
end

---Get the directory part only.
---@return string | nil
function FilePicker:get_directory()
  if self.file.label ~= "" then
    local dir_part = common.dirname(self.file.label)
    if dir_part then return dir_part end
  end
  return nil
end

---Filter a list of directories by applying currently set filters.
---@param list table<integer, string>
---@return table<integer,string>
function FilePicker:filter(list)
  if #self.filters > 0 then
    local new_list = {}
    for _, value in ipairs(list) do
      if common.match_pattern(value, self.filters) then
        table.insert(new_list, value)
      elseif
        (self.pick_mode & FilePicker.mode.FILE) > 0
        or
        (self.pick_mode & FilePicker.mode.FILE_EXISTS) > 0
      then
        local path = common.home_expand(value)
        local abs_path = check_directory_path(path)
        if abs_path then
          table.insert(new_list, value)
        end
      end
    end
    return new_list
  end
  return list
end

---@param self widget.filepicker
local function show_file_picker(self)
  core.command_view:enter("Choose File", {
    text = self.file.label,
    submit = function(text)
      local filename = system.absolute_path(common.home_expand(text))
      self.file:set_label(filename or text)
      self:on_change(filename or (text ~= "" and text or nil))
    end,
    suggest = function (text)
      return self:filter(
        common.home_encode_list(common.path_suggest(common.home_expand(text)))
      )
    end,
    validate = function(text)
      if #self.filters > 0 and text ~= "" and not common.match_pattern(text, self.filters) then
        core.error(
          "File does not match the filters: %s",
          table.concat(self.filters, ", ")
        )
        return false
      end
      local filename = common.home_expand(text)
      local path_stat, err = system.get_file_info(filename)
      if path_stat and path_stat.type == 'dir' then
        core.error("Cannot open %s, is a folder", text)
        return false
      end
      if (self.pick_mode & FilePicker.mode.FILE_EXISTS) > 0 then
        if not path_stat then
          core.error("Cannot open file %s: %s", text, err)
          return false
        end
      else
        local dirname = common.dirname(filename)
        local dir_stat = dirname and system.get_file_info(dirname)
        if dirname and not dir_stat then
          core.error("Directory does not exists: %s", dirname)
          return false
        end
      end
      return true
    end,
  })
end

---@param self widget.filepicker
local function show_dir_picker(self)
  local current = self.file.label
  core.command_view:enter("Choose Directory", {
    text = current,
    submit = function(text)
      local path = common.home_expand(text)
      local abs_path = check_directory_path(path)
      self.file:set_label(abs_path or text)
      self:on_change(abs_path or (text ~= "" and text or nil))
    end,
    suggest = function(text)
      return self:filter(suggest_directory(text))
    end,
    validate = function(text)
      if #self.filters > 0 and text ~= "" and not common.match_pattern(text, self.filters) then
        core.error(
          "Directory does not match the filters: %s",
          table.concat(self.filters, ", ")
        )
        return false
      end
      if (self.pick_mode & FilePicker.mode.DIRECTORY_EXISTS) > 0 then
        local path = common.home_expand(text)
        local abs_path = check_directory_path(path)
        if not abs_path then
          core.error("Cannot open directory %q", path)
          return false
        end
      end
      return true
    end
  })
end

function FilePicker:show_picker()
  if
    (self.pick_mode & FilePicker.mode.FILE) > 0
    or
    (self.pick_mode & FilePicker.mode.FILE_EXISTS) > 0
  then
    show_file_picker(self)
  else
    show_dir_picker(self)
  end
end

function FilePicker:update()
  if not FilePicker.super.update(self) then return false end

  if self:get_width() ~= (self.file:get_width() + self.button:get_width()) then
    self:set_size(
      self.file:get_width() + self.button:get_width(),
      self.button:get_height()
    )
  end

  return true
end


return FilePicker
