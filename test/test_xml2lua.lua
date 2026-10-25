local lu = require 'luaunit'
lu.ORDER_ACTUAL_EXPECTED = false

local support = require "test/support"
local xml2lua = require "xml2lua"

Test_xml2lua = {}

local people_xml = [==[<?xml version="1.0"?>
<people>
  <person type="natural">
    <name>Manoel</name>
    <city>Palmas-TO</city>
  </person>
  <person type="legal">
    <name>University of Brasília</name>
    <city>Brasília-DF</city>
  </person>
</people>]==]

function Test_xml2lua:Test_tree_handler_parses_elements_and_attributes()
    local handler = require("xmlhandler.tree"):new()
    local parser = xml2lua.parser(handler)
    parser:parse(people_xml)

    local people = handler.root.people
    lu.assertEquals("table", type(people.person))
    lu.assertEquals(2, #people.person)
    lu.assertEquals("Manoel", people.person[1].name)
    lu.assertEquals("Palmas-TO", people.person[1].city)
    lu.assertEquals("natural", people.person[1]._attr.type)
    lu.assertEquals("University of Brasília", people.person[2].name)
    lu.assertEquals("legal", people.person[2]._attr.type)
end

function Test_xml2lua:Test_tree_handler_handles_repeated_and_self_closing_tags()
    local handler = require("xmlhandler.tree"):new()
    local parser = xml2lua.parser(handler)
    parser:parse([[<root><item>A</item><item>B</item><empty like="yes"/></root>]])

    lu.assertEquals(2, #handler.root.root.item)
    lu.assertEquals("A", handler.root.root.item[1])
    lu.assertEquals("B", handler.root.root.item[2])
    lu.assertEquals("yes", handler.root.root.empty._attr.like)
end

function Test_xml2lua:Test_tree_handler_expands_entities_and_cdata()
    local handler = require("xmlhandler.tree"):new()
    local parser = xml2lua.parser(handler)
    parser:parse([==[<root><text>A &amp; B &lt; C</text><code><![CDATA[a < b & c]]></code></root>]==])

    lu.assertEquals("A & B < C", handler.root.root.text)
    lu.assertEquals("a < b & c", handler.root.root.code)
end

function Test_xml2lua:Test_tree_handler_can_skip_attributes()
    local handler = require("xmlhandler.tree"):new()
    local parser = xml2lua.parser(handler)
    parser:parse([[<root><item id="1"><a>A</a><b>B</b></item></root>]], false)

    lu.assertEquals("A", handler.root.root.item.a)
    lu.assertEquals("B", handler.root.root.item.b)
    lu.assertNil(handler.root.root.item._attr)
end

function Test_xml2lua:Test_toXml_serializes_table_as_xml()
    local xml = xml2lua.toXml({
        people = {
            person = {
                { name = "Manoel", city = "Palmas-TO", _attr = { type = "natural" } },
                { name = "Breno", city = "Palmas-TO", _attr = { type = "legal" } },
            },
        },
    })

    lu.assertStrContains(xml, '<person type="natural">')
    lu.assertStrContains(xml, "<name>Manoel</name>")
    lu.assertStrContains(xml, '<person type="legal">')
    lu.assertStrContains(xml, "<name>Breno</name>")
    lu.assertStrContains(xml, "\n  <person")
    lu.assertStrContains(xml, "\n    <name>")
end

function Test_xml2lua:Test_toXml_supports_compact_mode()
    local old = xml2lua.pretty
    xml2lua.pretty = false
    local ok, xml = pcall(xml2lua.toXml, { root = { first = "1", second = "2" } })
    xml2lua.pretty = old

    lu.assertTrue(ok, xml)
    lu.assertNil(xml:find("\n"))
    lu.assertStrContains(xml, "<root>")
    lu.assertStrContains(xml, "<first>1</first>")
    lu.assertStrContains(xml, "<second>2</second>")
    lu.assertStrContains(xml, "</root>")
end

function Test_xml2lua:Test_top_level_helpers()
    lu.assertEquals("{answer=42}", xml2lua.toString({ answer = 42 }))
    lu.assertEquals("    ", xml2lua.getSpaces(2))
    lu.assertTrue(xml2lua.isChildArray({ "a", "b" }))
    lu.assertFalse(xml2lua.isChildArray({ key = "value" }))
    lu.assertTrue(xml2lua.isTableEmpty({}))
    lu.assertTrue(xml2lua.isTableEmpty({ _attr = { id = "1" } }))
    lu.assertFalse(xml2lua.isTableEmpty({ value = "x" }))
end

function Test_xml2lua:Test_load_file_reads_xml_from_disk()
    local path = support.temp_file("xml2lua_input", "<root><value>42</value></root>")
    local handler = require("xmlhandler.tree"):new()
    local parser = xml2lua.parser(handler)
    parser:parse(xml2lua.loadFile(path))

    lu.assertEquals("42", handler.root.root.value)
end

function Test_xml2lua:Test_dom_handler_builds_a_node_tree()
    local xmlhandler = require "xmlhandler.dom"
    local handler = xmlhandler:new()
    local parser = xml2lua.parser(handler)
    parser:parse([==[<?xml version="1.0"?>
<!-- top -->
<root x="1"><a>hi &amp; bye</a><b/></root>]==])

    lu.assertEquals("ROOT", handler.root._type)
    lu.assertEquals(3, #handler.root._children)
    lu.assertEquals("DECL", handler.root._children[1]._type)
    lu.assertEquals("COMMENT", handler.root._children[2]._type)
    lu.assertEquals("top", handler.root._children[2]._text)

    local root = handler.root._children[3]
    lu.assertEquals("ELEMENT", root._type)
    lu.assertEquals("root", root._name)
    lu.assertEquals("1", root._attr.x)
    lu.assertEquals("ELEMENT", root._children[1]._type)
    lu.assertEquals("TEXT", root._children[1]._children[1]._type)
    lu.assertEquals("hi & bye", root._children[1]._children[1]._text)
    lu.assertEquals("ELEMENT", root._children[2]._type)
    lu.assertEquals("b", root._children[2]._name)

    local rendered = handler:toXml(handler.root)
    lu.assertStrContains(rendered, '<?xml version="1.0"?>')
    lu.assertStrContains(rendered, "<!--top-->")
    lu.assertStrContains(rendered, '<root x="1">')
    lu.assertStrContains(rendered, "hi &amp; bye")
    lu.assertStrContains(rendered, "<b/>")
end

function Test_xml2lua:Test_dom_handler_supports_processing_instructions_and_dtd()
    local handler = require("xmlhandler.dom"):new()
    local parser = xml2lua.parser(handler)
    parser:parse([==[<?xml version="1.0"?>
<?test value="1"?>
<!DOCTYPE root SYSTEM "root.dtd">
<root/>]==])

    local types = {}
    for _, node in ipairs(handler.root._children) do
        types[#types + 1] = node._type
    end
    lu.assertEquals({ "DECL", "PI", "DTD", "ELEMENT" }, types)
    lu.assertEquals("test", handler.root._children[2]._name)
    lu.assertEquals('root SYSTEM "root.dtd"', handler.root._children[3]._text)
end

function Test_xml2lua:Test_print_handler_exposes_event_callbacks()
    local handler = require "xmlhandler.print"
    for _, name in ipairs {
        "starttag", "endtag", "text", "cdata", "comment", "dtd", "pi", "decl",
    } do
        lu.assertEquals("function", type(handler[name]), name)
    end
end

function Test_xml2lua:Test_parser_reports_malformed_xml()
    local handler = require("xmlhandler.tree"):new()
    local parser = xml2lua.parser(handler)
    lu.assertErrorMsgContains("Unbalanced Tag", function()
        parser:parse("<root><item></root>")
    end)
end

if not RUN_ALL then
    os.exit(lu.LuaUnit.run('-v'))
end
