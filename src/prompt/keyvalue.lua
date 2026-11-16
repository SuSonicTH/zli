-- Scrollable key/value viewer.

local config = require "prompt.config"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local render = require "prompt.render"
local term = require "term"
local theme_mod = require "prompt.theme"

local M = {}

local function describe(value)
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then
        return tostring(value)
    end
    if value == nil then return "nil" end
    if kind == "table" then
        local parts = {}
        for key, item in pairs(value) do
            parts[#parts + 1] = tostring(key) .. "=" .. tostring(item)
        end
        table.sort(parts)
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return tostring(value)
end

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.keyvalue: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.keyvalue: message must be a non-empty string", 3)
    end
    if type(options.data) ~= "table" then
        error("prompt.keyvalue: data must be a table", 3)
    end
    if options.order ~= nil and type(options.order) ~= "table" then
        error("prompt.keyvalue: order must be an array of keys", 3)
    end
    if options.wrap ~= nil and type(options.wrap) ~= "boolean" then
        error("prompt.keyvalue: wrap must be a boolean", 3)
    end
    if options.format ~= nil and type(options.format) ~= "function" then
        error("prompt.keyvalue: format must be a function", 3)
    end
end

local function sorted_keys(data)
    local keys = {}
    for key in pairs(data) do keys[#keys + 1] = key end
    local rank = { number = 1, string = 2, boolean = 3 }
    table.sort(keys, function(left, right)
        local left_type, right_type = type(left), type(right)
        if left_type == right_type and (left_type == "number" or left_type == "string") then
            return left < right
        end
        local left_rank = rank[left_type] or 4
        local right_rank = rank[right_type] or 4
        if left_rank ~= right_rank then return left_rank < right_rank end
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function ordered_keys(options)
    local data = options.data
    if options.order == nil then return sorted_keys(data) end
    local keys = {}
    local seen = {}
    for _, key in ipairs(options.order) do
        if data[key] ~= nil and not seen[key] then
            keys[#keys + 1] = key
            seen[key] = true
        end
    end
    return keys
end

local function value_text(options, key)
    local value = options.data[key]
    if options.format then
        local formatted = options.format(value, key)
        if formatted == nil then return "" end
        return tostring(formatted)
    end
    return describe(value)
end

local function build_lines(options, columns, theme)
    local keys = ordered_keys(options)
    local key_width = 1
    for _, key in ipairs(keys) do
        local width = term.width(tostring(key))
        if width > key_width then key_width = width end
    end
    key_width = math.min(key_width, math.max(1, math.floor(columns * 0.4)))

    local wrap = options.wrap ~= false
    local value_width = math.max(1, columns - 2 - key_width - 2)
    local lines = {}
    for _, key in ipairs(keys) do
        local text = value_text(options, key)
        local label = tostring(key) .. ":"
        local prefix_width = key_width + 2
        local wrapped
        if wrap then
            wrapped = render.wrap_spans({ render.span(text) }, value_width)
        else
            wrapped = {}
            for line in (text .. "\n"):gmatch("(.-)\n") do
                wrapped[#wrapped + 1] = { render.span(line) }
            end
            if #wrapped == 0 then wrapped[1] = {} end
        end

        local label_style = "accent"
        for index, value_line in ipairs(wrapped) do
            local spans = { render.span("  ", nil) }
            if index == 1 then
                spans[#spans + 1] = render.span(label, label_style)
                local gap = prefix_width - term.width(label)
                if gap > 0 then spans[#spans + 1] = render.span(string.rep(" ", gap)) end
            else
                spans[#spans + 1] = render.span(string.rep(" ", prefix_width))
            end
            for _, span in ipairs(value_line) do spans[#spans + 1] = span end
            lines[#lines + 1] = render.clip(spans, columns, theme)
        end
    end
    return lines, keys
end

local function make_viewer(options)
    validate_options(options)
    local show_help = true
    local state = {
        top = 1,
        height = 1,
        width = nil,
        max_height = nil,
        cache_width = nil,
        lines = {},
        keys = {},
    }

    local function refresh(columns, theme)
        local width = columns or (term.size() and term.size().columns) or 80
        if state.cache_width ~= width then
            state.lines, state.keys = build_lines(options, width, theme)
            state.cache_width = width
        end
    end

    local function scroll_by(delta)
        local total = #state.lines
        state.top = math.max(1, math.min(state.top + delta, math.max(1, total - state.height + 1)))
    end

    local function build(theme)
        local size = term.size() or { columns = 80, rows = 24 }
        local columns = state.width or size.columns
        local rows = state.max_height or size.rows
        refresh(columns, theme)
        if #state.lines == 0 then
            state.lines = { render.line(render.span("  no entries", "muted")) }
        end

        local overhead = 1 + (show_help and 1 or 0) + 1
        local available = math.max(1, rows - overhead)
        local total = #state.lines
        local body_height
        if total > available then
            body_height = math.max(1, available - 2)
        else
            body_height = math.max(1, total)
        end
        state.height = body_height
        state.top = math.max(1, math.min(state.top, math.max(1, total - body_height + 1)))

        local visible, _, last = render.viewport(state.lines, state.top, body_height)
        local lines = {
            render.line(render.span("? ", "accent"), render.span(options.message, "message")),
        }
        if state.top > 1 then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_up") .. " more", "muted")
            )
        end
        for _, line in ipairs(visible) do lines[#lines + 1] = line end
        if last < total then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_down") .. " more", "muted")
            )
        end
        lines[#lines + 1] = field_mod.help_line(
            total > body_height
                and "arrows scroll  page up/down  home/end  enter/q/esc close"
                or "enter/q/esc closes"
        )
        return render.frame(lines)
    end

    local function on_event(event)
        if event.type ~= "key" then return "continue" end
        local quit = input.key(event, "q")
            or (input.key(event, "char") and event.char == "q")
        if input.cancel(event) then return "submit", true end
        if quit then return "submit", true end
        if input.key(event, "up") then
            scroll_by(-1)
            return "continue"
        elseif input.key(event, "down") then
            scroll_by(1)
            return "continue"
        elseif input.key(event, "home") then
            state.top = 1
            return "continue"
        elseif input.key(event, "end") then
            state.top = math.max(1, #state.lines - state.height + 1)
            return "continue"
        elseif input.key(event, "page_up") then
            scroll_by(-math.max(1, state.height))
            return "continue"
        elseif input.key(event, "page_down") then
            scroll_by(math.max(1, state.height))
            return "continue"
        elseif input.enter(event) then
            return "submit", true
        end
        return "continue"
    end

    return {
        handle = on_event,
        build = build,
        set_width = function(width) state.width = width end,
        set_max_height = function(height) state.max_height = height end,
    }
end

function M.run(options)
    local theme = theme_mod.build()
    local viewer = make_viewer(options)
    local render_frame = function()
        return viewer.build(theme)
    end
    local packed = table.pack(input.run {
        screen = options.screen,
        commit = options.commit,
        frame = function()
            viewer.set_max_height(nil)
            return render_frame()
        end,
        on_event = function(event) return viewer.handle(event) end,
        summary = function() return render.status(theme, "success", "closed") end,
        final_frame = render_frame,
        eof_summary = render.status(theme, "success", "closed"),
    })
    if packed[1] == nil then return true end
    return table.unpack(packed, 1, packed.n)
end

local function fallback_keyvalue(options)
    io.write("? " .. options.message .. "\n")
    for _, key in ipairs(ordered_keys(options)) do
        io.write(tostring(key) .. ": " .. value_text(options, key) .. "\n")
    end
    return true
end

function M.__call(_, options)
    validate_options(options)
    if not config.is_interactive() then
        return fallback_keyvalue(options)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
