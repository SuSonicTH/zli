-- Single and multi select lists.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local input = require "prompt.input"
local items_mod = require "prompt.items"
local render = require "prompt.render"

local M = {}

local function positive(value, name, default)
    if value == nil then return default end
    if type(value) ~= "number" or value < 1 then
        error("prompt: " .. name .. " must be a positive number", 3)
    end
    return math.floor(value)
end

local function validate(options)
    if type(options) ~= "table" then
        error("prompt: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt: message must be a non-empty string", 3)
    end
    options.page_size = positive(options.page_size, "page_size", config.get("page_size"))
    if options.filter ~= nil and options.filter ~= true and options.filter ~= false and options.filter ~= "auto" then
        error("prompt: filter must be true, false or 'auto'", 3)
    end
end

local function backspace(text)
    local offset = utf8.offset(text, -1)
    if offset == nil or offset <= 1 then return "" end
    return text:sub(1, offset - 1)
end

local function first_enabled(visible)
    for position, item in ipairs(visible) do
        if not item.disabled then return position end
    end
    return nil
end

local function position_of(visible, index)
    if index == nil then return nil end
    for position, item in ipairs(visible) do
        if item.index == index then return position end
    end
    return nil
end

local function move(visible, selected, delta)
    if #visible == 0 then return selected end
    local position = position_of(visible, selected) or (delta > 0 and 0 or #visible + 1)
    local candidate = position
    for _ = 1, #visible do
        candidate = candidate + delta
        if candidate > #visible then candidate = 1 end
        if candidate < 1 then candidate = #visible end
        local item = visible[candidate]
        if not item.disabled then return item.index end
    end
    return selected
end

local function term_size()
    local term = require "term"
    local size = term.size()
    if not size then return { columns = 80, rows = 24 } end
    return size
end

local function page_size_for(options, extra)
    local size = term_size()
    local overhead = 4 + (extra or 0)
    return math.max(3, math.min(options.page_size, size.rows - 1 - overhead))
end

local function build(theme, options, state, multi)
    local visible = items_mod.filter(state.items, state.query)
    state.visible = visible
    local page = page_size_for(options, state.filter_enabled and 1 or 0)
    local selected_position = position_of(visible, state.selected)
    if selected_position == nil then
        state.selected = first_enabled(visible) and visible[first_enabled(visible)].index or nil
        selected_position = position_of(visible, state.selected)
    end

    local lines = {}
    lines[#lines + 1] = render.line(
        render.span("? ", "accent"),
        render.span(options.message, "message")
    )

    if state.filter_enabled then
        lines[#lines + 1] = render.line(
            render.span("  filter: ", "muted"),
            render.span(state.query == "" and theme.symbol("ellipsis") or state.query, "accent")
        )
    end

    local top = state.top or 1
    if selected_position then
        if selected_position < top then top = selected_position end
        if selected_position >= top + page then top = selected_position - page + 1 end
    end
    top = math.max(1, math.min(top, math.max(1, #visible - page + 1)))
    state.top = top

    local has_above = top > 1
    local has_below = top + page - 1 < #visible
    if has_above then
        lines[#lines + 1] = render.line(render.span("  " .. theme.symbol("arrow_up") .. " more", "muted"))
    end

    for position = top, math.min(#visible, top + page - 1) do
        local item = visible[position]
        local current = item.index == state.selected
        local label_style = current and "selected" or (item.disabled and "muted" or nil)
        local spans = { render.span("  " .. (current and theme.symbol("pointer") or " ") .. " ", "accent") }
        if multi then
            local checked = state.checked[item.index]
            spans[#spans + 1] = render.span(
                checked and theme.symbol("checked") or theme.symbol("unchecked"),
                checked and (current and "selected" or "accent") or "muted"
            )
            spans[#spans + 1] = render.span(" ", nil)
        end
        spans[#spans + 1] = render.span(item.label, label_style)
        if item.description then
            spans[#spans + 1] = render.span("  " .. item.description, current and "selected_muted" or "muted")
        end
        if item.disabled then
            spans[#spans + 1] = render.span(" (disabled)", "muted")
        end
        lines[#lines + 1] = spans
    end

    if has_below then
        lines[#lines + 1] = render.line(render.span("  " .. theme.symbol("arrow_down") .. " more", "muted"))
    end
    if #visible == 0 then
        lines[#lines + 1] = render.line(render.span("  no matches", "muted"))
    end

    if state.error then
        lines[#lines + 1] = render.line(render.span(state.error, "error"))
    end

    local help
    if multi then
        help = "space toggle  a all  i invert  enter done  esc cancel"
        if state.filter_enabled then help = help .. "  type to filter" end
    else
        help = "arrows move  enter select  esc cancel"
        if state.filter_enabled then help = help .. "  type to filter" end
    end
    lines[#lines + 1] = render.line(render.span(help, "muted"))

    return render.frame(lines)
end

local function selected_label(state, multi)
    local chosen = {}
    for _, item in ipairs(state.items) do
        if multi and state.checked[item.index] then chosen[#chosen + 1] = item.label end
        if not multi and item.index == state.selected then return item.label end
    end
    if not multi then return "" end
    if #chosen == 0 then return "none" end
    if #chosen <= 3 then return table.concat(chosen, ", ") end
    return #chosen .. " selected"
end

local function make_runner(options, multi)
    validate(options)
    local items = items_mod.normalize(options.items)
    local state = {
        items = items,
        query = "",
        selected = items_mod.default_index(items, options.default, options.default_index) or items_mod.first_enabled(items),
        checked = items_mod.default_set(items, options.default, options.default_indices),
        top = 1,
        error = nil,
    }
    state.filter_enabled = options.filter == true or (options.filter == "auto" and #items > options.page_size)

    local function update_selection()
        local visible = items_mod.filter(items, state.query)
        if position_of(visible, state.selected) == nil then
            state.selected = first_enabled(visible) and visible[first_enabled(visible)].index or nil
        end
    end

    local function on_event(event)
        if event.type == "key" then
            if input.cancel(event) then
                if input.key(event, "esc") and state.query ~= "" then
                    state.query = ""
                    state.error = nil
                    update_selection()
                    return "continue"
                end
                return "cancel"
            end
            if input.enter(event) then
                local visible = state.visible or items_mod.filter(items, state.query)
                local current = state.selected
                local item
                for _, candidate in ipairs(visible) do
                    if candidate.index == current then item = candidate break end
                end
                if item == nil then
                    state.error = "Choose an item."
                    return "continue"
                end
                if item.disabled then
                    state.error = "That item is disabled."
                    return "continue"
                end
                if multi then
                    local count = 0
                    for _ in pairs(state.checked) do count = count + 1 end
                    local minimum = options.required and math.max(1, options.min or 0) or (options.min or 0)
                    if count < minimum then
                        state.error = "Choose at least " .. minimum .. "."
                        return "continue"
                    end
                    if options.max and count > options.max then
                        state.error = "Choose at most " .. options.max .. "."
                        return "continue"
                    end
                    return "submit", items_mod.selected_values(items, state.checked)
                elseif options.return_index then
                    return "submit", item.index
                else
                    return "submit", item.value
                end
            end
            if input.key(event, "up") or (not state.filter_enabled and input.key(event, "char") and event.char == "k") then
                state.selected = move(items_mod.filter(items, state.query), state.selected, -1)
                state.error = nil
                return "continue"
            end
            if input.key(event, "down") or (not state.filter_enabled and input.key(event, "char") and event.char == "j") then
                state.selected = move(items_mod.filter(items, state.query), state.selected, 1)
                state.error = nil
                return "continue"
            end
            if input.key(event, "home") then
                local visible = items_mod.filter(items, state.query)
                state.selected = visible[first_enabled(visible) or 1] and visible[first_enabled(visible) or 1].index
                state.error = nil
                return "continue"
            end
            if input.key(event, "end") then
                local visible = items_mod.filter(items, state.query)
                for position = #visible, 1, -1 do
                    if not visible[position].disabled then
                        state.selected = visible[position].index
                        break
                    end
                end
                state.error = nil
                return "continue"
            end
            if input.key(event, "page_up") or input.key(event, "page_down") then
                local direction = input.key(event, "page_up") and -1 or 1
                local page = page_size_for(options, state.filter_enabled and 1 or 0)
                local visible = items_mod.filter(items, state.query)
                local position = position_of(visible, state.selected) or 1
                local target = math.max(1, math.min(#visible, position + direction * page))
                for offset = 0, #visible do
                    local candidate = target + offset * direction
                    if candidate < 1 or candidate > #visible then break end
                    if not visible[candidate].disabled then
                        state.selected = visible[candidate].index
                        break
                    end
                end
                state.error = nil
                return "continue"
            end

            if multi then
                local all = input.ctrl(event, "a") or (not state.filter_enabled and input.key(event, "char") and event.char == "a")
                local invert = input.ctrl(event, "i") or (not state.filter_enabled and input.key(event, "char") and event.char == "i")
                if input.key(event, "char") and event.char == " " then
                    local item
                    for _, candidate in ipairs(state.items) do
                        if candidate.index == state.selected then item = candidate break end
                    end
                    if item and not item.disabled then
                        state.checked[item.index] = not state.checked[item.index] or nil
                    end
                    state.error = nil
                    return "continue"
                elseif all then
                    for _, item in ipairs(items_mod.filter(items, state.query)) do
                        if not item.disabled then state.checked[item.index] = true end
                    end
                    state.error = nil
                    return "continue"
                elseif invert then
                    for _, item in ipairs(items_mod.filter(items, state.query)) do
                        if not item.disabled then
                            state.checked[item.index] = not state.checked[item.index] or nil
                        end
                    end
                    state.error = nil
                    return "continue"
                end
            end

            if state.filter_enabled then
                if input.key(event, "backspace") then
                    state.query = backspace(state.query)
                    state.top = 1
                    update_selection()
                    return "continue"
                end
                if input.ctrl(event, "u") then
                    state.query = ""
                    state.top = 1
                    update_selection()
                    return "continue"
                end
                local char = input.printable(event)
                if char then
                    state.query = state.query .. char
                    state.top = 1
                    update_selection()
                    return "continue"
                end
            end
        end
        return "continue"
    end

    return function()
        local theme = require("prompt.theme").build()
        return input.run {
            screen = options.screen,
            commit = options.commit,
            frame = function() return build(theme, options, state, multi) end,
            on_event = on_event,
            summary = function()
                return render.summary(theme, options.message, selected_label(state, multi))
            end,
            final_frame = function() return build(theme, options, state, multi) end,
        }
    end
end

function M.select(options)
    options = options or {}
    local run = make_runner(options, false)
    if not config.is_interactive() then
        validate(options)
        local items = items_mod.normalize(options.items)
        local selected = items_mod.default_index(items, options.default, options.default_index) or items_mod.first_enabled(items)
        return fallback.select(options, items, selected)
    end
    return run()
end

function M.multiselect(options)
    options = options or {}
    local run = make_runner(options, true)
    if not config.is_interactive() then
        validate(options)
        local items = items_mod.normalize(options.items)
        local checked = items_mod.default_set(items, options.default, options.default_indices)
        options.has_default = options.default ~= nil or options.default_indices ~= nil
        return fallback.multiselect(options, items, checked)
    end
    return run()
end

return M
