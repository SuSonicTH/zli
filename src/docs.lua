-- Structured documentation API.
--
-- The Lua manual part is generated at build time (docs_manual.lua); the
-- bundled library part is authored in doc/libraries.lua and shipped as
-- docs_libraries.lua.  Both use GitHub-flavored Markdown rendered through the
-- bundled md4c binding by docs_markdown.lua.

-- Documentation is shipped as separate payload entries.  A custom or reduced
-- payload may omit one of them; report that as a documentation problem rather
-- than leaking a generic `module '...' not found` error.
local function require_documentation(name)
    local ok, value = pcall(require, name)
    if not ok then
        error("ZLI documentation is not available in this payload (missing " ..
            name .. ")", 0)
    end
    return value
end

local markdown = require_documentation("docs_markdown")
local manual = require_documentation("docs_manual")
local authored = require_documentation("docs_libraries")

local docs = {}

docs.meta = manual.meta or {}
docs.manual_nodes = manual.nodes or {}
-- Public alias for the parsed manual node list.
docs.nodes = docs.manual_nodes
docs.groups = authored.groups or {}
docs.entries = {}

-- The HTML manual numbers the authored chapters after the Lua manual (which
-- keeps chapters 1-4 once the C API chapters are omitted).  These numbers are
-- display-only: titles stay unnumbered for @help, search and the Markdown
-- mirror.
local authored_chapter_start = 5
for i, group in ipairs(docs.groups) do
    group.manual_number = authored_chapter_start + i - 1
    for j, module in ipairs(group.modules or {}) do
        module.manual_number = string.format("%d.%d", group.manual_number, j)
    end
end

local function group_heading(group)
    return tostring(group.manual_number) .. " – " .. group.title
end

local function module_heading(module)
    return tostring(module.manual_number) .. " – " .. (module.title or module.name)
end
docs.by_name = {}
docs.modules = {}

local function lower(value)
    return tostring(value or ""):lower()
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize_name(value)
    local name = trim(value)
    name = name:gsub("%s*%b()%s*$", "")
    return lower(name)
end

