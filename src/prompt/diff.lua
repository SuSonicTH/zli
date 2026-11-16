-- Scrollable unified and split diff viewer.

local config = require "prompt.config"
local diffengine = require "prompt.diffengine"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local render = require "prompt.render"
local term = require "term"
local theme_mod = require "prompt.theme"

local M = {}

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.diff: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.diff: message must be a non-empty string", 3)
    end
    for _, name in ipairs { "old", "new" } do
        local value = options[name]
        if type(value) ~= "string" and type(value) ~= "table" then
            error("prompt.diff: " .. name .. " must be a string or an array of lines", 3)
        end
    end
    if options.mode ~= nil and options.mode ~= "unified" and options.mode ~= "split" then
        error("prompt.diff: mode must be 'unified' or 'split'", 3)
    end
    if options.context ~= nil and (type(options.context) ~= "number" or options.context < 0) then
        error("prompt.diff: context must be zero or positive", 3)
    end
    if options.labels ~= nil and type(options.labels) ~= "table" then
        error("prompt.diff: labels must be an array of two strings", 3)
    end
end

local function label_pair(options)
    local labels = options.labels or {}
    local old_label = labels[1] or "old"
    local new_label = labels[2] or "new"
    return tostring(old_label), tostring(new_label)
end

local function normalize_source(value)
    if type(value) == "string" then return value end
    local lines = {}
    for index, line in ipairs(value) do lines[index] = tostring(line) end
    return lines
end

local function number_width(value)
    return #tostring(value or 0)
end

local function op_text(op)
    return tostring(op.text or "")
end

