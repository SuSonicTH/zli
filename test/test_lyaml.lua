local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local support = require "test/support"

local lyaml = require "lyaml"
local yaml = require "yaml"
local explicit = require "lyaml.explicit"
local functional = require "lyaml.functional"
local implicit = require "lyaml.implicit"

local function assert_same(actual, expected, message)
    lu.assertTrue(rawequal(actual, expected), message or "values are not identical")
end

Test_lyaml = {}

function Test_lyaml:Test_load_basic()
    local value = lyaml.load([[
name: demo
enabled: true
count: 42
ratio: 1.5
tags:
  - alpha
  - beta
nested:
  key: value
  list: [1, 2, 3]
]])

    lu.assertEquals("demo", value.name)
    lu.assertEquals(true, value.enabled)
    lu.assertEquals(42, value.count)
    lu.assertEquals(1.5, value.ratio)
    lu.assertEquals({ "alpha", "beta" }, value.tags)
    lu.assertEquals("value", value.nested.key)
    lu.assertEquals({ 1, 2, 3 }, value.nested.list)
end

function Test_lyaml:Test_load_yaml11_scalars()
    local value = lyaml.load([[
yes_value: yes
no_value: no
on_value: on
off_value: off
hex: 0x1f
binary: 0b1010
octal: 012
inf: .inf
ninf: -.inf
nan: .nan
date: 2024-01-02
]])

    lu.assertEquals(true, value.yes_value)
    lu.assertEquals(false, value.no_value)
    lu.assertEquals(true, value.on_value)
    lu.assertEquals(false, value.off_value)
    lu.assertEquals(31, value.hex)
    lu.assertEquals(10, value.binary)
    lu.assertEquals(10, value.octal)
    lu.assertEquals(math.huge, value.inf)
    lu.assertEquals(-math.huge, value.ninf)
    lu.assertTrue(value.nan ~= value.nan)
    lu.assertEquals("2024-01-02", value.date)
end

function Test_lyaml:Test_null_sentinel()
    local value = lyaml.load("a: ~\nb: null\nc:\n")
    lu.assertEquals(lyaml.null, value.a)
    lu.assertEquals(lyaml.null, value.b)
    lu.assertEquals(lyaml.null, value.c)
    lu.assertTrue(functional.isnull(value.a))
    lu.assertFalse(functional.isnull("~"))

    local text = lyaml.dump({ { a = lyaml.null } })
    local back = lyaml.load(text)
    lu.assertEquals(lyaml.null, back.a)
end

function Test_lyaml:Test_anchors_and_aliases()
    local value = lyaml.load([[
base: &base
  x: 1
  y: 2
other: *base
]])

    lu.assertEquals(1, value.base.x)
    assert_same(value.base, value.other)
end

function Test_lyaml:Test_merge_keys()
    local value = lyaml.load([[
base: &base
  x: 1
  y: 2
child:
  <<: *base
  y: 3
]])

    lu.assertEquals(1, value.child.x)
    lu.assertEquals(3, value.child.y)
end

function Test_lyaml:Test_multiple_documents()
    local stream = "--- one\n...\n--- two\n...\n"
    lu.assertEquals("one", lyaml.load(stream))

    local documents = lyaml.load(stream, { all = true })
    lu.assertEquals(2, #documents)
    lu.assertEquals("one", documents[1])
    lu.assertEquals("two", documents[2])
end

function Test_lyaml:Test_explicit_tags()
    local value = lyaml.load([[
a: !!str 123
b: !!int "42"
c: !!float "1.5"
d: !!bool "yes"
]])
    lu.assertEquals("123", value.a)
    lu.assertEquals(42, value.b)
    lu.assertEquals(1.5, value.c)
    lu.assertEquals(true, value.d)
end

function Test_lyaml:Test_custom_implicit_scalar()
    local strict = functional.anyof { implicit.null, implicit.decimal, functional.id }
    local value = lyaml.load("a: yes\nb: 10\n", { implicit_scalar = strict })
    lu.assertEquals("yes", value.a)
    lu.assertEquals(10, value.b)
end

function Test_lyaml:Test_invalid_yaml_raises()
    local ok, err = pcall(lyaml.load, "a: [")
    lu.assertFalse(ok)
    lu.assertNotNil(tostring(err):match("^2:1:"))

    ok, err = pcall(lyaml.load, "a: !!int nope")
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "int")
end

