-- Selection, filtering and checked-state helpers shared by list components.

local items_mod = require "prompt.items"

local M = {}

local List = {}
List.__index = List

function List:position_of(index)
    if index == nil then return nil end
    for position, item in ipairs(self.visible) do
        if item.index == index then return position end
    end
    return nil
end

function List:first_enabled_position()
    for position, item in ipairs(self.visible) do
        if not item.disabled then return position end
    end
    return nil
end

function List:last_enabled_position()
    for position = #self.visible, 1, -1 do
        if not self.visible[position].disabled then return position end
    end
    return nil
end

function List:refresh()
    if self.matcher then
        self.visible = self.matcher(self.items, self.query)
    else
        self.visible = items_mod.filter(self.items, self.query)
    end
    self:ensure_selected()
    return self.visible
end

function List:ensure_selected()
    if self:position_of(self.selected) ~= nil then return self.selected end
    local position = self:first_enabled_position()
    if position then
        self.selected = self.visible[position].index
    else
        self.selected = nil
    end
    return self.selected
end

function List:current()
    local position = self:position_of(self.selected)
    if position == nil then return nil end
    return self.visible[position]
end

function List:current_position()
    return self:position_of(self.selected)
end

function List:move(delta)
    if #self.visible == 0 then return self.selected end
    local position = self:position_of(self.selected) or (delta > 0 and 0 or #self.visible + 1)
    local candidate = position
    for _ = 1, #self.visible do
        candidate = candidate + delta
        if candidate > #self.visible then candidate = 1 end
        if candidate < 1 then candidate = #self.visible end
        local item = self.visible[candidate]
        if not item.disabled then
            self.selected = item.index
            return self.selected
        end
    end
    return self.selected
end

function List:first()
    local position = self:first_enabled_position()
    if position == nil and #self.visible > 0 then position = 1 end
    self.selected = position and self.visible[position].index or nil
    return self.selected
end

function List:last()
    local position = self:last_enabled_position()
    if position then self.selected = self.visible[position].index end
    return self.selected
end

function List:page(delta, size)
    if #self.visible == 0 then return self.selected end
    size = math.max(1, math.floor(size or self.height or 10))
    local position = self:position_of(self.selected) or 1
    local target = math.max(1, math.min(#self.visible, position + delta * size))
    for offset = 0, #self.visible do
        local candidate = target + offset * delta
        if candidate < 1 or candidate > #self.visible then break end
        if not self.visible[candidate].disabled then
            self.selected = self.visible[candidate].index
            break
        end
    end
    return self.selected
end

function List:set_query(query)
    self.query = tostring(query or "")
    self:refresh()
    return self.visible
end

function List:set_matcher(matcher)
    self.matcher = matcher
    return self:refresh()
end

function List:item_at(index)
    for _, item in ipairs(self.items) do
        if item.index == index then return item end
    end
    return nil
end

function List:set_selected(index)
    local item = self:item_at(index)
    if item and not item.disabled then
        self.selected = index
    end
    return self.selected
end

function List:toggle(index)
    index = index or self.selected
    local item = self:item_at(index)
    if item == nil or item.disabled then return self.checked end
    if self.checked[index] then
        self.checked[index] = nil
    else
        self.checked[index] = true
    end
    return self.checked
end

function List:set_checked(index, value)
    local item = self:item_at(index)
    if item == nil or item.disabled then return self.checked end
    self.checked[index] = value and true or nil
    return self.checked
end

function List:check_all(visible_only)
    local source = visible_only and self.visible or self.items
    for _, item in ipairs(source) do
        if not item.disabled then self.checked[item.index] = true end
    end
    return self.checked
end

function List:invert_all(visible_only)
    local source = visible_only and self.visible or self.items
    for _, item in ipairs(source) do
        if not item.disabled then
            self.checked[item.index] = not self.checked[item.index] or nil
        end
    end
    return self.checked
end

function List:clear_checked()
    self.checked = {}
    return self.checked
end

function List:checked_count()
    local count = 0
    for _ in pairs(self.checked) do count = count + 1 end
    return count
end

function List:selected_values()
    return items_mod.selected_values(self.items, self.checked)
end

function List:has_checked()
    return self:checked_count() > 0
end

function M.new(options)
    options = options or {}
    if type(options) ~= "table" then
        error("prompt.list: expecting an options table", 2)
    end
    if type(options.items) ~= "table" then
        error("prompt.list: items must be a table", 2)
    end
    local list = setmetatable({
        items = options.items,
        query = tostring(options.query or ""),
        selected = options.selected,
        checked = options.checked or {},
        matcher = options.matcher,
        height = options.height,
    }, List)
    list:refresh()
    return list
end

return M