local function build_unified(options, theme)
    local old_label, new_label = label_pair(options)
    local context = options.context or 3
    local ops = diffengine.diff(normalize_source(options.old), normalize_source(options.new))
    local hunks = diffengine.hunks(ops, context)

    local old_width, new_width = 1, 1
    for _, op in ipairs(ops) do
        if op.old_index and number_width(op.old_index) > old_width then
            old_width = number_width(op.old_index)
        end
        if op.new_index and number_width(op.new_index) > new_width then
            new_width = number_width(op.new_index)
        end
    end

    local lines = {
        render.line(render.span("--- ", "muted"), render.span(old_label, "removed")),
        render.line(render.span("+++ ", "muted"), render.span(new_label, "added")),
    }
    if #hunks == 0 then
        lines[#lines + 1] = render.line(render.span("  no changes", "muted"))
        return lines
    end

    for _, hunk in ipairs(hunks) do
        lines[#lines + 1] = render.line(
            render.span(string.format(
                "@@ -%d,%d +%d,%d @@",
                hunk.old_start, hunk.old_count, hunk.new_start, hunk.new_count
            ), "border")
        )
        for _, op in ipairs(hunk.lines) do
            local style = op.tag == "insert" and "added"
                or op.tag == "delete" and "removed"
                or nil
            local marker = op.tag == "insert" and "+" or op.tag == "delete" and "-" or " "
            local old_column = op.old_index and tostring(op.old_index) or ""
            local new_column = op.new_index and tostring(op.new_index) or ""
            lines[#lines + 1] = render.line(
                render.span(string.format("  %" .. old_width .. "s %" .. new_width .. "s ",
                    old_column, new_column), "muted"),
                render.span(marker .. " ", style or "muted"),
                render.span(op_text(op), style)
            )
        end
    end
    return lines
end

local function split_sign(tag)
    if tag == "insert" then return "+" end
    if tag == "delete" then return "-" end
    return " "
end

local function build_split(options, theme)
    local old_label, new_label = label_pair(options)
    local context = options.context or 3
    local ops = diffengine.diff(normalize_source(options.old), normalize_source(options.new))
    local hunks = diffengine.hunks(ops, context)

    local old_width, new_width = 1, 1
    for _, op in ipairs(ops) do
        if op.old_index and number_width(op.old_index) > old_width then
            old_width = number_width(op.old_index)
        end
        if op.new_index and number_width(op.new_index) > new_width then
            new_width = number_width(op.new_index)
        end
    end

    local size = term.size() or { columns = 80, rows = 24 }
    local columns = (options.screen_width or size.columns)
    local left_width = math.max(8, math.floor((columns - 3) / 2))
    local right_width = math.max(8, columns - left_width - 3)

    local lines = {
        render.line(
            render.pad(render.clip(render.line(render.span(old_label, "removed")), left_width, theme), left_width),
            render.span(" " .. theme.symbol("separator") .. " ", "border"),
            render.pad(render.clip(render.line(render.span(new_label, "added")), right_width, theme), right_width)
        ),
    }
    if #hunks == 0 then
        lines[#lines + 1] = render.line(render.span("  no changes", "muted"))
        return lines
    end

    local function pane(column_width, number_column, number, text, style)
        local prefix = string.format("%" .. number_column .. "s ", number or "")
        local available = math.max(1, column_width - #prefix - 2)
        local clipped = term.truncate(text, available, theme.symbol("ellipsis"))
        local spans = {
            render.span(prefix, "muted"),
            render.span(split_sign(style == "added" and "insert" or style == "removed" and "delete" or "equal"),
                style or "muted"),
            render.span(" ", style or nil),
            render.span(clipped, style),
        }
        return render.pad(spans, column_width)
    end

    for _, hunk in ipairs(hunks) do
        local header = string.format("@@ -%d,%d +%d,%d @@",
            hunk.old_start, hunk.old_count, hunk.new_start, hunk.new_count)
        lines[#lines + 1] = render.line(render.span(header, "border"))
        local index = 1
        local hunk_lines = hunk.lines
        while index <= #hunk_lines do
            local op = hunk_lines[index]
            if op.tag == "equal" then
                lines[#lines + 1] = render.line(
                    pane(left_width, old_width, op.old_index, op_text(op), nil),
                    render.span(" " .. theme.symbol("separator") .. " ", "border"),
                    pane(right_width, new_width, op.new_index, op_text(op), nil)
                )
                index = index + 1
            else
                local deletes, inserts = {}, {}
                while index <= #hunk_lines and hunk_lines[index].tag ~= "equal" do
                    local changed = hunk_lines[index]
                    if changed.tag == "delete" then
                        deletes[#deletes + 1] = changed
                    else
                        inserts[#inserts + 1] = changed
                    end
                    index = index + 1
                end
                local count = math.max(#deletes, #inserts)
                for offset = 1, count do
                    local removed = deletes[offset]
                    local added = inserts[offset]
                    lines[#lines + 1] = render.line(
                        pane(left_width, old_width, removed and removed.old_index,
                            removed and op_text(removed) or "", removed and "removed" or nil),
                        render.span(" " .. theme.symbol("separator") .. " ", "border"),
                        pane(right_width, new_width, added and added.new_index,
                            added and op_text(added) or "", added and "added" or nil)
                    )
                end
            end
        end
    end
    return lines
end

local function make_viewer(options)
    validate_options(options)
    local mode = options.mode or "unified"
    local state = {
        top = 1,
        height = 1,
        width = nil,
        max_height = nil,
        cache_width = nil,
        lines = {},
    }

    local function build(theme, columns)
        if state.cache_width ~= columns then
            local copy = {}
            for key, value in pairs(options) do copy[key] = value end
            copy.screen_width = columns
            state.lines = mode == "split" and build_split(copy, theme) or build_unified(copy, theme)
            state.cache_width = columns
        end

        local size = term.size() or { columns = 80, rows = 24 }
        local rows = state.max_height or size.rows
        local overhead = 1 + 2
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
            state.top = math.max(1, state.top - 1)
            return "continue"
        elseif input.key(event, "down") then
            state.top = math.max(1, math.min(state.top + 1, math.max(1, #state.lines - state.height + 1)))
            return "continue"
        elseif input.key(event, "home") then
            state.top = 1
            return "continue"
        elseif input.key(event, "end") then
            state.top = math.max(1, #state.lines - state.height + 1)
            return "continue"
        elseif input.key(event, "page_up") then
            state.top = math.max(1, state.top - math.max(1, state.height))
            return "continue"
        elseif input.key(event, "page_down") then
            state.top = math.max(1, math.min(
                state.top + math.max(1, state.height),
                math.max(1, #state.lines - state.height + 1)
            ))
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
    local packed = table.pack(input.run {
        screen = options.screen,
        commit = options.commit,
        frame = function()
            local size = term.size() or { columns = 80 }
            return viewer.build(theme, size.columns)
        end,
        on_event = function(event) return viewer.handle(event) end,
        summary = function() return render.status(theme, "success", "closed") end,
        final_frame = function()
            local size = term.size() or { columns = 80 }
            return viewer.build(theme, size.columns)
        end,
        eof_summary = render.status(theme, "success", "closed"),
    })
    if packed[1] == nil then return true end
    return table.unpack(packed, 1, packed.n)
end

local function fallback_diff(options)
    local old_label, new_label = label_pair(options)
    io.write("? " .. options.message .. "\n")
    local text = diffengine.unified(normalize_source(options.old), normalize_source(options.new), {
        context = options.context or 3,
        old_label = old_label,
        new_label = new_label,
    })
    if text == "" then
        io.write("no changes\n")
    else
        io.write(text)
    end
    return true
end

function M.__call(_, options)
    validate_options(options)
    if not config.is_interactive() then
        return fallback_diff(options)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
