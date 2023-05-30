local cl = require "crossline"
local aux = require "aux"
aux.extendlibs()

--[[ Init screen ]]
cl.screen.clear()
local dim = cl.screen.dimentions()
local header = "FullMoon REPL"

cl.set_color(cl.color.fg.blue)
cl.cursor.set(math.floor((dim.x - #header) / 2), 2)
cl.set_prompt_color(cl.color.fg.blue)
print(header)

cl.set_color(cl.color.fg.default)
print([[


    A Fullmoon Read Print Eval Loop
    Type a command and hit enter to execute it
    the results will be printed and you can enter hte next command

    To exit the loop enter quit on a new line
    Hit F1 to see help on editing commands
]])
cl.cursor.set(0, dim.y - 1)

-- [[ unility functions ]]

local function printError(type, message)
    cl.set_color(cl.color.fg.red)
    local space = (type and type ~= "") and " " or ""
    io.write(type, space, "error: ")
    cl.set_color(cl.color.fg.default)
    io.write(message, "\n")
end

-- [[ REPL loop ]]
while (true) do
    local line = cl.readline("> ")
    if (line:trim():lower() == "quit") then
        break
    end

    local result, error = load(line, "repl")
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

cl.screen.clear()
