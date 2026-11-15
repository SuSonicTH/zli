local term = require "term"
local readline = require "readline"
local pager = require "pager"
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

argparse = require "argparse"
benchmark = require "benchmark"
collection = require "collection"
csv = require "csv"
F = require "F"
fs = require "filesystem"
grid = require "grid"
gzip = require "gzip"
httpclient = require "httpclient"
httpserver = require "httpserver"
json = require "cjson"
log = require "log"
lpeg = require "lpeg"
lu = require "luaunit"
luastrip = require "luastrip"
markdown = require "markdown"
memoize = require "memoize"
pager = require "pager"
re = require "re"
readline = require "readline"
serpent = require "serpent"
sqlite3 = require "sqlite3"
stream = require "stream"
tar = require "tar"
term = require "term"
timer = require "timer"
unzip = require "unzip"
uuid = require "uuid"
xlsxmlwriter = require "xlsxmlwriter"
xml2lua = require "xml2lua"
zip = require "zip"

]==])
end
dofile(init)

--[[ Init history ]]
local history_path = os.home .. "/.config/zli/repl_history.json"
local legacy_history = os.home .. "/.config/zli/repl_history"
if not fs.exists(history_path) and fs.exists(legacy_history) then
    pcall(fs.rename, legacy_history, history_path)
end
local history = readline.history.new({ max = 2000 })

local function try_rename(old, new)
    local called, first, second = pcall(fs.rename, old, new)
    if not called then return false end
    return first ~= nil or second == nil
end

local function load_history()
    local ok, message = history:load(history_path)
    if ok then return true end

    local backup = history_path .. ".bak"
    local renamed = try_rename(history_path, backup)
    if renamed then
        io.stderr:write(string.format("warning: could not read %s: %s (moved to %s)\n", history_path, tostring(message), backup))
        return true
    end
    io.stderr:write(string.format("warning: could not read %s: %s\n", history_path, tostring(message)))
    return false
end

local history_writable

--[[ Init screen ]]

term.clear("all")
local dim = term.size() or { columns = 80, rows = 24 }
local header = "ZIL - REPL"

term.style({ fg = "blue" })
term.move_to(math.max(1, math.floor((dim.columns - #header) / 2) + 1), 2)
print(header)

print([[

    A Zig Lua Interpreter - Read Print Eval Loop
    Type a command and hit enter to execute it
    the results will be printed and you can enter the next command

    To exit the loop enter quit on a new line
    Type :help for the documentation index or :help <name> for an entry

    Ctrl+Shift+X or Alt+X toggles multiline mode, Ctrl+Enter or Alt+Enter submits
    Ctrl+R searches history, Ctrl+C and Ctrl+D exit
]])
term.reset_style()
history_writable = load_history()

-- [[ utility functions ]]

local function printError(kind, message)
    term.style({ fg = "red" })
    local space = (kind and kind ~= "") and " " or ""
    io.write(kind, space, "error: ")
    term.reset_style()
    io.write(message, "\n")
end

function Pretty_print(name, value)
    if type(value) == 'table' then
        pager.print(table.tostring(value, name))
    elseif type(value) == 'string' then
        pager.print(name .. " = \"" .. value .. "\"")
    else
        pager.print(name .. " = " .. tostring(value))
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
    term.restore()
    term.clear("all")
    if history_writable then
        history:save(history_path)
    end
    os.exit(0)
end

local function last_line(text)
    return (text:match("([^\n]*)$") or ""):trim():lower()
end

local function is_complete(buffer)
    local lower = buffer:trim():lower()
    if lower:match("^:help") then
        return true
    end
    local tail = last_line(buffer)
    if tail == "quit" or tail == "exit" then
        return true
    end
    local _, err = load(buffer, "repl")
    return err == nil or tostring(err):sub(-5) ~= "<eof>"
end

local function execute()
    while (true) do
        local line = readline.read({
            prompt = "> ",
            continuation = ">> ",
            history = history,
            multiline = is_complete,
        })

        if line == nil then
            -- Ctrl-D, Ctrl-C or end of input
            exit_repl()
        end

        local trimmed = line:trim()
        local lower_line = trimmed:lower()
        local help_query = nil
        if last_line(line) == "quit" or last_line(line) == "exit" then
            exit_repl()
        elseif lower_line:match("^:help%s*$") then
            help_query = ""
        elseif lower_line:match("^:help%s+") then
            help_query = trimmed:sub(6):gsub("^%s+", "")
        end

        if help_query ~= nil then
            pager.print(help_text(help_query))
        else
            if (line:sub(1, 1) == '?') then
                line = "Pretty_print('" .. line:sub(2) .. "', " .. line:sub(2) .. ")"
            end

            local result, error = load("return " .. line, "repl")
            if result == nil then
                result, error = load(line, "repl")
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
