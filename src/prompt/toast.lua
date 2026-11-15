-- Short one-line notice drawn on the live line.
--
-- `timeout = 0` with `persist = false` is a no-op: a transient notice that is
-- cleared immediately would only leave a blank line.  Combine a zero timeout
-- with `persist = true` to leave the notice in the scrollback.

local config = require "prompt.config"
local input = require "prompt.input"
local live = require "prompt.live"
local render = require "prompt.render"
local theme_mod = require "prompt.theme"

local M = {}

local kinds = {
    info = true,
    success = true,
    warning = true,
    danger = true,
}

local function validate(options)
    if type(options) ~= "table" then
        error("prompt.toast: expecting an options table", 3)
    end
    if type(options.message) ~= "string" or options.message == "" then
        error("prompt.toast: message must be a non-empty string", 3)
    end
    if options.kind ~= nil and not kinds[options.kind] then
        error("prompt.toast: kind must be info, success, warning or danger", 3)
    end
    if options.timeout ~= nil and (type(options.timeout) ~= "number" or options.timeout < 0) then
        error("prompt.toast: timeout must be zero or positive", 3)
    end
    if options.persist ~= nil and type(options.persist) ~= "boolean" then
        error("prompt.toast: persist must be a boolean", 3)
    end
end

function M.__call(_, options)
    validate(options)
    local kind = options.kind or "info"
    local timeout = options.timeout == nil and 1.5 or options.timeout
    local persist = options.persist == true

    local theme = theme_mod.build()
    local spans = render.status(theme, kind, options.message)

    if not config.is_interactive() then
        io.write(render.plain(spans) .. "\n")
        io.flush()
        return true
    end

    if timeout == 0 and not persist then
        -- There is no time to see a transient notice, and drawing it only to
        -- erase it would leave a blank line.
        return true
    end

    local region = live.new(options.screen, options.message)
    region:update(spans)

    if timeout > 0 then
        local session = input.open()
        local ok, message = xpcall(function()
            local deadline = os.nanotime() + timeout
            while true do
                local remaining = deadline - os.nanotime()
                if remaining <= 0 then break end
                local wait = math.max(1, math.min(50, math.floor(remaining * 1000)))
                local event = session:read(wait)
                if event == nil then
                    -- Poll timed out; check the deadline again.
                elseif event.type == "eof" then
                    break
                elseif event.type == "key" then
                    break
                elseif event.type == "resize" then
                    region:update(spans)
                end
            end
        end, debug.traceback)
        session:close()
        if not ok then
            region:close()
            error(message, 0)
        end
    end

    if persist then
        region:finish(kind, options.message)
    else
        region:close()
    end
    return true
end

return setmetatable(M, { __call = function(_, options) return M.__call(M, options) end })