function Test_lyaml:Test_dump_and_round_trip()
    local value = {
        name = "demo",
        enabled = true,
        count = 42,
        ports = { 80, 443 },
        nested = { key = "value" },
        nothing = lyaml.null,
    }

    local text = lyaml.dump({ value })
    local loaded = lyaml.load(text)

    lu.assertEquals("demo", loaded.name)
    lu.assertEquals(true, loaded.enabled)
    lu.assertEquals(42, loaded.count)
    lu.assertEquals({ 80, 443 }, loaded.ports)
    lu.assertEquals("value", loaded.nested.key)
    lu.assertEquals(lyaml.null, loaded.nothing)
end

function Test_lyaml:Test_dump_quotes_scalar_lookalikes()
    local value = {
        number = "42",
        boolean = "yes",
        null = "~",
        word = "null",
        empty = "",
    }

    local text = lyaml.dump({ value })
    local loaded = lyaml.load(text)

    lu.assertEquals("42", loaded.number)
    lu.assertEquals("yes", loaded.boolean)
    lu.assertEquals("~", loaded.null)
    lu.assertEquals("null", loaded.word)
    lu.assertEquals("", loaded.empty)
end

function Test_lyaml:Test_dump_multiline_string()
    local text = lyaml.dump({ { note = "first line\nsecond line\n" } })
    lu.assertStrContains(text, "|")
    lu.assertEquals("first line\nsecond line\n", lyaml.load(text).note)
end

function Test_lyaml:Test_dump_anchors()
    local base = { x = 1 }
    local text = lyaml.dump({ { a = base, b = base } }, { anchors = { base = base } })
    lu.assertStrContains(text, "&base")
    lu.assertStrContains(text, "*base")

    local loaded = lyaml.load(text)
    assert_same(loaded.a, loaded.b)
end

function Test_lyaml:Test_dump_unsupported_type_raises()
    lu.assertError(function()
        lyaml.dump({ { f = function() end } })
    end)
end

