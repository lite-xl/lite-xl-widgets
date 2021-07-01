--
-- ListBox Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local style = require "core.style"
local Widget = require "widget"

---@class widget.listbox.column
---@field public name string
---@field public width string
---@field public expand boolean
local ListBoxColumn = {}

---@alias widget.listbox.row table<integer, renderer.font|renderer.color|integer|string>

---@alias widget.listbox.colpos table<integer,integer>

---@class widget.listbox : widget
---@field private rows widget.listbox.row[]
---@field private row_data any
---@field private columns widget.listbox.column[]
---@field private positions widget.listbox.colpos[]
---@field private mouse widget.position
---@field private selected_row integer
---@field private largest_row integer
---@field private expand boolean
local ListBox = Widget:extend()

---Indicates on a widget.listbox.row that the end
---of a column was reached.
---@type integer
ListBox.COLEND = 1

---Indicates on a widget.listbox.row that a new line
---follows while still rendering the same column.
---@type integer
ListBox.NEWLINE = 2

---Constructor
---@param parent widget
function ListBox:new(parent)
  ListBox.super.new(self, parent)
  self.rows = {}
  self.row_data = {}
  self.columns = {}
  self.positions = {}
  self.mouse = {x = 0, y = 0}
  self.selected_row = 0
  self.largest_row = 0
  self.expand = false

  self:set_size(200, style.font:get_height() + (style.padding.y / 2))
end

---If no width is given column will be set to automatically
---expand depending on the longest element
---@param name string
---@param width? number
---@param expand? boolean
function ListBox:add_column(name, width, expand)
  local column = {
    name = name,
    width = width or style.font:get_width(name),
    expand = width and false or true
  }

  table.insert(self.columns, column)
end

