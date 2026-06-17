local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

Test_auxiliary = {}

--[[ zig functions ]]

function Test_auxiliary.Test_string_split()
    lu.assertEquals({ "1", "2", "3", "4", n = 4 }, table.pack(string.split("1,2,3,4")))
    lu.assertEquals({ "one", "two", "three", "four", n = 4 }, table.pack(string.split("one|two|three|four", '|')))
    lu.assertEquals({ "", "la", "le", "lu", "", n = 5 }, table.pack(string.split("<>la<>le<>lu<>", '<>')))
    lu.assertEquals({ "", "", "", "", n = 4 }, table.pack(string.split(";;;", ';')))
    lu.assertEquals({ "Test", n = 1 }, table.pack(string.split("Test", ';')))
end

function Test_auxiliary.Test_string_to_table()
    lu.assertEquals({ "1", "2", "3", "4" }, string.to_table("1,2,3,4"))
    lu.assertEquals({ "one", "two", "three", "four" }, string.to_table("one|two|three|four", '|'))
    lu.assertEquals({ "", "la", "le", "lu", "" }, string.to_table("<>la<>le<>lu<>", '<>'))
    lu.assertEquals({ "", "", "", "" }, string.to_table(";;;", ';'))
    lu.assertEquals({ "Test" }, string.to_table("Test", ';'))
end

function Test_auxiliary.Test_string_trim()
    lu.assertEquals("Test", string.trim("Test"))
    lu.assertEquals("Test", string.trim("      Test      "))
    lu.assertEquals("Test", (" Test "):trim())
    lu.assertEquals("Test", string.trim("\t\t Test \n\n"))
    lu.assertEquals("Test", string.trim("  \t  \t Test \r\n "))
end

function Test_auxiliary.Test_string_ltrim()
    lu.assertEquals("Test", string.ltrim("Test"))
    lu.assertEquals("Test      ", string.ltrim("      Test      "))
    lu.assertEquals("Test ", (" Test "):ltrim())
    lu.assertEquals("Test \n\n", string.ltrim("\t\t Test \n\n"))
    lu.assertEquals("Test \r\n ", string.ltrim("  \t  \t Test \r\n "))
end

function Test_auxiliary.Test_string_rtrim()
    lu.assertEquals("Test", string.rtrim("Test"))
    lu.assertEquals("      Test", string.rtrim("      Test      "))
    lu.assertEquals(" Test", (" Test "):rtrim())
    lu.assertEquals("\t\t Test", string.rtrim("\t\t Test \n\n"))
    lu.assertEquals("  \t  \t Test", string.rtrim("  \t  \t Test \r\n "))
end

function Test_auxiliary.Test_os_nanotime()
    local first = os.nanotime()
    lu.assertEquals("number", type(first))
    local second = os.nanotime()
    lu.assertIsTrue(first < second)
end

function Test_auxiliary.Test_table_next()
    local tbl = { 'a', 'b', 'c', 'd' }
    local actual = {}
    local i = 1
    for itm in table.next(tbl) do
        actual[i] = itm
        i = i + 1
    end
    lu.assertEquals(tbl, actual)
end

function Test_auxiliary.Test_os_get_name()
    local names = { windows = true, linux = true, macos = true, unknown = true }
    lu.assertIsTrue(names[os.get_name()])
end

local b64_encoded = "VGhpcyBpcyBhIHRlc3Qgc3RyaW5nIDEyMyE="
local b64_decoded = "This is a test string 123!"

function Test_auxiliary.Test_base64encode()
    lu.assertEquals(b64_encoded, b64_decoded:base64encode())
end

function Test_auxiliary.Test_base64decode()
    lu.assertEquals(b64_decoded, b64_encoded:base64decode())
end

function Test_auxiliary.Test_base64urlEncode()
    lu.assertEquals(b64_encoded, b64_decoded:base64urlEncode())
end

function Test_auxiliary.Test_base64urlDecode()
    lu.assertEquals(b64_decoded, b64_encoded:base64decode())
end

function Test_auxiliary.Test_urlEncode()
    lu.assertEquals(7, ("ÖÄÜßüäö"):utf8len())
end

--[[ lua functions ]]

