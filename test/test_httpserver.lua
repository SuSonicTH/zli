local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local http = require "httpserver"

Test_httpserver = {}

function Test_httpserver.Test_resolve_web_path()
    lu.assertEquals("/srv/a/b", http.resolve_web_path("/srv/", "/a/b"))
    lu.assertEquals("/srv/a", http.resolve_web_path("/srv/", "/a/../a"))
    lu.assertEquals("/srv/a", http.resolve_web_path("/srv/", "/a?query=1"))
    lu.assertEquals("/srv/a", http.resolve_web_path("/srv/", "/%61"))
end

function Test_httpserver.Test_resolve_web_path_blocks_traversal()
    lu.assertEquals("/srv/etc/passwd", http.resolve_web_path("/srv/", "/../../etc/passwd"))
    lu.assertEquals("/srv/etc/passwd", http.resolve_web_path("/srv/", "/%2e%2e/%2e%2e/etc/passwd"))
end

function Test_httpserver.Test_cache_and_free_cache()
    http.clear_cache()
    local calls = 0
    local cached = http.cache(function()
        calls = calls + 1
        return "value"
    end, 100)

    lu.assertEquals("value", cached({}, { target = "/a" }))
    lu.assertEquals("value", cached({}, { target = "/a" }))
    lu.assertEquals(1, calls)

    http.free_cache(-1)
    lu.assertEquals("value", cached({}, { target = "/a" }))
    lu.assertEquals(2, calls)
    http.clear_cache()
end

function Test_httpserver.Test_serve_file_missing_returns_404()
    local response = http.serve_file("./test/temp/does-not-exist")
    lu.assertEquals(http.status.not_found, response.status)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
