local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

Test_auxiliary = {}

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

function Test_auxiliary.Test_table_create()
    local tbl = table.create(5, 0)
    for i = 1, 5 do
        tbl[i] = i
    end

    lu.assertEquals({ 1, 2, 3, 4, 5 }, tbl)
    lu.assertError(table.create)
    lu.assertError(table.create, 1)
    lu.assertError(table.create, "1", 2)
end

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

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