function Test_lyaml:Test_low_level_parser()
    local types = {}
    for event in yaml.parser("a: [1, b]") do
        types[#types + 1] = event.type
    end

    lu.assertEquals({
        "STREAM_START",
        "DOCUMENT_START",
        "MAPPING_START",
        "SCALAR",
        "SEQUENCE_START",
        "SCALAR",
        "SCALAR",
        "SEQUENCE_END",
        "MAPPING_END",
        "DOCUMENT_END",
        "STREAM_END",
    }, types)
end

function Test_lyaml:Test_low_level_scanner()
    local first
    for token in yaml.scanner("a: 1") do
        first = token
        break
    end

    lu.assertNotNil(first)
    lu.assertEquals("STREAM_START", first.type)
    lu.assertNotNil(first.start_mark)
    lu.assertNotNil(first.end_mark)
end

function Test_lyaml:Test_low_level_emitter()
    local emitter = yaml.emitter()
    emitter.emit { type = "STREAM_START" }
    emitter.emit { type = "DOCUMENT_START" }
    emitter.emit { type = "SCALAR", value = "hi" }
    emitter.emit { type = "DOCUMENT_END" }
    local ok, stream = emitter.emit { type = "STREAM_END" }

    lu.assertTrue(ok)
    lu.assertEquals("--- hi\n...\n", stream)
end

function Test_lyaml:Test_explicit_scalar_option()
    local converters = {
        ["tag:yaml.org,2002:int"] = explicit.int,
        ["tag:yaml.org,2002:str"] = explicit.str,
    }
    local value = lyaml.load("a: !!int '42'\nb: !!str 7\n", {
        explicit_scalar = converters,
    })
    lu.assertEquals(42, value.a)
    lu.assertEquals("7", value.b)
end

function Test_lyaml:Test_sexagesimal_scalars()
    local value = lyaml.load("a: 1:20\nb: 1:20.5\nc: 190:20:30\n")
    lu.assertEquals(80, value.a)
    lu.assertEquals(80.5, value.b)
    lu.assertEquals(685230, value.c)
end

function Test_lyaml:Test_mapping_keys_are_converted()
    local value = lyaml.load("1: a\ntrue: b\n~: c\n")
    lu.assertEquals("a", value[1])
    lu.assertEquals("b", value[true])
    lu.assertEquals("c", value[lyaml.null])
end

function Test_lyaml:Test_merge_sequence()
    local value = lyaml.load([[
a: &a
  x: 1
b: &b
  x: 2
  y: 3
child:
  <<: [*a, *b]
]])
    lu.assertEquals(1, value.child.x)
    lu.assertEquals(3, value.child.y)
end

function Test_lyaml:Test_null_in_sequence()
    local value = lyaml.load("list: [~, 1, null]\n")
    lu.assertEquals(lyaml.null, value.list[1])
    lu.assertEquals(1, value.list[2])
    lu.assertEquals(lyaml.null, value.list[3])
end

function Test_lyaml:Test_quoted_keys()
    local value = lyaml.load([["a b": 1
'a: b': 2
]])
    lu.assertEquals(1, value["a b"])
    lu.assertEquals(2, value["a: b"])
end

function Test_lyaml:Test_nul_bytes_round_trip()
    local value = lyaml.load('a: "x\\0y"')
    lu.assertEquals(3, #value.a)
    lu.assertEquals("x\0y", value.a)

    local text = lyaml.dump({ { value = "x\0y" } })
    local back = lyaml.load(text)
    lu.assertEquals("x\0y", back.value)
end

function Test_lyaml:Test_dump_multiple_documents()
    local text = lyaml.dump({ { a = 1 }, { b = 2 } })
    local documents = lyaml.load(text, { all = true })
    lu.assertEquals(2, #documents)
    lu.assertEquals(1, documents[1].a)
    lu.assertEquals(2, documents[2].b)
end

function Test_lyaml:Test_dump_rejects_invalid_utf8()
    local ok, err = pcall(lyaml.dump, { { value = "\255" } })
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "UTF-8")
end

function Test_lyaml:Test_dump_rejects_invalid_anchor()
    local value = { a = 1 }
    local ok, err = pcall(lyaml.dump, { { x = value } }, {
        anchors = { ["bad anchor"] = value },
    })
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "anchor")
end

function Test_lyaml:Test_dump_rejects_userdata_and_threads()
    local ok, err = pcall(lyaml.dump, { { value = io.stdout } })
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "userdata")

    ok, err = pcall(lyaml.dump, { { value = coroutine.create(function() end) } })
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "thread")
end

function Test_lyaml:Test_scanner_token_fields()
    local tokens = {}
    for token in yaml.scanner("%YAML 1.1\n---\na: 1\n") do
        tokens[#tokens + 1] = token
    end

    local version
    local scalar
    for _, token in ipairs(tokens) do
        if token.type == "VERSION_DIRECTIVE" then
            version = token
        elseif token.type == "SCALAR" and token.value == "a" then
            scalar = token
        end
    end

    lu.assertNotNil(version)
    lu.assertEquals(1, version.major)
    lu.assertEquals(1, version.minor)
    lu.assertNotNil(scalar)
    lu.assertEquals(1, scalar.length)
    lu.assertEquals("PLAIN", scalar.style)
end

function Test_lyaml:Test_emitter_rejects_invalid_events()
    local emitter = yaml.emitter()
    lu.assertTrue(emitter.emit { type = "STREAM_START" })
    lu.assertTrue(emitter.emit { type = "DOCUMENT_START" })

    local ok, err = emitter.emit {
        type = "SCALAR",
        value = "x",
        style = string.rep("A", 100000),
    }
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "style")

    ok, err = emitter.emit { type = "SCALAR", value = "y" }
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "no longer usable")
end

