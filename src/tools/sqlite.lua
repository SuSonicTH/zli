local term = require "term"
local readline = require "readline"
local pager = require "pager"
local sqlite = require "sqlite3"
local json = require "cjson"

--[[ Init history ]]
local history_file = os.home .. "/.config/zli/sqlite_history"
local history = readline.history.new({ max = 2000 })

local function try_rename(old, new)
    local called, first, second = pcall(require("filesystem").rename, old, new)
    if not called then return false end
    return first ~= nil or second == nil
end

local function load_history()
    local ok, message = history:load(history_file)
    if ok then return true end

    local backup = history_file .. ".bak"
    local renamed = try_rename(history_file, backup)
    if renamed then
        io.stderr:write(string.format("warning: could not read %s: %s (moved to %s)\n", history_file, tostring(message), backup))
        return true
    end
    io.stderr:write(string.format("warning: could not read %s: %s\n", history_file, tostring(message)))
    return false
end

local history_writable

--[[ Init screen ]]
term.clear("all")
local dim = term.size() or { columns = 80, rows = 24 }
local header = "ZLI - SQLite"

term.style({ fg = "blue" })
term.move_to(math.max(1, math.floor((dim.columns - #header) / 2) + 1), 2)
print(header)

print([[


    A SQLite commandline interface
    Type a command, end it with semicolon and hit enter to execute it
    the results will be printed and you can enter the next command

    To exit enter "quit;" on a new line

    Ctrl+Shift+X or Alt+X toggles multiline mode, Ctrl+Enter or Alt+Enter submits
    Ctrl+R searches history, Ctrl+C and Ctrl+D exit
]])
term.reset_style()
history_writable = load_history()

local db = sqlite.open_memory()

local function get_command()
    return readline.read({
        prompt = "> ",
        continuation = ">> ",
        history = history,
        multiline = function(buffer)
            return buffer:find(";", 1, true) ~= nil
        end,
    })
end

local function collect_result(result, columns, values, column_names)
    if (result.has_rows == nil) then
        result.has_rows = true
        result.columns = columns
        result.column_names = column_names
    end
    -- lsqlite3 reuses the same values table for every row, so copy it
    local row = {}
    for i = 1, columns do
        row[i] = values[i]
    end
    table.insert(result, row)
    return 0
end

local function collect_result_table(result, columns, values, column_names)
    local row = {}
    for i, name in ipairs(column_names) do
        row[name] = values[i]
    end
    table.insert(result, row)
    return 0
end

local function to_strings(values)
    local strings = {}
    for i, value in ipairs(values) do
        strings[i] = tostring(value)
    end
    return strings
end

local function print_result_csv(result, columns, values, column_names)
    result.csv_lines = result.csv_lines or {}
    if not result.header then
        result.csv_lines[#result.csv_lines + 1] = table.concat(to_strings(column_names), ",")
        result.header = true
    end
    result.csv_lines[#result.csv_lines + 1] = table.concat(to_strings(values), ",")
    return 0
end

local function print_result_table_get_line(widths, spaces, values)
    local strings = to_strings(values)
    local line = { "| " }
    for i, value in ipairs(strings) do
        line[#line + 1] = (value .. spaces[i]):sub(1, widths[i]) .. " | "
    end
    return table.concat(line)
end

local function print_result_table(result)
    local widths = {}
    for i, name in ipairs(result.column_names) do
        widths[i] = #tostring(name)
    end
    for _, row in ipairs(result) do
        for i, name in ipairs(row) do
            local length = #tostring(name)
            if length > widths[i] then
                widths[i] = length
            end
        end
    end
    local spaces = {}
    local line_with = 0
    for i, width in ipairs(widths) do
        spaces[i] = (" "):rep(width)
        line_with = line_with + width + 3;
    end
    line_with = line_with + 1

    local output = {}
    output[#output + 1] = ("-"):rep(line_with)
    output[#output + 1] = print_result_table_get_line(widths, spaces, result.column_names)
    output[#output + 1] = ("-"):rep(line_with)
    for _, row in ipairs(result) do
        output[#output + 1] = print_result_table_get_line(widths, spaces, row)
    end
    output[#output + 1] = ("-"):rep(line_with)

    pager.print(output)
end

local print_mode = "table"
local print_collector = {
    csv = print_result_csv,
    json = collect_result_table,
    lua = collect_result_table,
    table = collect_result,
}

local function status_ok()
    term.style({ fg = "green" })
    io.write("OK\n")
    term.reset_style()
end

local function status_error(message)
    term.style({ fg = "red" })
    io.write("Error: ", message, "\n")
    term.reset_style()
end

local function status_last_error()
    term.style({ fg = "red" })
    io.write("Error: ")
    term.reset_style()
    io.write(db:error_message(), "\n")
end

local function print_status(result)
    if (result == sqlite.OK) then
        status_ok("OK")
    else
        status_last_error()
    end
end

local execute_file
local function execute_command(command)
    local lower = command:lower()
    if lower:match("^%s*exit%s*;%s*$") or lower:match("^%s*quit%s*;%s*$") then
        return false;
    elseif lower:match("^%s*open%s+\"(.*)\"%s*;%s*$") then
        local filename = command:match("^%s*open%s+\"(.*)\"%s*;%s*$")
        db:close()
        db, _, error = sqlite.open(filename)
        if db then
            status_ok()
        else
            status_error(error)
        end
    elseif lower:match("^%s*close%s*;%s*$") then
        print_status(db:close())
        db = sqlite.open_memory()
    elseif lower:match("^%s*file%s+\"(.*)\"%s*;%s*$") then
        local filename = command:match("^%s*file%s+\"(.*)\"%s*;%s*$")
        local file, err = io.open(filename, 'r')
        if file == nil then
            status_error(err)
        else
            execute_file(file)
            file:close()
        end
    elseif lower:match("^%s*mode%s*;%s*$") then
        print("current mode: " .. print_mode)
    elseif lower:match("^%s*mode%s+%w+%s*;%s*$") then
        local mode = command:match("^%s*mode%s+(%w+)%s*;%s*$"):lower()
        local collector = print_collector[mode]
        if collector then
            print_mode = mode
            status_ok()
        else
            status_error("mode " .. mode .. " unknown")
        end
    else
        local result = {}
        local status = db:exec(command, print_collector[print_mode], result)
        if result.csv_lines then
            pager.print(table.concat(result.csv_lines, "\n"))
        elseif #result > 0 then
            if print_mode == "lua" then
                pager.print(table.tostring(result, "result"))
            elseif print_mode == "json" then
                print(json.encode(result))
            elseif print_mode == "table" then
                print_result_table(result)
            end
        end
        print_status(status)
    end
    return true
end

execute_file = function(file)
    local command = ""
    local prompt = "> "
    for line in file:lines() do
        term.style({ fg = "blue" })
        io.write(prompt)
        term.reset_style()
        io.write(line, "\n")
        command = command .. line .. " "
        if string.find(command, ";", 1, true) then
            execute_command(command)
            prompt = "> "
            command = ""
        else
            prompt = ">>"
        end
    end
end

local function execute()
    while (true) do
        local command = get_command()
        if command == nil then
            if history_writable then history:save(history_file) end
            return
        end
        if not execute_command(command) then
            if history_writable then history:save(history_file) end
            return
        end
    end
end

execute()
