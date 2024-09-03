--
-- SearchReplaceList Widget.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local common = require "core.common"
local style = require "core.style"
local Widget = require "libraries.widget"

---@class widget.searchreplacelist.lineposition
---@field col1 integer
---@field col2 integer
---@field checked boolean?

---@class widget.searchreplacelist.line
---@field line integer
---@field text string
---@field positions widget.searchreplacelist.lineposition[]

---@class widget.searchreplacelist.file
---@field path string
---@field lines widget.searchreplacelist.line[]
---@field expanded boolean

---@class widget.searchreplacelist.item
---@field checked boolean
---@field file widget.searchreplacelist.file?
---@field parent widget.searchreplacelist.item?
---@field line widget.searchreplacelist.line?
---@field position widget.searchreplacelist.lineposition?

---@class widget.searchreplacelist : widget
---@field replacement string?
---@field selected integer
---@field hovered integer
---@field items widget.searchreplacelist.item[]
---@field total_files integer
---@field total_results integer
---@field base_dir string
---@overload fun(parent:widget, find:string, replacement:string?):widget.searchreplacelist
local SearchReplaceList = Widget:extend()

---Colors to use when performing a replacement.
local DIFF = {
  ADD = { common.color "#72b886" },
  DEL = { common.color "#F36161" },
  TEXT = { common.color "#000000" }
}

---Constructor
---@param parent widget
---@param replacement string?
function SearchReplaceList:new(parent, replacement)
  SearchReplaceList.super.new(self, parent)

  self.type_name = "widget.searchreplacelist"

  self.replacement = replacement or nil
  self.selected = 0
  self.hovered = 0
  self.items = {}
  self.max_width = 0
  self.hovered_checkbox = false
  self.hovered_expander = false
  self.scrollable = true
  self.total_files = 0
  self.total_results = 0
  self.base_dir = ""
end

---Overridable event triggered when an item is clicked.
---@param item widget.searchreplacelist.item
---@param clicks integer
function SearchReplaceList:on_item_click(item, clicks) end

