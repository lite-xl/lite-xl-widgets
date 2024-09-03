--
-- TreeList Widget heavily based on TreeView plugin.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local core = require "core"
local common = require "core.common"
local style = require "core.style"
local Widget = require "libraries.widget"

---@class widget.treelist.item
---@field name string
---@field label string
---@field data any?
---@field expanded boolean?
---@field visible boolean?
---@field tooltip string?
---@field depth integer?
---@field childs widget.treelist.item[]?
---@field parent widget.treelist.item[]?
---@field icon string?

---@class widget.treelist : widget
---@field items widget.treelist.item[]
---@field selected_item widget.treelist.item?
---@field hovered_item widget.treelist.item?
---@field icon_font renderer.font?
---@field private count_lines integer
---@field private scroll_width integer
---@overload fun(parent:widget?):widget.treelist
local TreeList = Widget:extend()

---Constructor
---@param parent? widget
function TreeList:new(parent)
  TreeList.super.new(self, parent)

  self.type_name = "widget.treelist"

  self.scrollable = true
  self.init_size = true
  self.count_lines = 0
  self.scroll_width = 0
  self.items = {}
  self.tooltip = { x = 0, y = 0, begin = 0, alpha = 0 }
  self.last_scroll_y = 0

  self.item_icon_width = 0
  self.item_text_spacing = 0
end

---Get the height of a single item.
---@return number h
function TreeList:get_item_height()
  return style.font:get_height() + style.padding.y
end

---Add new item to to tree list
---@param item widget.treelist.item
function TreeList:add_item(item)
  table.insert(self.items, item)
end

---Remove all items from the tree
function TreeList:clear()
  self.items = {}
  self.selected_item = nil
  self.hovered_item = nil
end

---Retrieve the amount of visible items and also yield them.
---@param item widget.treelist.item
---@param x number
---@param y number
---@param w number
---@param h number
---@param depth? number
---@return integer items_count
function TreeList:get_items(item, x, y, w, h, depth)
  if not depth then depth = 0 else depth = depth + 1 end
  item.depth = depth
  coroutine.yield(item, x, y, w, h)
  local count_lines = 1
  if item and item.childs and item.expanded then
    for _, child in ipairs(item.childs) do
      if child.visible ~= false then
        count_lines = count_lines + self:get_items(
          child, x, y + count_lines * h, w, h, depth
        )
      end
    end
  end
  return count_lines
end

---Allows iterating the currently visible items only.
---@return fun():widget.treelist.item,number,number,number,number
function TreeList:each_item()
  return coroutine.wrap(function()
    local count_lines = 0
    local ox, oy = self:get_content_offset()
    local h = self:get_item_height()
    if #self.items > 0 then
      for i=1, #self.items do
        count_lines = count_lines + self:get_items(
          self.items[i],
          ox, oy + style.padding.y + h * count_lines,
          self.size.x, h
        )
      end
    end
    self.count_lines = count_lines
  end)
end

---Retrieve an item by name using the query format:
---"parent_name>child_name_2>child_name_2>etc..."
---@param query string
---@param items? widget.treelist.item[]
---@param separator? string Use a different separator (default: >)
---@return widget.treelist.item?
function TreeList:query_item(query, items, separator)
  local parent = items or self.items
  local item = nil
  separator = separator or ">"
  for name in query:gmatch("([^"..separator.."]+)") do
      if parent then
        local found = false
        for _, child in ipairs(parent) do
          if name == child.name then
            item = child
            parent = child.childs
            found = true
            break
          end
        end
        if not found then return nil end
      else
        return nil
      end
  end
  return item
end

---Set the active item.
---@param selection widget.treelist.item
---@param selection_y? number
---@param center? boolean
---@param instant? boolean
function TreeList:set_selection(selection, selection_y, center, instant)
  self.selected_item = selection
  if selection and selection_y
      and (selection_y <= 0 or selection_y >= self.size.y) then
    local lh = self:get_item_height()
    if not center and selection_y >= self.size.y - lh then
      selection_y = selection_y - self.size.y + lh
    end
    if center then
      selection_y = selection_y - (self.size.y - lh) / 2
    end
    local _, y = self:get_content_offset()
    self.scroll.to.y = selection_y - y
    self.scroll.to.y = common.clamp(
      self.scroll.to.y, 0, self:get_scrollable_size() - self.size.y
    )
    if instant then
      self.scroll.y = self.scroll.to.y
    end
  end
