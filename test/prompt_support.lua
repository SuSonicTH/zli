-- Shared helpers for headless prompt component tests.
-- This file is not named test_* so the full runner does not execute it.

local config = require "prompt.config"
local input = require "prompt.input"
local render = require "prompt.render"

local support = {}

--- Run `fn` with injected terminal events and captured frames.
-- Returns the packed result and the capture table.  The capture table also
-- records commits in `frames.commits`.
function support.drive(events, fn)
    config.reset()
    config.configure { force_interactive = true }
    render.capture = {}
    input.events = events or {}
    local ok, result = pcall(function() return table.pack(fn()) end)
    local frames = render.capture
    input.events = nil
    render.capture = nil
    config.reset()
    if not ok then error(result, 0) end
    return result, frames
end

function support.key(code, extra)
    local event = { type = "key", code = code }
    for name, value in pairs(extra or {}) do event[name] = value end
    return event
end

function support.char(value, extra)
    local event = { type = "key", code = "char", char = value }
    for name, item in pairs(extra or {}) do event[name] = item end
    return event
end

function support.paste(value, extra)
    local event = { type = "paste", text = value }
    for name, item in pairs(extra or {}) do event[name] = item end
    return event
end

function support.resize(columns, rows)
    return { type = "resize", columns = columns, rows = rows }
end

--- Flatten a captured frame into plain text.
function support.frame_text(frame)
    local lines = {}
    for index, line in ipairs(frame and frame.lines or {}) do
        lines[index] = render.plain(line)
    end
    return table.concat(lines, "\n")
end

--- Flatten every captured frame into a single newline-separated string.
function support.frames_text(frames)
    local parts = {}
    for _, frame in ipairs(frames or {}) do
        parts[#parts + 1] = support.frame_text(frame)
    end
    return table.concat(parts, "\n---\n")
end

return support
