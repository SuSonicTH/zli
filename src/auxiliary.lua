local serpent = require "serpent"

function arg_error(func, narg, message, level)
    error("bad argument #" .. narg .. " to " .. func .. " (" .. message .. ")", level)
end

function arg_check(func, narg, test, message)
    if ~test then
        arg_error(func, narg, message, 3)
    end
end

function arg_check_type(func, narg, arg, ...)
    local types = { ... }
    local actual = type(arg)
    for _, expected in ipairs(types) do
        if actual == expected then return arg end
    end
    if #types == 1 then
        arg_error(func, narg, types[1] .. " expected, got " .. type(arg), 3)
    else
        arg_error(func, narg, "expected one of [" .. table.concat(types, ',') .. "], got " .. type(arg), 3)
    end
    return arg
end

function sorted_pairs(tbl, func)
    local keys = {}
    local idx = 1

    for key, _ in pairs(tbl) do
        keys[idx] = key
        idx = idx + 1
    end

    table.sort(keys, func)

    local index = 1
    return function()
        local key = keys[index]
        index = index + 1
        return key, tbl[key]
    end
end

local function io_read_lines(filename)
    local ret = {}
    for line in io.lines(filename) do
        table.insert(ret, line)
    end
    return ret
end

local function io_write_lines(filename, tbl, eol)
    eol = eol or "\n"
    local fh = assert(io.open(filename, "w"))
    for _, line in ipairs(tbl) do
        fh:write(line, eol)
    end
    fh:close()
end

local function io_read_file(filename)
    local fh = assert(io.open(filename, "r"))
    local str = fh:read("a")
    fh:close()
    return str
end

local function io_write_file(filename, data)
    local fh = assert(io.open(filename, "w+"))
    fh:write(data)
    fh:close()
end

local function io_append_file(filename, data)
    local fh = assert(io.open(filename, "a+"))
    fh:write(data)
    fh:close()
end

local function table_copy(orig, copies)
    copies = copies or {}
    if type(orig) == 'table' then
        if copies[orig] then
            return copies[orig]
        else
            local copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[table_copy(orig_key, copies)] = table_copy(orig_value, copies)
            end
            setmetatable(copy, table_copy(getmetatable(orig), copies))
            return copy
        end
    else
        return orig
    end
end

local function table_tostring(tbl, name)
    arg_check_type("table.tostring", 1, tbl, 'table')
    arg_check_type("table.tostring", 2, name, 'string', 'nil')

    local str = serpent.block(tbl, {
        sortkeys = true,
        indent = "    ",
        --sparse = true,
        compact = false,
        comment = false,
        nocode = true
    })
    if name then
        return name .. " = " .. str
    end
    return str
end

local function table_print(tbl, name)
    arg_check_type("table.print", 1, tbl, 'table')
    arg_check_type("table.print", 2, name, 'string', 'nil')
    print(table_tostring(tbl, name))
end

