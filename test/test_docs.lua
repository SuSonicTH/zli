local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local fs = require "filesystem"
local support = require "test/support"
local docs = require "docs"
local markdown = require "docs_markdown"

Test_docs = {}

local function normalized(text)
    return (text:gsub("\r\n", "\n"))
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
    ["lua-zlib"] = { "zlib" },
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
    lu.assertStrContains(entry.signature, "string.byte")

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
                lu.assertNotStrContains(text, needle, "C API content in manual nodes")
            end
        end
    end

    local html = docs.render_manual_html()
    for _, needle in ipairs(forbidden) do
        lu.assertNotStrContains(html, needle)
    end
    lu.assertNotStrContains(html, "lua_absindex")
    lu.assertNotStrContains(html, "luaL_openlibs")
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

function Test_docs.Test_markdown_renderer()
    local html = markdown.to_html("- **`+`**: addition\n- plain")
    lu.assertStrContains(html, "<li><strong><code>+</code></strong>: addition</li>")
    lu.assertStrContains(html, "<li>plain</li>")

    html = markdown.to_html("```lua\nlocal x = 1 < 2\n```")
    lu.assertStrContains(html, "local x = 1 &lt; 2")

    local text = markdown.to_text("# Title\n\nSome `code` here.")
    lu.assertStrContains(text, "Title")
    lu.assertStrContains(text, "Some code here.")
end

function Test_docs.Test_markdown_renders_nested_emphasis()
    local html = markdown.to_html("***x***")
    lu.assertStrContains(html, "<strong><em>x</em></strong>")

    lu.assertEquals("x", markdown.render_inline_text("***x***"))
    lu.assertEquals("x", markdown.render_inline_text("**x**"))
    lu.assertEquals("x", markdown.render_inline_text("*x*"))

    -- The generated manual used to contain nested <em> and <b><em> markup.
    local entry = docs.find("the-numerical-for-loop")
    lu.assertNotNil(entry)
    lu.assertEquals("section", entry.kind)
    lu.assertStrContains(entry.signature, "**for**")

    local text = docs.render_entry(entry, "text", 80)
    lu.assertStrContains(text, "The numerical for loop")
    lu.assertNotStrContains(text, "**")

    html = docs.render_entry(entry, "html")
    lu.assertStrContains(html, "<strong>for</strong>")
    lu.assertNotStrContains(html, "**")

    html = docs.render_search_html("numerical for loop", docs.search("numerical for loop"))
    lu.assertNotStrContains(html, "**")
end

function Test_docs.Test_help_output_has_no_markdown_markers()
    local output, status = run({ "@help", "filesystem.walk" })
    lu.assertEquals(0, status, output)
    lu.assertStrContains(output, "Walk a directory tree, calling func(path) for each entry.")
    lu.assertNotStrContains(output, "`")

    output, status = run({ "@help", "--search", "call func" })
    lu.assertEquals(0, status, output)
    lu.assertNotStrContains(output, "`")

    output, status = run({ "@help", "--search", "numerical for loop" })
    lu.assertEquals(0, status, output)
    lu.assertStrContains(output, "The numerical for loop")
    lu.assertNotStrContains(output, "**")
end

function Test_docs.Test_manual_html_contains_language_and_libraries()
    local html = docs.render_manual_html()
    lu.assertStrContains(html, "ZLI Reference Manual")
    lu.assertStrContains(html, "The Language")
    lu.assertStrContains(html, "The Standard Libraries")
    lu.assertStrContains(html, "The Complete Syntax of Lua")
    lu.assertStrContains(html, "id=\"pdf-string.byte\"")
    lu.assertStrContains(html, "filesystem")
    lu.assertStrContains(html, "Third-party libraries")

    lu.assertNotStrContains(html, "The Application Program Interface")
    lu.assertNotStrContains(html, "The Auxiliary Library")
    lu.assertNotStrContains(html, "Loading the Libraries in C code")
    lu.assertNotStrContains(html, "lua_absindex")
    lu.assertNotStrContains(html, "luaL_openlibs")
end

