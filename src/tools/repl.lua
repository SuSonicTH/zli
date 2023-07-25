local cl = require "crossline"

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
        print(table.tostring(value, name))
    elseif type(value) == 'string' then
        print(name .. " = \"" .. value .. "\"")
    else
        print(name .. " = " .. tostring(value))
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