end

---Sets the selection to the file with the specified path.
---TODO: Not tested, idea is to allow query like selections using item names
---by introducing a get_item/set_item methods that accepts a string query,
---For the moment we leave this inherited TreeView function here.
---@param path string #Absolute path of item to select
---@param expand boolean #Expand dirs leading to the item
---@param scroll_to boolean #Scroll to make the item visible
---@param instant boolean #Don't animate the scroll
---@return table? #The selected item
function TreeList:set_selection_from_path(path, expand, scroll_to, instant)
  local separator = "||"
  local to_select, to_select_y
  local let_it_finish, done
  ::restart::
  for item, _,y,_,_ in self:each_item() do
    if not done then
      if item.childs and #item.childs > 0 then
        local _, to = string.find(path, item.name..separator, 1, true)
        if to and to == #item.name + #separator then
          to_select, to_select_y = item, y
          if expand and not item.expanded then
            self:toggle_expand(true, item)
            -- Because we altered the size of the TreeList
            -- and because TreeList:get_scrollable_size uses self.count_lines
            -- which gets updated only when TreeList:each_item finishes,
            -- we can't stop here or we risk that the scroll
            -- gets clamped by View:clamp_scroll_position.
            let_it_finish = true
            -- We need to restart the process because if TreeList:toggle_expand
            -- altered the cache, TreeList:each_item risks looping indefinitely.
            goto restart
          end
        end
      else
        if item.name == path then
          to_select, to_select_y = item, y
          done = true
          if not let_it_finish then break end
        end
      end
    end
  end
  if to_select then
    self:set_selection(to_select, scroll_to and to_select_y, true, instant)
  end
  return to_select
end

---Set the icon font used to render the items icon.
---@param font renderer.font
function TreeList:set_icon_font(font)
  if font:get_size() ~= style.icon_font:get_size() then
    font:set_size(style.icon_font:get_size())
  end
  self.icon_font = font
end

---Keep the icon font size updated to match current scale.
function TreeList:on_scale_change()
  if self.icon_font then
    self.icon_font:set_size(style.icon_font:get_size())
  end
end

function TreeList:on_mouse_moved(px, py, ...)
  if TreeList.super.on_mouse_moved(self, px, py, ...) then
    self.hovered_item = nil
  else
    return false
  end

  local position = self:get_position()
  local item_changed, tooltip_changed
  for item, x,y,w,h in self:each_item() do
    if px > x and py > y and px <= (self.size.x + position.x) and py <= y + h then
      item_changed = true
      self.hovered_item = item

      x = math.max(x, self.position.x)
      if px > x and py > y and px <= x + w and py <= y + h then
        tooltip_changed = true
        self.tooltip.x, self.tooltip.y = px, py
        self.tooltip.begin = system.get_time()
      end
      break
    end
  end
  if not item_changed then self.hovered_item = nil end
  if not tooltip_changed then self.tooltip.x, self.tooltip.y = nil, nil end

  return true
end

---Override to listen for item click events.
---@param item widget.treelist.item
---@param button string
---@param clicks integer
function TreeList:on_item_click(item, button, x, y, clicks) end

function TreeList:on_mouse_pressed(button, x, y, clicks)
  if TreeList.super.on_mouse_pressed(self, button, x, y, clicks) then
    if self:scrollbar_hovering() then return true end
    self:set_selection(self.hovered_item)
    if self.hovered_item then
      local emit_click = false
      if clicks > 1 then
        self:toggle_expand()
      else
        if self.hovered_item.childs then
          local x1, x2 = self:get_chevron_position(self.hovered_item)
          if x >= x1 and x <= x2 then
            self:toggle_expand()
          else
            emit_click = true
          end
        else
          emit_click = true
        end
      end
      if emit_click then
        self:on_item_click(self.hovered_item, button, x, y, clicks)
      end
    end
    return true
  end
  return false
