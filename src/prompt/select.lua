-- Single and multi select lists.

local config = require "prompt.config"
local fallback = require "prompt.fallback"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local items_mod = require "prompt.items"
local list_mod = require "prompt.list"
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
    local visible = state.list.visible
    state.list:ensure_selected()
    local page = page_size_for(options, state.filter_enabled and 1 or 0)
    local selected_position = state.list:current_position()

    local lines = {}
    lines[#lines + 1] = render.line(
        render.span("? ", "accent"),
        render.span(options.message, "message")
    )

    if state.filter_enabled then
        lines[#lines + 1] = render.line(
            render.span("  filter: ", "muted"),
            render.span(state.list.query == "" and theme.symbol("ellipsis") or state.list.query, "accent")
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
        local current = item.index == state.list.selected
        local label_style = current and "selected" or (item.disabled and "muted" or nil)
        local spans = {
            render.span("  ", nil),
            render.span(current and theme.symbol("pointer") or " ", current and "selected" or "accent"),
            render.span(" ", current and "selected" or nil),
        }
        if multi then
            local checked = state.list.checked[item.index]
            local glyph_style
            if current then
                glyph_style = "selected"
            elseif checked then
                glyph_style = "accent"
            else
                glyph_style = "muted"
            end
            spans[#spans + 1] = render.span(
                checked and theme.symbol("checked") or theme.symbol("unchecked"),
                glyph_style
            )
            spans[#spans + 1] = render.span(" ", current and "selected" or nil)
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

    local help
    if multi then
        if state.filter_enabled then
            help = "space type  left/right toggle  alt+a all  alt+i invert  enter done  esc cancel"
        else
            help = "space or left/right toggle  a all  i invert  enter done  esc cancel"
        end
    else
        help = "arrows move  enter select  esc cancel"
        if state.filter_enabled then help = help .. "  type to filter" end
    end
    if state.show_help ~= false then
        lines[#lines + 1] = field_mod.help_line(help)
    end

    return render.frame(lines)
end

local function selected_label(state, multi)
    if not multi then
        local item = state.list:item_at(state.list.selected)
        return item and item.label or ""
    end

    local chosen = {}
    for _, item in ipairs(state.list.items) do
        if state.list.checked[item.index] then chosen[#chosen + 1] = item.label end
    end
    if #chosen == 0 then return "none" end
    if #chosen <= 3 then return table.concat(chosen, ", ") end
    return #chosen .. " selected"
end

local function make_field(options, multi, field_options)
    field_options = field_options or {}
    validate(options)
    if multi then
        if options.min ~= nil and (type(options.min) ~= "number" or options.min < 0) then
            error("prompt.multiselect: min must be a non-negative number", 3)
        end
        if options.max ~= nil and (type(options.max) ~= "number" or options.max < 1) then
            error("prompt.multiselect: max must be a positive number", 3)
        end
        if options.min and options.max and options.min > options.max then
            error("prompt.multiselect: min must not exceed max", 3)
        end
    end
    local items = items_mod.normalize(options.items)
    local list = list_mod.new {
        items = items,
        selected = items_mod.default_index(items, options.default, options.default_index)
            or items_mod.first_enabled(items),
        checked = items_mod.default_set(items, options.default, options.default_indices),
        height = options.page_size,
    }
    local state = {
        list = list,
        top = 1,
        error = nil,
        show_help = field_options.show_help ~= false,
    }
    state.filter_enabled = options.filter == true
        or (options.filter == "auto" and #items > options.page_size)

    local function on_event(event)
        if event.type == "paste" and state.filter_enabled then
            state.list:set_query(state.list.query .. event.text:gsub("[\r\n]+", " "))
            state.top = 1
            return "continue"
        end
        if event.type == "key" then
            if input.cancel(event) then
                if input.key(event, "esc") and state.list.query ~= "" then
                    state.list:set_query("")
                    state.error = nil
                    state.top = 1
                    return "continue"
                end
                return "cancel"
            end
            if input.enter(event) then
                local item = state.list:current()
                if item == nil then
                    state.error = "Choose an item."
                    return "continue"
                end
                if item.disabled then
                    state.error = "That item is disabled."
                    return "continue"
                end
                if multi then
                    local count = state.list:checked_count()
                    local minimum = options.required and math.max(1, options.min or 0) or (options.min or 0)
                    if count < minimum then
                        state.error = "Choose at least " .. minimum .. "."
                        return "continue"
                    end
                    if options.max and count > options.max then
                        state.error = "Choose at most " .. options.max .. "."
                        return "continue"
                    end
                    return "submit", state.list:selected_values()
                elseif options.return_index then
                    return "submit", item.index
                else
                    return "submit", item.value
                end
            end
            if input.key(event, "up")
                or (not state.filter_enabled and input.key(event, "char") and event.char == "k") then
                state.list:move(-1)
                state.error = nil
                return "continue"
            end
            if input.key(event, "down")
                or (not state.filter_enabled and input.key(event, "char") and event.char == "j") then
                state.list:move(1)
                state.error = nil
                return "continue"
            end
            if input.key(event, "home") then
                state.list:first()
                state.error = nil
                return "continue"
            end
            if input.key(event, "end") then
                state.list:last()
                state.error = nil
                return "continue"
            end
            if input.key(event, "page_up") or input.key(event, "page_down") then
                local direction = input.key(event, "page_up") and -1 or 1
                local page = page_size_for(options, state.filter_enabled and 1 or 0)
                state.list:page(direction, page)
                state.error = nil
                return "continue"
            end

            if multi then
                if input.key(event, "left") or input.key(event, "right") then
                    local item = state.list:item_at(state.list.selected)
                    if item and not item.disabled then
                        state.list:toggle(item.index)
                    end
                    state.error = nil
                    return "continue"
                end
                local all = input.ctrl(event, "a") or input.alt_char(event, "a")
                    or (not state.filter_enabled and input.key(event, "char") and event.char == "a")
                local invert = input.alt_char(event, "i")
                    or (not state.filter_enabled and input.key(event, "char") and event.char == "i")
                if not state.filter_enabled and input.key(event, "char") and event.char == " " then
                    local item = state.list:item_at(state.list.selected)
                    if item and not item.disabled then
                        state.list:toggle(item.index)
                    end
                    state.error = nil
                    return "continue"
                elseif all then
                    state.list:check_all(true)
                    state.error = nil
                    return "continue"
                elseif invert then
                    state.list:invert_all(true)
                    state.error = nil
                    return "continue"
                end
            end

            if state.filter_enabled then
                if input.key(event, "backspace") then
                    state.list:set_query(backspace(state.list.query))
                    state.top = 1
                    return "continue"
                end
                if input.ctrl(event, "u") then
                    state.list:set_query("")
                    state.top = 1
                    return "continue"
                end
                local char = input.printable(event)
                if char then
                    state.list:set_query(state.list.query .. char)
                    state.top = 1
                    return "continue"
                end
            end
        end
        return "continue"
    end

    local field
    field = field_mod.new {
        type = field_options.type or (multi and "multiselect" or "select"),
        options = options,
        message = field_options.message or options.message,
        draw_active = function(_, width, theme)
            return build(theme, options, state, multi)
        end,
        draw_compact = function(self, theme)
            return render.summary(theme, self.message, selected_label(state, multi))
        end,
        handle = function(self, event)
            local action, value = on_event(event)
            self.error = state.error
            return action, value
        end,
        value = function()
            if multi then return state.list:selected_values() end
            local item = state.list:current()
            if item == nil then return nil end
            if options.return_index then return item.index end
            return item.value
        end,
        set_value = function(_, value)
            state.error = nil
            if multi then
                local checked = {}
                local values = type(value) == "table" and value or { value }
                for _, candidate in ipairs(values) do
                    local index = items_mod.find(items, candidate)
                    if index and not items[index].disabled then checked[index] = true end
                end
                state.list.checked = checked
                state.list:refresh()
            else
                local index
                if options.return_index then
                    index = items_mod.find_index(items, value)
                end
                if index == nil then index = items_mod.find(items, value) end
                if index then state.list.selected = index end
                state.list:refresh()
            end
        end,
        summary = function(self, theme)
            return render.summary(theme, self.message, selected_label(state, multi))
        end,
        close = function() end,
    }

    local function run()
        local theme = require("prompt.theme").build()
        return input.run {
            screen = options.screen,
            commit = options.commit,
            frame = function() return field:frame(nil, theme) end,
            on_event = function(event) return field:handle(event) end,
            summary = function() return field:summary(theme) end,
            final_frame = function() return field:frame(nil, theme) end,
        }
    end
    return field, run
end

function M.select(options)
    options = options or {}
    local _, run = make_field(options, false)
    if not config.is_interactive() then
        validate(options)
        local items = items_mod.normalize(options.items)
        local selected = items_mod.default_index(items, options.default, options.default_index)
            or items_mod.first_enabled(items)
        return fallback.select(options, items, selected)
    end
    return run()
end

function M.multiselect(options)
    options = options or {}
    local _, run = make_field(options, true)
    if not config.is_interactive() then
        validate(options)
        local items = items_mod.normalize(options.items)
        local checked = items_mod.default_set(items, options.default, options.default_indices)
        options.has_default = options.default ~= nil or options.default_indices ~= nil or items_mod.has_checked(items)
        return fallback.multiselect(options, items, checked)
    end
    return run()
end

--- Build a reusable select or multiselect field for `prompt.form`.
-- `field_options.multi = true` creates a multiselect field.  A boolean second
-- argument is accepted for compatibility with earlier internal callers.
function M.new_field(options, field_options)
    if type(field_options) == "boolean" then
        field_options = { multi = field_options }
    end
    field_options = field_options or {}
    local field = make_field(options or {}, field_options.multi == true, field_options)
    return field
end

return M
