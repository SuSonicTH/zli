-- Interactive file and directory picker with an optional text preview.

local config = require "prompt.config"
local field_mod = require "prompt.field"
local input = require "prompt.input"
local render = require "prompt.render"
local scroll = require "prompt.scroll"
local term = require "term"
local theme_mod = require "prompt.theme"

local filesystem = require "filesystem"

local M = {}

local separator = filesystem.separator or "/"
local preview_bytes = 8192

local function expand_home(path)
    path = tostring(path or "")
    if path == "~" then
        return os.getenv("HOME") or os.getenv("USERPROFILE") or path
    end
    if path:sub(1, 2) == "~/" or path:sub(1, 2) == "~\\" then
        local home = os.getenv("HOME") or os.getenv("USERPROFILE")
        if home then return home .. path:sub(2) end
    end
    return path
end

local function basename(path)
    local name = tostring(path or ""):gsub("[/\\]+$", ""):match("[^/\\]+$")
    return name or tostring(path or "")
end

local function join_path(base, name)
    if base == nil or base == "" then return name end
    return filesystem.concat_path(base, name)
end

local function is_hidden(name)
    return name:sub(1, 1) == "."
end

local function path_is_absolute(path)
    return path:sub(1, 1) == "/"
        or path:sub(1, 1) == "\\"
        or path:match("^%a:[/\\]") ~= nil
end

local function resolve_input(path, base)
    local expanded = expand_home(path)
    if path_is_absolute(expanded) then
        return filesystem.absolute(expanded)
    end
    return filesystem.absolute(join_path(base, expanded))
end

local function glob_pattern(glob)
    local pattern = "^"
    for index = 1, #glob do
        local char = glob:sub(index, index)
        if char == "*" then
            pattern = pattern .. ".*"
        elseif char == "?" then
            pattern = pattern .. "."
        elseif char:match("[%^%$%(%)%%%.%[%]%+%-%{%}%|\\]") then
            pattern = pattern .. "%" .. char
        else
            pattern = pattern .. char
        end
    end
    return pattern .. "$"
end

local function matches_filter(name, filter)
    if filter == nil or #filter == 0 then return true end
    local candidate = os.is_windows and name:lower() or name
    for _, glob in ipairs(filter) do
        local pattern = glob_pattern(os.is_windows and glob:lower() or glob)
        if candidate:match(pattern) then return true end
    end
    return false
end