end

function TreeList:on_mouse_left()
  TreeList.super.on_mouse_left(self)
  self.hovered_item = nil
end

function TreeList:update()
  if not self:is_visible() then return end

  local duration = system.get_time() - self.tooltip.begin
  local tooltip_delay = 0.5
  if self.hovered_item and self.tooltip.x and duration > tooltip_delay then
    self:move_towards(self.tooltip, "alpha", 255, 1, "treeview")
  else
    self.tooltip.alpha = 0
  end

  self.item_icon_width = style.icon_font:get_width("D")
  self.item_text_spacing = style.icon_font:get_width("f") / 2

  -- this will make sure hovered_item is updated
  local dy = math.abs(self.last_scroll_y - self.scroll.y)
  if dy > 0 then
    self:on_mouse_moved(core.root_view.mouse.x, core.root_view.mouse.y, 0, 0)
    self.last_scroll_y = self.scroll.y
  end

  TreeList.super.update(self)
end

function TreeList:get_scrollable_size()
  return self.count_lines and self:get_item_height() * (self.count_lines + 1) or math.huge
end

function TreeList:get_h_scrollable_size()
  local  _, _, v_scroll_w = self.v_scrollbar:get_thumb_rect()
  return self.scroll_width + (
    self.size.x > self.scroll_width + v_scroll_w and 0 or style.padding.x
  )
end

local function replace_alpha(color, alpha)
  local r, g, b = table.unpack(color)
  return { r, g, b, alpha }
end

function TreeList:draw_tooltip()
  if not self.hovered_item or not self.hovered_item.tooltip then
    return
  end

  local text = common.home_encode(self.hovered_item.tooltip)
  local w, h = style.font:get_width(text), style.font:get_height()

  local tooltip_offset = style.font:get_height()
  local x, y = self.tooltip.x + tooltip_offset, self.tooltip.y + tooltip_offset
  w, h = w + style.padding.x, h + style.padding.y

  if x + w > core.root_view.root_node.size.x then -- check if we can span right
    x = x - w -- span left instead
  end

  local tooltip_border = 1
  local bx, by = x - tooltip_border, y - tooltip_border
  local bw, bh = w + 2 * tooltip_border, h + 2 * tooltip_border
  renderer.draw_rect(
    bx, by, bw, bh, replace_alpha(style.text, self.tooltip.alpha)
  )
  renderer.draw_rect(
    x, y, w, h, replace_alpha(style.background2, self.tooltip.alpha)
  )
  common.draw_text(
    style.font,
    replace_alpha(style.text, self.tooltip.alpha),
    text, "center", x, y, w, h
  )
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
function TreeList:get_item_icon(item, active, hovered)
  local character = item.icon
  local font = self.icon_font or style.icon_font
  local color = style.text
  if active or hovered then
    color = style.accent
  end
  return character, font, color
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
function TreeList:get_item_text(item, active, hovered)
  local text = item.label
  local font = style.font
  local color = style.text
  if active or hovered then
    color = style.accent
  end
  return text, font, color
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
---@param x number
---@param y number
---@param w number
---@param h number
function TreeList:draw_item_text(item, active, hovered, x, y, w, h)
  local item_text, item_font, item_color = self:get_item_text(item, active, hovered)
  return common.draw_text(item_font, item_color, item_text, "left", x, y, 0, h)
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
---@param x number
---@param y number
---@param w number
---@param h number
function TreeList:draw_item_icon(item, active, hovered, x, y, w, h)
  local icon_char, icon_font, icon_color = self:get_item_icon(item, active, hovered)
  if not icon_char then return 0 end
  common.draw_text(icon_font, icon_color, icon_char, "left", x, y, 0, h)
  return self.item_icon_width + self.item_text_spacing
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
---@param x number
---@param y number
---@param w number
---@param h number
function TreeList:draw_item_body(item, active, hovered, x, y, w, h)
    x = x + self:draw_item_icon(item, active, hovered, x, y, w, h)
    return self:draw_item_text(item, active, hovered, x, y, w, h)
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
---@param x number
---@param y number
---@param w number
---@param h number
function TreeList:draw_item_chevron(item, active, hovered, x, y, w, h)
  if item.childs and #item.childs > 0 then
    local chevron_icon = item.expanded and "-" or "+"
    local chevron_color = hovered and style.accent or style.text
    common.draw_text(style.icon_font, chevron_color, chevron_icon, "left", x, y, 0, h)
  end
  return style.padding.x