local function add_alias(entry, alias)
    if alias == nil or alias == "" then return end
    entry.aliases = entry.aliases or {}
    entry.aliases[#entry.aliases + 1] = alias
end

local function make_slug(text)
    local slug = lower(text)
    slug = slug:gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
    if slug == "" then slug = "section" end
    return slug
end

-- Every heading needs a stable anchor, even when the generated manual did not
-- carry an HTML name/id for it.  All renderers and the TOC use this helper so
-- synthesized anchors cannot drift from the emitted HTML id.
local function heading_anchor(node)
    return node.anchor or make_slug(node.title)
end

local function group_anchor(group)
    return "group-" .. make_slug(group.title)
end

local function module_anchor(module)
    return "module-" .. make_slug(module.name)
end

local function add_entry(entry, priority)
    entry.name = entry.name or entry.signature or "(anonymous)"
    entry.kind = entry.kind or "function"
    entry.anchor = entry.anchor or entry.name
    entry.anchor = tostring(entry.anchor):gsub("[^%w%._:@%-]", "-")
    entry.summary = entry.summary or ""
    entry.markdown = entry.markdown or ""
    docs.entries[#docs.entries + 1] = entry

    local key = normalize_name(entry.name)
    local existing = docs.by_name[key]
    if existing == nil or (priority or 0) > (existing._priority or 0) then
        docs.by_name[key] = entry
        entry._priority = priority or 0
    end
    for _, alias in ipairs(entry.aliases or {}) do
        local alias_key = normalize_name(alias)
        local old = docs.by_name[alias_key]
        if old == nil or (priority or 0) > (old._priority or 0) then
            docs.by_name[alias_key] = entry
            entry._priority = priority or 0
        end
    end
end

-- Lua standard library module names by manual section.
-- The standard-library chapter is generated as chapter 4 because the C API
-- chapters are omitted from the ZLI manual.
local section_modules = {
    ["4.2"] = "basic",
    ["4.3"] = "coroutine",
    ["4.4"] = "package",
    ["4.5"] = "string",
    ["4.6"] = "utf8",
    ["4.7"] = "table",
    ["4.8"] = "math",
    ["4.9"] = "io",
    ["4.10"] = "os",
    ["4.11"] = "debug",
}

-- Manual entries first.
for _, node in ipairs(docs.manual_nodes) do
    if node.type == "entry" then
        node.source = "lua"
        node.url = "#" .. node.anchor
        add_entry(node, 10)
    end
end

-- Manual headings become searchable sections and provide the standard
-- library module entries.  Headings covered by section_modules produce a
-- single module entry whose alias is the heading anchor, so there is no
-- duplicate section-topic entry with the same anchor.
for _, node in ipairs(docs.manual_nodes) do
    if node.type == "heading" then
        local anchor = heading_anchor(node)
        local module = node.level == 2 and section_modules[anchor] or nil
        if module then
            local module_entry = {
                name = module,
                aliases = { anchor },
                signature = module,
                kind = "module",
                summary = node.title:match("^[%d%.]+%s*[^%s]+%s*(.*)$") or node.title,
                markdown = "",
                anchor = anchor,
                source = "lua",
            }
            add_entry(module_entry, 20)
            docs.modules[module] = module_entry
        else
            local topic = {
                name = "lua:" .. anchor,
                aliases = { anchor },
                signature = node.title,
                kind = "section",
                summary = "",
                markdown = "",
                anchor = anchor,
                source = "lua",
                level = node.level,
            }
            add_entry(topic, 1)
        end
    end
end

-- Authored groups: ZLI libraries, third-party libraries, tools and ZLI topics.
for _, group in ipairs(docs.groups) do
    for _, module in ipairs(group.modules or {}) do
        module.source = module.source or group.source or "zli"
        module.group = group.title
        local module_entry = {
            name = module.name,
            aliases = module.aliases,
            signature = module.title or module.name,
            kind = "module",
            summary = module.summary or "",
            markdown = module.markdown or "",
            anchor = "module-" .. make_slug(module.name),
            source = module.source,
            upstream = module.upstream,
            license = module.license,
            group = group.title,
        }
        add_entry(module_entry, 20)
        docs.modules[module.name] = module_entry

        for _, entry in ipairs(module.entries or {}) do
            entry.module = entry.module or module.name
            entry.source = entry.source or module.source
            entry.group = group.title
            entry.upstream = entry.upstream or module.upstream
            entry.license = entry.license or module.license
            entry.parent = module.name
            if module.name == "filesystem" and entry.name:sub(1, 11) == "filesystem." then
                add_alias(entry, "fs." .. entry.name:sub(12))
            end
            add_entry(entry, 10)
        end
    end
end

table.sort(docs.entries, function(a, b)
    return lower(a.name) < lower(b.name)
end)

docs.by_module = {}
for _, entry in ipairs(docs.entries) do
    if entry.kind ~= "module" and entry.kind ~= "section" then
        local module = entry.module or entry.parent
        if module then
            docs.by_module[module] = docs.by_module[module] or {}
            local list = docs.by_module[module]
            list[#list + 1] = entry
        end
    end
end

-- Flat table of contents shared by the text and HTML renderers.  Anchors are
-- produced by the same helpers as the emitted headings, so they always match.
docs.toc = {}
local function toc_add(kind, level, title, anchor)
    docs.toc[#docs.toc + 1] = {
        type = kind,
        level = level,
        title = title,
        anchor = anchor,
    }
end

for _, node in ipairs(docs.manual_nodes) do
    if node.type == "heading" then
        toc_add("manual", node.level or 1, node.title, heading_anchor(node))
    end
end

for _, group in ipairs(docs.groups) do
    toc_add("group", 1, group_heading(group), group_anchor(group))
    if not group.flat then
        for _, module in ipairs(group.modules or {}) do
            toc_add("module", 2, module_heading(module), module_anchor(module))
        end
    end
end

toc_add("licenses", 1, "Licenses and attribution", "licenses")

function docs.find(name)
    if name == nil then return nil end
    return docs.by_name[normalize_name(name)]
end

local function tokenize(query)
    local tokens = {}
    for token in lower(query):gmatch("[^%s]+") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

local function contains(haystack, needle)
    if haystack == nil or haystack == "" or needle == "" then return false end
    return lower(haystack):find(needle, 1, true) ~= nil
end

local function score_token(entry, token)
    local name = lower(entry.name)
    local score = 0

    if name == token then
        score = 10000
    else
        for _, alias in ipairs(entry.aliases or {}) do
            if lower(alias) == token then
                score = 9500
                break
            end
        end
        if score == 0 and (name:sub(-(#token + 1)) == "." .. token or name:sub(-(#token + 1)) == ":" .. token) then
            score = 8000
        elseif score == 0 and name:sub(1, #token) == token then
            score = 7000
        elseif score == 0 and name:find(token, 1, true) then
            score = 6000
        end
    end

    if score == 0 and contains(entry.signature, token) then score = 4000 end
    if score == 0 and contains(entry.summary, token) then score = 3000 end
    if score == 0 and contains(entry.markdown, token) then score = 1000 end
    if score == 0 and contains(entry.module, token) then score = 2000 end
    return score
end

function docs.search(query, options)
    options = options or {}
    local query_text = trim(query)
    if query_text == "" then return {} end

    local tokens = tokenize(query_text)
    local results = {}
    for _, entry in ipairs(docs.entries) do
        local score = 0
        local matched = 0
        for _, token in ipairs(tokens) do
            local value = score_token(entry, token)
            if value > 0 then
                matched = matched + 1
                score = score + value
            end
        end
        if matched > 0 then
            -- Favour matches covering all query terms.
            score = score + (matched == #tokens and 5000 or 0)
            results[#results + 1] = { entry = entry, score = score }
        end
    end

    table.sort(results, function(a, b)
        if a.score == b.score then
            return lower(a.entry.name) < lower(b.entry.name)
        end
        return a.score > b.score
    end)

    local limit = options.limit or 50
    local values = {}
    for i = 1, math.min(limit, #results) do
        values[i] = results[i].entry
    end
    return values
end

function docs.render_markdown(text)
    return markdown.to_html(text)
end

function docs.render_text(text, width)
    return markdown.to_text(text, width)
end

function docs.render_inline(text)
    return markdown.render_inline_html(text)
end

function docs.render_inline_text(text)
    return markdown.render_inline_text(text or "")
end

local function major_minor(version)
    version = tostring(version or "")
    return version:match("^(%d+%.%d+)") or version
end

local function source_label(entry)
    if entry.source == "lua" then
        return "Lua " .. major_minor(docs.meta.version) .. " manual"
    elseif entry.upstream then
        return entry.source .. " — " .. entry.upstream
    end
    return entry.source or ""
end

function docs.render_entry(entry, format, width)
    if entry == nil then return "" end
    if format == "html" then
        local out = {
            '<h3 id="', entry.anchor or entry.name, '"><code>',
            markdown.render_inline_html(entry.signature or entry.name),
            "</code></h3>",
        }
        if entry.markdown ~= "" then
            out[#out + 1] = markdown.to_html(entry.markdown)
        end
        if entry.summary ~= "" and entry.markdown == "" then
            out[#out + 1] = "<p>" .. markdown.render_inline_html(entry.summary) .. "</p>"
        end
        return table.concat(out)
    end

    local blocks = {}
    local heading = markdown.render_inline_text(entry.signature or entry.name)
    blocks[#blocks + 1] = heading .. "\n" .. string.rep("-", math.min(#heading, width or 80))
    if entry.summary ~= "" then
        blocks[#blocks + 1] = markdown.render_inline_text(entry.summary)
    end
    if entry.markdown ~= "" then
        blocks[#blocks + 1] = markdown.to_text(entry.markdown, width)
    end
    if entry.kind == "module" then
        local children = docs.by_module[entry.name] or {}
        if #children > 0 then
            local names = {}
            for _, child in ipairs(children) do
                names[#names + 1] = child.name
            end
            table.sort(names)
            local lines = { "documented entries:" }
            for _, name in ipairs(names) do
                lines[#lines + 1] = "  " .. name
            end
            blocks[#blocks + 1] = table.concat(lines, "\n")
        end
    end
    local source = source_label(entry)
    if source ~= "" then
        blocks[#blocks + 1] = "source: " .. source
    end
    return table.concat(blocks, "\n\n")
end

local css = [==[
:root {
    --ink: #000000;
    --blue: #000080;
    --rule: #d8d8d8;
    --paper: #ffffff;
    --shade: #f8f8f8;
}
* { box-sizing: border-box; }
html { background: var(--shade); }
body {
    margin: 0;
    color: var(--ink);
    background: var(--paper);
    font-family: Helvetica, Arial, sans-serif;
    line-height: 1.35;
}
header {
    position: sticky;
    top: 0;
    z-index: 5;
    display: flex;
    gap: 1em;
    align-items: center;
    justify-content: space-between;
    padding: 0.7em 1.2em;
    background: #f2f2f2;
    border-bottom: 1px solid var(--rule);
}
header .brand { color: var(--blue); font-family: Verdana, Geneva, sans-serif; font-size: 1.05em; }
header .brand strong { font-weight: normal; }
header form { margin: 0; }
header input[type=search] {
    width: min(28em, 50vw);
    padding: 0.45em 0.8em;
    border: 1px solid #a0a0a0;
    border-radius: 2em;
    font: inherit;
}
.layout { display: grid; grid-template-columns: 20em minmax(0, 1fr); }
nav.toc {
    position: sticky;
    top: 3.2em;
    align-self: start;
    max-height: calc(100vh - 3.2em);
    overflow: auto;
    padding: 1em;
    border-right: 1px solid var(--rule);
    font-size: 0.9em;
}
nav.toc h2 { margin: 0 0 0.5em; font-size: 1em; }
nav.toc ul { list-style: none; margin: 0; padding: 0 0 0 0.7em; }
nav.toc li { margin: 0.18em 0; }
nav.toc li.level1 { padding-left: 0; font-weight: bold; margin-top: 0.45em; }
nav.toc li.level2 { padding-left: 1em; font-weight: normal; }
nav.toc a { color: var(--blue); text-decoration: none; }
nav.toc a:hover { text-decoration: underline; }
main {
    min-width: 0;
    max-width: 70em;
    padding: 2em 3em 5em;
}
h1, h2, h3, h4 {
    color: var(--blue);
    font-family: Verdana, Geneva, sans-serif;
    font-weight: normal;
    text-align: left;
}
h1 { font-size: 1.9em; margin: 2em 0 0.8em; }
h2 { font-size: 1.45em; margin: 1.8em 0 0.7em; }
h3 { font-size: 1.15em; margin: 1.6em 0 0.5em; }
h4 { font-size: 1em; margin: 1.3em 0 0.4em; }
h3 code { font-family: inherit; font-size: inherit; }
p { text-align: justify; margin: 0.7em 0; }
a { color: var(--blue); text-decoration: none; }
a:hover { background: #d0d0ff; border-radius: 4px; }
code, pre { font-family: "DejaVu Sans Mono", Consolas, monospace; font-size: 0.92em; }
code { background: var(--shade); padding: 0.08em 0.25em; border-radius: 3px; }
pre {
    background: var(--shade);
    padding: 0.9em 1em;
    border-radius: 8px;
    overflow: auto;
    line-height: 1.3;
}
pre code { background: none; padding: 0; }
ul, ol { margin: 0.6em 0 0.8em 1.4em; padding: 0; }
li { margin: 0.2em 0; text-align: justify; }
blockquote {
    margin: 1em 0;
    padding: 0.2em 1em;
    border-left: 4px solid var(--rule);
    color: #333;
}
hr { border: 0; border-top: 1px solid var(--rule); margin: 1.6em 0; }
table { border-collapse: collapse; margin: 1em 0; }
th, td { border: 1px solid var(--rule); padding: 0.35em 0.6em; text-align: left; vertical-align: top; }
th { background: var(--shade); }
.entry { margin-bottom: 0.4em; }
.overview { margin: 0.8em 0 1.6em; }
.source, .meta { color: #666; font-size: 0.85em; }
.meta a { color: #666; text-decoration: underline; }
.attribution { color: #666; font-size: 0.85em; border-top: 1px solid var(--rule); margin-top: 3em; padding-top: 1em; }
.search-results { list-style: none; padding: 0; }
.search-results li { margin: 0.8em 0; }
.search-results .name { font-family: "DejaVu Sans Mono", Consolas, monospace; }
.search-results .summary { color: #444; }
@media (max-width: 820px) {
    .layout { display: block; }
    nav.toc { position: static; max-height: none; border-right: 0; border-bottom: 1px solid var(--rule); }
    main { padding: 1.2em; }
    header input[type=search] { width: 45vw; }
}
]==]

local overview_lua_version = major_minor(docs.meta.version)
if overview_lua_version == "" then overview_lua_version = "5.5" end

local overview_markdown = string.format([==[
ZLI is a portable Lua %s interpreter distributed as a single statically
linked binary.  It bundles the Lua standard libraries together with a broad
selection of third-party libraries and ZLI's own filesystem, networking,
collection and tooling modules, so the same executable runs on a wide range
of systems without installed dependencies.

This manual documents the Lua language, the standard library, every bundled
library, and the command-line tools.  Use the search box above, or
`zli @help` / `:help` in the REPL, to look up an API.
]==], overview_lua_version)

local function page(title, body)
    return table.concat({
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\">",
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
        "<title>", markdown.escape_html(title), "</title>",
        "<style>", css, "</style></head><body>",
        "<header><div class=\"brand\"><strong>ZLI</strong> reference manual</div>",
        "<form action=\"/search\" method=\"get\"><input type=\"search\" name=\"q\" placeholder=\"search documentation\"></form></header>",
        body,
        "</body></html>",
    })
end

local function toc_html()
    local out = { "<nav class=\"toc\"><h2>Contents</h2><ul class=\"manual-toc\">" }
    out[#out + 1] = "<li class=\"level1\"><a href=\"#lua-manual\">Lua " ..
        markdown.escape_html(docs.meta.version or "5.5") .. " language and libraries</a></li>"
    for _, node in ipairs(docs.manual_nodes) do
        if node.type == "heading" and node.level <= 2 then
            local anchor = heading_anchor(node)
            local class = node.level == 1 and "level1" or "level2"
            out[#out + 1] = "<li class=\"" .. class .. "\"><a href=\"#" ..
                markdown.escape_html(anchor) .. "\">" ..
                markdown.render_inline_html(node.title) .. "</a></li>"
        end
    end
    for _, group in ipairs(docs.groups) do
        out[#out + 1] = "<li class=\"level1\"><a href=\"#" ..
            markdown.escape_html(group_anchor(group)) .. "\">" ..
            markdown.render_inline_html(group_heading(group)) .. "</a></li>"
        if not group.flat then
            for _, module in ipairs(group.modules or {}) do
                out[#out + 1] = "<li class=\"level2\"><a href=\"#" ..
                    markdown.escape_html(module_anchor(module)) .. "\">" ..
                    markdown.render_inline_html(module_heading(module)) .. "</a></li>"
            end
        end
    end
    out[#out + 1] = "<li class=\"level1\"><a href=\"#licenses\">Licenses and attribution</a></li>"
    out[#out + 1] = "</ul></nav>"
    return table.concat(out)
end

local function render_manual_nodes()
    local out = {}
    for _, node in ipairs(docs.manual_nodes) do
        if node.type == "heading" then
            local level = math.min(node.level or 1, 4)
            local anchor = heading_anchor(node)
            out[#out + 1] = "<h" .. level
            out[#out + 1] = " id=\"" .. markdown.escape_html(anchor) .. "\""
            out[#out + 1] = ">" .. markdown.render_inline_html(node.title) .. "</h" .. level .. ">"
        elseif node.type == "markdown" then
            out[#out + 1] = markdown.to_html(node.text)
        elseif node.type == "entry" then
            out[#out + 1] = docs.render_entry(node, "html")
        end
    end
    return table.concat(out)
end

local function module_meta_html(module)
    local parts = { "source: " .. markdown.escape_html(module.source or "zli") }
    if module.license and module.license ~= "" then
        parts[#parts + 1] = "license: " .. markdown.escape_html(module.license)
    end
    if module.upstream and module.upstream ~= "" then
        local url = markdown.escape_html(module.upstream)
        parts[#parts + 1] = "upstream: <a href=\"" .. url .. "\">" .. url .. "</a>"
    end
    return "<p class=\"meta\">" .. table.concat(parts, " &middot; ") .. "</p>"
end

local function render_module(group, module)
    local out = {}
    local anchor = module_anchor(module)
    if group.flat then
        -- Single-module chapters (Command line tools and ZLI) read as one
        -- chapter: no module subheading or source banner.  The anchor stays
        -- available for search results and deep links.
        out[#out + 1] = "<span id=\"" .. markdown.escape_html(anchor) .. "\"></span>"
    else
        out[#out + 1] = "<h2 id=\"" .. markdown.escape_html(anchor) .. "\">" ..
            markdown.render_inline_html(module_heading(module)) .. "</h2>"
        out[#out + 1] = module_meta_html(module)
    end
    if module.summary and module.summary ~= "" then
        out[#out + 1] = "<p class=\"source\">" .. markdown.render_inline_html(module.summary) .. "</p>"
    end
    if module.markdown and module.markdown ~= "" then
        out[#out + 1] = markdown.to_html(module.markdown)
    end
    for _, entry in ipairs(module.entries or {}) do
        out[#out + 1] = docs.render_entry(entry, "html")
    end
    return table.concat(out)
end

local function render_authored()
    local out = {}
    for _, group in ipairs(docs.groups) do
        out[#out + 1] = "<h1 id=\"" .. markdown.escape_html(group_anchor(group)) .. "\">" ..
            markdown.render_inline_html(group_heading(group)) .. "</h1>"
        if group.intro then
            out[#out + 1] = markdown.to_html(group.intro)
        end
        for _, module in ipairs(group.modules or {}) do
            out[#out + 1] = render_module(group, module)
        end
    end
    return table.concat(out)
end

local function render_licenses()
    local out = {
        "<div class=\"attribution\">",
        "<h2 id=\"licenses\">Licenses and attribution</h2>",
        "<p>Lua manual content is derived from the Lua ",
        markdown.escape_html(docs.meta.version or "5.5"),
        " Reference Manual, Copyright &copy; 1994&ndash;2026 Lua.org, PUC-Rio, ",
        "freely available under the <a href=\"https://www.lua.org/license.html\">Lua license</a>. ",
        "Bundled library documentation is part of ZLI and is distributed under the same license.</p>",
    }

    local modules = {}
    for _, group in ipairs(docs.groups) do
        for _, module in ipairs(group.modules or {}) do
            if module.upstream or module.license then
                modules[#modules + 1] = module
            end
        end
    end
    table.sort(modules, function(a, b)
        return lower(a.name) < lower(b.name)
    end)

    if #modules > 0 then
        out[#out + 1] = "<h3>Third-party components</h3><ul class=\"licenses\">"
        for _, module in ipairs(modules) do
            local parts = { "<strong>" .. markdown.escape_html(module.title or module.name) .. "</strong>" }
            if module.license and module.license ~= "" then
                parts[#parts + 1] = markdown.escape_html(module.license)
            end
            if module.upstream and module.upstream ~= "" then
                local url = markdown.escape_html(module.upstream)
                parts[#parts + 1] = "<a href=\"" .. url .. "\">" .. url .. "</a>"
            end
            out[#out + 1] = "<li>" .. table.concat(parts, " &mdash; ") .. "</li>"
        end
        out[#out + 1] = "</ul>"
    end

    out[#out + 1] = "</div>"
    return table.concat(out)
end

function docs.render_manual_html()
    local body = table.concat({
        "<div class=\"layout\">",
        toc_html(),
        "<main>",
        "<h1>ZLI Reference Manual</h1>",
        "<p class=\"source\">Lua ", markdown.escape_html(docs.meta.version or "5.5"),
        " &middot; ZLI ", markdown.escape_html((ZLI and ZLI.version) or ""), "</p>",
        "<div class=\"overview\">", markdown.to_html(overview_markdown), "</div>",
        "<h1 id=\"lua-manual\">Lua ", markdown.escape_html(docs.meta.version or "5.5"),
        " language and standard libraries</h1>",
        render_manual_nodes(),
        render_authored(),
        render_licenses(),
        "</main></div>",
    })
    return page("ZLI Reference Manual", body)
end

function docs.render_search_html(query, results)
    local out = {
        "<main style=\"max-width:70em;margin:0 auto;padding:2em 3em 5em\">",
        "<h1>Search</h1>",
    }
    if query == nil or trim(query) == "" then
        out[#out + 1] = "<p>Enter a name or search term in the box above.</p>"
    else
        out[#out + 1] = "<p>" .. tostring(#results) .. " result(s) for <code>" ..
            markdown.escape_html(query) .. "</code>.</p>"
        if #results == 0 then
            out[#out + 1] = "<p>No matching entries.</p>"
        else
            out[#out + 1] = "<ul class=\"search-results\">"
            for _, entry in ipairs(results) do
                out[#out + 1] = "<li><a class=\"name\" href=\"/#" ..
                    markdown.escape_html(entry.anchor or entry.name) .. "\">" ..
                    markdown.render_inline_html(entry.signature or entry.name) .. "</a>"
                if entry.summary and entry.summary ~= "" then
                    out[#out + 1] = "<div class=\"summary\">" .. markdown.render_inline_html(entry.summary) .. "</div>"
                end
                out[#out + 1] = "</li>"
            end
            out[#out + 1] = "</ul>"
        end
    end
    out[#out + 1] = "<p><a href=\"/\">back to the manual</a></p></main>"
    return page("Search - ZLI Reference Manual", table.concat(out))
end

local function parent_upstream(entry)
    local parent_name = entry.parent or entry.module
    local parent = parent_name and docs.modules[parent_name] or nil
    return parent and parent.upstream or nil
end

local function markdown_entry(entry, level)
    local out = {}
    out[#out + 1] = string.rep("#", level) .. " `" .. (entry.signature or entry.name) .. "`"
    out[#out + 1] = ""
    if entry.summary and entry.summary ~= "" then
        out[#out + 1] = entry.summary
        out[#out + 1] = ""
    end
    if entry.markdown and entry.markdown ~= "" then
        out[#out + 1] = entry.markdown
        out[#out + 1] = ""
    end
    -- Entries inherit their module's upstream metadata for lookup and search,
    -- but repeating it under every entry only adds noise to the mirror.
    if entry.upstream and entry.upstream ~= "" and entry.upstream ~= parent_upstream(entry) then
        out[#out + 1] = "Upstream: " .. entry.upstream
        out[#out + 1] = ""
    end
    return table.concat(out, "\n")
end

function docs.render_libraries_markdown()
    local out = {
        "# ZLI library reference",
        "",
        "<!-- Generated from doc/libraries.lua. Do not edit by hand. -->",
        "",
        "All modules are loaded with `require`.",
        "",
        "Libraries that support error handling return `nil, message` on failure by",
        "default. Set `ZLI.error_handling = \"raise\"` before `require` to raise",
        "instead. A loaded library can also be reconfigured in place:",
        "",
        "```lua",
        "local filesystem = require \"filesystem\"",
        "filesystem:config { error_handling = \"raise\" }",
        "```",
        "",
        "Argument/type errors always raise. `zip`/`unzip` use their own error",
        "returns and do not honor `ZLI.error_handling`.",
        "",
        "The Lua language and standard-library reference is generated from the",
        "Lua 5.5 manual and served by `zli @manual`; this file covers the bundled",
        "ZLI, third-party and tool documentation.",
        "",
    }

    for _, group in ipairs(docs.groups) do
        out[#out + 1] = "## " .. group.title
        out[#out + 1] = ""
        if group.intro then
            out[#out + 1] = group.intro
            out[#out + 1] = ""
        end
        for _, module in ipairs(group.modules or {}) do
            out[#out + 1] = "### " .. (module.title or module.name)
            out[#out + 1] = ""
            if module.summary and module.summary ~= "" then
                out[#out + 1] = module.summary
                out[#out + 1] = ""
            end
            if module.upstream then
                out[#out + 1] = "Upstream: " .. module.upstream
                out[#out + 1] = ""
            end
            if module.license then
                out[#out + 1] = "License: " .. module.license
                out[#out + 1] = ""
            end
            if module.markdown and module.markdown ~= "" then
                out[#out + 1] = module.markdown
                out[#out + 1] = ""
            end
            for _, entry in ipairs(module.entries or {}) do
                out[#out + 1] = markdown_entry(entry, 4)
            end
        end
    end

    local text = table.concat(out, "\n"):gsub("\n\n\n+", "\n\n")
    -- A multi-line final entry leaves a blank line behind.  Keep the mirror
    -- byte-for-byte stable with exactly one terminating newline.
    return (text:gsub("\n+$", "")) .. "\n"
end

return docs