function Test_lyaml:Test_emitter_rejects_invalid_utf8()
    local emitter = yaml.emitter()
    lu.assertTrue(emitter.emit { type = "STREAM_START" })
    lu.assertTrue(emitter.emit { type = "DOCUMENT_START" })

    local ok, err = emitter.emit { type = "SCALAR", value = "\255" }
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), "UTF-8")
end

function Test_lyaml:Test_document_start_directives()
    local emitter = yaml.emitter()
    lu.assertTrue(emitter.emit { type = "STREAM_START", encoding = "UTF8" })
    lu.assertTrue(emitter.emit {
        type = "DOCUMENT_START",
        version_directive = { major = 1, minor = 1 },
        tag_directives = {
            { handle = "!e!", prefix = "tag:example.com,2000:" },
        },
    })
    lu.assertTrue(emitter.emit { type = "SCALAR", value = "thing", tag = "!e!thing" })
    lu.assertTrue(emitter.emit { type = "DOCUMENT_END" })
    local ok, stream = emitter.emit { type = "STREAM_END" }
    lu.assertTrue(ok)
    lu.assertStrContains(stream, "%YAML 1.1")
    lu.assertStrContains(stream, "%TAG !e! tag:example.com,2000:")
end

function Test_lyaml:Test_document_start_rejects_bad_directives()
    local cases = {
        { type = "DOCUMENT_START", version_directive = { major = 1 } },
        { type = "DOCUMENT_START", version_directive = { major = "1", minor = 1 } },
        { type = "DOCUMENT_START", tag_directives = { false } },
        { type = "DOCUMENT_START", tag_directives = {
            [1] = { handle = "!a!", prefix = "tag:a:" },
            [3] = { handle = "!b!", prefix = "tag:b:" },
        } },
        { type = "DOCUMENT_START", tag_directives = {
            { handle = {}, prefix = "!" },
        } },
        { type = "DOCUMENT_START", tag_directives = {
            { handle = "bad", prefix = "tag:a:" },
        } },
    }

    for _, event in ipairs(cases) do
        local emitter = yaml.emitter()
        lu.assertTrue(emitter.emit { type = "STREAM_START" })
        local ok, err = emitter.emit(event)
        lu.assertFalse(ok)
        lu.assertNotNil(err)
    end
end

function Test_lyaml:Test_multi_document_anchors()
    local base = { x = 1 }
    local text = lyaml.dump({ { a = base }, { b = base } }, {
        anchors = { base = base },
    })
    local documents = lyaml.load(text, { all = true })
    lu.assertEquals(2, #documents)
    lu.assertEquals(1, documents[1].a.x)
    lu.assertEquals(1, documents[2].b.x)
end

function Test_lyaml:Test_literal_merge_key()
    local value = lyaml.load('"<<": literal')
    lu.assertEquals("literal", value["<<"])

    value = lyaml.load("!!str <<: literal")
    lu.assertEquals("literal", value["<<"])

    value = lyaml.load("child:\n  !foo <<: {y: 2}\n")
    lu.assertEquals(2, value.child["<<"].y)

    value = lyaml.load("child:\n  !<tag:yamlXorg,2002:merge> <<: 2\n")
    lu.assertEquals(2, value.child["<<"])

    local text = lyaml.dump({ { ["<<"] = { x = 1 }, y = 2 } })
    local back = lyaml.load(text)
    lu.assertEquals(1, back["<<"].x)
    lu.assertEquals(2, back.y)
end

function Test_lyaml:Test_iterators_in_coroutines()
    local iterator = yaml.parser("a: 1")
    local co = coroutine.create(function()
        for event in iterator do
            return event
        end
    end)
    local ok, event = coroutine.resume(co)
    lu.assertTrue(ok)
    lu.assertEquals("STREAM_START", event.type)

    local bad = yaml.parser("a: [")
    local bad_co = coroutine.create(function()
        for _ in bad do end
    end)
    ok, event = coroutine.resume(bad_co)
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(event), "did not find expected node content")

    local scanner = yaml.scanner("a: 1")
    local scan_co = coroutine.create(function()
        for token in scanner do
            return token
        end
    end)
    ok, event = coroutine.resume(scan_co)
    lu.assertTrue(ok)
    lu.assertEquals("STREAM_START", event.type)
