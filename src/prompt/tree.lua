-- Hierarchical picker with expansion, optional filtering and cascade checks.

local config = require "prompt.config"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local M = {}

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.tree: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.tree: message must be a non-empty string", 3)
    end
    if type(options.items) ~= "table" or #options.items == 0 then
        error("prompt.tree: items must be a non-empty table", 3)
    end
    if options.expanded ~= nil
        and type(options.expanded) ~= "boolean"
        and type(options.expanded) ~= "number"
    then
        error("prompt.tree: expanded must be a boolean or a depth", 3)
    end
    if options.as ~= nil and options.as ~= "value" and options.as ~= "node" and options.as ~= "path" then
        error("prompt.tree: as must be 'value', 'node' or 'path'", 3)
    end
    if options.min ~= nil and (type(options.min) ~= "number" or options.min < 0) then
        error("prompt.tree: min must be a non-negative number", 3)
    end
    if options.max ~= nil and (type(options.max) ~= "number" or options.max < 1) then
        error("prompt.tree: max must be a positive number", 3)
    end
    if options.min and options.max and options.min > options.max then
        error("prompt.tree: min must not exceed max", 3)
    end
end

local function normalize(nodes, parent, depth)
    local result = {}
    for index, raw in ipairs(nodes) do
        local source = raw
        if type(raw) == "string" then raw = { label = raw } end
        if type(raw) ~= "table" then
            error("prompt.tree: node " .. index .. " must be a string or a table", 3)
        end
        if raw.label == nil then
            error("prompt.tree: node " .. index .. " needs a label", 3)
        end
        local label = tostring(raw.label)
        local value = raw.value
        if value == nil then value = label end
        local node = {
            label = label,
            value = value,
            description = raw.description and tostring(raw.description) or nil,
            disabled = raw.disabled and true or false,
            source = source,
            parent = parent,
            depth = depth,
            children = {},
        }
        if raw.children ~= nil then
            if type(raw.children) ~= "table" then
                error("prompt.tree: children of '" .. label .. "' must be a table", 3)
            end
            node.children = normalize(raw.children, node, depth + 1)
        end
        result[#result + 1] = node
    end
    return result
end

local function collect(nodes, all)
    for _, node in ipairs(nodes) do
        node.index = #all + 1
        all[#all + 1] = node
        collect(node.children, all)
    end
end

local function table_equal(left, right, seen)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not table_equal(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function candidate_list(value)
    if type(value) ~= "table" then return { value } end
    if #value > 0 then return value end
    if next(value) == nil then return {} end
    return { value }
end

local function make_field(options, field_options)
    field_options = field_options or {}
    validate_options(options)
    local roots = normalize(options.items, nil, 0)
    local all = {}
    collect(roots, all)

    local as = options.as or "value"
    local multi = options.multi == true
    local filter_enabled = options.filter ~= false
    local show_help = field_options.show_help ~= false
    local expanded = {}
    for _, node in ipairs(all) do
        if #node.children > 0 then
            if options.expanded == true then
                expanded[node.index] = true
            elseif type(options.expanded) == "number" and options.expanded > 0 then
                expanded[node.index] = node.depth < options.expanded
            else
                expanded[node.index] = false
            end
        end
    end

    local state = {
        query = "",
        visible = {},
        selected = nil,
        checked = {},
        keep = {},
        forced = {},
        match = {},
        width = nil,
        max_height = nil,
        error = nil,
    }

    local function result_for(node)
        if as == "node" then return node.source end
        if as == "path" then
            local path = {}
            local cursor = node
            while cursor do
                table.insert(path, 1, cursor.label)
                cursor = cursor.parent
            end
            return path
        end
        return node.value
    end

    local function position_of(index)
        for position, node in ipairs(state.visible) do
            if node.index == index then return position end
        end
        return nil
    end

    local function ensure_selected()
        local position = position_of(state.selected)
        if position and not state.visible[position].disabled then return end
        state.selected = nil
        for _, node in ipairs(state.visible) do
            if not node.disabled then
                state.selected = node.index
                return
            end
        end
    end

    local function refresh()
        local query = state.query:lower()
        local filtering = query ~= ""
        state.keep = {}
        state.forced = {}
        state.match = {}
        if filtering then
            local function mark(nodes)
                local any = false
                for _, node in ipairs(nodes) do
                    local self_match = node.label:lower():find(query, 1, true) ~= nil
                    local child_match = mark(node.children)
                    if self_match or child_match then
                        state.keep[node.index] = true
                        if self_match then state.match[node.index] = true end
                        if child_match then state.forced[node.index] = true end
                        any = true
                    end
                end
                return any
            end
            mark(roots)
        end

        local visible = {}
        local function walk(nodes)
            for _, node in ipairs(nodes) do
                if not filtering or state.keep[node.index] then
                    visible[#visible + 1] = node
                end
                if #node.children > 0 then
                    local open = filtering and state.forced[node.index] or expanded[node.index]
                    if open then walk(node.children) end
                end
            end
        end
        walk(roots)
        state.visible = visible
        if filtering and not state.match[state.selected or 0] then
            state.selected = nil
            for _, node in ipairs(visible) do
                if state.match[node.index] and not node.disabled then
                    state.selected = node.index
                    break
                end
            end
        end
        ensure_selected()
    end

    local function current()
        local position = position_of(state.selected)
        if position == nil then return nil end
        return state.visible[position]
    end

    local function select_index(index)
        for position, node in ipairs(state.visible) do
            if node.index == index and not node.disabled then
                state.selected = index
                return true
            end
        end
        return false
    end

    local function move(delta)
        local count = #state.visible
        if count == 0 then return end
        local position = position_of(state.selected) or (delta > 0 and 0 or count + 1)
        for _ = 1, count do
            position = position + delta
            if position > count then position = 1 end
            if position < 1 then position = count end
            if not state.visible[position].disabled then
                state.selected = state.visible[position].index
                return
            end
        end
    end

    local function first_enabled_position()
        for position, node in ipairs(state.visible) do
            if not node.disabled then return position end
        end
        return nil
    end

    local function last_enabled_position()
        for position = #state.visible, 1, -1 do
            local node = state.visible[position]
            if not node.disabled then return position end
        end
        return nil
    end

    local function page(delta)
        local size = require("term").size() or { rows = 24 }
        local step = math.max(1, size.rows - 8)
        move(delta * step)
    end

    local function set_subtree(node, value)
        if not node.disabled then state.checked[node.index] = value and true or nil end
        for _, child in ipairs(node.children) do set_subtree(child, value) end
    end

    local function checked_count()
        local count = 0
        for _, node in ipairs(all) do
            if state.checked[node.index] and not node.disabled then count = count + 1 end
        end
        return count
    end

    local function selected_values()
        local values = {}
        for _, node in ipairs(all) do
            if state.checked[node.index] and not node.disabled then
                values[#values + 1] = result_for(node)
            end
        end
        return values
    end

    local function subtree_counts(node)
        local enabled = node.disabled and 0 or 1
        local checked = (enabled == 1 and state.checked[node.index]) and 1 or 0
        for _, child in ipairs(node.children) do
            local child_enabled, child_checked = subtree_counts(child)
            enabled = enabled + child_enabled
            checked = checked + child_checked
        end
        return enabled, checked
    end

    local function same_result(node, candidate)
        if node.value == candidate or node.source == candidate then return true end
        return table_equal(result_for(node), candidate) or table_equal(node.value, candidate)
    end

    local function toggle()
        local node = current()
        if node == nil or node.disabled then return end
        if multi then
            set_subtree(node, not state.checked[node.index])
        elseif #node.children > 0 then
            expanded[node.index] = not expanded[node.index]
            refresh()
        end
    end

    local function minimum()
        if options.required then return math.max(1, options.min or 0) end
        return options.min or 0
    end

    local function build(theme)
        local size = require("term").size() or { columns = 80, rows = 24 }
        local columns = state.width or size.columns
        local rows = state.max_height or size.rows
        local lines = {
            render.line(render.span("? ", "accent"), render.span(options.message, "message")),
        }
        if filter_enabled then
            lines[#lines + 1] = render.line(
                render.span("  filter: ", "muted"),
                render.span(state.query == "" and theme.symbol("ellipsis") or state.query, "accent")
            )
        end

        local overhead = 1 + (filter_enabled and 1 or 0) + (show_help and 1 or 0) + 1
        local available = math.max(1, rows - overhead)
        local total = #state.visible
        local body_height
        if total > available then
            body_height = math.max(1, available - 2)
        else
            body_height = math.max(1, total)
        end
        local position = position_of(state.selected) or 1
        local top = state.top or 1
        if position < top then top = position end
        if position > top + body_height - 1 then top = position - body_height + 1 end
        top = math.max(1, math.min(top, math.max(1, total - body_height + 1)))
        state.top = top

        local reserve_top = top > 1
        local reserve_bottom = top + body_height - 1 < total
        local filtering = state.query ~= ""

        if reserve_top then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_up") .. " more", "muted")
            )
        end

        for index = top, math.min(#state.visible, top + body_height - 1) do
            local node = state.visible[index]
            local selected = node.index == state.selected
            local spans = {
                render.span("  ", nil),
                render.span(
                    selected and theme.symbol("pointer") or " ",
                    selected and "selected" or "accent"
                ),
                render.span(" ", selected and "selected" or nil),
                render.span(string.rep("  ", node.depth), nil),
            }
            local label_style = selected and "selected" or (node.disabled and "muted" or nil)
            if multi then
                local enabled, checked = subtree_counts(node)
                local glyph, glyph_style
                if enabled > 0 and checked == enabled then
                    glyph = theme.symbol("checked")
                    glyph_style = selected and "selected" or "accent"
                elseif checked > 0 then
                    glyph = theme.symbol("partial")
                    glyph_style = selected and "selected" or "warning"
                else
                    glyph = theme.symbol("unchecked")
                    glyph_style = selected and "selected" or "muted"
                end
                spans[#spans + 1] = render.span(glyph .. " ", glyph_style)
            end
            if #node.children > 0 then
                local open = expanded[node.index] or (filtering and state.forced[node.index])
                spans[#spans + 1] = render.span(
                    (open and theme.symbol("expanded") or theme.symbol("collapsed")) .. " ",
                    selected and "selected" or "accent"
                )
            else
                spans[#spans + 1] = render.span(theme.symbol("file") .. " ", "muted")
            end
            spans[#spans + 1] = render.span(node.label, label_style)
            if node.description then
                spans[#spans + 1] = render.span(
                    "  " .. node.description,
                    selected and "selected_muted" or "muted"
                )
            end
            if node.disabled then
                spans[#spans + 1] = render.span(" (disabled)", "muted")
            end
            lines[#lines + 1] = render.clip(spans, columns, theme)
        end

        if #state.visible == 0 then
            lines[#lines + 1] = render.line(render.span("  no matches", "muted"))
        end
        if reserve_bottom then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_down") .. " more", "muted")
            )
        end

        local help
        if multi then
            help = "arrows move  space check  enter done  esc cancel"
        else
            help = "arrows move  right/left expand  space toggle  enter select  esc cancel"
        end
        if filter_enabled then help = help .. "  type to filter" end
        if show_help then lines[#lines + 1] = field_mod.help_line(help) end
        return render.frame(lines)
    end

    local function on_event(event)
        if event.type == "paste" and filter_enabled then
            state.query = state.query .. event.text:gsub("[\r\n]+", " ")
            refresh()
            return "continue"
        end
        if event.type ~= "key" then return "continue" end

        if input.cancel(event) then
            if input.key(event, "esc") and state.query ~= "" then
                state.query = ""
                refresh()
                state.error = nil
                return "continue"
            end
            return "cancel"
        end

        state.error = nil
        if input.key(event, "up") then
            move(-1)
            return "continue"
        elseif input.key(event, "down") then
            move(1)
            return "continue"
        elseif input.key(event, "home") then
            local position = first_enabled_position()
            if position then state.selected = state.visible[position].index end
            return "continue"
        elseif input.key(event, "end") then
            local position = last_enabled_position()
            if position then state.selected = state.visible[position].index end
            return "continue"
        elseif input.key(event, "page_up") then
            page(-1)
            return "continue"
        elseif input.key(event, "page_down") then
            page(1)
            return "continue"
        elseif input.key(event, "right") then
            local node = current()
            if node and #node.children > 0 then
                if not expanded[node.index] then
                    expanded[node.index] = true
                    refresh()
                else
                    local position = position_of(node.index)
                    local next_node = position and state.visible[position + 1]
                    if next_node and next_node.parent == node then
                        select_index(next_node.index)
                    end
                end
            end
            return "continue"
        elseif input.key(event, "left") then
            local node = current()
            if node then
                if #node.children > 0 and expanded[node.index] then
                    expanded[node.index] = false
                    refresh()
                elseif node.parent then
                    select_index(node.parent.index)
                end
            end
            return "continue"
        elseif input.enter(event) then
            if multi then
                local count = checked_count()
                if count < minimum() then
                    state.error = "Choose at least " .. minimum() .. "."
                    return "continue"
                end
                if options.max and count > options.max then
                    state.error = "Choose at most " .. options.max .. "."
                    return "continue"
                end
                return "submit", selected_values()
            end
            local node = current()
            if node == nil then
                state.error = "Choose a node."
                return "continue"
            end
            if node.disabled then
                state.error = "That node is disabled."
                return "continue"
            end
            return "submit", result_for(node)
        elseif input.key(event, "char") and event.char == " " then
            toggle()
            return "continue"
        end

        if filter_enabled then
            if input.key(event, "backspace") then
                local offset = utf8.offset(state.query, -1)
                if offset == nil or offset <= 1 then
                    state.query = ""
                else
                    state.query = state.query:sub(1, offset - 1)
                end
                refresh()
                return "continue"
            end
            if input.ctrl(event, "u") then
                state.query = ""
                refresh()
                return "continue"
            end
            local char = input.printable(event)
            if char then
                state.query = state.query .. char
                refresh()
                return "continue"
            end
        end
        return "continue"
    end

    local field
    field = field_mod.new {
        type = "tree",
        options = options,
        message = options.message,
        draw_active = function(self, width, theme)
            state.width = width
            state.max_height = self.max_height
            return build(theme)
        end,
        draw_compact = function(self, theme)
            local node = current()
            local label = node and node.label or "none"
            if multi then
                local count = checked_count()
                if count == 0 then label = "none" else label = count .. " selected" end
            end
            return render.summary(theme, self.message, label)
        end,
        handle = function(self, event)
            local action, value = on_event(event)
            self.error = state.error
            return action, value
        end,
        value = function()
            if multi then return selected_values() end
            local node = current()
            if node == nil then return nil end
            return result_for(node)
        end,
        set_value = function(_, value)
            state.error = nil
            if multi then
                local values = candidate_list(value)
                local wanted = {}
                for _, candidate in ipairs(values) do
                    for _, node in ipairs(all) do
                        if not node.disabled and same_result(node, candidate) then
                            wanted[node.index] = true
                        end
                    end
                end
                state.checked = wanted
                return
            end
            for _, node in ipairs(all) do
                if not node.disabled and same_result(node, value) then
                    local parent = node.parent
                    while parent do
                        expanded[parent.index] = true
                        parent = parent.parent
                    end
                    state.selected = node.index
                    refresh()
                    return
                end
            end
        end,
        summary = function(self, theme)
            local node = current()
            local label = node and node.label or "none"
            if multi then
                local count = checked_count()
                if count == 0 then label = "none" else label = count .. " selected" end
            end
            return render.summary(theme, self.message, label)
        end,
        close = function() end,
    }

    refresh()
    if options.default ~= nil then field:set_value(options.default) end
    return field
end

function M.new_field(options, field_options)
    return make_field(options, field_options)
end

function M.run(options)
    local theme = theme_mod.build()
    local field = make_field(options)
    local packed = table.pack(input.run {
        screen = options.screen,
        commit = options.commit,
        frame = function() return field:frame(nil, theme) end,
        on_event = function(event) return field:handle(event) end,
        summary = function() return field:summary(theme) end,
        final_frame = function() return field:frame(nil, theme) end,
    })
    field:close()
    return table.unpack(packed, 1, packed.n)
end

local function fallback_tree(options)
    local roots = normalize(options.items, nil, 0)
    local all = {}
    collect(roots, all)
    local as = options.as or "value"
    local multi = options.multi == true

    local function result_for(node)
        if as == "node" then return node.source end
        if as == "path" then
            local path = {}
            local cursor = node
            while cursor do
                table.insert(path, 1, cursor.label)
                cursor = cursor.parent
            end
            return path
        end
        return node.value
    end

    local function same_result(node, candidate)
        if node.value == candidate or node.source == candidate then return true end
        return table_equal(result_for(node), candidate) or table_equal(node.value, candidate)
    end

    local minimum = options.required and math.max(1, options.min or 0) or (options.min or 0)

    local function default_problem(values)
        if not multi then return nil end
        local count = #values
        if count < minimum then
            return "Choose at least " .. minimum .. "."
        end
        if options.max and count > options.max then
            return "Choose at most " .. options.max .. "."
        end
        return nil
    end

    local function default_result()
        if options.default == nil then return nil end
        if multi then
            local values = candidate_list(options.default)
            local chosen = {}
            for _, candidate in ipairs(values) do
                for _, node in ipairs(all) do
                    if not node.disabled and same_result(node, candidate) then
                        chosen[node.index] = true
                    end
                end
            end
            if next(chosen) == nil then return nil end
            local values_out = {}
            for _, node in ipairs(all) do
                if chosen[node.index] then
                    values_out[#values_out + 1] = result_for(node)
                end
            end
            return values_out
        end
        for _, node in ipairs(all) do
            if not node.disabled and same_result(node, options.default) then
                return result_for(node)
            end
        end
        return nil
    end

    local implicit
    if not multi then
        implicit = default_result()
        if implicit == nil then
            for _, node in ipairs(all) do
                if not node.disabled then
                    implicit = result_for(node)
                    break
                end
            end
        end
    end

    io.write("? " .. options.message .. "\n")
    for _, node in ipairs(all) do
        local disabled = node.disabled and " (disabled)" or ""
        io.write(string.format("  %d) %s%s%s\n",
            node.index, string.rep("  ", node.depth), node.label, disabled))
    end

    io.write(multi and "choices: " or "choice: ")
    while true do
        local line = io.read("l")
        if line == nil then
            local policy = config.get("eof")
            if policy == "error" then
                error("prompt: end of input while waiting for an answer", 3)
            end
            if policy ~= "nil" then
                local fallback = default_result()
                if fallback ~= nil then
                    local problem = default_problem(fallback)
                    if problem then return nil, problem end
                    return fallback
                end
            end
            return nil, "eof"
        end
        io.write("\n")
        line = (line:gsub("^%s+", ""):gsub("%s+$", ""))
        if line == "" then
            local fallback = default_result()
            if fallback == nil and not multi then fallback = implicit end
            if fallback ~= nil and default_problem(fallback) == nil then
                return fallback
            end
        end
        if multi then
            local chosen = {}
            local ok = true
            if line ~= "" then
                for token in line:gmatch("[^,%s]+") do
                    local number = tonumber(token)
                    local node = number and all[number]
                    if node == nil then
                        io.write("Unknown choice '" .. token .. "'.\n")
                        ok = false
                        break
                    elseif node.disabled then
                        io.write("Choice " .. number .. " is disabled.\n")
                        ok = false
                        break
                    end
                    chosen[node.index] = true
                end
            end
            if ok then
                local count = 0
                for _ in pairs(chosen) do count = count + 1 end
                if count < minimum then
                    io.write("Choose at least " .. minimum .. ".\n")
                elseif options.max and count > options.max then
                    io.write("Choose at most " .. options.max .. ".\n")
                else
                    local values = {}
                    for _, node in ipairs(all) do
                        if chosen[node.index] then values[#values + 1] = result_for(node) end
                    end
                    return values
                end
            end
        else
            local number = tonumber(line)
            local node = number and all[number]
            if node == nil then
                io.write("Please choose one of the listed numbers.\n")
            elseif node.disabled then
                io.write("That node is disabled.\n")
            else
                return result_for(node)
            end
        end
        io.write(multi and "choices: " or "choice: ")
    end
end

function M.__call(_, options)
    if not config.is_interactive() then
        validate_options(options)
        return fallback_tree(options)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