function Test_docs.Test_manual_html_has_upstream_license_and_attribution()
    local html = docs.render_manual_html()

    local expected = {
        { "argparse", "https://github.com/luarocks/argparse" },
        { "lpeg", "https://www.inf.puc-rio.br/~roberto/lpeg/" },
        { "sqlite3", "http://lua.sqlite.org/" },
        { "crossline", "https://github.com/jcwangxp/Crossline" },
        { "zip", "https://zlib.net/" },
        { "unzip", "https://zlib.net/" },
    }
    for _, item in ipairs(expected) do
        local entry = docs.find(item[1])
        lu.assertNotNil(entry, "missing module documentation: " .. item[1])
        lu.assertEquals(item[2], entry.upstream, "wrong upstream for " .. item[1])
        lu.assertEquals("MIT", entry.license, "wrong license for " .. item[1])
        lu.assertStrContains(html, item[2], false, "missing upstream URL for " .. item[1])
    end

    lu.assertStrContains(html, "license: MIT")
    lu.assertStrContains(html, "source: third_party")
    lu.assertStrContains(html, "id=\"licenses\"")
    lu.assertStrContains(html, "Licenses and attribution")
    lu.assertStrContains(html, "href=\"#licenses\"")
    lu.assertStrContains(html, "Lua license")
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
    lu.assertStrContains(text, "### argparse")
    lu.assertNotStrContains(text,
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
    lu.assertEquals(0, status, output)
    local committed = fs.read_all("doc/libraries.md")
    lu.assertEquals(normalized(committed), normalized(output))
end

function Test_docs.Test_markdown_mirror_survives_hostile_init()
    local home = support.temp_dir("docs_hostile_home")
    local config = home .. "/.config/zli"
    fs.create_tree(config)
    io.write_file(config .. "/init.lua", 'print("INIT NOISE")\n')

    local output_file = support.temp_path("docs_hostile_markdown")
    local stdout, status = run(
        { "@help", "--markdown", "--output", output_file }, { home = home })
    lu.assertEquals(0, status, stdout)

    -- The init script really runs (and prints), but it cannot corrupt the
    -- file mirror because @help renders into a buffer before writing.
    lu.assertStrContains(stdout, "INIT NOISE")
    local committed = fs.read_all("doc/libraries.md")
    lu.assertEquals(normalized(committed), normalized(fs.read_all(output_file)))
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
    lu.assertStrContains(output, "entry=string.byte")
    lu.assertStrContains(output, "nodes=true")
    lu.assertStrContains(output, "toc=true")
end

function Test_docs.Test_help_cli_lookup_and_errors()
    local output, status = run({ "@help", "string.byte" })
    lu.assertEquals(0, status, output)
    lu.assertStrContains(output, "string.byte")
    local version = docs.meta.version or ""
    local major_minor = version:match("^(%d+%.%d+)") or version
    lu.assertStrContains(output, "Lua " .. major_minor .. " manual")

    output, status = run({ "@help", "does-not-exist-anywhere" })
    lu.assertNotEquals(0, status, output)
    lu.assertStrContains(output, "no documentation found")

    output, status = run({ "@help", "--search", "trim" })
    lu.assertEquals(0, status, output)
    lu.assertStrContains(output, "string.trim")
end

function Test_docs.Test_help_list_output_and_search_errors()
    local list_output, status = run({ "@help", "--list" })
    lu.assertEquals(0, status, list_output)
    lu.assertStrContains(list_output, "Lua standard library")
    lu.assertStrContains(list_output, "\n  tools\n")

    local list_file = support.temp_path("help_list_output")
    local stdout, list_status = run({ "@help", "--list", "--output", list_file })
    lu.assertEquals(0, list_status, stdout)
    lu.assertEquals("", stdout)
    lu.assertEquals(normalized(list_output), normalized(fs.read_all(list_file)))

    local lookup_file = support.temp_path("help_lookup_output")
    stdout, status = run({ "@help", "--output", lookup_file, "string.byte" })
    lu.assertEquals(0, status, stdout)
    lu.assertEquals("", stdout)
    lu.assertStrContains(fs.read_all(lookup_file), "string.byte")

    local search_file = support.temp_path("help_search_output")
    stdout, status = run({ "@help", "--output", search_file, "--search", "trim" })
    lu.assertEquals(0, status, stdout)
    lu.assertEquals("", stdout)
    lu.assertStrContains(fs.read_all(search_file), "string.trim")

    local index_file = support.temp_path("help_index_output")
    stdout, status = run({ "@help", "--output", index_file })
    lu.assertEquals(0, status, stdout)
    lu.assertEquals("", stdout)
    lu.assertStrContains(fs.read_all(index_file), "ZLI reference manual")

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
    lu.assertStrContains(output, "--search requires a query")
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
        lu.assertStrContains(html, 'id="' .. entry.anchor .. '"', false,
            "missing entry anchor " .. tostring(entry.anchor) .. " for " .. tostring(entry.name))
    end
    for _, item in ipairs(docs.toc) do
        lu.assertStrContains(html, 'id="' .. item.anchor .. '"', false,
            "missing TOC anchor " .. tostring(item.anchor) .. " for " .. tostring(item.title))
    end
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
        lu.assertStrContains(html, 'id="' .. anchor .. '"', false,
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
    local entry = docs.find("6.2")
    lu.assertNotNil(entry)
    lu.assertEquals("basic", entry.name)
    lu.assertEquals("6.2", entry.anchor)

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
    lu.assertStrContains(text, "Call func for every item.")
    lu.assertStrContains(text, "source: zli")
    lu.assertNotStrContains(text, "\n\n\n")
end

function Test_docs.Test_lua_source_label_uses_manual_version()
    local entry = docs.find("string.byte")
    lu.assertNotNil(entry)
    local text = docs.render_entry(entry, "text", 80)
    local version = docs.meta.version or ""
    local major_minor = version:match("^(%d+%.%d+)") or version
    lu.assertStrContains(text, "source: Lua " .. major_minor .. " manual")
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
    uuid = true,
    xlsxmlwriter = true,
    luaunit = true,
    serpent = true,
    csv = true,
    luastrip = true,
    sqlite3 = true,
    argparse = true,
    lpeg = true,
    re = true,
    cjson = true,
    zlib = true,
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