end

function Test_lyaml:Test_core_module_is_hidden()
    local ok, err = pcall(require, "lyaml.core")
    lu.assertFalse(ok)
    lu.assertNotNil(err)
end

function Test_lyaml:Test_raw_core_rejects_non_string_fields()
    local script = [[
local core = require "lyaml.core"
local function attempt(event, setup)
    local emitter = core.emitter()
    if setup then setup(emitter) end
    local ok, err = emitter.emit(event)
    assert(ok == false)
    assert(type(err) == "string" and #err > 0)
end
attempt { type = false }
attempt { type = "STREAM_START", encoding = false }
attempt({ type = "SCALAR", value = "x", style = false }, function(emitter)
    assert(emitter.emit { type = "STREAM_START" })
    assert(emitter.emit { type = "DOCUMENT_START" })
end)
print("RAW_CORE_OK")
]]
    local output, status = support.run({ "-" }, { stdin = script })
    lu.assertEquals(0, status, output)
    lu.assertStrContains(output, "RAW_CORE_OK")
end

function Test_lyaml:Test_tag_directives_from_index()
    local meta = {
        __index = function(_, key)
            if key == "handle" then return "!e!" end
            if key == "prefix" then return "tag:example.com,2000:" end
        end,
    }
    local emitter = yaml.emitter()
    lu.assertTrue(emitter.emit { type = "STREAM_START" })
    lu.assertTrue(emitter.emit {
        type = "DOCUMENT_START",
        tag_directives = { setmetatable({}, meta) },
    })
    lu.assertTrue(emitter.emit { type = "SCALAR", value = "thing", tag = "!e!thing" })
    lu.assertTrue(emitter.emit { type = "DOCUMENT_END" })
    local ok, stream = emitter.emit { type = "STREAM_END" }
    lu.assertTrue(ok)
    lu.assertStrContains(stream, "%TAG !e! tag:example.com,2000:")
end

function Test_lyaml:Test_yaml_module_can_reload()
    package.loaded.yaml = nil
    local reloaded = require "yaml"
    package.loaded.yaml = yaml
    lu.assertNotNil(reloaded)
    lu.assertEquals(yaml.version, reloaded.version)
end

function Test_lyaml:Test_raw_core_emitter_survives_gc()
    local core = debug.getregistry()["zli.yaml.core"]
    lu.assertNotNil(core)

    local emit = core.emitter().emit
    collectgarbage("collect")
    collectgarbage("collect")

    lu.assertTrue(emit { type = "STREAM_START" })
    lu.assertTrue(emit { type = "DOCUMENT_START" })
    lu.assertTrue(emit { type = "SCALAR", value = string.rep("x", 20000) })
    lu.assertTrue(emit { type = "DOCUMENT_END" })
    local ok, stream = emit { type = "STREAM_END" }
    lu.assertTrue(ok)
    lu.assertTrue(#stream > 20000)
end

function Test_lyaml:Test_version()
    lu.assertStrContains(yaml.version, "6.2.10")
    lu.assertEquals(yaml.version, lyaml._VERSION)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