---Add a new file with all the matching lines and positions.
---@param path string
---@param lines widget.searchreplacelist.line[]
---@param expanded boolean?
function SearchReplaceList:add_file(path, lines, expanded)
  if type(expanded) == "nil" then expanded = true end
  table.insert(self.items, {
    checked = true,
    file = {
      path = path,
      lines = lines,
      expanded = false
    }
  })
  self.total_files = self.total_files + 1
  -- expand results and count them
  if expanded and #lines > 0 then
    self:expand(#self.items, true)
  -- count the results only
  else
    for _, line in ipairs(self.items[#self.items]) do
      self.total_results = self.total_results + #line.positions
    end
  end
end

---Removes all elements from the list and reset it.
function SearchReplaceList:clear()
  self.selected = 0
  self.hovered = 0
  self.items = {}
  self.max_width = 0
  self.hovered_checkbox = false
  self.hovered_expander = false
  self.total_files = 0
  self.total_results = 0
end

---Uncollapse a file line results.
---@param position integer
function SearchReplaceList:expand(position, count_results)
  local parent = self.items[position]
  if
    parent and parent.file
    and
    not parent.file.expanded
  then
    local insert_pos = position+1
    local items = {}
    for _, line in ipairs(parent.file.lines) do
      for _, line_pos in ipairs(line.positions) do
        table.insert(items, {
          parent = parent,
          line = line,
          position = line_pos
        })
        if count_results then
          self.total_results = self.total_results + 1
        end
      end
    end
    common.splice(self.items, insert_pos, 0, items)
    parent.file.expanded = true
  end
end

---Collapse a file line results.
---@param position integer
function SearchReplaceList:contract(position)
  local parent = self.items[position]
  if
    parent and parent.file
    and
    parent.file.expanded
  then
    local start_pos = position+1
    local end_pos = 0
    for _, line in ipairs(parent.file.lines) do
      for _, _ in ipairs(line.positions) do
        end_pos = end_pos + 1
      end
    end
    common.splice(self.items, start_pos, end_pos)
    parent.file.expanded = false
  end
end

---Collapse/uncollapse a file line results.
---@param position integer
function SearchReplaceList:toggle_expand(position)
  local parent = self.items[position]
  if parent and parent.file then
    if parent.file.expanded then
      self:contract(position)
    else
      self:expand(position)
    end
  end
end

---Toggle the checkbox of the given item position.
---@param pos integer
function SearchReplaceList:toggle_check(pos)
  local item = self.items[pos]
  if not item or self.replacement == nil then return end
  if item.file then
    item.checked = not item.checked
    for _, line in ipairs(item.file.lines) do
      for _, position in ipairs(line.positions) do
        position.checked = item.checked
      end
    end
  else
    if type(item.position.checked) == "nil" then
      item.position.checked = false
    else
      item.position.checked = not item.position.checked
    end
    local parent_checked = true
    for _, line in ipairs(item.parent.file.lines) do
      for _, position in ipairs(line.positions) do
        if position.checked == false then
          parent_checked = false
          break
        end
      end
    end
    item.parent.checked = parent_checked
  end
end

---Replace a position on a string with a given replacement.
---@param str string
---@param s integer
---@param e integer
---@param rep string
local function replace_substring(str, s, e, rep)
    local head = s <= 1 and "" or string.sub(str, 1, s - 1)
    local tail = e >= #str and "" or string.sub(str, e + 1)
    return head .. rep .. tail
end

---Applies the replacement on the given item position but not on the real file.
---
---The purpose of this function is to reflect the changes on the listed items.
---@param position integer
function SearchReplaceList:apply_replacement(position)
  local item = self.items[position]
  if item and item.file and self.replacement then
    local replacement = self.replacement
    local replacement_len = #self.replacement
    for _, line in ipairs(item.file.lines) do
      local offset = 0
      for _, pos in ipairs(line.positions) do
        local col1 = pos.col1 + offset
        local col2 = pos.col2 + offset
        if pos.checked or type(pos.checked) == "nil" then
          line.text = replace_substring(line.text, col1, col2, replacement)
          local current_len = col2 - col1 + 1
          local len_diff = 0
          if current_len > replacement_len then
            len_diff = current_len - replacement_len
            offset = offset - len_diff
            col2 = col2 - len_diff
          elseif current_len < replacement_len then
            len_diff = replacement_len - current_len
            offset = offset + len_diff
            col2 = col2 + len_diff
          end
        end
        pos.col1, pos.col2 = col1, col2
      end
    end
  end
end

---Select the item that follows currently selected item.
---@return widget.searchreplacelist.item?
function SearchReplaceList:select_next()
  local items_count = #self.items
  if items_count <= 0 then return nil end
  local selected = self.selected+1
  if selected > items_count then selected = 1 end
  self.selected = common.clamp(selected, 1, items_count)
  self:scroll_to_selected()
  return self.items[self.selected]
end

---Select the item that precedes currently selected item.
---@return widget.searchreplacelist.item?
function SearchReplaceList:select_prev()
  local items_count = #self.items
  if items_count <= 0 then return nil end
  local selected = self.selected-1
  if selected < 1 then selected = items_count end
  self.selected = common.clamp(selected, 1, items_count)
  self:scroll_to_selected()
  return self.items[self.selected]
end

---Get the currently selected item.
---@return widget.searchreplacelist.item?
function SearchReplaceList:get_selected()
  if self.selected > 0 and self.selected <= #self.items then
    return self.items[self.selected]
  end
  return nil
end

---Get the line height used when drawing each item row.
---@return number height
function SearchReplaceList:get_line_height()
  return style.padding.y + style.font:get_height()
end

---Used when calculating if vertical scrolling is needed.
---@return number size
function SearchReplaceList:get_scrollable_size()
  return #self.items * self:get_line_height() + style.padding.y
end

---Used when calculating if horizontal scrolling is needed.
---@return number size
function SearchReplaceList:get_h_scrollable_size()
  local width = style.padding.x / 2
    + style.icon_font:get_width("-")
    + style.padding.x / 2
    + self.max_width
  if self.replacement then
    local cb_w = self:get_checkbox_size()
    width = width
      + cb_w + style.padding.x / 2
      + style.font:get_width(self.replacement)
  end
  return width
end

---Get the checkbox size based on the line height.
---@param y? number
---@return number w
---@return number h
---@return number y Vertically center align coord based on given y param
function SearchReplaceList:get_checkbox_size(y)
  if not y then y = 0 end
  local lh = self:get_line_height()
  local w = lh * 0.6
  local h = w
  y = y + ((lh / 2) - (h / 2))
  return w, h, y
end

---Get the position of first and last visible items.
---@return integer first
---@return integer last
function SearchReplaceList:get_visible_items_range()
  local lh = self:get_line_height()
  local min = math.max(1, math.floor(self.scroll.y / lh))
  return min, min + math.floor(self.size.y / lh) + 1
end

---Allows iterating the currently visible items only.
---@return fun():integer,widget.searchreplacelist.item,number,number,number,number
function SearchReplaceList:each_visible_item()
  return coroutine.wrap(function()
    local lh = self:get_line_height()
    local x, y = self:get_content_offset()
    local min, max = self:get_visible_items_range()
    y = y + lh * (min - 1)
    for i = min, max do
      local item = self.items[i]
      if not item then break end
      coroutine.yield(i, item, x, y, self.size.x, lh)
      y = y + lh
    end
  end)
end

---Iterates over all files, only those that have a position checked on replacement mode.
---@return fun():integer,widget.searchreplacelist.file
function SearchReplaceList:each_file()
  return coroutine.wrap(function()
    local replacement = self.replacement
    for i, item in ipairs(self.items) do
      if item.file then
        if replacement then
          local none_checked = true
          for _, line in ipairs(item.file.lines) do
            for _, pos in ipairs(line.positions) do
              if type(pos.checked) == "nil" or pos.checked then
                none_checked = false
                break
              end
            end
          end
          if none_checked then
            goto continue
          end
        end
        coroutine.yield(i, item.file)
      end
      ::continue::
    end
  end)
end

---Scroll to currently selected item only if not already visible.
function SearchReplaceList:scroll_to_selected()
  if self.selected == 0 then return end
  local h = self:get_line_height()
  local y = h * (self.selected - 1)
  self.scroll.to.y = math.min(self.scroll.to.y, y)
  self.scroll.to.y = math.max(self.scroll.to.y, y + h - self.size.y)
end

function SearchReplaceList:on_mouse_moved(mx, my, ...)
  if not SearchReplaceList.super.on_mouse_moved(self, mx, my, ...) then
    return false
  end
  self.hovered = 0
  for i, item, x,y,w,h in self:each_visible_item() do
    w = self.size.x
    if mx >= x and my >= y and mx < x + w and my < y + h then
      self.hovered = i
      x = x + style.padding.x / 2
      w = style.icon_font:get_width('-')
      if item.file and mx >= x and my >= y and mx < x + w and my < y + h then
        self.hovered_expander = true
        self.hovered_checkbox = false
      else
        self.hovered_expander = false
      end
      if not self.hovered_expander and self.replacement then
        x = x + w + style.padding.x / 2
        w, h, y = self:get_checkbox_size(y)
        if mx >= x and my >= y and mx < x + w and my < y + h then
          self.hovered_checkbox = true
          self.hovered_expander = false
        else
          self.hovered_checkbox = false
        end
      end
      break
    end
  end
  return true
end

function SearchReplaceList:on_mouse_pressed(button, x, y, clicks)
  if
    not SearchReplaceList.super.on_mouse_pressed(self, button, x, y, clicks)
  then
    return false
  end
  if self:scrollbar_hovering() then return true end
  local item = self.items[self.hovered]
  if not item then return true end
  self.selected = self.hovered
  if self.hovered_checkbox then
    self:toggle_check(self.selected)
  elseif item.file and (clicks > 1 or self.hovered_expander) then
    if not item.file.expanded then
      self:expand(self.hovered)
    else
      self:contract(self.hovered)
    end
  else
    self:on_item_click(item, clicks)
  end
  return true
end

function SearchReplaceList:draw_checkbox(checked, hovered, x, y, lh)
  local w, h, cy = self:get_checkbox_size(y)
  renderer.draw_rect(x, cy, w, h, style.text)
  renderer.draw_rect(
    x + 2, cy + 2, w-4, h-4,
    hovered and style.dim or style.background
  )
  if checked then
    renderer.draw_rect(x + 5, cy + 5, w-10, h-10, style.caret)
  end
  return x + w
end

function SearchReplaceList:draw()
  if not SearchReplaceList.super.draw(self) then return false end

  core.push_clip_rect(
    self.position.x,
    self.position.y,
    self.size.x,
    self.size.y
  )

  local font = self:get_font()

  local replacement = self.replacement
  local replacement_width = font:get_width(replacement or "")
  local file_path

  self.max_width = 0

  for i, item, x,y,w,h in self:each_visible_item() do
    if item.file then
      file_path = common.relative_path(self.base_dir, item.file.path)
    end

    -- add left padding
    x = x + style.padding.x / 2

    local text_color = style.text

    if i == self.selected then
      renderer.draw_rect(self.position.x, y, self.size.x, h, style.selection)
    elseif i == self.hovered then
      renderer.draw_rect(self.position.x, y, self.size.x, h, style.line_highlight)
      text_color = style.accent
    end

    -- draw collapse/contract symbol
    if item.file then
      common.draw_text(
        style.icon_font,
        (self.hovered == i and self.hovered_expander) and style.accent or style.text,
        item.file.expanded and "-" or "+",
        "left",
        x, y, w, h
      )
      x = x + style.icon_font:get_width("-")
    else
      x = x + style.icon_font:get_width("-")
    end

    x = x + style.padding.x / 2

    -- draw checkbox
    if replacement then
      local checked = false
      if item.file then
        checked = item.checked
      else
        if type(item.position.checked) == "nil" then
          checked = true
        else
          checked = item.position.checked
        end
      end
      x = style.padding.x / 2 + self:draw_checkbox(
        checked,
        i == self.hovered and self.hovered_checkbox or false,
        x, y, h
      )
    end

    -- draw text
    local text = item.file and file_path or item.line.text
    local all_text = ""

    if item.line then
      local start_pos, end_pos = 1, #text
      local prefix, postfix = "", ""
      -- truncate long lines to keep good rendering performance
      if #text > 120 then
        start_pos = math.max(item.position.col1 - 50, 1)
        end_pos = math.min(item.position.col2 + 50, end_pos)
        if start_pos ~= 1 then prefix = "..." end
        if end_pos ~= #text then postfix = "..." end
      end
      x = common.draw_text(
        font,
        style.syntax["number"],
        tostring(item.line.line) .. ": ",
        "left",
        x, y, w, h
      )
      local start_text = item.position.col1 ~= 1 and
        prefix .. text:sub(start_pos, item.position.col1-1)
        or
        ""
      local end_text = item.position.col2 ~= #text and
        text:sub(item.position.col2+1, end_pos) .. postfix
        or
        ""
      local found_text = text:sub(item.position.col1, item.position.col2)
      local found_width = style.font:get_width(found_text)
      if start_text ~= "" then
        x = common.draw_text(
          font,
          text_color,
          start_text,
          "left",
          x, y, w, h
        )
      end
      local found_color = not replacement and style.dim or DIFF.DEL
      local found_text_color = not replacement and text_color or DIFF.TEXT
      renderer.draw_rect(x, y, found_width, h, found_color)
      x = common.draw_text(font, found_text_color, found_text, "left", x, y, w, h)
      if replacement then
        renderer.draw_rect(x, y, replacement_width, h, DIFF.ADD)
        x = common.draw_text(font, DIFF.TEXT, replacement, "left", x, y, w, h)
      end
      if end_text ~= "" then
        x = common.draw_text(
          font,
          text_color,
          end_text,
          "left",
          x, y, w, h
        )
      end
      all_text = item.line.line .. ": " .. start_text .. found_text .. end_text
    else
      x = common.draw_text(font, text_color, text, "left", x, y, w, h)
      all_text = file_path
    end

    -- recalc max_width for horizontal scrollbar
    self.max_width = math.max(self.max_width, style.font:get_width(all_text))
  end

  core.pop_clip_rect()

  self:draw_scrollbar()

  return true
end


return SearchReplaceList
