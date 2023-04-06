local sqlite3 = require "sqlite3"
local lpeg = require "lpeg"
local lfs = require "lfs"
local zlib = require "zlib"
local lu = require 'luaunit'
local re = require 're'
local aux = require "aux"

TestLibraries = {}

function TestLibraries:test_zlib()
    local test_string = "abcdefghijklmnopqrstuvabcdefghijklmnopqrstuv"
    local deflated = zlib.deflate()(test_string, "finish")
    local inflated = zlib.inflate()(deflated, "finish")
    lu.assertEquals(inflated, test_string)
end

function TestLibraries:test_lpeg()
    local number = lpeg.R "09" ^ 1 / tonumber
    local list = number * ("," * number) ^ 0
    local function add(acc, newvalue) return acc + newvalue end
    local sum = lpeg.Cf(list, add)
    lu.assertEquals(sum:match("10,30,43"),83)
end

function TestLibraries:test_re()
    lu.assertEquals(re.gsub("hello World", "[aeiou]", "."),"h.ll. W.rld")
end

function TestLibraries:test_lfs()
    local actual = {}
    for file in lfs.dir("./src/") do
        actual[#actual + 1] = file
    end
    table.sort(actual)
    lu.assertEquals(actual, {
        ".",
        "..",
        "fm_aux.c",
        "fm_aux.h",
        "linit.c",
        "lualib.h",
        "lx_value.c",
        "lx_value.h"
    })
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
    for result in db:nrows('SELECT num, val FROM numbers order by 1') do
        actual[#actual+1]=result.num..':'..result.val
    end
    db:close()
    os.remove('test.sqlite3')
    
    local expected = {"1:one", "2:two", "3:three"}
    
    lu.assertEquals(actual, expected)
end

function TestLibraries:test_aux()
    local TEST="   TEST   "
    lu.assertEquals(aux.ltrim(TEST), "TEST   ")
    lu.assertEquals(aux.rtrim(TEST), "   TEST")
    lu.assertEquals(aux.trim(TEST), "TEST")
    lu.assertEquals({aux.split("1,2,3")}, {"1","2","3"})
end

local runner = lu.LuaUnit.new()
runner:setOutputType("text")
os.exit(runner:runSuite())
