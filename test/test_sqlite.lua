local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local json = require "cjson"
local sqlite = require "sqlite3"
local support = require "test/support"

Test_sqlite = {}

local function new_home()
    return support.temp_dir("sqlite_home")
end

local function run_sqlite(input, home)
    return support.run({ "@sqlite" }, {
        home = home,
        stdin = input,
    })
end

local function find_json_array(output)
    for line in output:gmatch("[^\n]+") do
        local trimmed = line:trim()
        if trimmed:sub(1, 1) == "[" and trimmed:sub(-1) == "]" then
            return json.decode(trimmed)
        end
    end
    return nil
end

function Test_sqlite.Test_executes_statements_and_prints_table()
    local home = new_home()
    local stdout, status = run_sqlite([[
create table people (id integer primary key, name text);
insert into people (name) values ('alice');
insert into people (name) values ('bob');
select * from people;
quit;
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "ZLI - SQLite")
    lu.assertStrContains(stdout, "OK")
    lu.assertStrContains(stdout, "| id | name")
    lu.assertStrContains(stdout, "alice")
    lu.assertStrContains(stdout, "bob")

    lu.assertTrue(fs.exists(home .. "/.config/zli/sqlite_history"))
end

function Test_sqlite.Test_accepts_commands_spanning_multiple_lines()
    local home = new_home()
    local stdout, status = run_sqlite([[
create table multi (
    id integer,
    name text
);
insert into multi values (1, 'multi line');
select * from multi;
quit;
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "multi line")
end

function Test_sqlite.Test_switches_output_modes()
    local home = new_home()
    local stdout, status = run_sqlite([[
create table people (id integer primary key, name text);
insert into people (name) values ('alice');
mode csv;
select * from people;
mode json;
select * from people;
mode lua;
select * from people;
mode;
quit;
]], home)

    lu.assertEquals(0, status, stdout)

    lu.assertStrContains(stdout, "id,name")
    lu.assertStrContains(stdout, "1,alice")

    local decoded = find_json_array(stdout)
    lu.assertNotIsNil(decoded, stdout)
    lu.assertEquals("alice", decoded[1].name)
    lu.assertEquals("1", decoded[1].id)

    lu.assertStrContains(stdout, "result = {")
    lu.assertStrContains(stdout, 'name = "alice"')
    lu.assertStrContains(stdout, "current mode: lua")
end

function Test_sqlite.Test_reports_errors_and_continues()
    local home = new_home()
    local stdout, status = run_sqlite([[
select * from missing;
mode unknown;
mode;
file "test/temp/sqlite-missing.sql";
quit;
]], home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "Error: no such table: missing")
    lu.assertStrContains(stdout, "Error: mode unknown unknown")
    lu.assertStrContains(stdout, "current mode: table")
    lu.assertStrContains(stdout, "sqlite-missing.sql")
end

function Test_sqlite.Test_executes_sql_file()
    local home = new_home()
    local sql = support.temp_file("sqlite_script", [[
create table scripted (id integer, name text);
insert into scripted values (1, 'from-file');
]])

    local stdout, status = run_sqlite('file "' .. sql .. '";\nselect * from scripted;\nquit;\n', home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "> create table scripted")
    lu.assertStrContains(stdout, "from-file")
end

function Test_sqlite.Test_open_and_close_persist_database()
    local home = new_home()
    local db_path = support.temp_path("sqlite_db") .. ".sqlite"
    if fs.exists(db_path) then
        fs.path(db_path):delete()
    end

    local stdout, status = run_sqlite(string.format([[
open %q;
create table t (x integer);
insert into t values (42);
close;
open %q;
select * from t;
quit;
]], db_path, db_path), home)

    lu.assertEquals(0, status, stdout)
    lu.assertStrContains(stdout, "42")

    -- verify the data was actually written to the database file
    local db = assert(sqlite.open(db_path))
    local rows = {}
    local result = db:exec("select x from t", function(_, _, values)
        rows[#rows + 1] = values[1]
        return 0
    end)
    db:close()

    lu.assertEquals(sqlite.OK, result)
    lu.assertEquals(1, #rows)
    lu.assertEquals("42", rows[1])
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
