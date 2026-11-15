-- Lua wrapper for the Zig line editor.
--
-- Piped input is read with io.read and still honours the multiline callback,
-- so scripts and tests behave like the interactive editor.

return function(readline)
    local term = require "term"

    local native_new_history = readline.new_history
    local function new_history(options)
        if options ~= nil and type(options) ~= "table" then
            error("readline.history.new: expecting an options table", 2)
        end
        local history = native_new_history(options)
        history.__readline_history = true
        return history
    end

    readline.history = {
        new = new_history,
        default = new_history(),
    }
    readline.new_history = nil

    local function validate(options)
        for _, name in ipairs({ "prompt", "continuation", "initial" }) do
            local value = options[name]
            if value ~= nil and type(value) ~= "string" then
                error("readline.read: option '" .. name .. "' must be a string", 3)
            end
        end
        for _, name in ipairs({ "multiline", "complete" }) do
            local value = options[name]
            if value ~= nil and type(value) ~= "function" then
                error("readline.read: option '" .. name .. "' must be a function", 3)
            end
        end
        if options.multiline_color ~= nil and type(options.multiline_color) ~= "boolean" then
            error("readline.read: option 'multiline_color' must be a boolean", 3)
        end
        if options.history ~= nil and options.history ~= false then
            local history = options.history
            if type(history) ~= "table"
                or history.__readline_history ~= true
                or type(history.add) ~= "function" then
                error("readline.read: option 'history' must be a history object", 3)
            end
        end
    end

    local function fallback(options)
        local buffer = options.initial or ""
        local first = true

        while true do
            local line = io.read("l")
            if line == nil then
                return nil, "eof"
            end

            line = line:gsub("\r$", "")
            if first then
                buffer = buffer .. line
                first = false
            else
                buffer = buffer .. "\n" .. line
            end

            if options.multiline == nil or options.multiline(buffer) then
                if options.history ~= nil and options.history ~= false and buffer ~= "" then
                    options.history:add(buffer)
                end
                return buffer
            end
        end
    end

    local zig_read = readline.read

    function readline.read(options)
        if type(options) == "string" then
            options = { prompt = options }
        elseif options == nil then
            options = {}
        elseif type(options) == "table" then
            local copy = {}
            for key, value in pairs(options) do
                copy[key] = value
            end
            options = copy
        else
            error("readline.read: expecting a prompt string or an options table", 2)
        end

        validate(options)

        if options.history == nil then
            options.history = readline.history.default
        end

        if not term.is_tty() then
            return fallback(options)
        end

        io.flush()
        return zig_read(options)
    end
end
