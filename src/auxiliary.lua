local serpent = require "serpent"

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

local function deepcopy(orig, copies)
    copies = copies or {}
    if type(orig) == 'table' then
        if copies[orig] then
            return copies[orig]
        else
            local copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
            return copy
        end
    else
        return orig
    end
end

local function table_tostring(tbl, name)
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

local function table_load_file(filename, options)
    return serpent.load(io_read_file(filename), options)
end

--setting global funcitons
io.readlines = io_read_lines
io.write_lines = io_write_lines
io.read_file = io_read_file
io.write_file = io_write_file
io.append_file = io_append_file

table.copy = deepcopy
table.tostring = table_tostring
table.dump = serpent.dump
table.dump_line = serpent.line
table.dump_block = serpent.block
table.load = serpent.load
table.load_file = table_load_file

math.maxdouble = 1.7976931348623158e+308
math.mindouble = 2.2250738585072014e-308
