local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local support = require "test/support"
local toml = require "toml"

Test_toml = {}

local sample = [==[
# A small but representative document.
title = "TOML Example"
enabled = true
count = 3
ratio = 1.5
ports = [ 8000, 8001, 8002 ]
owner.name = "Tom"
owner.dob = 1979-05-27T07:32:00Z

[database]
server = "192.168.1.1"
connection_max = 5000

[[products]]
name = "Hammer"
sku = 738594937

[[products]]
name = "Nail"
sku = 284758393
]==]

function Test_toml:Test_parse_string_returns_scalars_tables_and_arrays()
    local data = toml.parse(sample, { load_from_string = true })

    lu.assertEquals("TOML Example", data.title)
    lu.assertEquals(true, data.enabled)
    lu.assertEquals(3, data.count)
    lu.assertEquals(1.5, data.ratio)
    lu.assertEquals("integer", math.type(data.count))
    lu.assertEquals("float", math.type(data.ratio))
    lu.assertEquals(8001, data.ports[2])
    lu.assertEquals("Tom", data.owner.name)
    lu.assertEquals("1979-05-27T07:32:00Z", data.owner.dob)
    lu.assertEquals("192.168.1.1", data.database.server)
    lu.assertEquals(5000, data.database.connection_max)
    lu.assertEquals(2, #data.products)
    lu.assertEquals("Hammer", data.products[1].name)
    lu.assertEquals(284758393, data.products[2].sku)
end

function Test_toml:Test_parse_supports_inline_tables_and_literal_strings()
    local data = toml.parse([==[
point = { x = 1, y = 2 }
path = 'C:\Users\demo'
literal = """line one
line two"""
]==], { load_from_string = true })

    lu.assertEquals(1, data.point.x)
    lu.assertEquals(2, data.point.y)
    lu.assertEquals([[C:\Users\demo]], data.path)
    lu.assertEquals("line one\nline two", data.literal)
end

function Test_toml:Test_parse_datetimes_as_strings_by_default()
    local data = toml.parse([==[
offset = 1979-05-27T07:32:00Z
local_datetime = 1979-05-27T07:32:00
local_date = 1979-05-27
local_time = 07:32:00
]==], { load_from_string = true })

    lu.assertEquals("string", type(data.offset))
    lu.assertEquals("1979-05-27T07:32:00Z", data.offset)
    lu.assertEquals("1979-05-27T07:32:00", data.local_datetime)
    lu.assertEquals("1979-05-27", data.local_date)
    lu.assertEquals("07:32:00", data.local_time)
end

function Test_toml:Test_parse_datetimes_as_tables()
    local data = toml.parse([==[
date = 1979-05-27
time = 07:32:00
]==], { load_from_string = true, parse_datetime_as = "table" })

    lu.assertEquals(1979, data.date.year)
    lu.assertEquals(5, data.date.month)
    lu.assertEquals(27, data.date.day)
    lu.assertEquals(7, data.time.hour)
    lu.assertEquals(32, data.time.min)
    lu.assertEquals(0, data.time.sec)
end

function Test_toml:Test_parse_uses_type_conversion_callbacks()
    local seen
    local data = toml.parse("date = 1979-05-27\n", {
        load_from_string = true,
        type_conversion = {
            ["date-local"] = function(raw)
                seen = raw
                return { raw = raw }
            end,
        },
    })

    lu.assertEquals("1979-05-27", seen)
    lu.assertEquals("1979-05-27", data.date.raw)
end

function Test_toml:Test_parse_reads_files()
    local path = support.temp_file("toml_config", [==[
name = "file example"

[server]
port = 8080
]==])

    local data = toml.parse(path)
    lu.assertEquals("file example", data.name)
    lu.assertEquals(8080, data.server.port)
end

function Test_toml:Test_parse_rejects_invalid_toml()
    local ok, err = pcall(toml.parse, "a = ", { load_from_string = true })
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "line 1")
end

function Test_toml:Test_parse_rejects_missing_files()
    local ok, err = pcall(toml.parse, support.temp_path("missing_toml"))
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "Unable to open file")
end

function Test_toml:Test_encode_returns_toml_text()
    local text = toml.encode({
        title = "demo",
        enabled = true,
        count = 3,
        ratio = 1.5,
        ports = { 8080, 8081 },
        database = { server = "localhost" },
    })

    lu.assertStrContains(text, 'title = "demo"')
    lu.assertStrContains(text, "enabled = true")
    lu.assertStrContains(text, "count = 3")
    lu.assertStrContains(text, "ratio = 1.5")
    lu.assertStrContains(text, "ports = [8080, 8081]")
    lu.assertStrContains(text, "[database]")
    lu.assertStrContains(text, 'server = "localhost"')
    lu.assertEquals("\n", text:sub(-1))
end

function Test_toml:Test_encode_round_trips_tables_and_arrays_of_tables()
    local original = {
        title = "round trip",
        ports = { 1, 2, 3 },
        products = {
            { name = "Hammer", sku = 1 },
            { name = "Nail", sku = 2 },
        },
    }

    local parsed = toml.parse(toml.encode(original), { load_from_string = true })
    lu.assertEquals("round trip", parsed.title)
    lu.assertEquals(3, parsed.ports[3])
    lu.assertEquals(2, #parsed.products)
    lu.assertEquals("Hammer", parsed.products[1].name)
    lu.assertEquals(2, parsed.products[2].sku)
end

function Test_toml:Test_encode_quotes_keys_and_preserves_unicode()
    local text = toml.encode({ ["key with space"] = "héllo" })

    lu.assertStrContains(text, '"key with space" = "héllo"')
end

function Test_toml:Test_encode_emits_datetime_strings_unquoted()
    local text = toml.encode({ when = "1979-05-27T07:32:00Z" })
    lu.assertStrContains(text, "when = 1979-05-27T07:32:00Z")
end

function Test_toml:Test_encode_supports_multiline_strings()
    local text = toml.encode({ text = "line one\nline two" }, { allow_multiline_strings = true })

    lu.assertStrContains(text, 'text = """line one')
    lu.assertStrContains(text, "line two")
end

function Test_toml:Test_module_metadata()
    lu.assertStrContains(toml._VERSION, "tinytoml")
    lu.assertEquals("1.1.0", toml._TOML_VERSION)
    lu.assertEquals("MIT", toml._LICENSE)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