local function normalize_filter(filter)
    if filter == nil then return nil end
    if type(filter) == "string" then return { filter } end
    if type(filter) ~= "table" then
        error("prompt.file: filter must be a glob string or an array of globs", 3)
    end
    local result = {}
    for index, value in ipairs(filter) do
        if type(value) ~= "string" or value == "" then
            error("prompt.file: filter " .. index .. " must be a non-empty string", 3)
        end
        result[#result + 1] = value
    end
    return result
end

local function validate_options(options)
    if type(options) ~= "table" then
        error("prompt.file: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.file: message must be a non-empty string", 3)
    end
    if options.start ~= nil and type(options.start) ~= "string" then
        error("prompt.file: start must be a path string", 3)
    end
    if options.mode ~= nil
        and options.mode ~= "file"
        and options.mode ~= "directory"
        and options.mode ~= "any"
    then
        error("prompt.file: mode must be 'file', 'directory' or 'any'", 3)
    end
    for _, name in ipairs { "show_hidden", "multi", "preview", "absolute" } do
        if options[name] ~= nil and type(options[name]) ~= "boolean" then
            error("prompt.file: " .. name .. " must be a boolean", 3)
        end
    end
    normalize_filter(options.filter)
end

local function path_object(path)
    local ok, object = pcall(filesystem.path, path)
    if not ok or object == nil then return nil end
    return object
end

local function kind_of(path)
    local object = path_object(path)
    if object == nil then return nil end
    local ok_dir, is_dir = pcall(function() return object:is_directory() end)
    if ok_dir and is_dir then return "directory" end
    local ok_file, is_file = pcall(function() return object:is_file() end)
    if ok_file and is_file then return "file" end
    return nil
end

local function resolve_start(start)
    if start == nil or start == "" then start = "." end
    local absolute = filesystem.absolute(expand_home(start))
    if absolute == nil then
        error("prompt.file: start directory does not exist: " .. tostring(start), 3)
    end
    local kind = kind_of(absolute)
    if kind == "file" then
        local parent = filesystem.parent(absolute)
        return parent and parent.full_path or absolute, basename(absolute)
    end
    return absolute, nil
end

local function strip_directory_separator(path)
    if path == "/" or path == "\\" then return path end
    if path:match("^%a:[/\\]$") then return path end
    local stripped = path:gsub("[/\\]+$", "")
    if stripped == "" then return path end
    return stripped
end

local function relative_result(absolute, base, is_directory)
    if is_directory then
        absolute = strip_directory_separator(absolute)
    end
    if absolute == base then return "." end
    local ok, relative = pcall(filesystem.to_relative, absolute, base)
    if ok and relative and relative ~= "" then return relative end
    return absolute
end

local function result_path(absolute, base, absolute_enabled, is_directory)
    if absolute_enabled then return absolute end
    return relative_result(absolute, base, is_directory)
end

local function list_directory(path)
    local ok, entries = pcall(filesystem.list, path)
    if not ok or type(entries) ~= "table" then return nil end
    return entries
end

local function entry_name(entry)
    if entry.name ~= nil and entry.name ~= "" then return tostring(entry.name) end
    return basename(entry.full_path)
end

local function read_entries(path, hidden, filter)
    local listed = list_directory(path)
    if listed == nil then return nil end
    local entries = {}
    for _, item in ipairs(listed) do
        local name = entry_name(item)
        local is_directory = false
        local ok, result = pcall(function() return item:is_directory() end)
        if ok then is_directory = result end
        local allowed = hidden or not is_hidden(name)
        if allowed and not is_directory then
            allowed = matches_filter(name, filter)
        end
        if allowed then
            entries[#entries + 1] = {
                name = name,
                label = is_directory and (name .. separator) or name,
                full_path = item.full_path,
                is_directory = is_directory,
            }
        end
    end
    table.sort(entries, function(left, right)
        if left.is_directory ~= right.is_directory then return left.is_directory end
        local a, b = left.name:lower(), right.name:lower()
        if a == b then return left.name < right.name end
        return a < b
    end)
    return entries
end

local function looks_binary(data)
    if data:find("\0", 1, true) then return true end
    local control = 0
    for index = 1, #data do
        local byte = data:byte(index)
        if byte < 9 or (byte > 13 and byte < 32) or byte == 127 then
            control = control + 1
        end
    end
    return #data > 0 and control / #data > 0.05
end

local function split_lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = line end
    return lines
end

local function read_preview(entry, width, height, theme, hidden)
    local lines = {}
    if entry == nil then return lines end
    if entry.is_directory then
        lines[#lines + 1] = render.line(render.span("directory", "accent"))
        local children = list_directory(entry.full_path) or {}
        local names = {}
        for _, child in ipairs(children) do
            local name = entry_name(child)
            if hidden or not is_hidden(name) then names[#names + 1] = name end
        end
        table.sort(names, function(left, right)
            local a, b = left:lower(), right:lower()
            if a == b then return left < right end
            return a < b
        end)
        for index = 1, math.min(#names, math.max(0, height - 1)) do
            lines[#lines + 1] = render.line(render.span("  " .. term.truncate(
                names[index], math.max(1, width - 2), theme.symbol("ellipsis")
            ), "muted"))
        end
        return lines
    end

    local ok, file = pcall(io.open, entry.full_path, "rb")
    if not ok or not file then
        lines[1] = render.line(render.span("cannot read file", "muted"))
        return lines
    end
    local data = file:read(preview_bytes) or ""
    file:close()
    if data == "" then
        lines[1] = render.line(render.span("empty file", "muted"))
        return lines
    end
    if looks_binary(data) then
        lines[1] = render.line(render.span("binary file", "muted"))
        return lines
    end

    local text_lines = split_lines(data)
    for index = 1, math.min(#text_lines, height) do
        local text = text_lines[index]:gsub("\t", "    ")
        lines[#lines + 1] = render.line(render.span(
            term.truncate(text, math.max(1, width), theme.symbol("ellipsis"))
        ))
    end
    if #data >= preview_bytes and #lines < height then
        lines[#lines + 1] = render.line(render.span(theme.symbol("ellipsis"), "muted"))
    end
    return lines
end

local function make_field(options, field_options)
    field_options = field_options or {}
    validate_options(options)
    local show_help = field_options.show_help ~= false
    local filter = normalize_filter(options.filter)
    local mode = options.mode or "file"
    local multi = options.multi == true
    local absolute_enabled = options.absolute == true
    local preview_enabled = options.preview ~= false
    local base, initial_name = resolve_start(options.start)

    local state = {
        current = base,
        entries = {},
        selected = 1,
        checked = {},
        check_order = {},
        show_hidden = options.show_hidden == true,
        path_mode = false,
        path_text = "",
        error = nil,
        top = 1,
        height = 1,
        width = nil,
        max_height = nil,
        preview_key = nil,
        preview_lines = {},
    }

    local scroller = scroll.new { rows = 1, height = 1 }

    local function selected_entry()
        return state.entries[state.selected]
    end

    local function checked_count()
        return #state.check_order
    end

    local function checked_results()
        local values = {}
        for _, path in ipairs(state.check_order) do
            local entry = state.checked[path]
            if entry then
                values[#values + 1] = result_path(
                    entry.full_path, base, absolute_enabled, entry.is_directory
                )
            end
        end
        return values
    end

    local function mode_allows(entry)
        if entry.is_directory then return mode ~= "file" end
        return mode ~= "directory"
    end

    local function select_name(name)
        if name == nil then return end
        for index, entry in ipairs(state.entries) do
            if entry.name == name then
                state.selected = index
                return
            end
        end
        state.selected = 1
    end

    local function load(preferred)
        local entries = read_entries(state.current, state.show_hidden, filter)
        state.error = nil
        if entries == nil then
            state.entries = {}
            state.selected = 1
            state.error = "Cannot open " .. tostring(state.current)
            return false
        end
        state.entries = entries
        state.selected = math.max(1, math.min(state.selected, #entries))
        state.preview_key = nil
        select_name(preferred)
        return true
    end

    local function navigate(path, preferred)
        state.current = path
        state.top = 1
        state.selected = 1
        load(preferred)
    end

    local function up()
        local parent = filesystem.parent(state.current)
        if parent == nil then return end
        navigate(parent.full_path, basename(state.current))
    end

    local function toggle_checked()
        local entry = selected_entry()
        if entry == nil or not mode_allows(entry) then return end
        local key = entry.full_path
        if state.checked[key] then
            state.checked[key] = nil
            for index, value in ipairs(state.check_order) do
                if value == key then
                    table.remove(state.check_order, index)
                    break
                end
            end
        else
            state.checked[key] = entry
            state.check_order[#state.check_order + 1] = key
        end
    end

    local function activate(entry)
        if entry == nil then
            state.error = "No entries."
            return "continue"
        end
        if entry.is_directory then
            if mode == "file" then
                navigate(entry.full_path)
                return "continue"
            end
            if multi and checked_count() > 0 then
                return "submit", checked_results()
            end
            return "submit", result_path(entry.full_path, base, absolute_enabled, true)
        end
        if multi and checked_count() > 0 then
            return "submit", checked_results()
        end
        if mode == "directory" then
            state.error = "Choose a directory."
            return "continue"
        end
        return "submit", result_path(entry.full_path, base, absolute_enabled, false)
    end

    local function complete_path()
        local text = expand_home(state.path_text)
        local directory, partial = text:match("^(.*[/\\])([^/\\]*)$")
        if directory == nil then
            directory = ""
            partial = text
        end
        local listed = list_directory(resolve_input(
            directory == "" and "." or directory, state.current
        ))
        if listed == nil then return end
        local candidates = {}
        local lowered = os.is_windows and partial:lower() or partial
        for _, item in ipairs(listed) do
            local name = entry_name(item)
            local candidate = os.is_windows and name:lower() or name
            if candidate:sub(1, #lowered) == lowered then
                local ok, is_directory = pcall(function() return item:is_directory() end)
                candidates[#candidates + 1] = name .. (ok and is_directory and separator or "")
            end
        end
        if #candidates == 0 then return end
        table.sort(candidates, function(left, right)
            local a, b = left:lower(), right:lower()
            if a == b then return left < right end
            return a < b
        end)
        if #candidates == 1 then
            state.path_text = directory .. candidates[1]
            return
        end
        local prefix = candidates[1]
        for index = 2, #candidates do
            local other = candidates[index]
            local length = math.min(#prefix, #other)
            local position = 1
            while position <= length and prefix:byte(position) == other:byte(position) do
                position = position + 1
            end
            -- Do not cut a multibyte UTF-8 sequence in half.
            while position > 1 do
                local byte = prefix:byte(position)
                if byte == nil or byte < 0x80 or byte >= 0xC0 then break end
                position = position - 1
            end
            prefix = prefix:sub(1, position - 1)
        end
        if #prefix > #partial then
            state.path_text = directory .. prefix
        end
    end

    local function open_path()
        local text = expand_home(state.path_text)
        local absolute = resolve_input(text, state.current)
        if absolute == nil then
            state.error = "Path not found: " .. text
            return "continue"
        end
        local kind = kind_of(absolute)
        if kind == "directory" then
            state.path_mode = false
            if mode == "file" then
                navigate(absolute)
                state.path_text = ""
                return "continue"
            end
            return "submit", result_path(absolute, base, absolute_enabled, true)
        elseif kind == "file" then
            if mode == "directory" then
                state.error = "Choose a directory."
                return "continue"
            end
            local name = basename(absolute)
            if not matches_filter(name, filter) then
                state.error = "File does not match the filter: " .. name
                return "continue"
            end
            state.path_mode = false
            return "submit", result_path(absolute, base, absolute_enabled, false)
        end
        state.error = "Not a file or directory: " .. text
        return "continue"
    end

    local function on_path_event(event)
        if event.type == "paste" then
            state.error = nil
            state.path_text = state.path_text .. event.text:gsub("[\r\n]+", "")
            return "continue"
        end
        if event.type ~= "key" then return "continue" end
        state.error = nil
        if input.ctrl(event, "c") then return "cancel" end
        if input.key(event, "esc") then
            state.path_mode = false
            state.path_text = ""
            state.error = nil
            return "continue"
        elseif input.key(event, "tab") then
            complete_path()
            return "continue"
        elseif input.key(event, "backspace") then
            local offset = utf8.offset(state.path_text, -1)
            if offset == nil or offset <= 1 then
                state.path_text = ""
            else
                state.path_text = state.path_text:sub(1, offset - 1)
            end
            return "continue"
        elseif input.ctrl(event, "u") then
            state.path_text = ""
            return "continue"
        elseif input.enter(event) then
            local action, value = open_path()
            return action, value
        end
        local char = input.printable(event)
        if char then
            state.path_text = state.path_text .. char
            return "continue"
        end
        return "continue"
    end

    local function on_event(event)
        if state.path_mode then return on_path_event(event) end
        if event.type ~= "key" then return "continue" end
        if input.cancel(event) then return "cancel" end
        state.error = nil

        if input.key(event, "up") then
            if #state.entries > 0 then
                state.selected = state.selected - 1
                if state.selected < 1 then state.selected = #state.entries end
            end
            return "continue"
        elseif input.key(event, "down") then
            if #state.entries > 0 then
                state.selected = state.selected + 1
                if state.selected > #state.entries then state.selected = 1 end
            end
            return "continue"
        elseif input.key(event, "home") then
            state.selected = 1
            return "continue"
        elseif input.key(event, "end") then
            state.selected = #state.entries
            return "continue"
        elseif input.key(event, "page_up") then
            state.selected = math.max(1, state.selected - math.max(1, state.height))
            return "continue"
        elseif input.key(event, "page_down") then
            state.selected = math.min(#state.entries, state.selected + math.max(1, state.height))
            if state.selected < 1 then state.selected = 1 end
            return "continue"
        elseif input.key(event, "left") or input.key(event, "backspace") then
            up()
            return "continue"
        elseif input.key(event, "right") then
            local entry = selected_entry()
            if entry and entry.is_directory then navigate(entry.full_path) end
            return "continue"
        elseif input.enter(event) then
            return activate(selected_entry())
        elseif input.key(event, "char") and event.char == " " then
            if multi then toggle_checked() end
            return "continue"
        elseif input.key(event, "char") and event.char == "/" then
            state.path_mode = true
            state.path_text = ""
            state.error = nil
            return "continue"
        elseif input.key(event, "char") and event.char == "h" then
            state.show_hidden = not state.show_hidden
            local preferred = selected_entry() and selected_entry().name or nil
            load(preferred)
            return "continue"
        end
        return "continue"
    end

    local function preview_for(entry, width, height, theme)
        if not preview_enabled or entry == nil or width < 1 or height < 1 then return {} end
        local key = table.concat({
            entry.full_path, tostring(width), tostring(height), tostring(theme.unicode),
            tostring(state.show_hidden),
        }, "\0")
        if state.preview_key == key then return state.preview_lines end
        state.preview_lines = read_preview(entry, width, height, theme, state.show_hidden)
        state.preview_key = key
        return state.preview_lines
    end

    local function build(theme)
        local size = term.size() or { columns = 80, rows = 24 }
        local columns = state.width or size.columns
        local rows = state.max_height or size.rows
        local overhead = 1 + 1 + (state.path_mode and 1 or 0) + (show_help and 1 or 0) + 1
        local available = math.max(1, rows - overhead)
        local total = #state.entries
        local body_height
        if total > available then
            body_height = math.max(1, available - 2)
        else
            body_height = math.max(1, total)
        end
        state.height = body_height

        scroller:set_rows(total)
        scroller:set_height(body_height)
        scroller:follow(state.selected)
        local top, bottom = scroller:visible()
        state.top = top

        local lines = {
            render.line(render.span("? ", "accent"), render.span(options.message, "message")),
            render.line(
                render.span("  " .. theme.symbol("directory") .. " ", "accent"),
                render.span(state.current, "muted")
            ),
        }
        local cursor
        if state.path_mode then
            local spans = {
                render.span("  > ", "accent"),
                render.span(state.path_text, "message"),
            }
            lines[#lines + 1] = spans
            cursor = { row = 3, column = 4 + term.width(state.path_text) }
        end

        local preview_on = preview_enabled and columns >= 72
        local left_width = columns - 2
        local preview_width = 0
        if preview_on then
            left_width = math.max(24, math.min(46, math.floor(columns * 0.45)))
            preview_width = math.max(1, columns - left_width - 3)
        end

        if top > 1 then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_up") .. " more", "muted")
            )
        end

        local body = {}
        for position = top, bottom do
            local entry = state.entries[position]
            local selected = position == state.selected
            local style = selected and "selected" or nil
            local spans = {
                render.span("  ", nil),
                render.span(
                    selected and theme.symbol("pointer") or " ",
                    selected and "selected" or "accent"
                ),
                render.span(" ", selected and "selected" or nil),
            }
            if multi then
                spans[#spans + 1] = render.span(
                    state.checked[entry.full_path] and theme.symbol("checked") or theme.symbol("unchecked"),
                    selected and "selected" or (state.checked[entry.full_path] and "accent" or "muted")
                )
                spans[#spans + 1] = render.span(" ", selected and "selected" or nil)
            end
            spans[#spans + 1] = render.span(
                (entry.is_directory and theme.symbol("directory") or theme.symbol("file")) .. " ",
                selected and "selected" or (entry.is_directory and "accent" or "muted")
            )
            spans[#spans + 1] = render.span(entry.label, style)
            body[#body + 1] = spans
        end

        if total == 0 then
            body[1] = render.line(render.span("  empty", "muted"))
        end

        if preview_on then
            local entry = selected_entry()
            local preview = preview_for(entry, preview_width, math.max(1, bottom - top + 1), theme)
            for index = 1, #body do
                local left = render.pad(
                    render.clip(body[index] or {}, left_width, theme), left_width
                )
                local spans = {}
                for _, span in ipairs(left) do spans[#spans + 1] = span end
                spans[#spans + 1] = render.span(" " .. theme.symbol("separator") .. " ", "border")
                for _, span in ipairs(preview[index] or {}) do spans[#spans + 1] = span end
                body[index] = render.clip(spans, columns, theme)
            end
        else
            for index = 1, #body do
                body[index] = render.clip(body[index], columns, theme)
            end
        end

        for _, line in ipairs(body) do lines[#lines + 1] = line end
        if bottom < total then
            lines[#lines + 1] = render.line(
                render.span("  " .. theme.symbol("arrow_down") .. " more", "muted")
            )
        end
        if show_help then
            if state.path_mode then
                lines[#lines + 1] = field_mod.help_line(
                    "type a path  tab complete  enter open  esc back"
                )
            elseif multi then
                lines[#lines + 1] = field_mod.help_line(
                    "arrows move  enter open  space check  / path  h hidden  esc cancel"
                )
            else
                lines[#lines + 1] = field_mod.help_line(
                    "arrows move  enter open  left up  / path  h hidden  esc cancel"
                )
            end
        end
        return render.frame(lines, cursor)
    end

    local function current_summary()
        local entry = selected_entry()
        if multi then
            local count = checked_count()
            if count > 0 then return count .. " selected" end
        end
        return entry and entry.label or "none"
    end

    load(initial_name)
    if initial_name then select_name(initial_name) end

    local field
    field = field_mod.new {
        type = "file",
        options = options,
        message = options.message,
        draw_active = function(self, width, theme)
            state.width = width
            state.max_height = self.max_height
            return build(theme)
        end,
        draw_compact = function(self, theme)
            return render.summary(theme, self.message, current_summary())
        end,
        handle = function(self, event)
            local action, value = on_event(event)
            self.error = state.error
            return action, value
        end,
        accepts_text = function()
            return state.path_mode
        end,
        value = function()
            local entry = selected_entry()
            if multi then
                if checked_count() > 0 then return checked_results() end
                if entry and mode_allows(entry) then
                    return result_path(entry.full_path, base, absolute_enabled, entry.is_directory)
                end
                return nil
            end
            if entry == nil or not mode_allows(entry) then return nil end
            return result_path(entry.full_path, base, absolute_enabled, entry.is_directory)
        end,
        set_value = function(_, value)
            state.error = nil
            if multi then
                state.checked = {}
                state.check_order = {}
                local values = type(value) == "table" and value or { value }
                for _, candidate in ipairs(values) do
                    local absolute = resolve_input(tostring(candidate), base)
                    if absolute and not state.checked[absolute] then
                        local is_directory = kind_of(absolute) == "directory"
                        local allowed = is_directory and mode ~= "file"
                            or (not is_directory and mode ~= "directory")
                        if allowed then
                            local entry = {
                                name = basename(absolute),
                                label = basename(absolute),
                                full_path = absolute,
                                is_directory = is_directory,
                            }
                            state.checked[absolute] = entry
                            state.check_order[#state.check_order + 1] = absolute
                        end
                    end
                end
                return
            end
            local absolute = resolve_input(tostring(value), base)
            if absolute == nil then return end
            local parent = filesystem.parent(absolute)
            if parent then navigate(parent.full_path, basename(absolute)) end
        end,
        summary = function(self, theme)
            return render.summary(theme, self.message, current_summary())
        end,
        close = function() end,
    }
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

local function fallback_file(options)
    local mode = options.mode or "file"
    local multi = options.multi == true
    local start = options.start
    if start == nil or start == "" then start = "." end
    local base, initial_name = resolve_start(start)
    local filter = normalize_filter(options.filter)
    local default
    if type(options.default) == "table" then
        local parts = {}
        for index, value in ipairs(options.default) do parts[index] = tostring(value) end
        default = table.concat(parts, ",")
    elseif options.default ~= nil then
        default = tostring(options.default)
    end

    -- The blank answer has to be a path that satisfies `mode`.  Resolve the
    -- starting directory or file once; never feed the original relative
    -- `start` back through resolve_input, which would join it twice.
    local blank, blank_label
    if default ~= nil then
        blank, blank_label = default, default
    elseif initial_name ~= nil then
        if mode == "directory" then
            blank, blank_label = base, base
        else
            blank, blank_label = initial_name, initial_name
        end
    elseif mode ~= "file" then
        blank, blank_label = base, start
    end

    local function parse_line(line)
        local tokens = {}
        if multi then
            for token in line:gmatch("[^,%s]+") do tokens[#tokens + 1] = token end
        else
            tokens[1] = line
        end

        local values = {}
        for _, token in ipairs(tokens) do
            local absolute = resolve_input(token, base)
            if absolute == nil then
                return nil, "Path not found: " .. token
            end
            local kind = kind_of(absolute)
            if kind == nil then
                return nil, "Not a file or directory: " .. token
            end
            if kind == "directory" and mode == "file" then
                return nil, "Choose a file, not a directory."
            end
            if kind == "file" and mode == "directory" then
                return nil, "Choose a directory, not a file."
            end
            if filter and kind == "file" and #filter > 0 then
                local name = basename(absolute)
                if not matches_filter(name, filter) then
                    return nil, "File does not match the filter: " .. name
                end
            end
            values[#values + 1] = result_path(
                absolute, base, options.absolute == true, kind == "directory"
            )
        end
        return values
    end

    -- Never advertise a blank answer that the current mode would reject.
    if blank ~= nil then
        local _, problem = parse_line(blank)
        if problem then blank, blank_label = nil, nil end
    end

    local prompt = "? " .. options.message
    if blank ~= nil then prompt = prompt .. " [" .. blank_label .. "]" end
    io.write(prompt .. ": ")
    while true do
        local line = io.read("l")
        if line == nil then
            local policy = config.get("eof")
            if policy == "error" then
                error("prompt: end of input while waiting for an answer", 3)
            end
            if policy == "nil" or default == nil then return nil, "eof" end
            local values, problem = parse_line(default)
            if problem then return nil, problem end
            if multi then return values end
            return values[1]
        end
        io.write("\n")
        line = (line:gsub("^%s+", ""):gsub("%s+$", ""))

        if line == "" and blank == nil then
            io.write("Please enter a path.\n")
            io.write("path: ")
        else
            if line == "" then line = blank end

            local values, problem = parse_line(line)
            if problem then
                io.write(problem .. "\n")
                io.write("path: ")
            elseif multi then
                return values
            else
                return values[1]
            end
        end
    end
end

function M.__call(_, options)
    validate_options(options)
    if not config.is_interactive() then
        return fallback_file(options)
    end
    return M.run(options)
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
