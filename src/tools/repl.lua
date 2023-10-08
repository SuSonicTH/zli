local cl = require "crossline"

--[[ ~/.config/repl.init ]]

local init = os.home .. "/.config/zli/repl_init.lua"
if lfs.attributes(init) == nil then
    io.write_file(init, [==[
--[================================================================================[
zli repl init file

you can put global initialisations here that will get executed on every
invocation of zli repl before the repl loop starts
it's usefull to set some loacl configurations or load default libraries

the ~/.config/init.lua gets executed before this script is executed
--]================================================================================]

csv = require "csv"
json = require "cjson"
log = require "log"
lpeg = require "lpeg"
lu = require "luaunit"
re = require "re"
require "lfs"
sqlite3 = require "sqlite3"
stream = require "stream"
zip = require "zip"
zlib = require "zlib"
cl = require "crossline"

]==])
end
dofile(init)

--[[ Init screen ]]
cl.screen.clear()
local dim = cl.screen.dimentions()
local header = "ZIL - REPL"

cl.set_color(cl.color.fg.blue)
cl.cursor.set(math.floor((dim.x - #header) / 2), 2)
cl.set_prompt_color(cl.color.fg.blue)
print(header)

cl.set_color(cl.color.fg.default)
print([[

    A Zig Lua Interperter - Read Print Eval Loop
    Type a command and hit enter to execute it
    the results will be printed and you can enter the next command

    To exit the loop enter quit on a new line
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

-- [[ REPL loop ]]
local function quit_if_requested(line)
    if (line:trim():lower() == "quit" or line:trim():lower() == "exit") then
        cl.screen.clear()
        os.exit(0)
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
                if (value) then
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

return {
    execute = execute
}