---You can give it a table a la statusview style where you pass elements
---like fonts, colors, ListBox.COLEND, ListBox.NEWLINE and multiline strings.
---@param row widget.listbox.row
---@param data any Associated with the row and given to on_row_click()
function ListBox:add_row(row, data)
  table.insert(self.rows, row)
  table.insert(self.positions, self:get_col_positions(row))

  if data then
    self.row_data[#self.rows] = data
  end

  -- increase columns width if needed
  if #self.columns > 0 then
    local ridx = #self.rows
    for col, pos in ipairs(self.positions[ridx]) do
      if self.columns[col].expand then
        local w = self:draw_row_range(row, pos[1], pos[2], 1, 1, true)
        self.columns[col].width = math.max(self.columns[col].width, w)
      end
    end
  end
end

-- Solution to safely remove elements from array table:
-- found at https://stackoverflow.com/a/53038524
local function array_remove(t, fnKeep)
  local j, n = 1, #t;

  for i=1, n do
    if (fnKeep(t, i, j)) then
      if (i ~= j) then
        t[j] = t[i];
        t[i] = nil;
      end
      j = j + 1;
    else
      t[i] = nil;
    end
  end

  return t;
end

---Remove a given row index from the list.
---@param ridx integer
function ListBox:remove_row(ridx)
  array_remove(self.rows, function(_, i, _)
    if i == ridx then
      return false
    end
    return true
  end)
end

---Get the starting and ending position of columns in a row table.
---@param row widget.listbox.row
---@return widget.listbox.colpos
function ListBox:get_col_positions(row)
  local positions = {}
  local idx = 1
  local idx_start = 1
  local row_len = #row

  for _, element in ipairs(row) do
    if element == ListBox.COLEND then
      table.insert(positions, { idx_start, idx-1 })
      idx_start = idx + 1
    elseif idx == row_len then
      table.insert(positions, { idx_start, idx })
    end
    idx = idx + 1
  end

  return positions
end

---Enables expanding the element to total size of parent.
function ListBox:enable_expand(expand)
  self.expand = expand
end

---Remove all the rows from the listbox.
function ListBox:clear()
  self.rows = {}
  self.positions = {}
  self.selected_row = 0

  for cidx, col in ipairs(self.columns) do
    col.width = self:get_col_width(cidx)
  end
end

local function lines(text)
  return (text .. "\n"):gmatch("(.-)\n")
end

---Taken from the logview and modified it a tiny bit.
---TODO: something similar should be on lite-xl core.
---@param font renderer.font
---@param text string
---@param x integer
---@param y integer
---@param color renderer.color
---@param only_calc boolean
---@return integer resx
---@return integer resy
---@return integer width
---@return integer height
function ListBox:draw_text_multiline(font, text, x, y, color, only_calc)
  local th = font:get_height()
  local resx, resy = x, y
  local width, height = 0, 0
  for line in lines(text) do
    resy = y
    if only_calc then
      resx = x + font:get_width(line)
    else
      resx = renderer.draw_text(font, line, x, y, color)
    end
    y = y + th
    width = math.max(width, resx - x)
    height = height + th
  end
  return resx, resy, width, height
end

---Render or calculate the size of the specified range of elements in a row.
---@param row widget.listbox.row
---@param start_idx integer
---@param end_idx integer
---@param x integer
---@param y integer
---@param only_calc boolean
---@return integer width
---@return integer height
function ListBox:draw_row_range(row, start_idx, end_idx, x, y, only_calc)
  local font = self.font or style.font
  local color = self.foreground_color or style.text
  local width = 0
  local height = font:get_height()
  local new_line = false
  local nx = x

  for pos=start_idx, end_idx, 1 do
    local element = row[pos]
    if type(element) == "userdata" then
      font = element
    elseif type(element) == "table" then
      color = element
    elseif element == ListBox.NEWLINE then
      y = y + font:get_height()
      nx = x
      new_line = true
    elseif type(element) == "string" then
      local rx, ry, w, h = self:draw_text_multiline(
        font, element, nx, y, color, only_calc
      )
      y = ry
      nx = rx
      if new_line then
        height = height + h
        width = math.max(width, w)
        new_line = false
      else
        height = math.max(height, h)
        width = width + w
      end
    end
  end

  return width, height
end

---Calculate the overall width of a column.
---@param col integer
---@return number
function ListBox:get_col_width(col)
  if self.columns[col] then
    if not self.columns[col].expand then
      return self.columns[col].width
    else
      local width = style.font:get_width(self.columns[col].name)
      for id, row in ipairs(self.rows) do
        local w, h = self:draw_row_range(
          row,
          self.positions[id][col][1],
          self.positions[id][col][2],
          1,
          1,
          true
        )
        width = math.max(width, w)
      end
      return width
    end
  end
  return 0
end

---Draw the column headers of the list if available
---@param w integer
---@param h integer
function ListBox:draw_header(w, h)
  local x = self.position.x + self.border.width
  local y = self.position.y + self.border.width
  renderer.draw_rect(x, y, w, h, style.dim)
  for _, col in ipairs(self.columns) do
    renderer.draw_text(
      style.font,
      col.name,
      x + style.padding.x / 2,
      y + style.padding.y / 2,
      style.accent
    )
    x = x + col.width + style.padding.x
  end
end

---Draw or calculate the size of the given row position.
---@param row integer
---@param x integer
---@param y integer
---@param only_calc boolean
---@return integer width
---@return integer height
function ListBox:draw_row(row, x, y, only_calc)
  local w, h = 0, 0

  if not only_calc and self.rows[row].w then
    w, h = self.rows[row].w, self.rows[row].h
    w = self.largest_row > 0 and self.largest_row or w
    local mouse = self.mouse
    if
      mouse.x >= x
      and
      mouse.x <= x + w
      and
      mouse.y >= y
      and
      mouse.y <= y + h
    then
      renderer.draw_rect(x, y, w, h, style.selection)
      self.selected_row = row
    end
    w, h = 0, 0
  end

  -- add padding on top
  y = y + (style.padding.y / 2)

  if #self.columns > 0 then
    for col, coldata in ipairs(self.columns) do
      -- padding on left
      w = w + style.padding.x / 2
      local cw, ch = self:draw_row_range(
        self.rows[row],
        self.positions[row][col][1],
        self.positions[row][col][2],
        x + w,
        y,
        only_calc
      )
      -- add column width and end with padding on right
      w = w + coldata.width + (style.padding.x / 2)
      -- only store column height if bigger than previous one
      h = math.max(h, ch)
    end
  else
    local cw, ch = self:draw_row_range(
      self.rows[row],
      1,
      #self.rows[row],
      x + style.padding.x / 2,
      y,
      only_calc
    )
    h = ch
    w = cw + style.padding.x
  end

  -- Add padding on top and bottom
  h = h + style.padding.y

  -- store the dimensions for inexpensive subsequent hover calculation
  self.rows[row].w = w
  self.rows[row].h = h

  -- TODO: performance improvement, render only the visible rows on the view?
  self.rows[row].x = x
  self.rows[row].y = y - (style.padding.y / 2)

  -- return height with padding on top and bottom
  return w, h
end

---
--- Events
---

function ListBox:on_mouse_leave(x, y, dx, dy)
  ListBox.super.on_mouse_leave(self, x, y, dx, dy)
  self.mouse.x = 0
  self.mouse.y = 0
  self.selected_row = 0
end

function ListBox:on_mouse_moved(x, y, dx, dy)
  ListBox.super.on_mouse_moved(self, x, y, dx, dy)
  self.mouse.x = x
  self.mouse.y = y
  self.selected_row = 0
end

function ListBox:on_click(button, x, y)
  if self.selected_row > 0 then
    self:on_row_click(self.selected_row, self.row_data[self.selected_row])
  end
end

---You can overwrite this to listen to item clicks
---@param idx integer
---@param data any Data associated with the row
function ListBox:on_row_click(idx, data) end

local last_scale_update = 0
function ListBox:update()
  if not ListBox.super.update(self) then return end

  -- only calculate columns width on scale change since this can be expensive
  if last_scale_update ~= SCALE then
    if #self.columns > 0 then
      for col, column in ipairs(self.columns) do
        column.width = self:get_col_width(col)
      end
    end
    last_scale_update = SCALE
  end
end

function ListBox:draw()
  if not ListBox.super.draw(self) then return end

  local new_width = 0
  local new_height = 0

  if #self.columns > 0 then
    new_height = new_height + style.font:get_height() + style.padding.y
    for _, col in ipairs(self.columns) do
      new_width = new_width + col.width + style.padding.x
    end
  end

  local x = self.position.x + self.border.width
  local y = self.position.y + self.border.width + new_height

  for ridx, row in ipairs(self.rows) do
    local w, h = self:draw_row(ridx, x, y)
    new_width = math.max(new_width, w)
    new_height = new_height + h
    y = y + h
  end

  self.size.y = new_height + (self.border.width * 2)

  if self.expand and new_width < self.parent.size.x then
    self.size.x = self.parent.size.x
      - (self.border.width * 2)

    self.largest_row = self.size.x
      - (self.parent.border.width * 2)

    if self.size.y < self.parent.size.y then
      self.size.y = self.parent.size.y
        - (self.border.width * 2)
    else
      self.size.x = self.size.x - style.scrollbar_size
    end
  else
    -- resize it self to largest row width and amount of rows
    self.size.x = new_width + (self.border.width * 2)
    self.largest_row = new_width
  end

  if #self.columns > 0 then
    self:draw_header(
      self.largest_row,
      style.font:get_height() + style.padding.y)
  end
end


return ListBox

