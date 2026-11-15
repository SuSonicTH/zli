-- Shared configuration for the prompt library.

local term = require "term"

local M = {}

local enums = {
    color = { auto = true, always = true, never = true },
    symbols = { auto = true, unicode = true, ascii = true },
    commit = { summary = true, frame = true, none = true },
    screen = { inline = true, alternate = true },
    eof = { default = true, ["nil"] = true, error = true },
}

local function fail(message)
    error("prompt.configure: " .. message, 3)
end

local function set(key, value)
    if enums[key] and not enums[key][value] then
        fail("invalid " .. key .. " value " .. tostring(value))
    end
    M.state[key] = value
end

M.state = {
    theme = {},
    color = "auto",
    symbols = "auto",
    commit = "summary",
    screen = "inline",
    eof = "default",
    page_size = 10,
    spinner_interval = 0.08,
    progress_interval = 0.08,
    force_interactive = nil,
}

function M.reset()
    M.state = {
        theme = {},
        color = "auto",
        symbols = "auto",
        commit = "summary",
        screen = "inline",
        eof = "default",
        page_size = 10,
        spinner_interval = 0.08,
        progress_interval = 0.08,
        force_interactive = nil,
    }
end

function M.configure(options)
    if options == nil then return M.state end
    if type(options) ~= "table" then
        error("prompt.configure: expecting an options table", 2)
    end

    for key, value in pairs(options) do
        if key == "theme" then
            if type(value) ~= "table" then fail("theme must be a table") end
            local merged = {}
            for name, style in pairs(M.state.theme) do merged[name] = style end
            for name, style in pairs(value) do merged[name] = style end
            M.state.theme = merged
        elseif key == "page_size" or key == "spinner_interval" or key == "progress_interval" then
            if type(value) ~= "number" or value <= 0 then
                fail(key .. " must be a positive number")
            end
            M.state[key] = value
        elseif key == "force_interactive" then
            M.state[key] = value and true or false
        elseif enums[key] then
            set(key, value)
        else
            fail("unknown option '" .. tostring(key) .. "'")
        end
    end
    return M.state
end

function M.get(key)
    if key then return M.state[key] end
    return M.state
end

function M.is_interactive()
    if M.state.force_interactive ~= nil then return M.state.force_interactive end
    return term.is_tty()
end

function M.screen()
    return M.state.screen
end

return M
