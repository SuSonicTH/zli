local cl = require "crossline"
local fs = require "filesystem"

local config = os.home .. "/.config"
if not fs.exists(config) then
    fs.mkdir(config)
end

local config_zli = config .. "/zli"
if not fs.exists(config_zli) then
    fs.mkdir(config_zli)
end

local init = config_zli .. "/repl_init.lua"
if not fs.exists(init) then
    io.write_file(init, [==[
--[================================================================================[
zli repl init file

you can put global initialisations here that will get executed on every
invocation of zli repl before the repl loop starts
it is useful to set local configuration or load default libraries

the ~/.config/zli/init.lua gets executed before this script is executed
--]================================================================================]

csv = require "csv"
json = require "cjson"
log = require "log"
lpeg = require "lpeg"
lu = require "luaunit"
re = require "re"
fs = require "filesystem"
sqlite3 = require "sqlite3"
stream = require "stream"
zip = require "zip"
gzip = require "gzip"
cl = require "crossline"
collection = require "collection"

]==])
end
dofile(init)

--[[ Init history ]]
local history_file = os.home .. "/.config/zli/repl_history"
cl.history.load(history_file)

--[[ Init screen ]]

cl.screen.clear()
local dim = cl.screen.dimensions()
local header = "ZIL - REPL"

cl.set_color(cl.color.fg.blue)
cl.cursor.set(math.floor((dim.x - #header) / 2), 2)
cl.set_prompt_color(cl.color.fg.blue)
print(header)

cl.set_color(cl.color.fg.default)
print([[

    A Zig Lua Interpreter - Read Print Eval Loop
    Type a command and hit enter to execute it
    the results will be printed and you can enter the next command

    To exit the loop enter quit on a new line
    Type :help for the documentation index or :help <name> for an entry
    Hit F1 to see help on editing commands
]])
cl.cursor.set(0, dim.y - 1)

-- [[ utility functions ]]

local function printError(type, message)
    cl.set_color(cl.color.fg.red)
    local space = (type and type ~= "") and " " or ""
    io.write(type, space, "error: ")
    cl.set_color(cl.color.fg.default)
    io.write(message, "\n")
end

function Pretty_print(name, value)
    if type(value) == 'table' then
        cl.print_paged(table.tostring(value, name))
    elseif type(value) == 'string' then
        cl.print_paged(name .. " = \"" .. value .. "\"")
    else
        cl.print_paged(name .. " = " .. tostring(value))
    end
end

local function help_text(query)
    local ok, docs = pcall(require, "docs")
    if not ok then
        return "documentation is not included in this payload"
    end

    query = query:trim()
    local force_search = false
    local search_query = query:match("^%-%-search%s+(.*)$")
    if search_query ~= nil then
        force_search = true
        query = search_query:trim()
    elseif query == "--search" then
        return "usage: :help --search <term>"
    end
    if query == "" then
        local lines = { "ZLI reference documentation", "" }
        for _, group in ipairs(docs.groups) do
            lines[#lines + 1] = group.title
            for _, module in ipairs(group.modules or {}) do
                lines[#lines + 1] = "  " .. module.name
            end
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Use :help <name>, for example :help string.byte"
        return table.concat(lines, "\n")
    end

    local entry = docs.find(query)
    if entry and not force_search then
        return docs.render_entry(entry, "text", 80)
    end

    local results = docs.search(query, { limit = 50 })
    if #results == 0 then
        return "no documentation found for '" .. query .. "'"
    end
    if #results == 1 and not force_search then
        return docs.render_entry(results[1], "text", 80)
    end
    local lines = { #results .. " result(s) for '" .. query .. "':", "" }
    for _, result in ipairs(results) do
        local summary = docs.render_inline_text(result.summary or "")
        local label = docs.render_inline_text(
            result.kind == "section" and (result.signature or result.name) or result.name)
        if summary ~= "" then
            lines[#lines + 1] = string.format("%-32s %s", label, summary)
        else
            lines[#lines + 1] = label
        end
    end
    return table.concat(lines, "\n")
end

-- [[ REPL loop ]]
local function exit_repl()
    cl.screen.clear()
    cl.history.save(history_file)
    os.exit(0)
end

local function quit_if_requested(line)
    if line == nil then
        -- Ctrl-D / end of input
        exit_repl()
    end
    local lower_line = line:trim():lower()
    if (lower_line == "quit" or lower_line == "exit") then
        exit_repl()
    end
end

local function get_multi_line(block)
    local result, error
    repeat
        local line = cl.readline(">>")
        quit_if_requested(line)
        block = block .. "\n" .. line
        result, error = load(block, "repl")
    until (result ~= nil or error:sub(-5) ~= "<eof>")
    return result, error
end

local function execute()
    while (true) do
        local line = cl.readline("> ")
        quit_if_requested(line)
        local lower_line = line:lower()
        local help_query = nil
        if lower_line:match("^:help%s*$") then
            help_query = ""
        elseif lower_line:match("^:help%s+") then
            help_query = line:sub(6):gsub("^%s+", "")
        end
        if help_query ~= nil then
            cl.print_paged(help_text(help_query))
        else
            if (line:sub(1, 1) == '?') then
                line = "Pretty_print('" .. line:sub(2) .. "', " .. line:sub(2) .. ")"
            end

            local result, error = load("return " .. line, "repl")
            if result == nil then
                result, error = load(line, "repl")
                if result == nil and error:sub(-5) == "<eof>" then
                    result, error = get_multi_line(line)
                end
            end

            if (result) then
                local success, value = pcall(result)
                if (success) then
                    if (value ~= nil) then
                        print(value)
                    end
                else
                    printError("eval", value)
                end
            else
                printError("compile", error)
            end
        end
    end
end

execute()
