require "sqlite3"
require "lpeg"
require "lfs"
require "zlib"
require "os"

local db=sqlite3.open('MyDatabase.sqlite3')
db:exec[=[
          CREATE TABLE numbers(num1,num2);
          INSERT INTO numbers VALUES(1,11);
          INSERT INTO numbers VALUES(2,22);
          INSERT INTO numbers VALUES(3,33);
        ]=]
for a in db:nrows('SELECT * FROM numbers') do 
    for k,v in pairs(a) do
        print (k..':'..v) 
    end
end
db:close()
os.remove('MyDatabase.sqlite3')

number = lpeg.R"09"^1 / tonumber
list = number * ("," * number)^0
function add (acc, newvalue) return acc + newvalue end
sum = lpeg.Cf(list, add)
print(sum:match("10,30,43"))

for file in lfs.dir ("luafilesystem") do
    print (file)
end

local test_string = "abcdefghijklmnopqrstuvabcdefghijklmnopqrstuv"
local deflated = zlib.deflate()(test_string, "finish")
local inflated = zlib.inflate()(deflated, "finish")
print (inflated)
print (inflated==test_string)
