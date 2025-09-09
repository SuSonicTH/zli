local cl = require "crossline"
local sqlite = require "sqlite3"
local json = require "cjson"

--[[ Init history ]]
local history_file = os.home .. "/.config/zli/sqlite_history"
cl.history.load(history_file)

--[[ Init screen ]]
cl.screen.clear()
local dim = cl.screen.dimentions()
local header = "ZLI - SQLite"

cl.set_color(cl.color.fg.blue)
cl.cursor.set(math.floor((dim.x - #header) / 2), 2)
cl.set_prompt_color(cl.color.fg.blue)
print(header)

cl.set_color(cl.color.fg.default)
print([[


    A SQLite commandline interface
    Type a command, end it with semicolon and hit enter to execute it
    the results will be printed and you can enter the next command

    To exit enter "quit;" on a new line
    Hit F1 to see help on editing commands
]])
--cl.cursor.set(0, dim.y - 1)


local db = sqlite.open_memory()

local function get_command()
    local command = cl.readline("> ")
    if command == nil then
        return nil;
    end

    while (not (string.find(command, ";", 1, true))) do
        local line = cl.readline(">>")
        if line == nil then
            return nil;
        end

        if (command:sub(-1) == " ") then
            command = command .. line
        else
            command = command .. " " .. line
        end
    end
    return command
end

local function collect_result(result, columns, values, column_names)
    if (result.has_rows == nil) then
        result.has_rows = true
        result.columns = columns
        result.column_names = column_names
    end
    table.insert(result, values)
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

local function print_result_csv(result, columns, values, column_names)
    if not result.header then
        cl.paging.start()
        cl.paging.print(table.concat(column_names, ","))
        result.header = true
    end
    if cl.paging.print(table.concat(values, ",")) then
        return 0;
    else
        return 1;
    end
end

local function print_result_table_get_line(widths, spaces, values)
    local line = { "| " }
    for i, value in ipairs(values) do
        line[#line + 1] = (value .. spaces[i]):sub(1, widths[i]) .. " | "
    end
    return table.concat(line)
end

local function print_result_table(result)
    local widths = {}
    for i, name in ipairs(result.column_names) do
        widths[i] = #name
    end
    for _, row in ipairs(result) do
        for i, name in ipairs(row) do
            if #name > widths[i] then
                widths[i] = #name
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

    cl.paging.start()
    cl.paging.print(output)
end

local print_mode = "table"
local print_collector = {
    csv = print_result_csv,
    json = collect_result_table,
    lua = collect_result_table,
    table = collect_result,
}

local function status_ok()
    cl.set_color(cl.color.fg.green)
    io.write("OK\n")
    cl.set_color(cl.color.fg.default)
end

local function status_error(message)
    cl.set_color(cl.color.fg.red)
    io.write("Error: ", message, "\n")
    cl.set_color(cl.color.fg.default)
end

local function status_last_error()
    cl.set_color(cl.color.fg.red)
    io.write("Error: ")
    cl.set_color(cl.color.fg.default)
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
    if lower:find("%s*exit%s*;") or command:find("%s*quit%s*;") then
        return false;
    elseif lower:find("%s*open%s*\"(.*)\"%s*;") then
        local filename = command:match("%s*open%s*\"(.*)\"%s*;")
        db:close()
        db, _, error = sqlite.open(filename)
        if db then
            status_ok()
        else
            status_error(error)
        end
    elseif lower:find("%s*close%s*;") then
        print_status(db:close())
        db = sqlite.open_memory
    elseif lower:find("%s*file%s*\"(.*)\"%s*;") then
        local filename = command:match("%s*file%s*\"(.*)\"%s*;")
        local file = io.open(filename, 'r')
        execute_file(file)
        file:close()
    elseif lower:find("%s*mode%s*;") then
        print("current mode: " .. print_mode)
    elseif lower:find("%s*mode%s+(%w+)%s*;") then
        local mode = command:match("%s*mode%s+(%w+)%s*;")
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
        if #result > 0 then
            if print_mode == "lua" then
                cl.paging.start()
                cl.paging.print { table.tostring(result, "result"):split("\n") }
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
        cl.set_color(cl.color.fg.blue)
        io.write(prompt)
        cl.set_color(cl.color.fg.default)
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
            return
        end
        if not execute_command(command) then
            cl.history.save(history_file)
            return
        end
    end
end

return {
    execute = execute,
    execute_file = execute_file,
}