end

---Get an item chevron starting and ending positions.
---@return number x1
---@return number x2
function TreeList:get_chevron_position(item)
  local ox = self:get_content_offset()
  local x1 = ox + item.depth * style.padding.x
  local x2 = x1 + style.padding.x * 2
  return x1, x2
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
---@param x number
---@param y number
---@param w number
---@param h number
function TreeList:draw_item_background(item, active, hovered, x, y, w, h)
  if hovered then
    local hover_color = { table.unpack(style.line_highlight) }
    hover_color[4] = 160
    renderer.draw_rect(self.position.x, y, self.size.x, h, hover_color)
  elseif active then
    renderer.draw_rect(self.position.x, y, self.size.x, h, style.line_highlight)
  end
end

---@param item widget.treelist.item
---@param active boolean
---@param hovered boolean
---@param x number
---@param y number
---@param w number
---@param h number
function TreeList:draw_item(item, active, hovered, x, y, w, h)
  self:draw_item_background(item, active, hovered, x, y, w, h)

  x = x + item.depth * style.padding.x + style.padding.x
  x = x + self:draw_item_chevron(item, active, hovered, x, y, w, h)

  return self:draw_item_body(item, active, hovered, x, y, w, h)
end

function TreeList:draw()
  if not TreeList.super.draw(self) then return end

  local position, ox = self:get_position(), self:get_content_offset()
  local _y, _h, sw = position.y, self.size.y, 0
  for item, x,y,w,h in self:each_item() do
    if y + h >= _y and y < _y + _h then
      w = self:draw_item(
        item,
        item == self.selected_item,
        item == self.hovered_item,
        x, y, w, h
      ) - position.x + (position.x - ox)
      sw = math.max(w, sw)
    end
  end
  self.scroll_width = sw

  self:draw_scrollbar()

  if
    self.hovered_item and self.hovered_item.tooltip
    and
    self.tooltip.x and self.tooltip.alpha > 0
  then
    core.root_view:defer_draw(self.draw_tooltip, self)
  end
end

---@param item? widget.treelist.item
---@param where integer
---@return widget.treelist.item item
---@return number x
---@return number y
---@return number w
---@return number h
function TreeList:get_item(item, where)
  item = item or self.selected_item

  local last_item, last_x, last_y, last_w, last_h
  local stop = false

  for it, x, y, w, h in self:each_item() do
    if not item and where >= 0 then
      return it, x, y, w, h
    end
    if item == it then
      if where < 0 and last_item then
        break
      elseif where == 0 or (where < 0 and not last_item) then
        return it, x, y, w, h
      end
      stop = true
    elseif stop then
      item = it
      return it, x, y, w, h
    end
    last_item, last_x, last_y, last_w, last_h = it, x, y, w, h
  end
  return last_item, last_x, last_y, last_w, last_h
end

---@param item? widget.treelist.item
---@return widget.treelist.item item
---@return number x
---@return number y
---@return number w
---@return number h
function TreeList:get_next(item)
  return self:get_item(item, 1)
end

---@param item? widget.treelist.item
---@return widget.treelist.item item
---@return number x
---@return number y
---@return number w
---@return number h
function TreeList:get_previous(item)
  return self:get_item(item, -1)
end

function TreeList:select_next()
  self.selected_item = self:get_next()
end

function TreeList:select_prev()
  self.selected_item = self:get_previous()
end

---Expand or collapse the currently selected or given item.
---@param toggle? boolean
---@param item? widget.treelist.item
function TreeList:toggle_expand(toggle, item)
  item = item or self.selected_item

  if not item then return end

  if item.childs and #item.childs > 0 then
    if type(toggle) == "boolean" then
      item.expanded = toggle
    else
      item.expanded = not item.expanded
    end
  end
end


return TreeList