function Test_auxiliary.Test_sorted_pairs()
    local tbl = { Z = 6, B = 2, A = 1, C = 3, Y = 5, X = 4 }
    local expected = "A=1,B=2,C=3,X=4,Y=5,Z=6"
    local actual = {}
    for k, v in sorted_pairs(tbl) do
        actual[#actual + 1] = k .. "=" .. v
    end
    lu.assertEquals(expected, table.concat(actual, ","))
end

function Test_auxiliary.Test_string_starts_with()
    lu.assertIsTrue(("Test"):starts_with "T")
    lu.assertIsTrue(("Test"):starts_with "Te")
    lu.assertIsTrue(("Test"):starts_with "Tes")
    lu.assertIsTrue(("Test"):starts_with "Test")
    lu.assertIsFalse(("Test"):starts_with "t")
    lu.assertIsFalse(("Test1"):starts_with "1")
end

function Test_auxiliary.Test_string_ends_with()
    lu.assertIsTrue(("Test"):ends_with "t")
    lu.assertIsTrue(("Test"):ends_with "st")
    lu.assertIsTrue(("Test"):ends_with "est")
    lu.assertIsTrue(("Test"):ends_with "Test")
    lu.assertIsFalse(("Test"):ends_with "T")
end

function Test_auxiliary.Test_string_contains()
    lu.assertIsTrue(("Test"):contains "T")
    lu.assertIsTrue(("Test"):contains "e")
    lu.assertIsTrue(("Test"):contains "s")
    lu.assertIsTrue(("Test"):contains "t")

    lu.assertIsTrue(("Test"):contains "Te")
    lu.assertIsTrue(("Test"):contains "es")
    lu.assertIsTrue(("Test"):contains "st")
    lu.assertIsTrue(("Test"):contains "Test")
end

function Test_auxiliary.Test_string_is_empty()
    lu.assertIsTrue((""):is_empty())
    lu.assertIsFalse(("Test"):is_empty())
end

function Test_auxiliary.Test_string_is_not_empty()
    lu.assertIsFalse((""):is_not_empty())
    lu.assertIsTrue(("Test"):is_not_empty())
end

function Test_auxiliary.Test_maxdouble()
    lu.assertEquals(1.7976931348623158e+308, math.maxdouble)
end

function Test_auxiliary.Test_mindouble()
    lu.assertEquals(2.2250738585072014e-308, math.mindouble)
end

function Test_auxiliary.Test_is_os()
    if os.name == "windows" then
        lu.assertIsTrue(os.is_windows)
        lu.assertIsFalse(os.is_linux)
        lu.assertIsFalse(os.is_mac)
    elseif os.name == "linux" then
        lu.assertIsFalse(os.is_windows)
        lu.assertIsTrue(os.is_linux)
        lu.assertIsFalse(os.is_mac)
    elseif os.name == "macos" then
        lu.assertIsFalse(os.is_windows)
        lu.assertIsFalse(os.is_linux)
        lu.assertIsTrue(os.is_mac)
    end
end

local textFileContents = [[
one
two

four
]]

local textLines = {
    'one',
    'two',
    '',
    'four',
}

function Test_auxiliary.Test_io_write_read_file()
    io.write_file("./test/temp/textfile", textFileContents)
    lu.assertEquals(textFileContents, io.read_file("./test/temp/textfile"))
end

function Test_auxiliary.Test_io_write_lines()
    io.write_lines("./test/temp/textlines", textLines)
    lu.assertEquals(textFileContents, io.read_file("./test/temp/textlines"))
end

function Test_auxiliary.Test_io_read_lines()
    io.write_lines("./test/temp/textlines", textLines)
    lu.assertEquals(textLines, io.read_lines("./test/temp/textlines"))
end

function Test_auxiliary.Test_io_append_file()
    io.write_file("./test/temp/textfile", textFileContents)
    local additional = "five\n"
    io.append_file("./test/temp/textfile", additional)
    lu.assertEquals(textFileContents .. additional, io.read_file("./test/temp/textfile"))
end

local testTable = {
    'one',
    'two',
    'three',
    subtable = {
        1, 2, 3
    },
    flag = true,
}

function Test_auxiliary.Test_table_copy()
    local copy = table.copy(testTable)
    lu.assertEquals(testTable, copy)
    lu.assertFalse(testTable == copy)
end

function Test_auxiliary.Test_table_tostring()
    lu.assertEquals([[
{
    "one",
    "two",
    "three",
    flag = true,
    subtable = {
        1,
        2,
        3
    }
}]], table.tostring(testTable))
end

function Test_auxiliary.Test_table_tostring_with_name()
    lu.assertEquals([[
tbl = {
    "one",
    "two",
    "three",
    flag = true,
    subtable = {
        1,
        2,
        3
    }
}]], table.tostring(testTable, "tbl"))
end

function Test_auxiliary.Test_table_save_read()
    local filename = "./test/temp/savedTable"
    table.save(filename, testTable)
    lu.assertEquals(testTable, table.load(filename))
end

local function filter(i)
    return i % 2 == 0 and true or false
end

function Test_auxiliary.Test_table_remove_if()
    local tbl = { 1, 2, 3, 4, 5, 6 }
    table.remove_if(tbl, filter)
    lu.assertEquals({ 1, 3, 5 }, tbl)
end

function Test_auxiliary.Test_table_filter()
    local tbl = { 1, 2, 3, 4, 5, 6 }
    local filtered = table.filter(tbl, filter)
    lu.assertEquals({ 2, 4, 6 }, filtered)
    lu.assertEquals(6, #tbl)
end

function Test_auxiliary.Test_table_add_all_with_numbers()
    local tbl = { 1, 2, 3 }
    table.add_all(tbl, 4, 5, 6)
    lu.assertEquals({ 1, 2, 3, 4, 5, 6 }, tbl)
end

function Test_auxiliary.Test_table_add_all_with_tables()
    local tbl = { 1, 2, 3 }
    table.add_all(tbl, { 4, 5 }, { 6, 7, 8 })
    lu.assertEquals({ 1, 2, 3, 4, 5, 6, 7, 8 }, tbl)
end

function Test_auxiliary.Test_table_insert_all_with_numbers()
    local tbl = { 4, 5, 9 }
    table.insert_all(tbl, 3, 6, 7, 8)
    lu.assertEquals({ 4, 5, 6, 7, 8, 9 }, tbl)
    table.insert_all(tbl, 1, 1, 2, 3)
    lu.assertEquals({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, tbl)
end

function Test_auxiliary.Test_table_insert_all_with_tables()
    local tbl = { 4, 5, 9 }
    table.insert_all(tbl, 3, { 6, 7, 8 })
    lu.assertEquals({ 4, 5, 6, 7, 8, 9 }, tbl)
    table.insert_all(tbl, 1, { 1, 2, 3 })
    lu.assertEquals({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, tbl)
end

function Test_auxiliary.Test_table_default()
    local tbl = table.default({ zero = 0 }, { one = 1, two = "two", three = true })
    lu.assertEquals(0, tbl.zero)
    lu.assertEquals(1, tbl.one)
    lu.assertEquals("two", tbl.two)
    lu.assertEquals(true, tbl.three)
    lu.assertIsNil(tbl.not_set)
end

function Test_auxiliary.Test_table_default_error_func()
    local miss = {}
    local tbl = table.default({ zero = 0 }, { one = 1, two = "two", three = true },
        function(t, k) miss[#miss + 1] = k end)
    local _ = tbl.not_set
    local _ = tbl.other
    local _ = tbl[true]
    lu.assertEquals({ "not_set", "other", true }, miss)
end

function Test_auxiliary.Test_table_default_error_func()
    local miss = {}
    local tbl = table.default({ zero = 0 }, { one = 1, two = "two", three = true },
        function(t, k) miss[#miss + 1] = k end)
    local _ = tbl.not_set
    local _ = tbl.other
    local _ = tbl[true]
    lu.assertEquals({ "not_set", "other", true }, miss)
end

function Test_auxiliary.Test_table_insert_sorted()
    local tbl = {}
    table.insert_sorted(tbl, 9)
    table.insert_sorted(tbl, 1)
    table.insert_sorted(tbl, 5)
    table.insert_sorted(tbl, 3)
    table.insert_sorted(tbl, 6)
    table.insert_sorted(tbl, 8)
    table.insert_sorted(tbl, 7)
    table.insert_sorted(tbl, 2)
    table.insert_sorted(tbl, 4)
    lu.assertEquals({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, tbl)
end

function Test_auxiliary.Test_os_home()
    lu.assertNotIsNil(os.home)
    lu.assertNotEquals("", os.home)
end

function Test_auxiliary.Test_math_round()
    lu.assertEquals(42, math.round(42))
    lu.assertEquals(42, math.round(42.2))
    lu.assertEquals(42, math.round(42.49))

    lu.assertEquals(42, math.round(42.5))
    lu.assertEquals(43, math.round(42.50001))
    lu.assertEquals(43, math.round(42.7))
    lu.assertEquals(43, math.round(42.99))

    lu.assertEquals(41, math.round(41))
    lu.assertEquals(41, math.round(41.2))
    lu.assertEquals(41, math.round(41.49))

    lu.assertEquals(42, math.round(41.5))
    lu.assertEquals(42, math.round(41.7))
    lu.assertEquals(42, math.round(41.99))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
