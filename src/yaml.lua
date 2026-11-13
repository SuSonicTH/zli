-- Safe Lua wrapper around the libYAML C binding.
--
-- The C module is registered as `lyaml.core`; this module validates event
-- tables before they reach libYAML so that malformed values cannot corrupt
-- the emitter or crash the interpreter.

-- The raw C binding is an implementation detail.  Keep a private reference in
-- the registry so this wrapper can be reloaded after `package.loaded.yaml` is
-- cleared, but make the C module unavailable to ordinary `require`.
local registry = debug.getregistry()
local core = registry["zli.yaml.core"]
if core == nil then
    core = require "lyaml.core"
    registry["zli.yaml.core"] = core
end
package.loaded["lyaml.core"] = nil
package.preload["lyaml.core"] = nil

local utf8 = require "utf8"

local M = {
    parser = core.parser,
    scanner = core.scanner,
    version = core.version,
}

local event_types = {
    STREAM_START = true,
    STREAM_END = true,
    DOCUMENT_START = true,
    DOCUMENT_END = true,
    MAPPING_START = true,
    MAPPING_END = true,
    SEQUENCE_START = true,
    SEQUENCE_END = true,
    SCALAR = true,
    ALIAS = true,
}

local styles = {
    STREAM_START = {},
    SCALAR = {
        PLAIN = true,
        SINGLE_QUOTED = true,
        DOUBLE_QUOTED = true,
        LITERAL = true,
        FOLDED = true,
    },
    MAPPING_START = { BLOCK = true, FLOW = true },
    SEQUENCE_START = { BLOCK = true, FLOW = true },
}

local encodings = { UTF8 = true, UTF16LE = true, UTF16BE = true }

local function is_valid_utf8(value)
    return utf8.len(value) ~= nil
end

local function is_valid_anchor(value)
    return #value > 0 and #value <= 1024 and value:find("^[%w_%-]+$") ~= nil
end

local function is_valid_tag(value)
    return #value > 0 and #value <= 4096 and value:find("[%s%c]") == nil
end

local function is_integer(value)
    return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function check_version_directive(value)
    if value == nil then
        return true
    end
    if type(value) ~= "table" then
        return false, "version_directive must be a table"
    end
    if not is_integer(value.major) or not is_integer(value.minor) then
        return false, "version_directive needs integer 'major' and 'minor'"
    end
    return true
end

local function check_tag_directives(value)
    if value == nil then
        return true
    end
    if type(value) ~= "table" then
        return false, "tag_directives must be a table"
    end

    local count, maximum = 0, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false, "tag_directives must be a dense array"
        end
        count = count + 1
        if key > maximum then
            maximum = key
        end
    end
    if count ~= maximum then
        return false, "tag_directives must be a dense array"
    end

    for i = 1, maximum do
        local item = value[i]
        if type(item) ~= "table" then
            return false, "tag_directives items must be tables"
        end
        local handle, prefix = item.handle, item.prefix
        if type(handle) ~= "string" or handle == "" or
           type(prefix) ~= "string" or prefix == "" then
            return false, "tag_directives items need non-empty string 'handle' and 'prefix'"
        end
        if handle ~= "!" and handle ~= "!!" and not handle:match("^![^%s!]+!$") then
            return false, "invalid tag directive handle"
        end
        if not is_valid_tag(prefix) then
            return false, "invalid tag directive prefix"
        end
    end

    return true
end

local function check_event(event)
    if type(event) ~= "table" then
        return false, "event must be a table"
    end

    local event_type = event.type
    if type(event_type) ~= "string" then
        return false, "event type must be a string"
    end
    if not event_types[event_type] then
        return false, "invalid event type '" .. event_type:sub(1, 64) .. "'"
    end

    if event_type == "DOCUMENT_START" then
        local ok, err = check_version_directive(event.version_directive)
        if not ok then
            return false, err
        end
        ok, err = check_tag_directives(event.tag_directives)
        if not ok then
            return false, err
        end
    end

    if event.encoding ~= nil then
        if type(event.encoding) ~= "string" or not encodings[event.encoding] then
            return false, "invalid stream encoding"
        end
    end

    if event.style ~= nil then
        if type(event.style) ~= "string" then
            return false, "event style must be a string"
        end
        local allowed = styles[event_type]
        if allowed and not allowed[event.style] then
            return false, "invalid style for " .. event_type
        end
    end

    if event.anchor ~= nil then
        if type(event.anchor) ~= "string" or not is_valid_anchor(event.anchor) then
            return false, "invalid anchor name"
        end
    elseif event_type == "ALIAS" then
        return false, "alias event requires an anchor"
    end

    if event.tag ~= nil then
        if type(event.tag) ~= "string" or not is_valid_tag(event.tag) then
            return false, "invalid tag"
        end
    end

    if event_type == "SCALAR" then
        if type(event.value) ~= "string" then
            return false, "scalar event requires a string value"
        end
        if not is_valid_utf8(event.value) then
            return false, "invalid UTF-8 in scalar value"
        end
    end

    return true
end

function M.emitter()
    local emitter = core.emitter()
    local dead = false

    local function emit(event)
        if dead then
            return false, "emitter is no longer usable"
        end

        local ok, err = check_event(event)
        if not ok then
            dead = true
            return false, err
        end

        local result, stream = emitter.emit(event)
        if not result then
            dead = true
            return false, stream
        end
        return result, stream
    end

    return { emit = emit }
end

return M
