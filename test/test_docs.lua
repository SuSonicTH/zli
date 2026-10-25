local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local support = require "test/support"
local docs = require "docs"
local markdown = require "docs_markdown"
local cjson = require "cjson"

Test_docs = {}

local function normalized(text)
    return (text:gsub("\r\n", "\n"))
end

local function split_lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function excerpt(text, limit)
    text = tostring(text or "")
    limit = limit or 160
    if #text <= limit then
        return text
    end
    return text:sub(1, limit) .. " ..."
end

--- Compare two multi-line documents without passing them to LuaUnit.
--
-- The mirror below is a few hundred kilobytes.  Reporting a mismatch through
-- lu.assertEquals puts both documents into the failure message, and LuaUnit
-- then matches `'.*:%d+: '` against that message, which is quadratic in its
-- length: a stale mirror turns into a test that appears to hang for minutes.
-- Compare line by line instead and keep the failure message to the first
-- differing line.
local function assert_same_document(expected, actual, label)
    expected, actual = normalized(expected), normalized(actual)
    if expected == actual then
        return
    end

    local expected_lines = split_lines(expected)
    local actual_lines = split_lines(actual)
    local count = math.max(#expected_lines, #actual_lines)
    for index = 1, count do
        if expected_lines[index] ~= actual_lines[index] then
            lu.fail(string.format(
                "%s differs at line %d (%d lines expected, %d lines actual)\n"
                    .. "  expected: %s\n  actual:   %s\n"
                    .. "regenerate with `zig build docs` and rebuild with `zig build`",
                label, index, #expected_lines, #actual_lines,
                excerpt(expected_lines[index]), excerpt(actual_lines[index])))
        end
    end
    lu.fail(label .. " differs in its trailing newline")
end

local MAX_FAILURE_MESSAGE = 8000

--- Wrap an assertion so a failure message stays small.
--
-- LuaUnit classifies a failure by matching `'.*:%d+: ' .. prefix .. '.*'`
-- against the whole error message.  The leading `.*` makes that match behave
-- quadratically, so a message that embeds the one megabyte manual HTML (or the
-- 300 KB markdown mirror) takes minutes instead of failing.  Cutting the
-- message keeps the location, the assertion text and the start of the report.
local function bounded(assertion)
    return function(...)
        local ok, err = pcall(assertion, ...)
        if ok then
            return
        end
        err = tostring(err)
        if #err > MAX_FAILURE_MESSAGE then
            err = err:sub(1, MAX_FAILURE_MESSAGE) .. "\n... (failure message truncated)"
        end
        error(err, 0)
    end
end

-- The manual HTML is over a megabyte, so these are the assertions that must
-- never hand a raw haystack to LuaUnit.
local assert_contains = bounded(lu.assertStrContains)
local assert_not_contains = bounded(lu.assertNotStrContains)

local function index_entry(index, name)
    for _, item in ipairs(index.entries or {}) do
        if item.n == name then return item end
    end
    return nil
end

-- Always isolate the payload tools from the developer's real configuration.
-- ZLI executes ~/.config/zli/init.lua before every tool, so a printing init
-- script would otherwise contaminate captured output.
local function run(args, options)
    options = options or {}
    return support.run(args, {
        exe = options.exe,
        home = options.home or support.temp_dir("docs_home"),
        stdin = options.stdin,
    })
end

-- README.md display names that differ from the module name passed to require.
local readme_require_names = {
    ["f-string"] = { "F" },
    ["ftcsv"] = { "csv" },
    ["lua-cjson"] = { "cjson" },
    ["luasqlite3"] = { "sqlite3" },
    ["logger"] = { "log" },
    ["unzip / zip"] = { "unzip", "zip" },
}

local readme_library_sections = {
    ["Included Lua libraries"] = true,
    ["Custom bindings to third-party libraries"] = true,
    ["ZLI libraries"] = true,
}

-- Read the library tables from README.md instead of keeping a second,
-- hardcoded list in this test.  Only the three library sections are parsed.
local function parse_readme_modules(path)
    local names = {}
    local in_section = false
    for line in fs.read_all(path):gmatch("[^\n]+") do
        local heading = line:match("^###%s+(.+)$")
        if heading then
            heading = heading:gsub("%s+$", "")
            in_section = readme_library_sections[heading] == true
        elseif line:match("^#") then
            in_section = false
        elseif in_section and line:match("^|") then
            local cell = line:match("^|%s*([^|]-)%s*|")
            if cell then
                local key = cell:gsub("`", ""):lower()
                if key ~= "" and key ~= "library" and not key:match("^%-+$") then
                    local mapped = readme_require_names[key]
                    if mapped then
                        for _, name in ipairs(mapped) do
                            names[#names + 1] = name
                        end
                    else
                        names[#names + 1] = key
                    end
                end
            end
        end
    end
    return names
end

function Test_docs.Test_structured_entries_are_available()
    local entry = docs.find("string.byte")
    lu.assertNotNil(entry)
    lu.assertEquals("function", entry.kind)
    assert_contains(entry.signature, "string.byte")

    entry = docs.find("filesystem.path")
    lu.assertNotNil(entry)
    lu.assertEquals("filesystem", entry.module)

    entry = docs.find("collection.list:add")
    lu.assertNotNil(entry)

    entry = docs.find("@compile")
    lu.assertNotNil(entry)

    entry = docs.find("ZLI.error_handling")
    lu.assertNotNil(entry)
end

function Test_docs.Test_c_api_is_absent()
    local forbidden = {
        "The Application Program Interface",
        "The Auxiliary Library",
        "Lua Standalone",
    }

    lu.assertNil(docs.find("lua_absindex"))
    lu.assertNil(docs.find("luaL_openlibs"))

    -- Check the parsed manual nodes themselves.  docs.find() on a section
    -- title normalizes to a different key, so it would be nil even when the
    -- content leaked into the manual.
    for _, node in ipairs(docs.nodes) do
        if node.type == "heading" or node.type == "entry" then
            local text = markdown.render_inline_text(
                node.title or node.signature or node.name or "")
            for _, needle in ipairs(forbidden) do
                assert_not_contains(text, needle, "C API content in manual nodes")
            end
        end
    end

    local html = docs.render_manual_html()
    for _, needle in ipairs(forbidden) do
        assert_not_contains(html, needle)
    end
    assert_not_contains(html, "lua_absindex")
    assert_not_contains(html, "luaL_openlibs")
end

function Test_docs.Test_search_ranks_exact_names()
    local results = docs.search("string.byte")
    lu.assertNotEquals(0, #results)
    lu.assertEquals("string.byte", results[1].name)

    results = docs.search("trim")
    lu.assertNotEquals(0, #results)
    lu.assertEquals("string.trim", results[1].name)

    results = docs.search("filesystem")
    lu.assertNotEquals(0, #results)
end

function Test_docs.Test_manual_html_embeds_search_index()
    local html = docs.render_manual_html()
    assert_contains(html, 'id="zli-search-index"')
    assert_contains(html, 'id="zli-search-form"')
    assert_contains(html, 'id="zli-search-view"')
    assert_contains(html, 'id="zli-search-heading"')
    assert_contains(html, "scroll-padding-top")
    assert_contains(html, "URLSearchParams")

    local payload = html:match('<script type="application/json" id="zli%-search%-index">(.-)</script>')
    lu.assertNotNil(payload)
    local index = cjson.decode(payload)
    lu.assertEquals(1, index.v)
    lu.assertEquals(#docs.entries, #index.entries)

    local expected = docs.find("string.byte")
    local item = index_entry(index, "string.byte")
    lu.assertNotNil(item)
    lu.assertEquals(expected.anchor, item.a)
    lu.assertEquals(expected.signature, item.s)
    assert_contains(item.sh, "string.byte")
end

function Test_docs.Test_search_index_matches_search_inputs()
    local index = docs.search_index()
    lu.assertEquals(#docs.entries, #index.entries)
    for i, entry in ipairs(docs.entries) do
        local item = index.entries[i]
        lu.assertEquals(entry.name, item.n)
        lu.assertEquals(entry.anchor, item.a)
        lu.assertEquals(entry.signature or "", item.s or "")
        lu.assertEquals(entry.summary or "", item.u or "")
        lu.assertEquals(entry.markdown or "", item.b or "")
        lu.assertEquals(entry.module or entry.parent or "", item.m or "")
        if entry.aliases and #entry.aliases > 0 then
            lu.assertEquals(entry.aliases, item.l)
        end
        lu.assertNotEquals("", item.sh)
    end
end

function Test_docs.Test_search_index_is_script_safe()
    local before = #docs.entries
    docs.entries[before + 1] = {
        name = "synthetic</script><!-- \"quote\" \\slash",
        anchor = "synthetic",
        signature = "</script>\"\\\1\226\128\169",
        summary = "<!-- & > \226\128\168",
        markdown = "line\n\1\226\128\168\226\128\169",
        module = "synthetic\2",
        aliases = { "alias</script>", "quote\"slash\\" },
    }
    local ok, json = pcall(docs.search_index_json)
    table.remove(docs.entries)

    lu.assertTrue(ok, json)
    assert_not_contains(json, "</script")
    assert_not_contains(json, "<!--")
    assert_not_contains(json, "\226\128\168")
    assert_not_contains(json, "\226\128\169")
    lu.assertNil(json:find("[<>&]"))

    local index = cjson.decode(json)
    local item = index_entry(index, "synthetic</script><!-- \"quote\" \\slash")
    lu.assertNotNil(item)
    assert_contains(item.n, "</script>")
    assert_contains(item.b, "line\n")
    lu.assertEquals("alias</script>", item.l[1])
    lu.assertEquals("quote\"slash\\", item.l[2])
end

function Test_docs.Test_manual_html_has_no_server_search_route()
    local html = docs.render_manual_html()
    assert_not_contains(html, 'action="/search"')
    assert_not_contains(html, 'href="/#')
    assert_contains(html, '<form id="zli-search-form"')
end

function Test_docs.Test_markdown_renderer()
    local html = markdown.to_html("- **`+`**: addition\n- plain")
    assert_contains(html, "<li><strong><code>+</code></strong>: addition</li>")
    assert_contains(html, "<li>plain</li>")

    html = markdown.to_html("```lua\nlocal x = 1 < 2\n```")
    assert_contains(html, "local x = 1 &lt; 2")

    -- Documentation signatures contain angle brackets that must stay text.
    html = markdown.to_html("zli @compile <config>")
    assert_contains(html, "&lt;config&gt;")
    assert_not_contains(html, "<config>")

    local text = markdown.to_text("# Title\n\nSome `code` here.")
    assert_contains(text, "Title")
    assert_contains(text, "Some code here.")

    text = markdown.to_text("| `Name` | `Value` |\n| --- | --- |\n| `a` | `longer` |")
    assert_contains(text, "| Name | Value  |")
    assert_contains(text, "| a    | longer |")
    assert_not_contains(text, "`")

    text = markdown.to_text("| A | B |\n| --- | --- |\n| | x |")
    assert_contains(text, "| A | B |")
    assert_contains(text, "|   | x |")
end

function Test_docs.Test_markdown_text_handles_list_continuations_and_wide_tables()
    -- Continuation lines belong to the list item, not a separate paragraph.
    local text = markdown.to_text("- first\n  continued\n- second", 80)
    assert_contains(text, "- first continued")
    assert_not_contains(text, "\n\ncontinued")

    -- Cell widths above Lua's string.format limit used to raise an error.
    local long = string.rep("long description ", 20)
    text = markdown.to_text("| Name | Description |\n| --- | --- |\n| x | " .. long .. " |", 80)
    assert_contains(text, "long description")
end

function Test_docs.Test_help_renders_wide_dialect_table()
    local output, status = run({ "@help", "markdown.dialects" })
    lu.assertEquals(0, status, output)
    assert_contains(output, "commonmark")
    assert_contains(output, "GitHub-style dialect")
end

function Test_docs.Test_markdown_renders_nested_emphasis()
    local html = markdown.to_html("***x***")
    assert_contains(html, "<strong>x</strong>")
    assert_contains(html, "<em>")

    lu.assertEquals("x", markdown.render_inline_text("***x***"))
    lu.assertEquals("x", markdown.render_inline_text("**x**"))
    lu.assertEquals("x", markdown.render_inline_text("*x*"))

    -- The generated manual used to contain nested <em> and <b><em> markup.
    local entry = docs.find("the-numerical-for-loop")
    lu.assertNotNil(entry)
    lu.assertEquals("section", entry.kind)
    assert_contains(entry.signature, "**for**")

    local text = docs.render_entry(entry, "text", 80)
    assert_contains(text, "The numerical for loop")
    assert_not_contains(text, "**")

    html = docs.render_entry(entry, "html")
    assert_contains(html, "<strong>for</strong>")
    assert_not_contains(html, "**")
end

function Test_docs.Test_help_output_has_no_markdown_markers()
    local output, status = run({ "@help", "filesystem.walk" })
    lu.assertEquals(0, status, output)
    assert_contains(output, "Walk a directory tree, calling func(path) for each entry.")
    assert_not_contains(output, "`")

    output, status = run({ "@help", "--search", "call func" })
    lu.assertEquals(0, status, output)
    assert_not_contains(output, "`")

    output, status = run({ "@help", "--search", "numerical for loop" })
    lu.assertEquals(0, status, output)
    assert_contains(output, "The numerical for loop")
    assert_not_contains(output, "**")
end

function Test_docs.Test_manual_html_contains_language_and_libraries()
    local html = docs.render_manual_html()
    assert_contains(html, "ZLI Reference Manual")
    assert_contains(html, "The Language")
    assert_contains(html, "The Standard Libraries")
    assert_not_contains(html, "The Complete Syntax of Lua")
    assert_not_contains(html, "id=\"9\"")
    assert_contains(html, "id=\"pdf-string.byte\"")
    assert_contains(html, "filesystem")
    assert_contains(html, "Third-party libraries")

    assert_not_contains(html, "The Application Program Interface")
    assert_not_contains(html, "The Auxiliary Library")
    assert_not_contains(html, "Loading the Libraries in C code")
    assert_not_contains(html, "lua_absindex")
    assert_not_contains(html, "luaL_openlibs")
end

function Test_docs.Test_manual_html_has_overview_after_header()
    local html = docs.render_manual_html()
    assert_contains(html, "portable Lua 5.5 interpreter")

    local header = html:find("<h1>ZLI Reference Manual</h1>", 1, true)
    local overview = html:find("portable Lua 5.5 interpreter", 1, true)
    local lua_chapter = html:find("id=\"lua-manual\"", 1, true)
    lu.assertNotNil(header)
    lu.assertNotNil(overview)
    lu.assertNotNil(lua_chapter)
    lu.assertTrue(header < overview)
    lu.assertTrue(overview < lua_chapter)
end

function Test_docs.Test_authored_chapters_are_numbered()
    local html = docs.render_manual_html()

    assert_contains(html, "5 – ZLI libraries")
    assert_contains(html, "5.1 – auxiliary")
    assert_contains(html, "5.2 – benchmark")
    assert_contains(html, "6 – Third-party libraries")
    assert_contains(html, "6.1 – argparse")
    assert_contains(html, "7 – Command line tools")
    assert_contains(html, "8 – ZLI")

    assert_contains(html, "<h1 id=\"group-command-line-tools\">7 – Command line tools</h1>")
    assert_contains(html, "<h1 id=\"group-zli\">8 – ZLI</h1>")

    -- Tools and the ZLI runtime are flattened into their chapters.
    assert_not_contains(html, "7.1 –")
    assert_not_contains(html, "8.1 –")
    assert_not_contains(html, "<h2 id=\"module-tools\"")
    assert_not_contains(html, "<h2 id=\"module-zli\"")

    -- Their module anchors still work for search results and deep links.
    assert_contains(html, "<span id=\"module-tools\"></span>")
    assert_contains(html, "<span id=\"module-zli\"></span>")

    -- The left TOC uses the same level1/level2 list as the Lua chapters.
    assert_contains(html, "<a href=\"#group-zli-libraries\">5 – ZLI libraries</a>")
    assert_contains(html, "<a href=\"#module-auxiliary\">5.1 – auxiliary</a>")
    assert_not_contains(html, "<h3><a href=\"#group-")
end

function Test_docs.Test_manual_html_has_upstream_license_and_attribution()
    local html = docs.render_manual_html()

    local expected = {
        { "argparse",  "https://github.com/luarocks/argparse" },
        { "lpeg",      "https://www.inf.puc-rio.br/~roberto/lpeg/" },
        { "sqlite3",   "http://lua.sqlite.org/" },
        { "crossline", "https://github.com/jcwangxp/Crossline" },
    }
    for _, item in ipairs(expected) do
        local entry = docs.find(item[1])
        lu.assertNotNil(entry, "missing module documentation: " .. item[1])
        lu.assertEquals(item[2], entry.upstream, "wrong upstream for " .. item[1])
        lu.assertEquals("MIT", entry.license, "wrong license for " .. item[1])
        assert_contains(html, item[2], false, "missing upstream URL for " .. item[1])
    end

    assert_contains(html, "license: MIT")
    assert_contains(html, "source: third_party")
    assert_contains(html, "id=\"licenses\"")
    assert_contains(html, "Licenses and attribution")
    assert_contains(html, "href=\"#licenses\"")
    assert_contains(html, "Lua license")
end

function Test_docs.Test_libraries_markdown_does_not_repeat_upstream()
    local text = docs.render_libraries_markdown()
    local count = 0
    for line in text:gmatch("[^\n]+") do
        if line:match("^Upstream:") then count = count + 1 end
    end

    local expected = 0
    for _, group in ipairs(docs.groups) do
        for _, module in ipairs(group.modules or {}) do
            if module.upstream then expected = expected + 1 end
        end
    end
    lu.assertEquals(expected, count)

    -- Inherited metadata stays available for lookup and text rendering.
    local module = docs.find("argparse")
    local entry = docs.find("argparse:parse")
    lu.assertEquals(module.upstream, entry.upstream)
    assert_contains(text, "### argparse")
    assert_not_contains(text,
        "#### `parser:parse([args])`\n\nParse command-line arguments.\n\nUpstream:")
end

function Test_docs.Test_entry_fields_and_coverage()
    local expected_modules = parse_readme_modules("README.md")
    lu.assertNotEquals(0, #expected_modules, "could not parse library tables from README.md")

    -- Modules documented in doc/libraries.lua that README.md does not list as
    -- a table row (collection submodules, the LPeg regex wrapper and the
    -- command line tools/ZLI topics).
    for _, name in ipairs({
        "collection.list", "collection.map", "collection.set",
        "re", "tools", "ZLI",
    }) do
        expected_modules[#expected_modules + 1] = name
    end

    for _, name in ipairs(expected_modules) do
        lu.assertNotNil(docs.find(name), "missing module documentation: " .. name)
    end

    for _, entry in ipairs(docs.entries) do
        lu.assertNotNil(entry.name, "entry without name")
        lu.assertNotNil(entry.kind, "entry without kind: " .. tostring(entry.name))
        lu.assertNotNil(entry.signature, "entry without signature: " .. tostring(entry.name))
    end
end

function Test_docs.Test_help_markdown_matches_committed_mirror()
    local output, status = run({ "@help", "--markdown" })
    lu.assertEquals(0, status, excerpt(output, 4000))
    assert_same_document(fs.read_all("doc/libraries.md"), output, "doc/libraries.md")
end

function Test_docs.Test_markdown_mirror_survives_hostile_init()
    local home = support.temp_dir("docs_hostile_home")
    local config = home .. "/.config/zli"
    fs.create_tree(config)
    io.write_file(config .. "/init.lua", 'print("INIT NOISE")\n')

    local output_file = support.temp_path("docs_hostile_markdown")
    local stdout, status = run(
        { "@help", "--markdown", "--output", output_file }, { home = home })
    lu.assertEquals(0, status, excerpt(stdout, 4000))

    -- The init script really runs (and prints), but it cannot corrupt the
    -- file mirror because @help renders into a buffer before writing.
    assert_contains(stdout, "INIT NOISE")
    assert_same_document(fs.read_all("doc/libraries.md"), fs.read_all(output_file), "doc/libraries.md")
end

function Test_docs.Test_require_docs_from_script_run_by_binary()
    local script = support.temp_file("docs_require_script", [[
local docs = require "docs"
local entry = docs.find("string.byte")
assert(entry, "string.byte is missing")
print("entry=" .. entry.name)
print("nodes=" .. tostring(#docs.nodes > 0))
print("toc=" .. tostring(#docs.toc > 0))
]])

    local output, status = run({ script })
    lu.assertEquals(0, status, output)
    assert_contains(output, "entry=string.byte")
    assert_contains(output, "nodes=true")
    assert_contains(output, "toc=true")
end

function Test_docs.Test_help_cli_lookup_and_errors()
    local output, status = run({ "@help", "string.byte" })
    lu.assertEquals(0, status, output)
    assert_contains(output, "string.byte")
    local version = docs.meta.version or ""
    local major_minor = version:match("^(%d+%.%d+)") or version
    assert_contains(output, "Lua " .. major_minor .. " manual")

    output, status = run({ "@help", "does-not-exist-anywhere" })
    lu.assertNotEquals(0, status, output)
    assert_contains(output, "no documentation found")

    output, status = run({ "@help", "--search", "trim" })
    lu.assertEquals(0, status, output)
    assert_contains(output, "string.trim")
end

function Test_docs.Test_help_list_output_and_search_errors()
    local list_output, status = run({ "@help", "--list" })
    lu.assertEquals(0, status, list_output)
    assert_contains(list_output, "Lua standard library")
    assert_contains(list_output, "\n  tools\n")

    local list_file = support.temp_path("help_list_output")
    local stdout, list_status = run({ "@help", "--list", "--output", list_file })
    lu.assertEquals(0, list_status, stdout)
    lu.assertEquals("", stdout)
    lu.assertEquals(normalized(list_output), normalized(fs.read_all(list_file)))

    local lookup_file = support.temp_path("help_lookup_output")
    stdout, status = run({ "@help", "--output", lookup_file, "string.byte" })
    lu.assertEquals(0, status, stdout)
    lu.assertEquals("", stdout)
    assert_contains(fs.read_all(lookup_file), "string.byte")

    local search_file = support.temp_path("help_search_output")
    stdout, status = run({ "@help", "--output", search_file, "--search", "trim" })
    lu.assertEquals(0, status, stdout)
    lu.assertEquals("", stdout)
    assert_contains(fs.read_all(search_file), "string.trim")

    local index_file = support.temp_path("help_index_output")
    stdout, status = run({ "@help", "--output", index_file })
    lu.assertEquals(0, status, stdout)
    lu.assertEquals("", stdout)
    assert_contains(fs.read_all(index_file), "ZLI reference manual")

    local markdown_output, markdown_status = run({ "@help", "--markdown" })
    lu.assertEquals(0, markdown_status, markdown_output)
    local markdown_file = support.temp_path("help_markdown_output")
    stdout, status = run({ "@help", "--markdown", "--output", markdown_file })
    lu.assertEquals(0, status, stdout)
    lu.assertEquals("", stdout)
    lu.assertEquals(normalized(markdown_output), normalized(fs.read_all(markdown_file)))

    local output
    output, status = run({ "@help", "--search" })
    lu.assertEquals(2, status, output)
    assert_contains(output, "--search requires a query")
end

function Test_docs.Test_manual_heading_titles_are_unique()
    local seen = {}
    for _, item in ipairs(docs.toc) do
        local title = markdown.render_inline_text(item.title)
        lu.assertNil(seen[title], "duplicate manual heading title: " .. title)
        seen[title] = true
    end
end

function Test_docs.Test_manual_entry_and_toc_anchors_resolve()
    lu.assertNotNil(docs.nodes)
    lu.assertEquals(#docs.manual_nodes, #docs.nodes)
    lu.assertNotNil(docs.toc)
    lu.assertNotEquals(0, #docs.toc)

    local html = docs.render_manual_html()
    for _, entry in ipairs(docs.entries) do
        assert_contains(html, 'id="' .. entry.anchor .. '"', false,
            "missing entry anchor " .. tostring(entry.anchor) .. " for " .. tostring(entry.name))
    end
    for _, item in ipairs(docs.toc) do
        assert_contains(html, 'id="' .. item.anchor .. '"', false,
            "missing TOC anchor " .. tostring(item.anchor) .. " for " .. tostring(item.title))
    end
end

function Test_docs.Test_toc_has_collapsible_module_entries()
    local html = docs.render_manual_html()
    assert_contains(html, 'class="level2 toc-module"')
    assert_contains(html, 'class="toc-toggle"')
    assert_contains(html, 'aria-expanded="false"')
    assert_contains(html, '<ul class="toc-entries" hidden>')
    assert_contains(html, 'href="#module-luaunit"')

    local luaunit = docs.find("luaunit.assertEquals")
    lu.assertNotNil(luaunit)
    assert_contains(html, 'href="#' .. luaunit.anchor .. '"')
    assert_contains(html, ">luaunit.assertEquals</a>")

    local byte = docs.find("string.byte")
    lu.assertNotNil(byte)
    assert_contains(html, 'href="#' .. byte.anchor .. '"')

    -- Modules without own entries stay links without an expand control.
    assert_contains(html, '<span class="toc-spacer" aria-hidden="true"></span>')
    assert_not_contains(html, "Toggle entries for memoize")
end

function Test_docs.Test_synthesized_heading_anchors_are_emitted()
    local html = docs.render_manual_html()
    local expected = {
        "captures",
        "character-class",
        "multiple-matches",
        "parameters",
        "pattern",
        "pattern-item",
        "the-generic-for-loop",
        "the-numerical-for-loop",
    }
    for _, anchor in ipairs(expected) do
        assert_contains(html, 'id="' .. anchor .. '"', false,
            "missing synthesized heading anchor " .. anchor)
    end
end

function Test_docs.Test_entry_names_and_anchors_are_unique()
    local names, anchors = {}, {}
    for _, entry in ipairs(docs.entries) do
        lu.assertNil(names[entry.name], "duplicate entry name: " .. tostring(entry.name))
        names[entry.name] = true
        lu.assertNil(anchors[entry.anchor], "duplicate entry anchor: " .. tostring(entry.anchor))
        anchors[entry.anchor] = true
    end
end

function Test_docs.Test_section_and_module_aliases_resolve()
    local entry = docs.find("4.2")
    lu.assertNotNil(entry)
    lu.assertEquals("basic", entry.name)
    lu.assertEquals("4.2", entry.anchor)

    entry = docs.find("basic")
    lu.assertNotNil(entry)
    lu.assertEquals("module", entry.kind)

    entry = docs.find("argparse.new")
    lu.assertNotNil(entry)
    lu.assertEquals("argparse", entry.name)
end

function Test_docs.Test_search_does_not_duplicate_argparse()
    local output, status = run({ "@help", "--search", "argparse" })
    lu.assertEquals(0, status, output)
    local count = 0
    for line in output:gmatch("[^\n]+") do
        if line:match("^argparse%s") then
            count = count + 1
        end
    end
    lu.assertEquals(1, count, output)
end

function Test_docs.Test_summary_only_entry_has_single_blank_line()
    local entry = docs.find("collection.list:for_each")
    lu.assertNotNil(entry)
    local text = docs.render_entry(entry, "text", 80)
    assert_contains(text, "Call func for every item.")
    assert_contains(text, "source: zli")
    assert_not_contains(text, "\n\n\n")
end

function Test_docs.Test_lua_source_label_uses_manual_version()
    local entry = docs.find("string.byte")
    lu.assertNotNil(entry)
    local text = docs.render_entry(entry, "text", 80)
    local version = docs.meta.version or ""
    local major_minor = version:match("^(%d+%.%d+)") or version
    assert_contains(text, "source: Lua " .. major_minor .. " manual")
end

-- Modules whose authored entries have completed the documentation depth pass.
-- Keep this list in sync when a new authored module is added.
local completed_doc_modules = {
    auxiliary = true,
    collection = true,
    ["collection.list"] = true,
    ["collection.map"] = true,
    ["collection.set"] = true,
    filesystem = true,
    grid = true,
    stream = true,
    timer = true,
    webserver = true,
    webui = true,
    uuid = true,
    xlsxmlwriter = true,
    luaunit = true,
    serpent = true,
    markdown = true,
    xml2lua = true,
    XmlParser = true,
    ["xmlhandler.tree"] = true,
    ["xmlhandler.dom"] = true,
    ["xmlhandler.print"] = true,
    csv = true,
    luastrip = true,
    sqlite3 = true,
    argparse = true,
    lpeg = true,
    re = true,
    cjson = true,
    gzip = true,
    tar = true,
    log = true,
    crossline = true,
    zip = true,
    unzip = true,
    httpclient = true,
    httpserver = true,
    tools = true,
    ZLI = true,
}

function Test_docs.Test_authored_entries_have_full_descriptions()
    local problems = {}
    local function report(message)
        problems[#problems + 1] = message
    end

    for _, group in ipairs(docs.groups) do
        for _, module in ipairs(group.modules or {}) do
            if completed_doc_modules[module.name] then
                if (module.markdown or ""):match("^%s*$") then
                    report(module.name .. ": missing module description")
                end
                for _, entry in ipairs(module.entries or {}) do
                    local text = entry.markdown or ""
                    local body = text:match("^%s*(.-)%s*$") or ""
                    local thin = (entry.kind == "function" or entry.kind == "method")
                        and #body < 80

                    if body == ""
                        or body == (entry.summary or "")
                        or body:find("TODO", 1, true)
                        or body:find("TBD", 1, true)
                        or body:find("FIXME", 1, true)
                        or body:find("???", 1, true)
                        or thin
                    then
                        report(module.name .. ": " .. entry.name)
                    end
                end
            end
        end
    end

    lu.assertEquals(0, #problems, table.concat(problems, "\n"))
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
