local os = require("os")
local string = require("string")
local io = require("io")

local ALL_LEVELS = {
    "OFF",
    "FATAL",
    "ERROR",
    "WARN",
    "INFO",
    "DEBUG",
    "TRACE"
}
local MAX_TAG_LENGTH = 0
for _, name in ipairs(ALL_LEVELS) do
    local len = string.len(name)
    if (len > MAX_TAG_LENGTH) then
        MAX_TAG_LENGTH = len
    end
end

local LEVEL_TAG = {}
local LEVEL = {}
for l, name in ipairs(ALL_LEVELS) do
    LEVEL[name] = l;
    LEVEL[name:lower()] = l;
    LEVEL_TAG[l] = '[' .. name .. ']' .. string.rep(" ", MAX_TAG_LENGTH - string.len(name)) .. " "
end

--[[ APPENDER ]]
local function streamAppender(handle)
    local appender = {
        handle = handle
    }

    function appender:append(logger, level, message)
        self.handle:write(
            os.date("%Y-%m-%d %H:%M:%S "),
            LEVEL_TAG[level],
            logger._tag,
            message, "\n"
        )
        self.handle:flush()
    end

    return appender
end

local function fileAppender(filename, mode)
    return streamAppender(io.open(filename, (mode == nil) and 'a' or mode))
end

local function stdoutAppender()
    return streamAppender(io.stdout)
end

--[[ LOGGER ]]
local function newLogger(name)
    local logger = {
        _name = name,
        _level = LEVEL.INFO,
        _tag = (name == nil or name == "" or name == "ROOT") and "" or '<' .. name .. '> ',
        _appender = {}
    }

    for level, name in ipairs(ALL_LEVELS) do
        if level > LEVEL.OFF then
            logger[name:lower()] = function(logger, message)
                if (logger._level >= level and ROOT_LOGGER._level >= level) then
                    for _, appender in ipairs(logger._appender) do
                        appender:append(logger, level, message)
                    end
                    if (logger ~= ROOT_LOGGER) then
                        for _, appender in ipairs(ROOT_LOGGER._appender) do
                            appender:append(logger, level, message)
                        end
                    end
                end
            end
        end
    end

    function logger:setLevel(level)
        logger._level = level
    end

    function logger:setAppender(appender)
        self._appender = { appender }
    end

    function logger:addAppender(appender)
        self._appender[#self._appender + 1] = appender
    end

    return logger
end

--[[ module ]]
if ROOT_LOGGER == nil then
    ROOT_LOGGER = setmetatable(newLogger("ROOT"), {
        __index = function(table, name)
            local logger = newLogger(name)
            table[name] = logger
            return logger
        end
    })
    ROOT_LOGGER:setAppender(stdoutAppender())
    ROOT_LOGGER.level = LEVEL
    ROOT_LOGGER.appender = {
        stdout = stdoutAppender,
        file = fileAppender,
        none = {
            append = function()
            end
        }
    }
end

return ROOT_LOGGER;
