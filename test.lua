require "sqlite3"

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
