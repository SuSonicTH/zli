-- Lua wrapper for the terminal pager.

return function(pager)
    local term = require "term"

    local defaults = {
        height = nil,
        prompt = "-- more --",
    }

    function pager.configure(options)
        if options ~= nil and type(options) ~= "table" then
            error("pager.configure: expecting an options table", 2)
        end
        options = options or {}
        if options.height ~= nil then
            if type(options.height) ~= "number" or options.height < 1 then
                error("pager height must be a positive number", 2)
            end
            defaults.height = math.floor(options.height)
        end
        if options.prompt ~= nil then
            defaults.prompt = tostring(options.prompt)
        end
    end

    local zig_print = pager.print

    function pager.print(text, options)
        if type(text) == "table" then
            text = table.concat(text, "\n")
        else
            text = tostring(text)
        end

        if options ~= nil and type(options) ~= "table" then
            error("pager.print: expecting an options table", 3)
        end
        options = options or {}
        local height = options.height or defaults.height or 0
        local prompt = options.prompt or defaults.prompt

        if not term.is_tty() then
            io.write(text)
            if text:sub(-1) ~= "\n" then
                io.write("\n")
            end
            return true
        end

        io.flush()
        return zig_print(text, height, prompt)
    end
end
