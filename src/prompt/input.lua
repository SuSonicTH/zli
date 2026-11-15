-- Terminal session handling, key helpers and the shared component loop.

local term = require "term"
local config = require "prompt.config"
local render = require "prompt.render"

local M = {}

local depth = 0

local function interactive()
    return config.is_interactive()
end

function M.is_test()
    return M.events ~= nil
end

function M.open()
    if M.is_test() then
        local session = { position = 1 }
        function session:read()
            local event = self.events[self.position]
            if event == nil then return { type = "eof" } end
            self.position = self.position + 1
            return event
        end
        function session:close() end
        session.events = M.events
        return session
    end

    if depth == 0 then
        term.enableRawMode()
        term.bracketed_paste(true)
        term.keyboard_enhancements(true, term.enhancements.disambiguate)
        term.hide_cursor()
    end
    depth = depth + 1

    local session = {}
    function session:read()
        while true do
            local event, message = term.read_event()
            if event == nil then return { type = "eof", message = message } end
            if event.type == "key" and event.kind == "release" then
                -- Ignore key releases; they are noise for every component.
            elseif event.type == "mouse" then
                -- Mouse support is intentionally out of scope in v1.
            else
                return event
            end
        end
    end
    function session:close()
        depth = depth - 1
        if depth == 0 then term.restore() end
    end
    return session
end

function M.key(ev, code)
    return ev and ev.type == "key" and ev.code == code
end

function M.ctrl(ev, char)
    return ev and ev.type == "key" and ev.control and ev.code == "char" and ev.char == char
end

function M.enter(ev)
    return ev and ev.type == "key" and ev.code == "enter" and not ev.alt
end

function M.alt_enter(ev)
    if not ev or ev.type ~= "key" then return false end
    if ev.code == "enter" and ev.alt then return true end
    return ev.code == "char" and ev.alt and (ev.char == "\r" or ev.char == "\n")
end

function M.cancel(ev)
    return M.key(ev, "esc") or M.ctrl(ev, "c")
end

function M.printable(ev)
    if not ev or ev.type ~= "key" then return nil end
    if ev.control or ev.alt then return nil end
    if ev.code ~= "char" then return nil end
    local char = ev.char
    if not char or char == "" or char == "\r" or char == "\n" or char == "\t" then return nil end
    local byte = string.byte(char)
    if byte and (byte < 32 or byte == 127) then return nil end
    return char
end

local function unpack_result(packed)
    return table.unpack(packed, 1, packed.n)
end

function M.run(options)
    if not interactive() then
        error("prompt: the interactive driver is unavailable", 2)
    end

    local screen = options.screen or config.get("screen")
    local commit = options.commit or config.get("commit")
    local presenter = render.new(screen)
    local session = M.open()
    local packed
    local failure

    local ok, message = xpcall(function()
        while true do
            presenter:draw(options.frame())
            local event = session:read()

            if event.type == "eof" then
                packed = table.pack(nil, "eof")
                local summary = options.eof_summary
                    or render.status(presenter.theme, "danger", "cancelled")
                presenter:commit(commit, summary, nil)
                break
            end

            local reply = table.pack(options.on_event(event))
            local action = reply[1]
            if action == "submit" then
                packed = table.pack(table.unpack(reply, 2, reply.n))
                local summary = options.summary and options.summary(unpack_result(packed))
                local final = options.final_frame and options.final_frame(unpack_result(packed))
                presenter:commit(commit, summary, final)
                break
            elseif action == "cancel" then
                packed = table.pack(nil, "cancelled")
                local summary = options.cancel_summary
                    or render.status(presenter.theme, "danger", "cancelled")
                presenter:commit(commit, summary, nil)
                break
            elseif action == "eof" then
                packed = table.pack(nil, "eof")
                local summary = options.eof_summary
                    or render.status(presenter.theme, "danger", "cancelled")
                presenter:commit(commit, summary, nil)
                break
            end
        end
    end, debug.traceback)

    if not ok then
        failure = message
    end
    session:close()
    presenter:close()

    if failure then error(failure, 0) end
    if packed == nil then return nil, "cancelled" end
    return unpack_result(packed)
end

return M
