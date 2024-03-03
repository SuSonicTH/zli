local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local stream = require "stream"

Test_stream = {}

function Test_stream:Test_concat()
    lu.assertEquals("1,2,3,4,5", stream({ 1, 2, 3, 4, 5 }):concat(","))
end

function Test_stream:Test_toarray()
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ 1, 2, 3, 4, 5 }):toarray())
end

function Test_stream:Test_map()
    lu.assertEquals({ 2, 3, 4, 5, 6 }, stream({ 1, 2, 3, 4, 5 }):map(function(v) return v + 1 end):toarray())
end

function Test_stream:Test_filter()
    lu.assertEquals({ 1, 3, 5 }, stream({ 1, 2, 3, 4, 5 }):filter(function(v) return v % 2 == 1 end):toarray())
    lu.assertEquals({ 2, 4 }, stream({ 1, 2, 3, 4, 5 }):filter(function(v) return v % 2 == 0 end):toarray())
end

function Test_stream:Test_skip()
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ 1, 2, 3, 4, 5 }):skip(0):toarray())
    lu.assertEquals({ 2, 3, 4, 5 }, stream({ 1, 2, 3, 4, 5 }):skip(1):toarray())
    lu.assertEquals({ 5 }, stream({ 1, 2, 3, 4, 5 }):skip(4):toarray())
end

function Test_stream:Test_limit()
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ 1, 2, 3, 4, 5 }):limit(10):toarray())
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ 1, 2, 3, 4, 5 }):limit(5):toarray())
    lu.assertEquals({ 1 }, stream({ 1, 2, 3, 4, 5 }):limit(1):toarray())
    lu.assertEquals({ 1, 2, 3 }, stream({ 1, 2, 3, 4, 5 }):limit(3):toarray())
end

function Test_stream:Test_reverse()
    lu.assertEquals({ 5, 4, 3, 2, 1 }, stream({ 1, 2, 3, 4, 5 }):reverse():toarray())
end

function Test_stream:Test_sort()
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ 4, 5, 1, 3, 2 }):sort():toarray())
end

function Test_stream:Test_maptonumber()
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ 1, 2, 3, 4, 5 }):maptonumber():toarray())
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ '1', '2', '3', '4', '5' }):maptonumber():toarray())
end

function Test_stream:Test_distinct()
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ 1, 1, 5, 2, 3, 2, 3, 4, 1, 5, 1, 4, 5 }):distinct():sort():toarray())
end

function Test_stream:Test_split()
    local odd, even = stream({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):split(function(num) return num % 2 == 1 end)
    lu.assertEquals("1,3,5,7,9", stream(odd):concat(","))
    lu.assertEquals("2,4,6,8", stream(even):concat(","))

    odd, even = stream({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):split(function(num) return num % 2 == 1 end)
    lu.assertEquals("2,4,6,8", stream(even):concat(","))
    lu.assertEquals("1,3,5,7,9", stream(odd):concat(","))
end

function Test_stream:Test_join()
    lu.assertEquals(
        stream().join(stream({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):split(function(num) return num % 2 == 1 end)):concat(","),
        "1,3,5,7,9,2,4,6,8"
    )

    lu.assertEquals(
        "1,2,3,4,5,6,7,8,9,10",
        stream({ 1, 2, 3, 4 }):join(stream({ 5, 6, 7, 8, 9 }), stream({ 10 })):concat(",")
    )
end

function Test_stream:Test_tosortedarray()
    lu.assertEquals({ 1, 2, 3, 4, 5 }, stream({ 4, 5, 1, 3, 2 }):tosortedarray())
end

function Test_stream:Test_allmatch()
    lu.assertIsTrue(stream({ 1, 3, 5, 7, 9 }):allmatch(function(val) return val % 2 == 1 end))
    lu.assertIsFalse(stream({ 1, 3, 5, 2, 7, 9 }):allmatch(function(val) return val % 2 == 1 end))
end

function Test_stream:Test_firstmatch()
    lu.assertEquals(4, stream({ 1, 2, 3, 4, 5 }):firstmatch(function(val) return val > 3 end))
end

function Test_stream:Test_anymatch()
    lu.assertIsTrue(stream({ 1, 3, 5, 7, 8, 9 }):anymatch(function(val) return val % 2 == 0 end))
    lu.assertIsFalse(stream({ 1, 3, 5, 7, 9 }):anymatch(function(val) return val % 2 == 0 end))
end

function Test_stream:Test_first()
    lu.assertEquals(3, stream({ 3, 5, 7, 8, 9 }):first())
end

function Test_stream:Test_last()
    lu.assertEquals(9, stream({ 3, 5, 7, 8, 9 }):last())
end

function Test_stream:Test_count()
    lu.assertEquals(5, stream({ 3, 5, 7, 8, 9 }):count())
    lu.assertEquals(9, stream({ 1, 2, 3, 4, 5, 6, 7, 8, 9 }):count())
end

function Test_stream:Test_sum()
    lu.assertEquals(32, stream({ 3, 5, 7, 8, 9 }):sum())
    lu.assertEquals(3, stream({ 3 }):sum())
    lu.assertEquals(0, stream({}):sum())
end

function Test_stream:Test_average()
    lu.assertEquals(6.4, stream({ 3, 5, 7, 8, 9 }):average())
    lu.assertEquals(3, stream({ 3 }):average())
    lu.assertEquals(0, stream({}):average())
end

function Test_stream:Test_median()
    lu.assertEquals(7, stream({ 3, 5, 7, 8, 9 }):median())
    lu.assertEquals(7, stream({ 8, 9, 3, 5, 7, 10, 1 }):median())
    lu.assertEquals(3, stream({ 3 }):median())
    lu.assertEquals(0, stream({}):median())
end

function Test_stream:Test_reduce()
    lu.assertEquals(32, stream({ 3, 5, 7, 8, 9 }):reduce(0, function(sum, value) return sum + value end))
end

function Test_stream:Test_min()
    lu.assertEquals(3, stream({ 3, 5, 7, 8, 9 }):min())
    lu.assertEquals(3, stream({ 5, 7, 8, 9, 3 }):min())
end

function Test_stream:Test_max()
    lu.assertEquals(9, stream({ 3, 5, 7, 8, 9 }):max())
    lu.assertEquals(10, stream({ 10, 3, 5, 7, 8, 9 }):max())
end

function Test_stream:Test_groupby()
    local map = stream({
        { name = 'test',   id = 1 },
        { name = 'test',   id = 2 },
        { name = 'other',  id = 3 },
        { name = 'other',  id = 4 },
        { name = 'single', id = 5 }
    }):groupby(function(tbl) return tbl.name end)

    lu.assertEquals(2, #map.test)
    lu.assertEquals(2, #map.other)
    lu.assertEquals(1, #map.single)

    lu.assertEquals({ name = 'test', id = 1 }, map.test[1])
    lu.assertEquals({ name = 'test', id = 2 }, map.test[2])

    lu.assertEquals(3, map.other[1].id)
    lu.assertEquals(4, map.other[2].id)

    lu.assertEquals({ name = 'single', id = 5 }, map.single[1])
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