local function table_remove_if(tbl, func)
    arg_check_type("table.remove", 1, tbl, 'table')
    arg_check_type("table.remove", 2, func, 'function')
    local remove = {}
    for i, item in ipairs(tbl) do
        if (func(item)) then
            remove[#remove + 1] = i
        end
    end

    for i, index in ipairs(remove) do
        table.remove(tbl, index - i + 1)
    end
    return tbl
end

local function table_filter(tbl, func)
    arg_check_type("table.filter", 1, tbl, 'table')
    arg_check_type("table.filter", 2, func, 'function')
    local ret = {}
    for i, item in ipairs(tbl) do
        if (func(item)) then
            ret[#ret + 1] = item
        end
    end
    return ret
end

local function table_add_all(tbl, ...)
    arg_check_type("table.add_all", 1, tbl, 'table')
    for _, arg in ipairs { ... } do
        if type(arg) == 'table' then
            for _, item in ipairs(arg) do
                tbl[#tbl + 1] = item
            end
        else
            tbl[#tbl + 1] = arg
        end
    end
    return tbl
end

local function table_insert_all(tbl, index, ...)
    arg_check_type("table.insert_all", 1, tbl, 'table')
    arg_check_type("table.insert_all", 2, index, 'number')
    for _, arg in ipairs { ... } do
        if type(arg) == 'table' then
            for _, item in ipairs(arg) do
                table.insert(tbl, index, item)
                index = index + 1
            end
        else
            table.insert(tbl, index, arg)
            index = index + 1
        end
    end
    return tbl
end

local function table_load_file(filename, options)
    arg_check_type("table.load_file", 1, filename, 'string')
    return serpent.load(io_read_file(filename), options)
end

local function default_index(self, key)
    local value = self.tbl[key]
    if value ~= nil then
        return value
    end
    value = self.default[key]

    if value == nil and rawget(self, "error") then
        local error_type = type(self.error)
        if error_type == 'function' then
            return self.error(self.tbl, key)
        elseif error_type == 'string' then
            error(self.error:format(key), 2)
        else
            error(string.format("option '%s' is not set and is not optional", key, 2))
        end
    end

    return value
end

local default_meta = { __index = default_index }

local function default(tbl, default, error)
    return setmetatable({
        tbl = tbl,
        default = default,
        error = error
    }, default_meta)
end

local function get_home()
    local home = os.getenv("HOME")
    if (home == nil and os.get_name() == "windows") then
        home = os.getenv("homedrive") .. os.getenv("homepath")
    end
    return home
end

local function lambda(lambda_str)
    arg_check_type("lambda / L / string:l()", 1, lambda_str, 'string')

    local firstChar = lambda_str:sub(1, 1)
    local function_string
    if firstChar == ":" then
        function_string = "return function (it) return it" .. lambda_str .. "() end"
    elseif firstChar == "." then
        function_string = "return function (it) return it" .. lambda_str .. " end"
    elseif firstChar == "(" then
        local param, expression = lambda_str:match("(%(.+%))%s*%->%s*(.*)")
        if param ~= nil then
            function_string = "return function " .. param .. " return " .. expression .. " end"
        else
            function_string = "return function " .. lambda_str .. " end"
        end
    elseif lambda_str:sub(1, 2) == "->" then
        function_string = "return function (it) return " .. lambda_str:sub(3) .. " end"
    else
        function_string = "return function (it) return " .. lambda_str .. " end"
    end

    local compiled, error_message = load(function_string, lambda_str)
    if compiled == nil then
        error("error compiling lambda '" .. lambda_str .. "': " .. error_message)
    end

    local success, lambda = pcall(compiled)
    if success and type(lambda) == 'function' then
        return lambda
    else
        error("error compiling lambda '" .. lambda_str .. "': " .. error_message)
    end
end

local function starts_with(self, str)
    if self:sub(1, #str) == str then
        return true
    else
        return false
    end
end

local function ends_with(self, str)
    if self:sub(#str) == str then
        return true
    else
        return false
    end
end

local function contains(self, str)
    if self:find(#str, 1, true) then
        return true
    else
        return false
    end
end

--setting global funcitons and constants
io.read_lines = io_read_lines
io.write_lines = io_write_lines
io.read_file = io_read_file
io.write_file = io_write_file
io.append_file = io_append_file

table.copy = table_copy
table.tostring = table_tostring
table.print = table_print
table.dump = serpent.dump
table.dump_line = serpent.line
table.dump_block = serpent.block
table.load = serpent.load
table.load_file = table_load_file
table.remove_if = table_remove_if
table.filter = table_filter
table.add_all = table_add_all
table.insert_all = table_insert_all
table.default = default

math.maxdouble = 1.7976931348623158e+308
math.mindouble = 2.2250738585072014e-308

os.name = os.get_name()
os.is_windows = os.get_name() == "windows"
os.is_linux = os.get_name() == "linux"
os.is_mac = os.get_name() == "macos"
os.home = get_home()
os.separator = os.get_name() == "windows" and "\\" or "/"

string.starts_with = starts_with
string.ends_with = ends_with
string.contains = contains
string.L = lambda
L = lambda
