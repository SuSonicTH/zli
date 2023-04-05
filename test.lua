require "sqlite3"
require "lpeg"
require "lfs"
require "zlib"
require "os"
local lu = require 'luaunit/luaunit'

TestLibraries = {}

function TestLibraries:test_zlib()
    local test_string = "abcdefghijklmnopqrstuvabcdefghijklmnopqrstuv"
    local deflated = zlib.deflate()(test_string, "finish")
    local inflated = zlib.inflate()(deflated, "finish")
    lu.assertEquals(test_string, inflated)
end

function TestLibraries:test_lpeg()
    local number = lpeg.R "09" ^ 1 / tonumber
    local list = number * ("," * number) ^ 0
    local function add(acc, newvalue) return acc + newvalue end
    local sum = lpeg.Cf(list, add)
    lu.assertEquals(83, sum:match("10,30,43"))
end

function TestLibraries:test_lfs()
    local actual = {}
    for file in lfs.dir("./src/") do
        actual[#actual + 1] = file
    end
    table.sort(actual)
    lu.assertEquals({ '.', '..', 'linit.c', 'lualib.h' }, actual)
end

function TestLibraries:test_sqlite()
    local db=sqlite3.open('test.sqlite3')
    db:exec[=[
              CREATE TABLE numbers(num,val);
              INSERT INTO numbers VALUES(1,'one');
              INSERT INTO numbers VALUES(2,'two');
              INSERT INTO numbers VALUES(3,'three');
            ]=]
    
    local actual = {}
    for a in db:nrows('SELECT * FROM numbers') do
        for k,v in pairs(a) do
            actual[#actual+1]=k..':'..v
        end
    end
    db:close()
    os.remove('test.sqlite3')
    
    local expected = {
        "val:one",
        "num:1",
        "val:two",
        "num:2",
        "val:three",
        "num:3",
    }
    
    lu.assertEquals(expected, actual)
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
