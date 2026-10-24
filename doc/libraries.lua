-- Structured documentation for the libraries, tools and ZLI-specific topics
-- bundled with ZLI.
--
-- This file is the source of truth for doc/libraries.md and for the library
-- part of the @manual page.  It is also loaded by `require "docs"`, which
-- powers `zli @help` and the REPL's `:help` command.
--
-- Entries use a small Markdown dialect (see src/docs_markdown.lua).  The Lua
-- standard library documentation is generated from the Lua 5.5 manual at
-- build time and lives in docs_manual.lua.

local function entry(name, signature, kind, summary, doc, aliases)
    return {
        name = name,
        signature = signature,
        kind = kind,
        summary = summary,
        markdown = doc,
        aliases = aliases,
    }
end

local function module(name, title, summary, doc, entries, options)
    options = options or {}
    return {
        name = name,
        title = title,
        summary = summary,
        markdown = doc,
        entries = entries,
        upstream = options.upstream,
        license = options.license,
        aliases = options.aliases,
    }
end

return {
    schema = 1,
    groups = {
        {
            id = "zli",
            title = "ZLI libraries",
            source = "zli",
            modules = {
                module("auxiliary", "auxiliary", "Extra string, table, file and OS helpers.", [==[
The `auxiliary` module is loaded automatically.  It extends the standard
`string`, `table`, `io`, `os` and `math` tables and adds a few global helpers.
]==], {
                    entry("arg_error", "arg_error(func, narg, message [, level])", "function",
                        "Raise a Lua argument error.",
                        "Raises `message` as a bad-argument error for argument `narg` of `func`.  `level` is passed to `error`."),
                    entry("arg_check", "arg_check(func, narg, test, message)", "function",
                        "Raise an argument error when `test` is false.",
                        "Convenience wrapper around `arg_error`.  `func` and `narg` identify the offending argument."),
                    entry("arg_check_type", "arg_check_type(func, narg, value, level, ...)", "function",
                        "Validate the type of an argument.",
                        "Accepts the value when its type is one of the types passed in `...`; otherwise raises an argument error."),
                    entry("sorted_pairs", "sorted_pairs(tbl [, comparator])", "function",
                        "Iterate a table in sorted key order.",
                        "Returns an iterator like `pairs`, sorted by key.  An optional comparator is passed to `table.sort`."),
                    entry("lambda", "lambda(source) / L(source)", "function",
                        "Create a Lua function from a short expression.",
                        "The global helper `lambda` and its aliases `L` and `string.L` compile a short lambda expression.  See the `string` helpers below."),
                    entry("string.starts_with", "string.starts_with(value, prefix)", "method",
                        "Return true when a string starts with `prefix`.",
                        [[
Return true when the string begins with `prefix`.

The comparison is case-sensitive and literal, not a Lua pattern match. An empty prefix always matches.

```lua
print(("hello"):starts_with("he")) --> true
print(("hello"):starts_with("lo")) --> false
```
]]),
                    entry("string.ends_with", "string.ends_with(value, suffix)", "method",
                        "Return true when a string ends with `suffix`.",
                        [[
Return true when the string ends with `suffix`.

The comparison is case-sensitive and literal. An empty suffix always matches.

```lua
print(("hello"):ends_with("lo")) --> true
print(("hello"):ends_with("he")) --> false
```
]]),
                    entry("string.contains", "string.contains(value, needle)", "method",
                        "Return true when a string contains `needle`.",
                        [[
Return true when the string contains `needle`.

The search is plain text, so pattern characters such as `%` and `.` have no special meaning. Case is significant.

```lua
print(("hello"):contains("ell")) --> true
print(("hello"):contains("ELL")) --> false
```
]]),
                    entry("string.is_empty", "string.is_empty(value)", "method",
                        "Return true for `nil` or the empty string.",
                        [[
Return true when the value is `nil` or the empty string.

Any non-empty string returns false. This helper is convenient for validating optional string arguments.

```lua
print(""):is_empty()   --> true
print("x"):is_empty()  --> false
```
]]),
                    entry("string.is_not_empty", "string.is_not_empty(value)", "method",
                        "Return true for a non-nil, non-empty string.",
                        [[
Return true when the value is a non-nil, non-empty string.

The logical complement of `string.is_empty`. `nil` and `""` both return false.

```lua
print("x"):is_not_empty() --> true
print(""):is_not_empty()  --> false
```
]]),
                    entry("string.split", "string.split(value [, separator])", "method",
                        "Split a string into multiple values.",
                        [[
Split a string into multiple return values.

`separator` defaults to a comma. The separator is literal text, not a Lua pattern, and may contain several characters. Empty fields are preserved, including leading and trailing ones.

```lua
local a, b, c = ("1,2,3"):split(",")
print(a, b, c) --> 1 2 3

local parts = table.pack(("a<>b"):split("<>"))
print(parts.n) --> 2
```
]]),
                    entry("string.to_table", "string.to_table(value [, separator])", "method",
                        "Split a string into a table.",
                        [[
Split a string into an array using a literal separator.

`separator` defaults to a comma. Empty fields are preserved, and the function accepts multi-character separators. Use `string.split` when multiple return values are more convenient.

```lua
table.print(("1,2,3"):to_table()) --> { "1", "2", "3" }
```
]]),
                    entry("string.trim", "string.trim(value)", "method",
                        "Remove leading and trailing whitespace.",
                        [[
Remove leading and trailing whitespace from a string.

Whitespace includes spaces, tabs, carriage returns, newlines and NUL bytes. The argument must be a string; the result is a new string.

```lua
print(("  hello\n"):trim()) --> "hello"
```
]]),
                    entry("string.ltrim", "string.ltrim(value)", "method",
                        "Remove leading whitespace.",
                        [[
Remove leading whitespace from a string.

Spaces, tabs, carriage returns, newlines and NUL bytes are stripped from the start only. The trailing part of the string is left untouched.

```lua
print(("  hello  "):ltrim()) --> "hello  "
```
]]),
                    entry("string.rtrim", "string.rtrim(value)", "method",
                        "Remove trailing whitespace.",
                        [[
Remove trailing whitespace from a string.

Spaces, tabs, carriage returns, newlines and NUL bytes are stripped from the end only. The leading part of the string is left untouched.

```lua
print(("  hello  "):rtrim()) --> "  hello"
```
]]),
                    entry("string.base64encode", "string.base64encode(value)", "method",
                        "Encode a string as standard Base64.",
                        [[
Encode a string as standard Base64 using the `A-Z a-z 0-9 + /` alphabet and padding.

The argument must be a string. Binary data, including NUL bytes, is preserved. Use `base64urlEncode` when the result must be URL-safe.

```lua
print(("hello"):base64encode()) --> "aGVsbG8="
```
]]),
                    entry("string.base64decode", "string.base64decode(value)", "method",
                        "Decode a standard Base64 string.",
                        [[
Decode a standard Base64 string, returning the original bytes.

The input must use the standard Base64 alphabet with correct padding. Invalid input raises an error rather than returning a partial result.

```lua
print(("aGVsbG8="):base64decode()) --> "hello"
```
]]),
                    entry("string.base64urlEncode", "string.base64urlEncode(value)", "method",
                        "Encode a string as URL-safe Base64.",
                        [[
Encode a string as URL-safe Base64 using the `-` and `_` characters in place of `+` and `/`.

Padding is included, so the result can be decoded with `base64urlDecode`. The input may contain arbitrary bytes.

```lua
print(("a+b/c?"):base64urlEncode())
```
]]),
                    entry("string.base64urlDecode", "string.base64urlDecode(value)", "method",
                        "Decode a URL-safe Base64 string.",
                        [[
Decode a URL-safe Base64 string, accepting `-` and `_` as the last two alphabet characters.

Invalid input raises an error. Use `base64decode` for the standard alphabet.

```lua
print(("aGVsbG8="):base64urlDecode()) --> "hello"
```
]]),
                    entry("string.urlEncode", "string.urlEncode(value)", "method",
                        "Percent-encode a string for use in a URL.",
                        [[
Percent-encode a string for use in a URL.

Letters, digits, `-`, `_`, `.` and `~` are left unchanged. Every other byte is replaced by `%XX` with uppercase hexadecimal digits, including spaces (which become `%20`).

```lua
print(("a b/c"):urlEncode()) --> "a%20b%2Fc"
```
]]),
                    entry("string.utf8len", "string.utf8len(value)", "method",
                        "Return the number of UTF-8 characters in a string.",
                        [[
Count the number of UTF-8 code points in a string.

The argument must be valid UTF-8; malformed input raises an error. The count is not the byte length: `"ÖÄÜ"` has length 3 even though it occupies more bytes.

```lua
print(("héllo"):utf8len()) --> 5
```
]]),
                    entry("table.copy", "table.copy(value [, copies])", "function",
                        "Deep-copy a table.",
                        "`copies` tracks already copied tables, which also makes the function safe for cyclic tables."),
                    entry("table.tostring", "table.tostring(value [, name])", "function",
                        "Pretty-print a table as a string.",
                        [[
Pretty-print a table as a Lua-like string and return it.

The output is produced by `serpent.block`, with sorted keys, four-space indentation and no comments. When `name` is supplied, the result is prefixed with `name = `.

```lua
print(table.tostring({ b = 2, a = { 1 } }))
```
]]),
                    entry("table.print", "table.print(value [, name])", "function",
                        "Pretty-print a table to standard output.",
                        [[
Pretty-print a table to standard output.

This is equivalent to `print(table.tostring(value, name))`. The table is formatted with sorted keys and four-space indentation.

```lua
table.print({ b = 2, a = 1 }, "config")
```
]]),
                    entry("table.remove_if", "table.remove_if(value, predicate)", "function",
                        "Remove elements for which `predicate` is true.",
                        [[
Remove, in place, every array element for which `predicate(item)` is truthy.

The table is compacted and returned, so the original table keeps its identity. Non-array keys are not inspected.

```lua
local t = { 1, 2, 3, 4 }
table.remove_if(t, function(n) return n % 2 == 0 end)
--> t is { 1, 3 }
```
]]),
                    entry("table.filter", "table.filter(value, predicate)", "function",
                        "Return a new table with elements accepted by `predicate`.",
                        [[
Return a new array containing the elements for which `predicate(item)` is truthy.

The original table is not modified. Only the array part is visited, and the result is a new array with consecutive indexes.
]]),
                    entry("table.add_all", "table.add_all(target, ...)", "function",
                        "Append all arguments to a table.",
                        [[
Append the given values to the end of a table and return that table.

Arguments that are tables are flattened one level: their array parts are appended element by element. Non-table arguments are appended directly. Non-array keys in table arguments are ignored.

```lua
local t = { 1 }
table.add_all(t, 2, { 3, 4 }, 5)
--> t is { 1, 2, 3, 4, 5 }
```
]]),
                    entry("table.insert_all", "table.insert_all(target, index, ...)", "function",
                        "Insert all arguments at a position.",
                        [[
Insert the given values into a table starting at `index`, shifting later elements right.

Table arguments are flattened one level, like `table.add_all`. The table is modified in place and returned.

```lua
local t = { 1, 4 }
table.insert_all(t, 2, 2, 3)
--> t is { 1, 2, 3, 4 }
```
]]),
                    entry("table.load", "table.load(filename)", "function",
                        "Load a serialized table from a file.",
                        [[
Load a serialized table from a file and return the resulting value.

The file contents are prefixed with `return` and evaluated, so the file must contain a Lua expression rather than a statement list. `table.save` produces compatible files.

```lua
local value = table.load("config.lua")
```
]]),
                    entry("table.save", "table.save(filename, value)", "function",
                        "Serialize a table to a file.",
                        [[
Serialize a table and write it to a file.

The output uses `table.tostring`, producing sorted keys, four-space indentation and no comments. The file is replaced if it already exists. The function returns nothing.

```lua
table.save("config.lua", { retries = 3, host = "localhost" })
```
]]),
                    entry("table.default", "table.default(value, defaults [, error])", "function",
                        "Fill missing keys from a defaults table.",
                        "Returns `value`, with each missing key copied from `defaults`.  When `error` is true, unexpected keys raise an error."),
                    entry("table.insert_sorted", "table.insert_sorted(value, item [, comparator])", "function",
                        "Insert an item while keeping a sorted table ordered.",
                        [[
Insert `item` into an already sorted array, keeping the array ordered.

The default comparator is `a < b`; pass a custom comparator as the third argument. The insertion position is found with a binary search, and the table is modified in place. The function returns nothing.

```lua
local t = {}
table.insert_sorted(t, 3)
table.insert_sorted(t, 1)
--> t is { 1, 3 }
```
]]),
                    entry("table.next", "table.next(value)", "function",
                        "Iterator helper used by `stream`.",
                        [[
Return a stateless iterator over the array part of a table.

Each call to the iterator returns the next value, or `nil` when there are no more values. This is the iterator used internally by `stream` and is equivalent to `ipairs` for well-formed arrays.

```lua
for value in table.next { "a", "b" } do
    print(value)
end
```
]]),
                    entry("io.read_lines", "io.read_lines(filename)", "function",
                        "Read all lines from a file into a table.",
                        [[
Read a text file into an array of lines and return the array.

Line terminators are removed and empty lines are preserved. The file is opened read-only and closed before returning. An open failure raises an error through `assert`.

```lua
local lines = io.read_lines("data.txt")
print(lines[1])
```
]]),
                    entry("io.write_lines", "io.write_lines(filename, lines [, eol])", "function",
                        "Write a table of lines to a file.",
                        [[
Write an array of lines to a file, replacing any existing contents.

Each line is written followed by `eol`, which defaults to `"\n"`. The file is opened in binary write mode and closed afterwards. An open failure raises an error through `assert`.

```lua
io.write_lines("out.txt", { "one", "two" })
```
]]),
                    entry("io.read_file", "io.read_file(filename)", "function",
                        "Read an entire file as a string.",
                        [[
Read an entire file as a string.

The file is opened in binary read mode and closed before returning. An open failure raises an error through `assert`, so check the path or wrap the call in `pcall` if missing files are expected.
]]),
                    entry("io.write_file", "io.write_file(filename, data)", "function",
                        "Write a string to a file, replacing its contents.",
                        [[
Write a string to a file, replacing its previous contents.

The file is opened in binary write mode, the data is written, and the file is closed. An open failure raises an error through `assert`.

```lua
io.write_file("out.txt", "hello")
```
]]),
                    entry("io.append_file", "io.append_file(filename, data)", "function",
                        "Append a string to a file.",
                        [[
Append a string to a file, creating the file if it does not exist.

The file is opened in append/update binary mode and closed afterwards. An open failure raises an error through `assert`.
]]),
                    entry("os.name", "os.name", "field",
                        "Operating system name.",
                        "One of `windows`, `linux`, `macos`, or the platform name reported by the interpreter."),
                    entry("os.home", "os.home", "field",
                        "The current user's home directory.",
                        [[
The current user's home directory as a string, or `nil` when it cannot be determined.

On Windows the value is built from `HOMEDRIVE` and `HOMEPATH`; elsewhere it comes from `HOME`.
]]),
                    entry("os.is_windows", "os.is_windows", "field",
                        "True on Windows.",
                        [[
True when the interpreter is running on Windows, false on every other platform.

This is a boolean companion to the `os.name` string.
]]),
                    entry("os.is_linux", "os.is_linux", "field",
                        "True on Linux.",
                        [[
True when the interpreter is running on Linux, false on every other platform.
]]),
                    entry("os.is_mac", "os.is_mac", "field",
                        "True on macOS.",
                        [[
True when the interpreter is running on macOS, false on every other platform.

The field is named `is_mac` even though `os.name` uses the value `"macos"`.
]]),
                    entry("os.separator", "os.separator", "field",
                        "The platform path separator (`\\` or `/`).",
                        [[
The platform's path separator: `\` on Windows and `/` elsewhere.

This is a one-character string intended for building paths, and it matches the separator used by the `filesystem` module.
]]),
                    entry("os.nanotime", "os.nanotime()", "function",
                        "Return a monotonic timestamp in nanoseconds.",
                        [[
Return a monotonic timestamp in nanoseconds.

The value is suitable for measuring elapsed time, not for displaying wall-clock dates. It is used by `timer` and `benchmark`.

```lua
local start = os.nanotime()
-- work
print(os.nanotime() - start)
```
]]),
                    entry("math.round", "math.round(value)", "function",
                        "Round a number to the nearest integer.",
                        [[
Round a number to the nearest integer.

Exact halves are rounded to the nearest even integer (banker's rounding): `0.5` becomes `0`, `1.5` becomes `2`, and `-2.5` becomes `-2`. Non-half values round to the nearest integer. The argument must be a number.

```lua
math.round(2.4) --> 2
math.round(2.5) --> 2
math.round(42.6) --> 43
```
]]),
                    entry("math.maxdouble", "math.maxdouble", "field",
                        "The largest finite double.",
                        [[
The largest finite IEEE-754 double-precision value, approximately `1.7976931348623157e308`.

This is a constant number, useful as an initial value for minimum searches.
]]),
                    entry("math.mindouble", "math.mindouble", "field",
                        "The smallest positive normalized double.",
                        [[
The smallest positive normalized IEEE-754 double-precision value, approximately `2.2250738585072014e-308`.

Denormalized values are smaller. This constant is useful as an initial value for maximum searches.
]]),
                }),

                module("benchmark", "benchmark", "Small benchmark runner with nanosecond precision.", [==[
`benchmark.run(table [, iterations])` runs every function in a benchmark table and
prints per-run timings and memory use.

Special keys `before_all`, `before_each`, `after_each` and `after_all` are called
around the run.  A key `before_<name>` or `after_<name>` is called around the
matching benchmark function.  The optional `iterations` argument overrides the
`iter` field of the benchmark table (default 3).
]==], {
                    entry("benchmark.run", "benchmark.run(bench [, iterations])", "function",
                        "Run a benchmark table and print the summary.",
                        "The benchmark table contains functions to measure plus optional setup and teardown hooks."),
                }),

                module("collection", "collection", "Java-style collections: lists, maps and sets.", [==[
`collection` provides `list`, `map` and `set` factories.  All collections support
`size`, `is_empty`, `add_all`, `remove_all`, `contains_all`, `equals`, `copy`,
`stream`, `union`, `intersection` and `difference`.  Lists and sets also support
`to_array`; use `map:values():to_array()` for maps.
]==], {
                    entry("collection:size", "collection:size()", "method",
                        "Return the number of elements.",
                        [[
Return the number of elements in the collection.

The value is maintained by the collection implementation, so it is O(1) for lists, maps and sets. Use `#collection` where the metatable provides a length operator.
]]),
                    entry("collection:is_empty", "collection:is_empty()", "method",
                        "Return true when the collection has no elements.",
                        [[
Return true when the collection contains no elements.

This is equivalent to `collection:size() == 0` and is O(1).
]]),
                    entry("collection:add_all", "collection:add_all(items)", "method",
                        "Add all items from another collection or table.",
                        [[
Add every element from another collection or table.

For a collection, its iterator is used, so values (not indexes) are added. For a plain table, the array part is traversed with `next`. Returns the collection itself for chaining.

```lua
local list = require("collection").list
local l = list:new():add_all { 1, 2 }
```
]]),
                    entry("collection:remove_all", "collection:remove_all(items)", "method",
                        "Remove all items found in another collection or table.",
                        [[
Remove every element supplied by another collection or table.

For plain tables the array values are used. The return value follows the first removal attempt: it is true when that first item was present and removed, otherwise false. This means callers should not rely on the result as an "any removed" flag.

```lua
local set = require("collection").set
local s = set:new { 1, 2, 3 }
s:remove_all { 2, 3 }
```
]]),
                    entry("collection:contains_all", "collection:contains_all(items)", "method",
                        "Return true when every item is present.",
                        [[
Return true when every element in the supplied collection or table is present in this collection.

The check stops at the first missing element. An empty input returns true. The input may be any collection or a plain array-like table.
]]),
                    entry("collection:equals", "collection:equals(other)", "method",
                        "Compare two collections for equal contents.",
                        [[
Compare this collection with another collection or plain table for equal contents.

Every element of the other object must be contained in this one, and the element counts must match. Element order is not significant, and duplicate values are compared by simple membership.

```lua
local set = require("collection").set
local s = set:new { 1, 2 }
print(s:equals { 2, 1 }) --> true
```
]]),
                    entry("collection:copy", "collection:copy()", "method",
                        "Return a shallow copy.",
                        [[
Return a shallow copy of the collection.

A new collection of the same kind is created with the current elements. The elements themselves are not copied, so nested tables are shared with the original. Ordered maps and sets are rebuilt through their ordinary constructor, so the copy may not preserve insertion order.

```lua
local l = list:new():add_all { { 1 }, 2 }
local copy = l:copy()
print(copy:get(1) == l:get(1)) --> true (same nested table)
```
]]),
                    entry("collection:stream", "collection:stream()", "method",
                        "Return a `stream` over the collection.",
                        [[
Return a `stream` over the collection's elements.

The stream is built from the collection's iterator, so sets and ordered maps preserve their iteration order. The collection itself is not modified.

```lua
local sum = require("collection").list:new{1,2,3}:stream():sum()
```
]]),
                    entry("collection:union", "collection:union(...)", "method",
                        "Return the union with other collections.",
                        [[
Return a new collection containing this collection's elements plus all elements from the given collections or tables.

The receiver is not modified. The result is created with `self:new(self)`, so it has the same collection type. Ordered variants are rebuilt through their ordinary constructor and may not preserve insertion order. Duplicate values follow the rules of that type (sets deduplicate, lists keep duplicates).
]]),
                    entry("collection:intersection", "collection:intersection(...)", "method",
                        "Return the intersection with other collections.",
                        [[
Return a new collection containing only elements that are present in this collection and in every given collection or table.

The receiver is unchanged. The result is a copy of the receiver reduced with `retain_all` for each argument, so type-specific behavior is preserved, but ordered variants may lose insertion order.
]]),
                    entry("collection:difference", "collection:difference(...)", "method",
                        "Return the difference with other collections.",
                        [[
Return a new collection containing the receiver's elements that are not present in any of the given collections or tables.

The receiver is unchanged. The result starts as a copy and removes each argument's elements in turn. Because the copy uses the ordinary constructor, ordered variants may lose insertion order.
]]),
                    entry("collection:to_array", "collection:to_array()", "method",
                        "Return the contents as an array.",
                        [[
Return the collection's elements as a plain array.

The array is built from `iterate_indexed`, so lists and sets produce consecutive indexes. The bundled map implementation does not define indexed iteration; use `map:values():to_array()` for maps instead of calling this method on a map.

```lua
local items = require("collection").list:new{ "a", "b" }:to_array()
--> { "a", "b" }
```
]]),
                }),

                module("collection.list", "collection.list", "Ordered list collection.", [==[
A list is an ordered sequence.  Methods that mutate a list return the list, so
calls can be chained.
]==], {
                    entry("collection.list.new", "collection.list.new([initial])", "function",
                        "Create a new list.",
                        [[
Create a new empty list, optionally populated from an array or another collection.

The initial values are added through `add_all`, so they become the list's elements in iteration order. A plain list keeps insertion order; use `new_sorted` for automatic sorting.

```lua
local list = require("collection").list
local l = list:new { "a", "b" }
print(l:size()) --> 2
```
]]),
                    entry("collection.list.new_sorted", "collection.list.new_sorted([initial [, comparator]])", "function",
                        "Create a list that keeps its elements sorted.",
                        [[
Create a list that keeps its elements in sorted order.

The optional comparator receives two values and returns true when the first sorts before the second; the default is `a < b`. The optional initial array or collection is inserted one element at a time in sorted position.

```lua
local list = require("collection").list
local l = list:new_sorted { "c", "a", "b" }
print(l:get(1)) --> "a"
```
]]),
                    entry("collection.list:add", "list:add([index,] item)", "method",
                        "Add one item, optionally at an index.",
                        [[
Add one item to the list, optionally at a 1-based index.

With one argument the item is appended, or inserted in sorted position for a sorted list. With two arguments the first is an index and the second is the item; inserting by index is not allowed in a sorted list. Passing more than two arguments raises an error. Returns the list.

```lua
local l = list:new():add("b"):add(1, "a")
--> { "a", "b" }
```
]]),
                    entry("collection.list:add_all", "list:add_all([index,] items)", "method",
                        "Add all items from a table or collection.",
                        [[
Add every item from an array or collection.

With one argument the items are appended (or inserted in sorted order for a sorted list). With two arguments the first is a starting index and the second is the collection; items are inserted from that index onward. Returns the list.
]]),
                    entry("collection.list:clear", "list:clear([size])", "method",
                        "Remove all items.",
                        [[
Remove all items from the list and reset its size to zero.

The optional argument is a size or capacity hint; the bundled implementation accepts a number but does not preallocate storage. Passing a table clears the list and then adds that table's items. Other argument types raise an error. Returns the list.

```lua
local l = list:new { 1, 2, 3 }:clear()
print(l:is_empty()) --> true
```
]]),
                    entry("collection.list:contains", "list:contains(item)", "method",
                        "Return true when the item is present.",
                        [[
Return true when the list contains the given value.

Comparison uses `==`, so table values are found by identity. The search is linear from the beginning of the list.
]]),
                    entry("collection.list:get", "list:get(index)", "method",
                        "Return the item at an index.",
                        [[
Return the item at a 1-based index, or `nil` when the index is outside the list.

A non-number index raises an argument error. Negative and zero indexes simply produce `nil`.
]]),
                    entry("collection.list:set", "list:set(index, item)", "method",
                        "Replace the item at an index.",
                        [[
Replace the item at a 1-based index and return the previous value.

A non-number index raises an argument error. Setting an index outside the current list stores the value there without changing the size; only `add` maintains the list length.
]]),
                    entry("collection.list:index_of", "list:index_of(item)", "method",
                        "Return the first index of an item, or 0.",
                        [[
Return the 1-based index of the first occurrence of an item, or `0` when it is absent.

Comparison uses `==`. The alias semantics are those of a linear forward search.

```lua
local l = list:new { "a", "b", "a" }
print(l:index_of("a")) --> 1
print(l:index_of("z")) --> 0
```
]]),
                    entry("collection.list:last_index_of", "list:last_index_of(item)", "method",
                        "Return the last index of an item, or 0.",
                        [[
Return the 1-based index of the last occurrence of an item, or `0` when it is absent.

The whole list is scanned, with later matches replacing earlier ones.
]]),
                    entry("collection.list:remove", "list:remove(item)", "method",
                        "Remove the first occurrence of an item.",
                        [[
Remove the first occurrence of an item from the list.

Returns true when an item was removed and false when it was not found. Later elements shift down to fill the gap, and the size is decremented.
]]),
                    entry("collection.list:remove_index", "list:remove_index(index)", "method",
                        "Remove the item at an index.",
                        [[
Remove the item at a 1-based index.

The list is compacted and its size is decremented. Returns the list itself, not the removed value, so the call can be chained.

```lua
local l = list:new { "a", "b", "c" }:remove_index(2)
--> { "a", "c" }
```
]]),
                    entry("collection.list:retain_all", "list:retain_all(items)", "method",
                        "Keep only items present in another collection.",
                        [[
Keep only items that are present in another collection or array-like table.

The list is modified in place, preserving the relative order of survivors, and is returned. A plain table is converted to a set for fast membership tests.
]]),
                    entry("collection.list:sublist", "list:sublist(from, to)", "method",
                        "Return a new list containing the given range.",
                        [[
Return a new list containing the inclusive range from `from` through `to`.

Both indexes must be numbers. The result is a new list; the original is unchanged. Values outside the list's current range may leave holes, so callers should pass valid indexes.

```lua
list:new{ "a", "b", "c" }:sublist(2, 3):to_array() --> { "b", "c" }
```
]]),
                    entry("collection.list:for_each", "list:for_each(func)", "method",
                        "Call `func` for every item.",
                        [[
Call `func(item)` for every item in list order.

Returns the list for chaining. Mutating the list during iteration has unspecified results.
]]),
                    entry("collection.list:for_each_index", "list:for_each_index(func)", "method",
                        "Call `func(index, item)` for every item.",
                        [[
Call `func(index, item)` for every item, with 1-based indexes.

Returns the list for chaining. This is useful when the position matters as well as the value.

```lua
list:new{ "a", "b" }:for_each_index(function(i, v) print(i, v) end)
```
]]),
                    entry("collection.list:iterate", "list:iterate()", "method",
                        "Return an iterator over items.",
                        [[
Return an iterator over the list's values.

Each call returns the next value, or `nil` at the end. Values are produced in array order.

```lua
for value in list:new{ "a", "b" }:iterate() do print(value) end
```
]]),
                    entry("collection.list:iterate_indexed", "list:iterate_indexed()", "method",
                        "Return an iterator over indexes and items.",
                        [[
Return an iterator over indexes and values.

Each call yields a 1-based index followed by the corresponding value. This is a thin wrapper over `ipairs` on the internal array.
]]),
                    entry("collection.list:iterator", "list:iterator(func)", "method",
                        "Call a function for every item until it returns false.",
                        [[
Call `func(item)` for every item until the callback returns `false` or `nil`.

Returns true when every callback returned a non-false value, false when iteration stopped early. This is a traversal helper, not an iterator factory.

```lua
local ok = list:new{ 1, 2, 3 }:iterator(function(v) return v < 3 end)
--> false
```
]]),
                    entry("collection.list:iterator_indexed", "list:iterator_indexed(func)", "method",
                        "Call an indexed function for every item until it returns false.",
                        [[
Call `func(index, item)` for every item until the callback returns `false` or `nil`.

Returns true when every callback returned a non-false value, false when iteration stopped early.
]]),
                }),

                module("collection.map", "collection.map", "Key-value map collection.", [==[
Maps preserve key/value associations and provide ordered variants through
`new_ordered`.
]==], {
                    entry("collection.map.new", "collection.map.new([initial])", "function",
                        "Create a new map.",
                        [[
Create a map from an optional table or existing map.

A plain table's key/value pairs are copied; an existing map's entries are copied through `put_all`. Iteration follows native table order. Use `new_ordered` when insertion order matters.

```lua
local map = require("collection").map
local m = map:new { a = 1, b = 2 }
print(m:get("a")) --> 1
```
]]),
                    entry("collection.map.new_ordered", "collection.map.new_ordered([initial])", "function",
                        "Create a map that iterates in insertion order.",
                        [[
Create a map that remembers insertion order for iteration.

The optional initial table or map is copied in its iteration order. Updating an existing key keeps its original position; removing and re-inserting a key moves it to the end.

```lua
local map = require("collection").map
local m = map:new_ordered { a = 1, b = 2 }
m:put("c", 3)
for k in m:iterate() do print(k) end --> a, b, c
```
]]),
                    entry("collection.map:put", "map:put(key, value)", "method",
                        "Associate a key with a value.",
                        [[
Associate `key` with `value` and return the previous value for that key, or `nil`.

If `value` is `nil`, the key is removed instead of stored. Adding a new non-nil key increments the size; in an ordered map it is appended to the insertion order.

```lua
local m = map:new()
print(m:put("a", 1)) --> nil
print(m:put("a", 2)) --> 1
```
]]),
                    entry("collection.map:get", "map:get(key)", "method",
                        "Return the value for a key, or nil.",
                        [[
Return the value associated with `key`, or `nil` when the key is absent.

Because `nil` is also used for missing entries, `contains_key` is the reliable existence test.
]]),
                    entry("collection.map:get_or_default", "map:get_or_default(key, default)", "method",
                        "Return a value or a default.",
                        [[
Return the value for `key`, or `default` when the key is absent.

A stored `false` value is returned as `false`, not replaced by the default.
]]),
                    entry("collection.map:put_all", "map:put_all(table)", "method",
                        "Copy all key/value pairs from a table or map.",
                        [[
Copy all key/value pairs from a plain table or another map into this map.

A collection argument must be a map; other collection types raise an argument error. Existing keys are overwritten, and the map itself is returned.

```lua
local m = map:new():put_all { a = 1, b = 2 }
```
]]),
                    entry("collection.map:put_if_absent", "map:put_if_absent(key, value)", "method",
                        "Insert a key only when it is not present.",
                        [[
Insert `value` only when `key` is not already present.

Returns `nil` when the value was inserted, or the existing value when the key was already present. A `nil` value is not inserted. Ordered maps append newly inserted keys.
]]),
                    entry("collection.map:remove", "map:remove(key [, value])", "method",
                        "Remove a key, optionally only when it has a given value.",
                        [[
Remove `key`, optionally only when its current value equals `value`.

With one argument, returns the removed value, or `nil` when the key was absent. With two arguments, returns true when the value matched and was removed, false when it did not, and `nil` when the key was absent. Removing the last key shrinks the size; ordered maps also remove it from the order.
]]),
                    entry("collection.map:merge", "map:merge(key, value, func)", "method",
                        "Merge a value into an existing key using `func`.",
                        [[
Merge a new value into `key` using a callback.

When the key exists, `func(key, value, old_value)` computes the replacement and `func` is required. When the key is absent, `value` is stored as-is and the callback is not called. Returns the final value, which may be `nil` to remove the key.

```lua
local m = map:new()
m:merge("count", 1) --> 1
m:merge("count", 2, function(_, new, old) return new + old end) --> 3
```
]]),
                    entry("collection.map:replace", "map:replace(key, old, new)", "method",
                        "Replace a value when it currently equals `old`.",
                        [[
Replace an existing value, in either conditional or unconditional form.

`m:replace(key, old, new)` replaces the value only when it currently equals `old`, and returns the old value. `m:replace(key, value)` sets the key to `value` unconditionally; if `value` is `nil`, the key is removed. In both forms the previous value is returned, or `nil` when the key was absent.
]]),
                    entry("collection.map:contains_key", "map:contains_key(key)", "method",
                        "Return true when a key exists.",
                        [[
Return true when the map has a non-nil value for `key`.

This is the correct existence check when values may legitimately be `false`.
]]),
                    entry("collection.map:contains_value", "map:contains_value(value)", "method",
                        "Return true when a value exists.",
                        [[
Return true when any entry in the map has the given value.

Comparison uses `==`, so table values are matched by identity rather than deep content. The search is linear.
]]),
                    entry("collection.map:entry_set", "map:entry_set()", "method",
                        "Return the entries as a set.",
                        [[
Return a set of tables, one per entry, each with `key` and `value` fields.

The set contains newly created entry tables, not references to the map. Entries are added to the set in the map's iteration order, but the returned value is an ordinary set.

```lua
for entry in map:new{ a = 1 }:entry_set():iterate() do
    print(entry.key, entry.value)
end
```
]]),
                    entry("collection.map:key_set", "map:key_set()", "method",
                        "Return the keys as a set.",
                        [[
Return a set containing every key in the map.

The returned set is independent of the map; modifying it does not affect the map. Iteration order follows the source map.
]]),
                    entry("collection.map:values", "map:values()", "method",
                        "Return the values as a collection.",
                        [[
Return a list containing every value in the map.

Values appear in the map's iteration order: insertion order for ordered maps, native table order otherwise. The returned list is independent of the map.
]]),
                    entry("collection.map:equals", "map:equals(other)", "method",
                        "Compare two maps for equal contents.",
                        [[
Compare this map with another map or plain table for equal key/value pairs.

A collection argument must be a map with the same size. Every key in the other object must exist here with an equal (not deep-equal) value, and the total counts must match.
]]),
                    entry("collection.map:compute", "map:compute(key, func)", "method",
                        "Compute a new value for a key.",
                        [[
Compute a new value for `key` with `func(key, old_value)` and store the result.

The callback is called even when the key is absent, with `nil` as the old value. If it returns `nil`, the key is removed; otherwise the value is stored. The computed value is returned.
]]),
                    entry("collection.map:compute_if_absent", "map:compute_if_absent(key, func)", "method",
                        "Compute a value only when the key is absent.",
                        [[
Compute and store a value only when `key` is absent.

The callback receives the key and its return value is stored when non-nil. If the key already exists, the existing value is returned without calling the callback.

```lua
local m = map:new()
print(m:compute_if_absent("a", function() return "A" end)) --> "A"
print(m:compute_if_absent("a", function() return "Z" end)) --> "A"
```
]]),
                    entry("collection.map:compute_if_present", "map:compute_if_present(key, func)", "method",
                        "Compute a value only when the key is present.",
                        [[
Recompute a value only when `key` is present.

The callback receives `(key, old_value)`. A non-nil result replaces the value; `nil` removes the key. Returns the new value, or `nil` when the key was absent.
]]),
                    entry("collection.map:for_each", "map:for_each(func)", "method",
                        "Call `func(key, value)` for every entry.",
                        [[
Call `func(key, value)` for every entry in the map.

Iteration follows insertion order for ordered maps and native table order otherwise. Returns the map for chaining.
]]),
                    entry("collection.map:iterate", "map:iterate()", "method",
                        "Return an iterator over keys and values.",
                        [[
Return an iterator yielding `key, value` pairs.

Ordered maps iterate in insertion order; ordinary maps use `pairs`. Returns the standard iterator triple suitable for a generic `for` loop.

```lua
for key, value in map:new{ a = 1 }:iterate() do print(key, value) end
```
]]),
                    entry("collection.map:iterator", "map:iterator(func)", "method",
                        "Call a function for every entry until it returns false.",
                        [[
Call `func(key, value)` for every entry until the callback returns `false` or `nil`.

Returns true when all callbacks returned a non-false value, false when iteration stopped early. This is a traversal helper, not an iterator factory.
]]),
                    entry("collection.map:size", "map:size()", "method",
                        "Return the number of entries.",
                        [[
Return the number of key/value entries in the map.

The count is maintained by `put` and `remove`, so it is O(1) and does not scan the table.
]]),
                    entry("collection.map:is_empty", "map:is_empty()", "method",
                        "Return true when the map has no entries.",
                        [[
Return true when the map contains no entries.

This is equivalent to `map:size() == 0`.
]]),
                }),

                module("collection.set", "collection.set", "Set collection with optional insertion order.", [==[
A set stores unique values.  `new_ordered` preserves insertion order during
iteration.
]==], {
                    entry("collection.set.new", "collection.set.new([initial])", "function",
                        "Create a new set.",
                        [[
Create a set from an optional initial collection or array-like table.

Duplicate values are stored only once, and element order follows the native table iteration order unless `new_ordered` is used. The initial table is copied, not referenced.

```lua
local set = require("collection").set
local s = set:new { 1, 2, 2, 3 }
print(s:size()) --> 3
```
]]),
                    entry("collection.set.new_ordered", "collection.set.new_ordered([initial])", "function",
                        "Create an insertion-ordered set.",
                        [[
Create a set that preserves insertion order during iteration.

The optional initial collection or array is added in order. Removing and re-adding a value places it at the end of the order. Use `iterate`, `iterate_indexed` or `for_each` to observe the order.

```lua
local s = require("collection").set:new_ordered { "b", "a" }
s:add("c")
for v in s:iterate() do print(v) end --> b, a, c
```
]]),
                    entry("collection.set:add", "set:add(item)", "method",
                        "Add one unique value.",
                        [[
Add a value to the set and return the set.

Adding a value that is already present leaves the set unchanged. `nil` is not a valid set element and raises an argument error, as does passing more than one value. Use `set:add_all` to add several items at once.

```lua
local s = require("collection").set:new()
s:add("x"):add("x") --> size remains 1
```
]]),
                    entry("collection.set:remove", "set:remove(item)", "method",
                        "Remove a value.",
                        [[
Remove a value from the set.

Returns true when the value was present and removed, false otherwise. Removing an absent value is harmless. Ordered sets keep the relative order of their remaining values.
]]),
                    entry("collection.set:contains", "set:contains(item)", "method",
                        "Return true when a value is present.",
                        [[
Return true when the set contains the given value.

Lookup is a direct table-key test, so it is O(1) on average. Values must be valid Lua table keys.
]]),
                    entry("collection.set:retain_all", "set:retain_all(items)", "method",
                        "Keep only values also present in another collection.",
                        [[
Keep only values that are also present in the supplied collection or table.

The set is modified in place and returned. For ordered sets, the surviving values retain their insertion order. Plain array-like tables and other collections are both accepted.
]]),
                    entry("collection.set:for_each", "set:for_each(func)", "method",
                        "Call `func(value)` for every value.",
                        [[
Call `func(value)` for every value in the set.

The iteration order is insertion order for ordered sets and native table order otherwise. Returns the set for chaining. Mutating the set during iteration has unspecified results.
]]),
                    entry("collection.set:iterate", "set:iterate()", "method",
                        "Return an iterator over values.",
                        [[
Return an iterator over the set's values.

Each call to the iterator returns the next value, or `nil` when exhausted. Ordered sets preserve insertion order; ordinary sets follow native table order.

```lua
for value in set:new{ "a", "b" }:iterate() do print(value) end
```
]]),
                    entry("collection.set:iterate_indexed", "set:iterate_indexed()", "method",
                        "Return an iterator over indexes and values.",
                        [[
Return an iterator over indexes and values.

Each call yields a consecutive 1-based index and the corresponding value. Ordered sets iterate their insertion-order array; ordinary sets count values in native table order.
]]),
                    entry("collection.set:iterator", "set:iterator(func)", "method",
                        "Call a function for every value until it returns false.",
                        [[
Call `func(value)` for every value until the callback returns `false` or `nil`.

Returns true when every callback returned a non-false value, false when iteration stopped early. This is a traversal helper, not an iterator factory.

```lua
local s = require("collection").set:new { 1, 2, 3 }
local ok = s:iterator(function(v) return v < 3 end) --> false, because 3 fails the predicate
```
]]),
                    entry("collection.set:iterator_indexed", "set:iterator_indexed(func)", "method",
                        "Call an indexed function for every value until it returns false.",
                        [[
Call `func(index, value)` for every value until the callback returns `false` or `nil`.

Returns true when every callback returned a non-false value, false when iteration stopped early. Indexes start at 1.
]]),
                    entry("collection.set:size", "set:size()", "method",
                        "Return the number of values.",
                        [[
Return the number of unique values in the set.

The count is maintained as values are added and removed, so it is O(1) and does not scan the set.
]]),
                    entry("collection.set:is_empty", "set:is_empty()", "method",
                        "Return true when the set is empty.",
                        [[
Return true when the set contains no values.

This is equivalent to `set:size() == 0`.
]]),
                }),

                module("crossline", "crossline", "Readline, screen, cursor, history and paging helpers.", [==[
`crossline` is a small self-contained readline replacement.  The module exposes
the low-level screen and cursor helpers plus history and paging functions used by
the REPL.
]==], {
                    entry("crossline.readline", "crossline.readline(prompt)", "function",
                        "Read a line with editing and history."),
                    entry("crossline.set_prompt_color", "crossline.set_prompt_color(color)", "function",
                        "Set the prompt colour."),
                    entry("crossline.set_color", "crossline.set_color(color)", "function",
                        "Set the current output colour.",
                        "Use values from `crossline.color.fg` and `crossline.color.bg`."),
                    entry("crossline.print_paged", "crossline.print_paged(text)", "function",
                        "Print long text through the pager."),
                    entry("crossline.screen.dimensions", "crossline.screen.dimensions()", "function",
                        "Return the terminal width and height.",
                        "Returns a table with `x` and `y` fields."),
                    entry("crossline.screen.clear", "crossline.screen.clear()", "function",
                        "Clear the terminal screen."),
                    entry("crossline.cursor.get", "crossline.cursor.get()", "function",
                        "Return the current cursor position (`x`, `y`)."),
                    entry("crossline.cursor.set", "crossline.cursor.set(x, y)", "function",
                        "Move the cursor to a position."),
                    entry("crossline.cursor.move", "crossline.cursor.move(x, y)", "function",
                        "Move the cursor relative to its current position."),
                    entry("crossline.cursor.hide", "crossline.cursor.hide()", "function",
                        "Hide the cursor."),
                    entry("crossline.cursor.show", "crossline.cursor.show()", "function",
                        "Show the cursor."),
                    entry("crossline.history.save", "crossline.history.save(filename)", "function",
                        "Save the command history."),
                    entry("crossline.history.load", "crossline.history.load(filename)", "function",
                        "Load the command history."),
                    entry("crossline.history.show", "crossline.history.show()", "function",
                        "Print the command history."),
                    entry("crossline.history.clear", "crossline.history.clear()", "function",
                        "Clear the command history."),
                    entry("crossline.paging.start", "crossline.paging.start()", "function",
                        "Start paging output."),
                    entry("crossline.paging.stop", "crossline.paging.stop()", "function",
                        "Stop paging output."),
                    entry("crossline.paging.check", "crossline.paging.check()", "function",
                        "Check whether paging is active."),
                    entry("crossline.paging.print", "crossline.paging.print(text)", "function",
                        "Print text through the pager."),
                }, { upstream = "https://github.com/jcwangxp/Crossline", license = "MIT" }),

                module("filesystem", "filesystem", "Filesystem and path manipulation.", [==[
`filesystem` provides module-level functions and path objects.  A path object is
a table with `path`, `name`, `full_path` and the path methods documented below.
Path objects are accepted anywhere a path string is accepted.

```lua
local fs = require "filesystem"
local p = fs.path("src/version")
p.full_path        --> "src/version"
p:exists()
p:size()
```
]==], {
                    entry("filesystem.cwd", "fs.cwd() / fs.current_directory()", "function",
                        "Return the current working directory.",
                        [[
Return the absolute path of the current working directory as a string. The path is resolved through the operating system, so it has no trailing separator and no `.` or `..` components.

On failure the function follows the module's error-handling mode: it returns `nil, message` by default, or raises when `fs:config { error_handling = "raise" }` was applied.

```lua
local fs = require "filesystem"
print(fs.cwd())
```
]]),
                    entry("filesystem.create_path", "fs.create_path(path, name)", "function",
                        "Create a path object from a directory and file name.",
                        [[
Build a path object from a directory part and a final name, without normalizing either component.

`path` is stored in the `path` field, `name` in the `name` field, and the joined result in `full_path`. A separator is inserted when `path` does not already end with one. Both arguments must be strings.

```lua
local p = require("filesystem").create_path("src", "version")
print(p.full_path) --> "src/version"
print(p.name)      --> "version"
```
]]),
                    entry("filesystem.path", "fs.path(...)", "function",
                        "Normalize components into a path object.",
                        "Accepts strings, path objects and path component tables.  Relative paths stay relative; paths beginning with `.` or `..` are resolved against the current directory."),
                    entry("filesystem.ensure_path", "fs.ensure_path(path)", "function",
                        "Return a path object, converting a string when needed.",
                        [[
Return a path object for `path`. A string is converted with `fs.path`; a table that already has a `full_path` field is returned unchanged.

Any other value raises an error, regardless of the module error-handling mode, because the check protects later filesystem calls from malformed path objects.
]]),
                    entry("filesystem.get_path", "fs.get_path(path)", "function",
                        "Return the underlying path string of a path object.",
                        [[
Return the path string stored in a path object, or the argument itself when it is already a string.

The function only extracts the value; it does not check existence or normalize the path. It is useful when passing a path object to another library.

```lua
local fs = require "filesystem"
local p = fs.path("src/version")
print(fs.get_path(p)) --> "src/version"
```
]]),
                    entry("filesystem.absolute", "fs.absolute(path)", "function",
                        "Return the absolute path, or nil when it does not exist.",
                        [[
Resolve `path` to its absolute, canonical form, following symbolic links. The path must exist.

Returns `nil` when the path cannot be resolved, for example because it is missing or a component is not accessible. It does not raise in the default error-handling mode.

```lua
local fs = require "filesystem"
print(fs.absolute("src/version"))
```
]]),
                    entry("filesystem.concat_path", "fs.concat_path(path, file)", "function",
                        "Join a path with a file name.",
                        [[
Join a directory path and a file name without normalizing the result.

`path` may be a string or an array of components; component arrays are joined with `fs.separator`. If `file` is `nil` or empty, `path` is returned unchanged. A separator is added when `path` does not already end in `/` or `\`.

```lua
local fs = require "filesystem"
print(fs.concat_path("src", "main.lua")) --> "src/main.lua"
```
]]),
                    entry("filesystem.split_path", "fs.split_path(path)", "function",
                        "Split a path into components.",
                        [[
Split a path into its slash- or backslash-separated components and return them as an array.

Separators and repeated separators are discarded, but `.` and `..` components are preserved. A leading root separator or drive letter is not included in the result.

```lua
local fs = require "filesystem"
table.print(fs.split_path("/usr/local/bin")) --> { "usr", "local", "bin" }
```
]]),
                    entry("filesystem.create_tree", "fs.create_tree(path)", "function",
                        "Create a directory and all missing parents.",
                        [[
Create `path` and every missing parent directory. Existing directories are left alone, so the call is idempotent.

`path` may be a string or a path object. Directory creation errors follow the module's error-handling mode.

```lua
local fs = require "filesystem"
fs.create_tree("build/cache/data")
```
]]),
                    entry("filesystem.delete_tree", "fs.delete_tree(path)", "function",
                        "Delete a directory tree recursively.",
                        [[
Recursively delete a directory tree, including the directory named by `path` itself.

Children are removed before their containing directory, and symbolic-link cycles are not followed. Deletion errors follow the module's error-handling mode.

```lua
require("filesystem").delete_tree("build/cache")
```
]]),
                    entry("filesystem.list", "path:list()", "method",
                        "Return the directory entries as an array of path objects.",
                        [[
Return the entries of a directory as an array of path objects. The returned paths are absolute, with `path` set to the directory and `name` set to the entry name.

`path` may be a path object or a string; with no argument the current directory is listed. Directory-open and traversal errors follow the module's error-handling mode.

```lua
local fs = require "filesystem"
for _, entry in ipairs(fs.path("src"):list()) do
    print(entry.name)
end
```
]]),
                    entry("filesystem.dir", "path:dir()", "method",
                        "Return the directory entries keyed by name.",
                        [[
Return the entries of a directory as a table keyed by entry name. Each value is a path object whose `full_path` points at the entry.

This is the keyed counterpart of `path:list()`. Errors are reported according to the module's error-handling mode.

```lua
local fs = require "filesystem"
local entries = fs.path("src"):dir()
print(entries["main.lua"].full_path)
```
]]),
                    entry("filesystem.iterate", "fs.iterate(path [, sorted])", "method",
                        "Iterate the entries of a directory.",
                        [[
Iterate the entries of a directory, yielding the entry name and its path object.

By default the order is the native directory order. Pass `true` as `sorted` to iterate names in sorted order. This is normally used as `for name, entry in fs.iterate(path) do ... end` or `path:iterate()`.

```lua
local fs = require "filesystem"
for name, entry in fs.path("src"):iterate(true) do
    print(name, entry.full_path)
end
```
]]),
                    entry("filesystem.walk", "fs.walk(path, func [, dir_first])", "function",
                        "Walk a directory tree, calling `func(path)` for each entry.",
                        [[
Walk a directory tree, calling `func(path)` once for every entry, including the starting path.

When `dir_first` is true, a directory is passed to `func` before its children. Otherwise children are visited first and the directory is reported on the way out. Symbolic-link targets are resolved and each real directory is visited at most once, which prevents cycles.

A string path must exist; the function then walks its absolute form. Errors opening or traversing a directory follow the module's error-handling mode.

```lua
local fs = require "filesystem"
fs.walk("src", function(path)
    print(path.full_path)
end, true)
```
]]),
                    entry("filesystem.tree", "fs.tree(path [, dir_first])", "function",
                        "Return all paths in a directory tree.",
                        [[
Return every path in a directory tree as an array, including the starting directory.

The order matches `fs.walk`: children before their directory by default, or directories first when `dir_first` is true. The starting path must exist.

```lua
local fs = require "filesystem"
local paths = fs.tree("src", true)
print(#paths)
```
]]),
                    entry("filesystem.tree_size", "fs.tree_size(path)", "function",
                        "Return the total size of files in a tree.",
                        [[
Return the combined size in bytes of all regular files below `path`. Directories and symbolic links do not add to the total.

The starting path is included in the walk, so a regular file passed directly contributes its own size. Errors follow the module's error-handling mode.
]]),
                    entry("filesystem.tree_size_hr", "fs.tree_size_hr(path)", "function",
                        "Return a human-readable tree size.",
                        [[
Return the total size of a directory tree formatted by `fs.size_to_hr`, for example `"12.40 KB"`.

This is a convenience wrapper around `fs.tree_size(path)`; it uses the same walk and error behavior.
]]),
                    entry("filesystem.stream", "fs.stream(path)", "function",
                        "Create a stream over directory entries.",
                        [[
Create a `stream` over the directory entries returned by `fs.list(path)`.

The stream yields path objects in native directory order. It does not recurse; use `fs.stream_tree` for a recursive stream.

```lua
local fs = require "filesystem"
local names = fs.path("src"):stream():map(function(p) return p.name end):toarray()
```
]]),
                    entry("filesystem.stream_tree", "fs.stream_tree(path [, dir_first])", "function",
                        "Create a stream over a directory tree.",
                        [[
Create a `stream` over all paths returned by `fs.tree(path, dir_first)`.

`dir_first` controls whether directories are yielded before their children, matching the corresponding `fs.walk` option. The stream includes the starting path.

```lua
local fs = require "filesystem"
local count = fs.stream_tree("src"):filter(function(p) return p:is_file() end):count()
```
]]),
                    entry("filesystem.read_all", "fs.read_all(path)", "function",
                        "Read an entire file as a string.",
                        [[
Read an entire file as a string and return it. The file is opened in text mode and closed before returning.

On failure the function follows the module's error-handling mode and returns `nil, message` by default. The path may be a string or a path object.

```lua
local text = require("filesystem").read_all("src/version")
```
]]),
                    entry("filesystem.read_lines", "fs.read_lines(path [, mode])", "function",
                        "Read a file into an array of lines.",
                        [[
Read a file into an array of lines. `mode` is passed to the underlying `file:lines` call and defaults to `"l"` (line without the terminator). Use `"L"` to keep newline characters.

On failure the function returns `nil, message` by default, or raises in raise mode.

```lua
local lines = require("filesystem").read_lines("src/version")
print(lines[1])
```
]]),
                    entry("filesystem.lines", "fs.lines(path [, mode])", "function",
                        "Iterate the lines of a file.",
                        [[
Iterate the lines of a file, yielding a 1-based index and the line text.

The optional `mode` is passed to `file:read` and defaults to `"l"` (line without its terminator); use `"L"` to keep newline characters. The file is closed automatically when the loop finishes. An open failure follows the module's error-handling mode.

```lua
local fs = require "filesystem"
for i, line in fs.lines("src/version") do
    print(i, line)
end
```
]]),
                    entry("filesystem.parent", "fs.parent(path)", "function",
                        "Return the parent path.",
                        [[
Return the parent directory of `path` as a path object, or `nil` when there is no parent.

Trailing separators are ignored. A root or drive root has no parent. A relative single-component path such as `"file"` resolves to the current directory because `fs.path(".")` is used as its parent.

```lua
local fs = require "filesystem"
print(fs.path("src/main.lua"):parent().full_path) --> "src"
```
]]),
                    entry("filesystem.child", "fs.child(path, name)", "function",
                        "Return a child path.",
                        [[
Return a new path object formed by joining `path` and `name`. No existence check is performed.

`name` must be a non-empty string; otherwise the function raises an error. The result is normalized by `fs.path`.

```lua
local fs = require "filesystem"
print(fs.path("src"):child("version").full_path) --> "src/version"
```
]]),
                    entry("filesystem.sibling", "fs.sibling(path, name)", "function",
                        "Return a sibling path.",
                        [[
Return a path in the same directory as `path` but with `name` as its final component. No existence check is performed.

A missing or empty name raises an error. For a path without a separator, the result is simply `fs.path(name)`.

```lua
local fs = require "filesystem"
print(fs.path("src/version"):sibling("main.lua").full_path)
```
]]),
                    entry("filesystem.to_relative", "fs.to_relative(path, base [, include_top])", "function",
                        "Return a path relative to a base path.",
                        [[
Return `path` expressed relative to `base`. Relative inputs are first resolved to absolute paths, so they must exist.

When `include_top` is true, the parent of `base` is used as the anchor, so `base` itself appears in the result. A trailing `/` is added when the result names a directory. If `path` is not below the anchor, its normalized full path is returned unchanged.

```lua
local fs = require "filesystem"
print(fs.to_relative("test/temp", "test")) --> "temp/"
```
]]),
                    entry("filesystem.is_empty", "fs.is_empty(path)", "function",
                        "Return true when a directory has no entries.",
                        [[
Return true when the directory named by `path` contains no entries. The path is converted with `fs.ensure_path` first.

The directory must exist and be readable. A failed listing raises a Lua error even in the default return-error mode, because the failure value is not a directory listing.
]]),
                    entry("filesystem.chmod", "fs.chmod(path, mode)", "function",
                        "Change file permissions on Linux.",
                        [[
Change a path's permissions on Linux using an octal mode string such as `"755"` or `"644"`.

The path may be a string or a path object. Returns true when the `chmod` command succeeds. It returns false on non-Linux systems, when the mode contains anything other than octal digits, or when the command fails. The function never raises.

```lua
local fs = require "filesystem"
assert(fs.chmod("script.sh", "755"))
```
]]),
                    entry("filesystem.chown", "fs.chown(path, owner)", "function",
                        "Change file ownership on Linux.",
                        [[
Change the owner of a file or directory on Linux using the system `chown` command.

`owner` is a string such as `"user"`, `"user:group"` or `"1000:1000"`; only letters, digits, `_`, `.`, `:`, and `-` are accepted. Returns true on success and false on non-Linux systems, invalid input, or command failure. It never raises.
]]),
                    entry("filesystem.size_to_hr", "fs.size_to_hr(bytes)", "function",
                        "Format a byte count as a human-readable size.",
                        [[
Format a byte count as a human-readable string using binary units (`KB`, `MB`, `GB`, `TB`).

Values below 1024 are returned as an integer followed by `" B"`; larger values use two decimal places. The argument must be an integer, otherwise an argument error is raised.

```lua
local fs = require "filesystem"
print(fs.size_to_hr(2048)) --> "2.00 KB"
```
]]),
                    entry("filesystem.config", "fs:config(options)", "method",
                        "Configure a loaded filesystem module.",
                        "Accepts `{ error_handling = \"return\" | \"raise\" }` and returns the same module table."),

                    entry("filesystem.path:exists", "path:exists()", "method",
                        "Return true when the path exists.",
                        [[
Return true when the path names an existing file or directory, and false otherwise.

The check is a direct open attempt, so permission failures and broken symbolic links also produce false. It does not raise for a missing path.
]]),
                    entry("filesystem.path:is_file", "path:is_file()", "method",
                        "Return true for a regular file.",
                        [[
Return true when the path currently refers to a regular file.

The path is examined with a stat call; missing paths and other filesystem errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:is_directory", "path:is_directory()", "method",
                        "Return true for a directory.",
                        [[
Return true when the path currently refers to a directory.

The path is examined with a stat call; missing paths and other filesystem errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:size", "path:size()", "method",
                        "Return the file size in bytes.",
                        [[
Return the size of the file or directory in bytes as an integer.

The value comes from the platform stat call. A missing path or stat failure follows the module's error-handling mode.
]]),
                    entry("filesystem.path:size_hr", "path:size_hr()", "method",
                        "Return a human-readable size.",
                        [[
Return the size of the path formatted with binary units, such as `"4.20 MB"`.

This combines `path:size()` with `fs.size_to_hr`; stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:stat", "path:stat()", "method",
                        "Return file metadata.",
                        [[
Return a table of metadata for the path. The table always contains `is_file`, `is_directory`, `size`, `size_hr`, `create_time`, `create_time_ms`, `create_time_stamp`, `modify_time`, `modify_time_ms`, `modify_time_stamp`, `mode` and `mode_flags`.

When the platform reports an access time, `access_time`, `access_time_ms` and `access_time_stamp` are also present. The `create_time` fields reflect the platform's creation/change timestamp and may have platform-specific semantics. A stat failure follows the module's error-handling mode.

```lua
local st = require("filesystem").path("src/version"):stat()
print(st.size, st.mode_flags)
```
]]),
                    entry("filesystem.path:access_time", "path:access_time()", "method",
                        "Return the last access time.",
                        [[
Return the last access time as a Unix timestamp in seconds, or `nil` when the platform does not report it.

Stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:create_time", "path:create_time()", "method",
                        "Return the creation time.",
                        [[
Return the platform's creation/change time as a Unix timestamp in seconds.

On POSIX systems this is usually the inode change time (`ctime`), not the original creation time. Stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:modify_time", "path:modify_time()", "method",
                        "Return the last modification time.",
                        [[
Return the last modification time as a Unix timestamp in seconds.

Stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:access_time_ms", "path:access_time_ms()", "method",
                        "Return access time in milliseconds.",
                        [[
Return the last access time as a Unix timestamp in milliseconds, or `nil` when the platform does not expose an access time.

Stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:create_time_ms", "path:create_time_ms()", "method",
                        "Return creation time in milliseconds.",
                        [[
Return the platform's creation/change time in milliseconds since the Unix epoch.

This is the millisecond form of `path:create_time()`; stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:modify_time_ms", "path:modify_time_ms()", "method",
                        "Return modification time in milliseconds.",
                        [[
Return the last modification time in milliseconds since the Unix epoch.

This is the millisecond form of `path:modify_time()`; stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:access_time_stamp", "path:access_time_stamp()", "method",
                        "Return a formatted access timestamp.",
                        [[
Return the last access time formatted as `YYYY/MM/DD HH:MM:SS` in local time, or `nil` when no access time is available.

Stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:create_time_stamp", "path:create_time_stamp()", "method",
                        "Return a formatted creation timestamp.",
                        [[
Return the platform's creation/change time formatted as `YYYY/MM/DD HH:MM:SS` in local time.

This is the formatted form of `path:create_time()`; stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:modify_time_stamp", "path:modify_time_stamp()", "method",
                        "Return a formatted modification timestamp.",
                        [[
Return the last modification time formatted as `YYYY/MM/DD HH:MM:SS` in local time.

This is the formatted form of `path:modify_time()`; stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:mode", "path:mode()", "method",
                        "Return the file mode.",
                        [[
Return the file permission bits as an integer, directly from the platform stat call.

Use `path:mode_flags()` for a readable `drwxr-xr-x`-style string. Stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:mode_flags", "path:mode_flags()", "method",
                        "Return the file mode flags.",
                        [[
Return the file type and permissions as a POSIX-style 10-character string, for example `"-rw-r--r--"` or `"drwxr-xr-x"`.

On Windows the permission bits are reported as all enabled. Stat errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:open", "path:open([mode])", "method",
                        "Open the file and return a file handle.",
                        [[
Open the path with `io.open` and return a Lua file handle plus the usual second result from `io.open`.

`mode` defaults to `"r"`. A missing file or permission failure therefore returns `nil, message` exactly as `io.open` does.

```lua
local p = require("filesystem").path("src/version")
local f = assert(p:open("r"))
print(f:read("a"))
f:close()
```
]]),
                    entry("filesystem.path:rename", "path:rename(new_path) / path:mv(new_path)", "method",
                        "Rename or move the path.",
                        [[
Rename or move the path to `new_path`. The aliases `path:mv` and `fs`-style names refer to the same operation.

The destination may be a string or a path object. On success there is no return value; errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:delete", "path:delete() / path:rm()", "method",
                        "Delete the file or empty directory.",
                        [[
Delete the file or empty directory named by the path. Non-empty directories are not removed recursively; use `path:delete_tree()` for that.

The aliases `path:rm` and `path:delete` are equivalent. Errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:change_directory", "path:change_directory() / path:cd()", "method",
                        "Change the current directory to this path.",
                        [[
Change the process working directory to this path. The aliases `path:cd` and `path:change_directory` are equivalent.

The path must be an existing directory. Errors follow the module's error-handling mode; on success there is no return value.
]]),
                    entry("filesystem.path:create_directory", "path:create_directory() / path:mkdir()", "method",
                        "Create the directory.",
                        [[
Create this directory as a single filesystem operation. Missing parents are not created and an existing directory is an error; use `fs.create_tree` for recursive creation.

The aliases `path:mkdir` and `path:create_directory` are equivalent. Errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:read_all", "path:read_all()", "method",
                        "Read the file as a string.",
                        [[
Read the file named by the path as a string.

This is the method form of `fs.read_all`; open and read errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:read_lines", "path:read_lines([mode])", "method",
                        "Read the file into an array of lines.",
                        [[
Read the file named by the path into an array of lines. The optional `mode` is passed to `file:lines` and defaults to `"l"`.

This is the method form of `fs.read_lines`; open and read errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:lines", "path:lines([mode])", "method",
                        "Iterate the lines of the file.",
                        [[
Iterate the lines of the file named by the path, yielding `index, line`.

The optional `mode` defaults to `"l"`; use `"L"` to keep line terminators. The underlying file is closed automatically when iteration finishes. Open errors follow the module's error-handling mode.

```lua
local p = require("filesystem").path("src/version")
for i, line in p:lines() do
    print(i, line)
end
```
]]),
                    entry("filesystem.path:iterate", "path:iterate([sorted])", "method",
                        "Iterate directory entries.",
                        [[
Iterate the directory entries, yielding entry names and path objects. Pass `true` as `sorted` for name order; the default is native directory order.

This is the method form of `fs.iterate`; directory errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:delete_tree", "path:delete_tree()", "method",
                        "Delete the directory tree.",
                        [[
Recursively delete this directory tree, including the directory itself.

This is the method form of `fs.delete_tree`; deletion errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:walk", "path:walk(func [, dir_first])", "method",
                        "Walk the directory tree.",
                        [[
Walk this directory tree, calling `func(path)` for each entry including the starting directory.

`dir_first` controls whether a directory is reported before or after its contents. Symbolic-link cycles are avoided by visiting each real directory once.

```lua
require("filesystem").path("src"):walk(function(p)
    if p:is_file() then print(p.full_path) end
end)
```
]]),
                    entry("filesystem.path:parent", "path:parent()", "method",
                        "Return the parent path.",
                        [[
Return the parent directory as a path object, or `nil` at a filesystem root.

This is the method form of `fs.parent`; trailing separators are ignored and relative single-component paths resolve against the current directory.
]]),
                    entry("filesystem.path:child", "path:child(name)", "method",
                        "Return a child path.",
                        [[
Return a new path object formed by appending `name` to this path.

`name` must be a non-empty string. The result is normalized; no existence check is made.
]]),
                    entry("filesystem.path:sibling", "path:sibling(name)", "method",
                        "Return a sibling path.",
                        [[
Return a path in the same directory with `name` as its final component.

A missing or empty name raises an error. No existence check is performed.
]]),
                    entry("filesystem.path:stream", "path:stream()", "method",
                        "Create a stream over directory entries.",
                        [[
Create a `stream` over this directory's entries.

The stream yields path objects from `fs.list`; it does not recurse. Directory errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:stream_tree", "path:stream_tree([dir_first])", "method",
                        "Create a stream over the tree.",
                        [[
Create a `stream` over this directory tree, including the starting path.

`dir_first` controls whether directories are yielded before their contents. The stream is built from `fs.tree`.

```lua
local files = require("filesystem").path("src"):stream_tree():filter(function(p)
    return p:is_file()
end):count()
```
]]),
                    entry("filesystem.path:tree", "path:tree([dir_first])", "method",
                        "Return the tree as an array of paths.",
                        [[
Return every path in this directory tree as an array, including the starting directory.

`dir_first` controls the order. The path must exist; otherwise errors follow the module's error-handling mode.
]]),
                    entry("filesystem.path:to_relative", "path:to_relative(base [, include_top])", "method",
                        "Return a relative path.",
                        [[
Return this path expressed relative to `base`, optionally including `base` itself when `include_top` is true.

Both paths are resolved to absolute paths first, so relative inputs must exist. A trailing `/` is added for directories. If the path is not below the anchor, its normalized full path is returned.

```lua
local fs = require "filesystem"
print(fs.path("test/temp"):to_relative("test")) --> "temp/"
```
]]),
                    entry("filesystem.path:chmod", "path:chmod(mode)", "method",
                        "Change permissions.",
                        [[
Change this path's permissions on Linux using an octal mode string such as `"755"` or `"644"`.

Returns true on success and false on non-Linux systems, invalid modes, or command failure. It never raises.

```lua
local p = require("filesystem").path("script.sh")
p:chmod("755")
```
]]),
                    entry("filesystem.path:chown", "path:chown(owner)", "method",
                        "Change ownership.",
                        [[
Change this path's owner on Linux. `owner` is a user name, `user:group` pair, or numeric uid/gid pair.

Returns true on success and false on non-Linux systems, invalid input, or command failure. It never raises.
]]),
                }, { aliases = { "fs" } }),

                module("grid", "grid", "Line-drawing text grids (tables).", [==[
`grid.new(config [, rows])` creates a text table.  `config` is an array of column
definitions: `{ name, align, min_width, max_width, fixed_width }`.  The table
configuration may also set `show_header` and `padding`.
]==], {
                    entry("grid.new", "grid.new(config [, rows])", "function",
                        "Create a grid.",
                        [[
Create a new grid from an array of column definitions.

Each column may set `name`, `align`, `min_width`, `max_width` and `fixed_width`; defaults are left alignment, minimum width 1 and maximum width 30. The optional configuration table may also set `show_header` (default true) and `padding` (default true). An optional `rows` array is added immediately. Both `grid.new(config)` and `grid:new(config)` are supported.

```lua
local grid = require "grid"
local g = grid.new({
    { name = "name" },
    { name = "size", align = "right", min_width = 4 },
})
g:add_row("version", 7)
print(g:tostring())
```
]]),
                    entry("grid:add_row", "grid:add_row(...) / grid:add_row(table)", "method",
                        "Add a row of values.",
                        [[
Add a row of values to the grid.

Values may be passed as separate arguments or as one array table. Each value is converted with `tostring`, and column widths grow to fit the content up to each column's `max_width`. The row is stored for later rendering; the method returns nothing.

```lua
local g = require("grid").new { { name = "item" }, { name = "qty" } }
g:add_row("apple", 3)
```
]]),
                    entry("grid:add_rows", "grid:add_rows(rows)", "method",
                        "Add multiple rows.",
                        [[
Add multiple rows to the grid.

`rows` must be an array of rows, where each row is itself an array of cell values (or a single table passed to `add_row`). Each row is added with `grid:add_row`; the method returns nothing.
]]),
                    entry("grid:header_string", "grid:header_string()", "method",
                        "Return the header lines.",
                        [[
Return the rendered header block as a string.

The block contains the top border and, when `show_header` is enabled, the header row. If the grid has no rows yet, this also initializes the column widths used by later row rendering.
]]),
                    entry("grid:row_string", "grid:row_string(...)", "method",
                        "Return one rendered row.",
                        [[
Return one rendered row as a string, including the separator border.

The values are formatted but not stored in the grid. If this is the first rendering call, the header block is included before the border and the row.

```lua
print(g:row_string("banana", 5))
```
]]),
                    entry("grid:last_string", "grid:last_string()", "method",
                        "Return the bottom border.",
                        [[
Return the bottom border of the grid as a string.

Column widths are calculated first if they have not been initialized. This is the same border printed by `grid:print_last` and appended by `grid:tostring`.
]]),
                    entry("grid:print_header", "grid:print_header()", "method",
                        "Print the header.",
                        [[
Print the header block returned by `grid:header_string`.

The output includes the top border and, when configured, the header row.
]]),
                    entry("grid:print_row", "grid:print_row(...)", "method",
                        "Print one row.",
                        [[
Print one rendered row returned by `grid:row_string`.

The values are formatted for display but are not added to the grid's stored rows.
]]),
                    entry("grid:print_last", "grid:print_last()", "method",
                        "Print the bottom border.",
                        [[
Print the bottom border of the grid.

This is equivalent to `print(grid:last_string())`; the return value is that of `print`.
]]),
                    entry("grid:tostring", "grid:tostring()", "method",
                        "Render the complete table as a string.",
                        [[
Render the complete grid as a string.

The result includes the top border, optional header row, all stored rows with separator borders, and the bottom border. The grid's `__tostring` metamethod calls this method, so `tostring(grid)` works too.

```lua
local g = require("grid").new { { name = "name" } }
g:add_row("value")
print(g:tostring())
```
]]),
                }),

                module("httpclient", "httpclient", "HTTP client based on Zig's HTTP client.", [==[
Every request function returns `response, body`.  `response` contains the status
line, headers and convenience fields.  On transport failure the functions return
`nil, message` unless `options.raiseError` is set.

Options include `header`, `query`, `parseJson`, `basicAuth`, `save` and
`raiseError`.  A table body is encoded as JSON automatically.
]==], {
                    entry("httpclient.get", "httpclient.get(url [, options [, body]])", "function", "Perform a GET request."),
                    entry("httpclient.head", "httpclient.head(url [, options [, body]])", "function", "Perform a HEAD request."),
                    entry("httpclient.post", "httpclient.post(url [, options [, body]])", "function", "Perform a POST request."),
                    entry("httpclient.put", "httpclient.put(url [, options [, body]])", "function", "Perform a PUT request."),
                    entry("httpclient.patch", "httpclient.patch(url [, options [, body]])", "function", "Perform a PATCH request."),
                    entry("httpclient.delete", "httpclient.delete(url [, options [, body]])", "function", "Perform a DELETE request."),
                    entry("httpclient.call", "httpclient.call(method, url [, options [, body]])", "function", "Perform a request with an explicit method."),
                    entry("httpclient.config", "httpclient:config(options)", "method", "Configure a loaded httpclient module."),
                }),

                module("httpserver", "httpserver", "HTTP server based on Zig's HTTP server.", [==[
`httpserver.serve(options)` starts a server.  Options include `address`, `port`,
`web_root`, `cache_web_root`, method route tables (`GET`, `POST`, ...) and a
`*` route table used for every method.

A route value may be a response string or a function `(options, request)`
returning a string, a response table, or a table that is encoded as JSON.
Request tables contain `method`, `target`, `version`, `header`, `body` and
other request metadata.  Responses use `{ status, body, header }`.
]==], {
                    entry("httpserver.serve", "httpserver.serve(options)", "function", "Start an HTTP server."),
                    entry("httpserver.config", "httpserver:config(options)", "method", "Configure a loaded httpserver module."),
                    entry("httpserver.serve_file", "httpserver.serve_file(path)", "function", "Serve a file from disk."),
                    entry("httpserver.resolve_web_path", "httpserver.resolve_web_path(root, target)", "function", "Resolve a URL path inside a web root."),
                    entry("httpserver.content_type", "httpserver.content_type(filename)", "function", "Look up a MIME type by file extension."),
                    entry("httpserver.cache", "httpserver.cache(func [, time])", "function", "Cache a route handler's result."),
                    entry("httpserver.status", "httpserver.status", "field", "HTTP status code table."),
                    entry("httpserver.cache_free_cycle", "httpserver.cache_free_cycle([seconds])", "function", "Set the cache expiry cycle."),
                    entry("httpserver.free_cache", "httpserver.free_cache([cycle])", "function", "Free expired cache entries."),
                    entry("httpserver.clear_cache", "httpserver.clear_cache()", "function", "Clear the content cache."),
                }),

                module("log", "log", "Simple logging library.", [==[
`require "log"` returns the root logger.  Named child loggers are created by
indexing the root logger.  The root logger writes to stdout by default.

Levels: `OFF`, `FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`.

```lua
local log = require "log"
log:info("hello")
log:setLevel(log.level.DEBUG)
log:addAppender(log.appender.file("/tmp/app.log"))
local child = log["worker"]
child:warn("from a named logger")
```
]==], {
                    entry("log:fatal", "log:fatal(message)", "method", "Log a fatal message."),
                    entry("log:error", "log:error(message)", "method", "Log an error message."),
                    entry("log:warn", "log:warn(message)", "method", "Log a warning."),
                    entry("log:info", "log:info(message)", "method", "Log an informational message."),
                    entry("log:debug", "log:debug(message)", "method", "Log a debug message."),
                    entry("log:trace", "log:trace(message)", "method", "Log a trace message."),
                    entry("log:setLevel", "log:setLevel(level)", "method", "Set the logger level."),
                    entry("log:setAppender", "log:setAppender(appender)", "method", "Replace the logger appender."),
                    entry("log:addAppender", "log:addAppender(appender)", "method", "Add an appender."),
                    entry("log.level", "log.level", "field", "Logger level constants."),
                    entry("log.appender", "log.appender", "field", "Built-in appenders: `stdout`, `file`, `none`."),
                }, { aliases = { "logger" } }),

                module("luastrip", "luastrip", "Lua source stripper/compactor.", [==[
`luastrip` removes comments and unnecessary whitespace while preserving Lua
semantics.  Malformed or unterminated input is handled without aborting the
interpreter.
]==], {
                    entry("luastrip.string", "luastrip.string(source)", "function",
                        "Strip a Lua source string.",
                        [[
Remove comments and unnecessary whitespace from a Lua source string and return the compacted source.

The stripper preserves token boundaries and string literals. Malformed or unterminated input is handled without crashing the interpreter; the function may return a partially stripped string or an error according to the module's error-handling mode.

```lua
local luastrip = require "luastrip"
print(luastrip.string("local a = 1 -- note")) --> "local a=1"
```
]]),
                    entry("luastrip.file", "luastrip.file(input, output)", "function",
                        "Strip a Lua source file into another file.",
                        [[
Read a Lua source file, strip comments and unnecessary whitespace, and write the result to another file.

Returns `true` on success. `input` and `output` may be path objects or strings. I/O and stripping errors follow the module's error-handling mode (`nil, message` by default, or a raised error in raise mode).
]]),
                    entry("luastrip.config", "luastrip:config(options)", "method",
                        "Configure a loaded luastrip module.",
                        [[
Configure a loaded `luastrip` module and return it.

The options table accepts `error_handling = "return"` or `"raise"`. The setting controls whether `luastrip.string` and `luastrip.file` return errors or raise them.

```lua
local luastrip = require("luastrip"):config { error_handling = "raise" }
```
]]),
                }),

                module("memoize", "memoize", "Function result memoization.", [==[
`memoize(func)` returns a wrapper that caches results.  Cache keys are the
arguments; cached values are held weakly.
]==], {
                }),

                module("stream", "stream", "Functional-style streams inspired by Java streams.", [==[
`stream(iterator)` wraps an iterator, table or function.  Most operations return a
new stream; terminal operations consume it.

Named functions can be passed as strings when a function has been registered with
the `lambda` helper.
]==], {
                    entry("stream.stream", "stream(iterator)", "function",
                        "Create a stream from an iterator, table or function.",
                        [[
Create a stream from an iterator, an array-like table, or a Lua iterator function.

A table containing a `next` field is treated as an existing stream and wrapped directly; any other table is iterated over its array part with `table.next`. A function may be passed with its state and control values as additional arguments. A non-function, non-table value becomes a one-element stream.

```lua
local stream = require "stream"
print(stream({ 1, 2, 3 }):sum()) --> 6
for n in stream(ipairs { "a", "b" }) do print(n) end
```
]]),
                    entry("stream.of", "stream():of(...)", "method",
                        "Create a stream from values.",
                        [[
Create a stream over the values passed as arguments. The method is available on a stream instance, so the usual form is `stream():of(...)`.

The values are stored in an array and iterated in order. This is a convenient alternative to writing `stream { ... }`.

```lua
local stream = require "stream"
print(stream():of(1, 2, 3):concat(",")) --> "1,2,3"
```
]]),
                    entry("stream:map", "stream:map(func)", "method",
                        "Transform each value.",
                        [[
Return a lazy stream that applies `func` to every value.

The function may be a Lua function or a string accepted by the `lambda` helper. `false` results are treated as ordinary values, not as end-of-stream. The source stream is consumed as the mapped stream is consumed.

```lua
stream({ 1, 2, 3 }):map(function(n) return n * 2 end):toarray() --> { 2, 4, 6 }
```
]]),
                    entry("stream:peek", "stream:peek(func)", "method",
                        "Inspect each value without changing it.",
                        [[
Return a lazy stream that calls `func(value)` for each value and passes the original value through unchanged.

This is intended for debugging or side effects. `func` may be a function or a registered lambda string.
]]),
                    entry("stream:filter", "stream:filter(func)", "method",
                        "Keep values accepted by `func`.",
                        [[
Return a lazy stream containing only values for which `func(value)` is truthy.

The stream pulls values from its source until it finds a match, so filters can be chained efficiently. `false` and `nil` are rejected; other values are kept.

```lua
stream({ 1, 2, 3, 4 }):filter(function(n) return n % 2 == 0 end):toarray() --> { 2, 4 }
```
]]),
                    entry("stream:skip", "stream:skip(count)", "method",
                        "Skip the first `count` values.",
                        [[
Skip the first `count` values and return the same stream, now positioned after them.

This operation is eager: it consumes the skipped values immediately. Negative counts behave like zero.

```lua
stream({ 1, 2, 3, 4 }):skip(2):toarray() --> { 3, 4 }
```
]]),
                    entry("stream:limit", "stream:limit(count)", "method",
                        "Limit the stream to `count` values.",
                        [[
Return a stream that yields at most `count` values from the source.

The limit is applied lazily and the source is not advanced beyond the requested values until another value is requested. A count of zero produces an empty stream.
]]),
                    entry("stream:reverse", "stream:reverse()", "method",
                        "Reverse the remaining values.",
                        [[
Consume the remaining values and return a new stream that yields them in reverse order.

The entire source is read into memory first, so this cannot be used on an infinite stream. The original stream is exhausted by the call.
]]),
                    entry("stream:sort", "stream:sort([comparator])", "method",
                        "Sort the remaining values.",
                        [[
Consume the remaining values and return a new stream sorted by the optional comparator.

The default comparator is `a < b`. Sorting requires reading the whole source into memory, so the original stream is exhausted.

```lua
stream({ 3, 1, 2 }):sort():toarray() --> { 1, 2, 3 }
```
]]),
                    entry("stream:maptonumber", "stream:maptonumber()", "method",
                        "Convert each value to a number.",
                        [[
Return a lazy stream that converts each value with `tonumber`.

Values that cannot be converted become `nil`; because `nil` also marks the end of a stream, a failed conversion effectively terminates that stream.
]]),
                    entry("stream:distinct", "stream:distinct()", "method",
                        "Drop duplicate values.",
                        [[
Return a lazy stream that drops duplicate values, keeping the first occurrence of each.

Duplicate detection uses the value itself as a table key, so values must be usable as Lua table keys. Encounter order is preserved.
]]),
                    entry("stream:split", "stream:split(func)", "method",
                        "Split into matching and non-matching streams.",
                        [[
Split the stream into two lazy streams according to a predicate.

The first stream yields values for which `func(value)` is truthy; the second yields the remaining values. Both streams share the same source, so consuming one advances the other. Pull values from both in parallel for predictable results.

```lua
local odd, even = stream({ 1, 2, 3, 4 }):split(function(n) return n % 2 == 1 end)
print(odd:concat(","))  --> "1,3"
print(even:concat(",")) --> "2,4"
```
]]),
                    entry("stream:join", "stream:join(...)", "method",
                        "Concatenate streams.",
                        [[
Return a lazy stream that concatenates this stream with the given streams.

The extra arguments must be stream objects. Each stream is consumed in turn. This is useful for chaining the two results of `split` back together.

```lua
local a, b = stream({ 1, 2 }):split(function(n) return n == 1 end)
print(a:join(b):concat(",")) --> "1,2"
```
]]),
                    entry("stream:foreach", "stream:foreach(func)", "method",
                        "Consume the stream, calling `func` for each value.",
                        [[
Consume the stream, calling `func(value)` for every value.

This is a terminal operation: the source is exhausted. It returns nothing. `func` may be a function or a registered lambda string.
]]),
                    entry("stream:toarray", "stream:toarray()", "method",
                        "Consume the stream into an array.",
                        [[
Consume the stream and return its values as a new array in encounter order.

This is a terminal operation. `false` values are retained; only `nil` ends the stream.
]]),
                    entry("stream:tosortedarray", "stream:tosortedarray([comparator])", "method",
                        "Consume into a sorted array.",
                        [[
Consume the stream into an array and sort it with the optional comparator.

The default comparator is `a < b`. This is a terminal operation, and the entire stream is read into memory.

```lua
stream({ "b", "a" }):tosortedarray() --> { "a", "b" }
```
]]),
                    entry("stream:print", "stream:print()", "method",
                        "Print each value.",
                        [[
Consume the stream, printing each value with `print`.

This is a terminal operation intended for quick inspection. Like `toarray`, it exhausts the source.
]]),
                    entry("stream:concat", "stream:concat([separator])", "method",
                        "Join values into a string.",
                        [[
Consume the stream and join its values into a string.

`separator` is passed to `table.concat` and defaults to an empty string. Non-string values must be convertible by `table.concat`.

```lua
stream({ 1, 2, 3 }):concat("-") --> "1-2-3"
```
]]),
                    entry("stream:allmatch", "stream:allmatch(func)", "method",
                        "Return true when every value matches.",
                        [[
Return true when every value in the stream satisfies `func`, and false as soon as one does not.

An empty stream returns true. This is a terminal operation, but it stops early on the first non-match.
]]),
                    entry("stream:firstmatch", "stream:firstmatch(func)", "method",
                        "Return the first matching value.",
                        [[
Return the first value for which `func(value)` is truthy, or `nil` when none matches.

Matching stops at the first hit. This is a terminal operation and leaves earlier values consumed.
]]),
                    entry("stream:nonmatch", "stream:nonmatch(func)", "method",
                        "Return true when no value matches.",
                        [[
Return true when no value in the stream satisfies `func`.

This is the negation of `stream:anymatch`; it stops at the first match. An empty stream returns true.
]]),
                    entry("stream:anymatch", "stream:anymatch(func)", "method",
                        "Return true when any value matches.",
                        [[
Return true when at least one value in the stream satisfies `func`, and false otherwise.

Evaluation stops at the first match. This is a terminal operation.
]]),
                    entry("stream:first", "stream:first()", "method",
                        "Return the first value.",
                        [[
Return the first value of the stream, or `nil` when the stream is empty.

This consumes one value, plus any values skipped by earlier lazy stages.
]]),
                    entry("stream:last", "stream:last()", "method",
                        "Return the last value.",
                        [[
Consume the stream and return its final value, or `nil` when it is empty.

The entire source is read to find the last value.
]]),
                    entry("stream:count", "stream:count()", "method",
                        "Count the remaining values.",
                        [[
Consume the stream and return the number of remaining values.

This is implemented as a reduction and reads the whole source.
]]),
                    entry("stream:sum", "stream:sum()", "method",
                        "Sum numeric values.",
                        [[
Consume the stream and return the sum of its numeric values.

An empty stream produces `0`. Non-numeric values cause an arithmetic error.
]]),
                    entry("stream:average", "stream:average()", "method",
                        "Average numeric values.",
                        [[
Consume the stream and return the arithmetic mean of its numeric values.

An empty stream returns `0`; otherwise the result is the sum divided by the count.
]]),
                    entry("stream:median", "stream:median()", "method",
                        "Median numeric value.",
                        [[
Consume the stream and return its median after sorting the values.

For an even number of values the two middle values are averaged. An empty stream returns `0`. The optional argument is accepted for compatibility but is not used.
]]),
                    entry("stream:iterator", "stream:iterator()", "method",
                        "Return the underlying iterator.",
                        [[
Return the underlying iterator function for this stream.

The iterator yields one value per call and returns `nil` when exhausted. Passing it to `stream` wraps the remaining values in a new stream object.
]]),
                    entry("stream:collector", "stream:collector(func)", "method",
                        "Apply a collector function.",
                        [[
Call a collector function with the stream's iterator and return the collector's result.

`func` receives the underlying `next` function and can consume it in any way. A string lambda may also be supplied. This is a terminal operation if the collector consumes the iterator.
]]),
                    entry("stream:reduce", "stream:reduce(state, func)", "method",
                        "Fold the stream into a value.",
                        [[
Fold the remaining values into an accumulator and return the final state.

`func(state, value)` is called for every value, starting with `state`. The function may be a function or a registered lambda string. An empty stream returns the initial state unchanged.

```lua
stream({ 1, 2, 3 }):reduce(0, function(sum, n) return sum + n end) --> 6
```
]]),
                    entry("stream:min", "stream:min([comparator])", "method",
                        "Return the minimum value.",
                        [[
Consume the stream and return its minimum value using the optional comparator.

The default comparator is `a < b`. An empty stream returns `nil`.

```lua
stream({ 4, 1, 3 }):min() --> 1
```
]]),
                    entry("stream:max", "stream:max([comparator])", "method",
                        "Return the maximum value.",
                        [[
Consume the stream and return its maximum value using the optional comparator.

The default comparator is `a < b`. An empty stream returns `nil`.

```lua
stream({ 4, 1, 3 }):max() --> 4
```
]]),
                    entry("stream:groupby", "stream:groupby(func)", "method",
                        "Group values by a key function.",
                        [[
Consume the stream and group values into a plain table keyed by `func(value)`.

Each key maps to an array of the values that produced it. The function may be a function or a registered lambda string. This is a terminal operation.

```lua
local groups = stream({ "ant", "ape", "bee" }):groupby(function(s) return s:sub(1, 1) end)
print(#groups.a) --> 2
```
]]),
                }),

                module("tar", "tar", "Read and write tar archives.", [==[
The tar module supports uncompressed tar plus gzip, xz and zstd-compressed tar
files when the corresponding support is available.

`tar.open(filename)` returns a reader.  `tar.create(filename)` returns a writer.
`tar.extract(archive, destination)` extracts an archive.
]==], {
                    entry("tar.open", "tar.open(filename)", "function", "Open a tar archive for reading.", "Returns an iterator function.  Iterate with `for entry in tar.open(path) do ... end`."),
                    entry("tar.create", "tar.create(filename)", "function", "Create a tar archive for writing."),
                    entry("tar.extract", "tar.extract(filename, destination)", "function", "Extract an entire archive into a directory.", "The archive may be plain tar or compressed with gzip, xz or zstd."),
                    entry("tar.config", "tar:config(options)", "method", "Configure a loaded tar module."),
                    entry("tar.writer:setRoot", "writer:setRoot(root)", "method", "Set the root directory written into the archive."),
                    entry("tar.writer:add_dir", "writer:add_dir(path)", "method", "Add a directory entry."),
                    entry("tar.writer:add_file", "writer:add_file(path [, archive_path])", "method", "Add a file."),
                    entry("tar.writer:add_file_bytes", "writer:add_file_bytes(path, data)", "method", "Add a file from memory."),
                    entry("tar.writer:add_link", "writer:add_link(path, target)", "method", "Add a symbolic link."),
                    entry("tar.writer:close", "writer:close()", "method", "Finish and close the archive."),
                    entry("tar.entry:name", "entry.name", "field", "The path stored in the archive."),
                    entry("tar.entry:type", "entry.type", "field", "The tar entry type (`file`, `directory`, `sym_link`, ...)."),
                    entry("tar.entry:size", "entry.size", "field", "Uncompressed size in bytes."),
                    entry("tar.entry:size_hr", "entry.size_hr", "field", "Human-readable size."),
                    entry("tar.entry:link_name", "entry.link_name", "field", "Symbolic-link target."),
                    entry("tar.entry:mode_flags", "entry.mode_flags", "field", "POSIX mode string."),
                    entry("tar.entry:is_file", "entry.is_file", "field", "True for a regular file."),
                    entry("tar.entry:is_directory", "entry.is_directory", "field", "True for a directory."),
                    entry("tar.entry:is_link", "entry.is_link", "field", "True for a symbolic link."),
                    entry("tar.entry:bytes", "entry:bytes()", "method", "Read the current regular file into a string."),
                    entry("tar.entry:extract", "entry:extract(destination)", "method", "Extract the current regular file."),
                }),

                module("timer", "timer", "Nanosecond timer.", [==[
`timer.new([start])` creates a timer and optionally starts it immediately.
Timers use `os.nanotime` and are monotonic.
]==], {
                    entry("timer.new", "timer.new([start])", "function",
                        "Create a timer.",
                        [[
Create a nanosecond-resolution timer backed by the monotonic `os.nanotime` clock.

When `start` is truthy the timer is started immediately; otherwise call `timer:start()` before measuring. The object exposes the timer methods and a `laps` array.

```lua
local timer = require "timer"
local t = timer.new(true)
-- work
print(t:stop())
```
]]),
                    entry("timer:start", "timer:start()", "method",
                        "Start or restart the timer.",
                        [[
Start or restart the timer, using the current monotonic time as the new origin.

Returns the timer object. Existing lap timestamps and the previous stop time are not cleared; call `timer:reset()` for a completely fresh timer.
]]),
                    entry("timer:lap", "timer:lap()", "method",
                        "Record a lap and return the lap time.",
                        [[
Record a lap at the current time and return the duration since the previous lap, or since the start for the first lap.

The timestamp is appended to `timer.laps`. The timer must have been started. Returns a duration in nanoseconds.
]]),
                    entry("timer:stop", "timer:stop()", "method",
                        "Stop the timer and return the elapsed time.",
                        [[
Stop the timer at the current time and return the elapsed duration since it was started.

The stop time is remembered by `timer:time()`. Stopping again updates the stop time and the reported duration.
]]),
                    entry("timer:time", "timer:time()", "method",
                        "Return the last measured time.",
                        [[
Return the last measured `stop - start` duration, or `nil` if the timer has not been stopped.

Starting the timer again does not immediately change this value; it changes when `stop()` is called again.
]]),
                    entry("timer:elapsed", "timer:elapsed()", "method",
                        "Return the time since the timer started.",
                        [[
Return the duration from the start time to now, without stopping the timer.

Returns `nil` when the timer has not been started. The value is in nanoseconds and comes from the monotonic clock.
]]),
                    entry("timer:lap_elapsed", "timer:lap_elapsed()", "method",
                        "Return the time since the last lap.",
                        [[
Return the time elapsed since the most recent lap, or since the start when no lap has been recorded.

The timer is not stopped and no lap is recorded. Calling this before `timer:start()` is an error.
]]),
                    entry("timer:reset", "timer:reset()", "method",
                        "Reset the timer and its laps.",
                        [[
Clear the start time, stop time and all recorded laps.

The timer becomes unstarted, so `timer:time()` and `timer:elapsed()` return `nil` until `start()` is called again. The function does not return the timer.
]]),
                }),

                module("uuid", "uuid", "UUID generation.", [==[
The `uuid` module generates RFC 9562 UUIDs.  `uuid.v4()` generates a random
UUID and `uuid.v7()` a time-ordered UUID.
]==], {
                    entry("uuid.v4", "uuid.v4()", "function",
                        "Generate a version 4 (random) UUID.",
                        [[
Generate a version 4 (random) UUID and return it as a lowercase 36-character string.

The version and variant bits are set according to RFC 9562. Each call uses random data, so values are not ordered.

```lua
local uuid = require "uuid"
print(uuid.v4()) --> "f47ac10b-58cc-4372-a567-0e02b2c3d479" (example)
```
]]),
                    entry("uuid.v7", "uuid.v7()", "function",
                        "Generate a version 7 (time-ordered) UUID.",
                        [[
Generate a version 7 (time-ordered) UUID and return it as a lowercase 36-character string.

The first 48 bits contain a Unix millisecond timestamp, so UUIDs created in the same millisecond share a prefix and later values generally sort after earlier ones. Random bits fill the remainder.

```lua
local uuid = require "uuid"
local id = uuid.v7()
```
]]),
                }),

                module("xlsxmlwriter", "xlsxmlwriter", "Simple Excel XML writer.", [==[
`require "xlsxmlwriter"` returns a constructor.  Calling it with a filename
creates a workbook object.

```lua
local workbook = require("xlsxmlwriter")("book.xml")
workbook:newSheet("Data")
workbook:addRow { "name", 42, { year = 2026, month = 10, day = 23 } }
workbook:close()
```
]==], {
                    entry("xlsxmlwriter:newSheet", "workbook:newSheet([name])", "method",
                        "Start a new worksheet.",
                        [[
Start a new worksheet in the workbook, closing the current worksheet first.

If `name` is omitted, a name such as `"Sheet1"` is generated from the sheet count. The name is XML-escaped. Returns the workbook object so calls can be chained.

```lua
local workbook = require("xlsxmlwriter")("book.xml")
workbook:newSheet("Data")
```
]]),
                    entry("xlsxmlwriter:closeSheet", "workbook:closeSheet()", "method",
                        "Close the current worksheet.",
                        [[
End the current row, if one is open, and close the current worksheet.

If no worksheet is open the call does nothing. Returns the workbook for chaining.
]]),
                    entry("xlsxmlwriter:nextRow", "workbook:nextRow(...)", "method",
                        "Start a new row, optionally with cells.",
                        [[
End any open row and start a new row, optionally filling it with cells.

Additional arguments are passed to `workbook:cells`. The row counter is incremented and the workbook is returned.

```lua
workbook:nextRow("name", "count")
```
]]),
                    entry("xlsxmlwriter:endRow", "workbook:endRow()", "method",
                        "End the current row.",
                        [[
Close the currently open row.

If no row is open the call does nothing. Returns the workbook for chaining.
]]),
                    entry("xlsxmlwriter:addRow", "workbook:addRow(values)", "method",
                        "Add a complete row from a table.",
                        [[
Add a complete row from an array of cell values.

The table is unpacked and passed to `nextRow`, so nested arrays are not flattened and the table must be an array. Returns the workbook.

```lua
workbook:addRow { "alice", 42 }
```
]]),
                    entry("xlsxmlwriter:cells", "workbook:cells(...)", "method",
                        "Append cells to the current row.",
                        [[
Append one or more cell values to the current row, opening a row first if necessary.

Each value is written by `workbook:cell`. Returns the workbook.
]]),
                    entry("xlsxmlwriter:addCells", "workbook:addCells(values)", "method",
                        "Append cells from a table.",
                        [[
Append all values from an array table to the current row.

The table is unpacked and passed to `cells`. Returns the workbook.
]]),
                    entry("xlsxmlwriter:cell", "workbook:cell(value)", "method",
                        "Append a single cell.",
                        [[
Append a single value to the current row, opening a row if needed.

Strings become string cells and numbers become numeric cells. A table with `year`, `month` and `day` becomes a date cell; adding `hour`, `min` and `sec` makes it a date-time cell; a table with only the time fields becomes a time cell. Other values are converted with `tostring` and written as strings. XML special characters are escaped.

```lua
workbook:cell("text"):cell(3.14):cell { year = 2026, month = 10, day = 24 }
```
]]),
                    entry("xlsxmlwriter:close", "workbook:close()", "method",
                        "Finish the workbook and close the file.",
                        [[
Close the current worksheet, write the closing workbook tag, and close the output file.

After this call the workbook should not be used further. Returns the workbook object.
]]),
                }),

                module("zip", "zip", "Create zip archives.", [==[
`zip.create(filename)` creates a zip archive.  The writer supports files,
in-memory data, directories and nested archives.  `zip.add_directory` adds a
filesystem directory tree.
]==], {
                    entry("zip.create", "zip.create(filename)", "function", "Create a zip archive for writing."),
                    entry("zip.open", "zip.open(filename)", "function", "Open an existing zip archive for appending."),
                    entry("zip.create_after", "zip.create_after(filename)", "function", "Create a zip archive after existing file data."),
                    entry("zip.add_directory", "zip.add_directory(writer, path [, include_top [, level]])", "function", "Add a directory tree to an archive."),
                    entry("zip.level", "zip.level", "field", "Compression level constants."),
                    entry("zip.writer:add_file", "writer:add_file(path [, archive_path [, level]])", "method", "Add a file."),
                    entry("zip.writer:create_directory", "writer:create_directory(path)", "method", "Add a directory entry."),
                    entry("zip.writer:open", "writer:open(path)", "method", "Open an entry for streaming writes."),
                    entry("zip.writer:write", "writer:write(data)", "method", "Write data to the current entry."),
                    entry("zip.writer:close", "writer:close()", "method", "Close the current entry."),
                    entry("zip.writer:close_zip", "writer:close_zip()", "method", "Finish and close the archive."),
                }, { upstream = "https://zlib.net/", license = "MIT" }),

                module("unzip", "unzip", "Read and extract zip archives.", [==[
`unzip.open(filename)` returns an archive object.  Archives expose entries as
tables with `name`, `path`, `full_path`, `is_file`, `is_directory`, sizes,
timestamps and `extract`.
]==], {
                    entry("unzip.open", "unzip.open(filename)", "function", "Open a zip archive."),
                    entry("unzip.extract", "unzip.extract(archive, destination)", "function", "Extract an archive to a directory."),
                    entry("unzip:list", "archive:list()", "method", "Return entries as an array."),
                    entry("unzip:dir", "archive:dir()", "method", "Return entries keyed by path."),
                    entry("unzip:info", "archive:info()", "method", "Return archive information."),
                    entry("unzip:extract", "archive:extract(destination)", "method", "Extract the archive."),
                    entry("unzip:read_all", "archive:read_all(name)", "method", "Read an entry as a string."),
                    entry("unzip:lines", "archive:lines(name)", "method", "Iterate the lines of an entry."),
                    entry("unzip:payload_start", "archive:payload_start()", "method", "Return the offset of an appended zip payload."),
                    entry("unzip:close", "archive:close()", "method", "Close the archive."),
                    entry("unzip.entry:read_all", "entry:read_all()", "method", "Read the entry as a string."),
                    entry("unzip.entry:lines", "entry:lines()", "method", "Iterate the entry's lines."),
                    entry("unzip.entry:extract", "entry:extract(destination)", "method", "Extract the entry."),
                }, { upstream = "https://zlib.net/", license = "MIT" }),
            },
        },

        {
            id = "third_party",
            title = "Third-party libraries",
            source = "third_party",
            modules = {
                module("argparse", "argparse", "Feature-rich command-line parser.", [==[
`argparse` is a feature-rich command-line parser inspired by Python's argparse.
The entry point is `argparse(name, description)`.

```lua
local parser = require("argparse")("myprog", "does something useful")
parser:argument("input", "input file")
parser:flag("-v --verbose", "verbose output")
local args = parser:parse()
```
]==], {
                    entry("argparse:argument", "parser:argument(name [, description [, default]])", "method", "Add a positional argument."),
                    entry("argparse:option", "parser:option(name [, description [, default]])", "method", "Add an option."),
                    entry("argparse:flag", "parser:flag(name [, description])", "method", "Add a boolean flag."),
                    entry("argparse:command", "parser:command(name [, description])", "method", "Add a subcommand."),
                    entry("argparse:mutex", "parser:mutex(...)", "method", "Create a mutually exclusive group."),
                    entry("argparse:group", "parser:group(name, ...)", "method", "Create an argument group."),
                    entry("argparse:parse", "parser:parse([args])", "method", "Parse command-line arguments."),
                    entry("argparse:pparse", "parser:pparse([args])", "method", "Parse arguments, returning an error message instead of raising."),
                    entry("argparse:get_usage", "parser:get_usage()", "method", "Return the generated usage string."),
                    entry("argparse:get_help", "parser:get_help()", "method", "Return the generated help text."),
                    entry("argparse:add_help_command", "parser:add_help_command([value])", "method", "Add a help command."),
                    entry("argparse:add_complete", "parser:add_complete([value])", "method", "Add shell completion support."),
                    entry("argparse:get_bash_complete", "parser:get_bash_complete()", "method", "Generate a bash completion script."),
                    entry("argparse:get_zsh_complete", "parser:get_zsh_complete()", "method", "Generate a zsh completion script."),
                    entry("argparse:get_fish_complete", "parser:get_fish_complete()", "method", "Generate a fish completion script."),
                    entry("argparse:error", "parser:error(message [, ...])", "method", "Raise a parser error."),
                    entry("argparse.Argument:args", "argument:args(...)", "method", "Set or get the argument's target names."),
                    entry("argparse.Argument:count", "argument:count(count)", "method", "Set how many values the argument consumes."),
                    entry("argparse.Argument:default", "argument:default(value)", "method", "Set the default value."),
                    entry("argparse.Argument:target", "argument:target(name)", "method", "Set the result field name."),
                    entry("argparse.Argument:convert", "argument:convert(func)", "method", "Set a value conversion function."),
                    entry("argparse.Argument:choices", "argument:choices(...)", "method", "Restrict values to a set of choices."),
                    entry("argparse.Argument:argname", "argument:argname(name)", "method", "Set the display name in help output."),
                    entry("argparse.Argument:show_default", "argument:show_default(boolean)", "method", "Control whether the default is shown in help."),
                    entry("argparse.Argument:hidden", "argument:hidden(boolean)", "method", "Hide the argument from help output."),
                    entry("argparse.Argument:overwrite", "argument:overwrite(boolean)", "method", "Control overwriting of repeated results."),
                }, { upstream = "https://github.com/luarocks/argparse", license = "MIT", aliases = { "argparse.new" } }),

                module("F", "F", "String interpolation inspired by Python f-strings.", [==[
`require "F"` returns a tagged string function.  Expressions inside `{}` are
evaluated and formatted.

```lua
local F = require "F"
print(F"1 + 2 = {1 + 2}")
```
]==], {
                }, { upstream = "https://github.com/dsidirop/f-strings", license = "MIT" }),

                module("csv", "csv (ftcsv)", "Fast CSV parser and writer.", [==[
`require "csv"` is the bundled `ftcsv` library.  It parses CSV strings and files
and encodes Lua tables as CSV.
]==], {
                    entry("csv.parse", "csv.parse(input [, delimiter [, options]])", "function",
                        "Parse CSV data.",
                        [[
Parse a CSV file or string and return an array of rows plus the final header list.

`input` is normally a filename. Set `options.loadFromString = true` to parse the string directly. The delimiter must be one character and defaults to `,`.

With the default `headers = true`, each row is a table keyed by the header row. Set `headers = false` to receive arrays. Other options include `rename` (map original headers to new names), `fieldsToKeep`, `headerFunc`, and `ignoreQuotes`.

```lua
local csv = require "csv"
local rows = csv.parse("a,b\n1,2\n", ",", { loadFromString = true })
print(rows[1].a, rows[1].b) --> 1 2
```
]]),
                    entry("csv.parseLine", "csv.parseLine(line [, delimiter [, options]])", "function",
                        "Parse a single CSV line.",
                        [[
Parse a CSV file incrementally and return an iterator over its rows.

Each iteration yields a 1-based row number and the parsed row (a table when `headers` is true, otherwise an array). The first result may include the header row depending on the options.

Options are the same as `csv.parse`, except that `loadFromString` is not supported and `bufferSize` may be set to control the read chunk size. A buffer that is too small for a row raises an error.

```lua
local csv = require "csv"
for i, row in csv.parseLine("data.csv") do
    print(i, row.name)
end
```
]]),
                    entry("csv.encode", "csv.encode(table [, delimiter [, options]])", "function",
                        "Encode a table as CSV.",
                        [[
Encode an array of row tables as a CSV string.

Headers are taken from the keys of the first row (sorted), or from `options.fieldsToKeep`. By default every field is quoted and rows end with `\r\n`. Options include `allowMissingKeys`, `onlyRequiredQuotes`, and `encodeNilAs`.

```lua
local csv = require "csv"
local text = csv.encode({ { name = "alice", age = 30 }, { name = "bob", age = 41 } })
print(text)
```
]]),
                }, { upstream = "https://github.com/FourierTransformer/ftcsv", license = "MIT" }),

                module("lpeg", "lpeg", "Parsing Expression Grammars for Lua.", [==[
LPeg provides pattern matching and parsing based on PEGs.  Patterns are combined
with arithmetic operators: `*` (sequence), `+` (choice), `-` (difference),
`^` (repetition), `#` (and predicate), `-p` (not predicate).  Captures use the
`C*` functions.

The complete LPeg manual is authoritative; this reference lists the public
constructors and capture helpers.
]==], {
                    entry("lpeg.match", "lpeg.match(pattern, subject [, init])", "function", "Match a pattern against a string."),
                    entry("lpeg.P", "lpeg.P(value)", "function", "Create a literal pattern or convert a value."),
                    entry("lpeg.R", "lpeg.R(...)", "function", "Create a pattern matching ranges of characters."),
                    entry("lpeg.S", "lpeg.S(set)", "function", "Create a pattern matching any character in a set."),
                    entry("lpeg.V", "lpeg.V(name)", "function", "Reference a grammar rule."),
                    entry("lpeg.B", "lpeg.B(pattern)", "function", "Match a pattern behind the current position."),
                    entry("lpeg.C", "lpeg.C(pattern)", "function", "Capture the matched substring."),
                    entry("lpeg.Cc", "lpeg.Cc(...)", "function", "Produce constant captures."),
                    entry("lpeg.Cmt", "lpeg.Cmt(pattern, function)", "function", "Match-time capture."),
                    entry("lpeg.Cb", "lpeg.Cb(name)", "function", "Back-reference capture."),
                    entry("lpeg.Carg", "lpeg.Carg(n)", "function", "Capture an extra argument."),
                    entry("lpeg.Cp", "lpeg.Cp()", "function", "Capture the current position."),
                    entry("lpeg.Cs", "lpeg.Cs(pattern)", "function", "Substitution capture."),
                    entry("lpeg.Ct", "lpeg.Ct(pattern)", "function", "Table capture."),
                    entry("lpeg.Cf", "lpeg.Cf(pattern, function)", "function", "Fold capture."),
                    entry("lpeg.Cg", "lpeg.Cg(pattern [, name])", "function", "Group capture."),
                    entry("lpeg.type", "lpeg.type(value)", "function", "Return the LPeg type of a value."),
                    entry("lpeg.version", "lpeg.version()", "function", "Return the LPeg version."),
                    entry("lpeg.setmaxstack", "lpeg.setmaxstack(size)", "function", "Set the maximum backtracking stack size."),
                    entry("lpeg.locale", "lpeg.locale([table])", "function", "Create locale-aware patterns."),
                    entry("lpeg.utfR", "lpeg.utfR(...)", "function", "Create UTF-8 aware range patterns."),
                }, { upstream = "https://www.inf.puc-rio.br/~roberto/lpeg/", license = "MIT" }),

                module("re", "re", "Regular expressions built on LPeg.", [==[
`re` implements a regular-expression syntax on top of LPeg.  Patterns can be
matched, searched, substituted and used in grammars.
]==], {
                    entry("re.match", "re.match(subject, pattern [, init])", "function", "Match a pattern against a string."),
                    entry("re.find", "re.find(subject, pattern [, init])", "function", "Find the first match."),
                    entry("re.gmatch", "re.gmatch(subject, pattern)", "function", "Iterate matches."),
                    entry("re.gsub", "re.gsub(subject, pattern, replacement)", "function", "Replace matches."),
                    entry("re.compile", "re.compile(pattern [, definition])", "function", "Compile a pattern."),
                }, { upstream = "https://www.inf.puc-rio.br/~roberto/lpeg/re.html", license = "MIT" }),

                module("cjson", "cjson", "Fast JSON encoding and decoding.", [==[
`cjson.encode(value)` and `cjson.decode(string)` are the common entry points.
The module also exposes configuration functions for number precision, invalid
numbers, sparse arrays, maximum depth and indentation.
]==], {
                    entry("cjson.encode", "cjson.encode(value)", "function", "Encode a Lua value as JSON."),
                    entry("cjson.decode", "cjson.decode(string)", "function", "Decode a JSON string."),
                    entry("cjson.new", "cjson.new()", "function", "Create a separate cjson instance."),
                    entry("cjson.encode_empty_table_as_object", "cjson.encode_empty_table_as_object(boolean)", "function", "Control empty-table encoding."),
                    entry("cjson.decode_array_with_array_mt", "cjson.decode_array_with_array_mt(boolean)", "function", "Control array metatables."),
                    entry("cjson.decode_allow_comment", "cjson.decode_allow_comment(boolean)", "function", "Allow comments while decoding."),
                    entry("cjson.encode_sparse_array", "cjson.encode_sparse_array(convert, ratio, safe)", "function", "Configure sparse-array handling."),
                    entry("cjson.encode_max_depth", "cjson.encode_max_depth(depth)", "function", "Set the maximum encode depth."),
                    entry("cjson.decode_max_depth", "cjson.decode_max_depth(depth)", "function", "Set the maximum decode depth."),
                    entry("cjson.encode_number_precision", "cjson.encode_number_precision(precision)", "function", "Set number precision."),
                    entry("cjson.encode_keep_buffer", "cjson.encode_keep_buffer(boolean)", "function", "Keep the encode buffer between calls."),
                    entry("cjson.encode_invalid_numbers", "cjson.encode_invalid_numbers(boolean)", "function", "Control encoding of NaN and infinity."),
                    entry("cjson.decode_invalid_numbers", "cjson.decode_invalid_numbers(boolean)", "function", "Control decoding of NaN and infinity."),
                    entry("cjson.encode_escape_forward_slash", "cjson.encode_escape_forward_slash(boolean)", "function", "Escape forward slashes."),
                    entry("cjson.encode_skip_unsupported_value_types", "cjson.encode_skip_unsupported_value_types(boolean)", "function", "Skip unsupported values."),
                    entry("cjson.encode_indent", "cjson.encode_indent(value)", "function", "Pretty-print JSON with indentation."),
                }, { upstream = "https://github.com/openresty/lua-cjson", license = "MIT" }),

                module("zlib", "zlib", "Lua binding to zlib.", [==[
`zlib.deflate()` and `zlib.inflate()` return streaming compressor/decompressor
functions.  `zlib.compress` and `zlib.decompress` are one-shot helpers.  Checksum
helpers `adler32` and `crc32` are also available.
]==], {
                    entry("zlib.deflate", "zlib.deflate([level [, window_bits [, mem_level [, strategy]]]])", "function", "Create a streaming deflate function."),
                    entry("zlib.inflate", "zlib.inflate([window_bits])", "function", "Create a streaming inflate function."),
                    entry("zlib.compress", "zlib.compress(data [, level])", "function", "Compress a string in one call."),
                    entry("zlib.decompress", "zlib.decompress(data [, window_bits])", "function", "Decompress a string in one call."),
                    entry("zlib.adler32", "zlib.adler32(data [, previous])", "function", "Compute an Adler-32 checksum."),
                    entry("zlib.crc32", "zlib.crc32(data [, previous])", "function", "Compute a CRC-32 checksum."),
                    entry("zlib.version", "zlib.version()", "function", "Return the zlib version."),
                }, { upstream = "https://github.com/brimworks/lua-zlib", license = "MIT" }),

                module("sqlite3", "sqlite3", "LuaSQLite3 binding.", [==[
The `sqlite3` module provides database, statement and result objects.  The most
common entry points are `sqlite3.open`, `db:exec`, `db:prepare`, `stmt:bind` and
the row iterators `db:nrows`, `db:rows` and `db:urows`.
]==], {
                    entry("sqlite3.open", "sqlite3.open(filename [, flags])", "function",
                        "Open a database file.",
                        [[
Open an existing SQLite database or create it when it does not exist, and return a database handle.

The optional `flags` argument is passed to `sqlite3_open_v2`; it defaults to `sqlite3.OPEN_READWRITE + sqlite3.OPEN_CREATE`. Constants such as `OPEN_READONLY`, `OPEN_SHAREDCACHE` and `OPEN_NOMUTEX` are available on the module.

On failure it returns `nil, error_code, error_message` rather than raising.

```lua
local sqlite3 = require "sqlite3"
local db = assert(sqlite3.open("app.sqlite3"))
db:exec("create table if not exists notes (body text)")
db:close()
```
]]),
                    entry("sqlite3.open_memory", "sqlite3.open_memory()", "function",
                        "Open an in-memory database.",
                        [[
Open a private in-memory SQLite database and return its handle. The database disappears when the handle is closed or garbage-collected.

On failure it returns `nil, error_code, error_message`. This is convenient for tests and temporary caches.

```lua
local sqlite3 = require "sqlite3"
local db = assert(sqlite3.open_memory())
db:exec("create table t (n integer)")
```
]]),
                    entry("sqlite3.open_ptr", "sqlite3.open_ptr(pointer)", "function",
                        "Open a database from a raw pointer.",
                        [[
Wrap an existing raw `sqlite3 *` pointer, passed as light userdata, in a Lua database handle.

The pointer is validated with a lightweight SQLite call; an invalid pointer raises an argument error. Use `db:get_ptr()` on another handle to obtain a compatible pointer when moving a database between Lua states.

```lua
local db = assert(sqlite3.open("app.sqlite3"))
local ptr = db:get_ptr()
local same = sqlite3.open_ptr(ptr)
```
]]),
                    entry("sqlite3.version", "sqlite3.version()", "function",
                        "Return the SQLite version.",
                        [[
Return the version string of the SQLite library that is linked into the interpreter, for example `"3.45.1"`.

The result comes from `sqlite3_libversion` and does not allocate or raise.
]]),
                    entry("sqlite3.lversion", "sqlite3.lversion()", "function",
                        "Return the LuaSQLite3 version.",
                        [[
Return the version of the bundled LuaSQLite3 binding, such as `"0.9.6"`.

This identifies the Lua wrapper, not the underlying SQLite engine; use `sqlite3.version()` for the engine version.
]]),
                    entry("sqlite3.complete", "sqlite3.complete(sql)", "function",
                        "Return true when a SQL string is complete.",
                        [[
Return true when `sql` contains one or more complete SQL statements, and false when another statement terminator is still needed.

The check uses SQLite's own parser and is useful for interactive input buffering.

```lua
local sqlite3 = require "sqlite3"
print(sqlite3.complete("select 1;")) --> true
print(sqlite3.complete("select 1"))  --> false
```
]]),
                    entry("sqlite3.temp_directory", "sqlite3.temp_directory([path])", "function",
                        "Get or set the temporary directory.",
                        [[
Get or set the directory SQLite uses for temporary files.

With no argument it returns the current directory string (possibly `nil`). With a string it sets the directory and returns the previous value; passing `nil` explicitly clears the setting. The setter is unavailable on Windows in this binding.

```lua
local sqlite3 = require "sqlite3"
sqlite3.temp_directory("/tmp")
```
]]),
                    entry("sqlite3.backup_init", "sqlite3.backup_init(target_db, target_name, source_db, source_name)", "function",
                        "Create an online backup object.",
                        [[
Start an online backup from a source database to a destination database and return a backup object.

The databases are passed as open handles, together with the source and destination database names (`"main"`, `"temp"`, or an attached name). Source and target must be different. On failure the function returns `nil`; details are stored on the destination handle and are available through `db:errcode()` and `db:errmsg()`.

```lua
local dst = assert(sqlite3.open("copy.sqlite3"))
local backup = sqlite3.backup_init(dst, "main", src, "main")
backup:step(-1)
backup:finish()
```
]]),
                    entry("sqlite3.db:exec", "db:exec(sql)", "method",
                        "Execute SQL statements.",
                        [[
Compile and execute one or more SQL statements. The alias `db:execute` behaves identically.

The function returns `sqlite3.OK` on success or a numeric SQLite error code. If a row callback is supplied, it is called as `func(udata, column_count, values, names)` for every result row. Returning `0` continues; returning a non-zero value aborts the remaining statements and makes `exec` return `sqlite3.ABORT`.

```lua
local db = assert(require("sqlite3").open_memory())
db:exec("create table t (n integer); insert into t values (1), (2)")
db:exec("select n from t", function(_, _, values)
    print(values[1])
    return 0
end)
```
]]),
                    entry("sqlite3.db:execute", "db:execute(sql)", "method",
                        "Alias for `db:exec`.",
                        [[
Alias for `db:exec`. It compiles and runs all statements in the SQL string and returns `sqlite3.OK` or an error code.

The optional row callback and userdata argument have the same behavior as in `db:exec`.
]]),
                    entry("sqlite3.db:prepare", "db:prepare(sql)", "method",
                        "Prepare a SQL statement.",
                        [[
Compile a single SQL statement and return a prepared statement object.

Use `stmt:bind*` to supply parameters, `stmt:step()` to execute or fetch rows, and `stmt:finalize()` when finished. The statement keeps a reference to the database, so finalize it before closing the database.

A preparation error is raised as a Lua error with the SQLite message.

```lua
local db = assert(require("sqlite3").open_memory())
db:exec("create table t (n integer)")
local stmt = db:prepare("insert into t values (?)")
stmt:bind_values(42)
stmt:step()
stmt:finalize()
```
]]),
                    entry("sqlite3.db:rows", "db:rows(sql [, parameters])", "method",
                        "Iterate result rows as arrays.",
                        [[
Return an iterator over the result rows as packed arrays. Index `1` is the first selected column.

Optional parameters may be supplied as individual values matching the statement's placeholders, or as one table whose numeric or named fields provide them. Preparation and binding errors are raised as Lua errors.

```lua
for row in db:rows("select n, n * 2 from t where n > ?", 1) do
    print(row[1], row[2])
end
```
]]),
                    entry("sqlite3.db:nrows", "db:nrows(sql [, parameters])", "method",
                        "Iterate result rows as name/value tables.",
                        [[
Return an iterator over the result rows as tables keyed by column name.

Parameters are supplied in the same way as for `db:rows`: either positional values or a single table. Duplicate column names overwrite earlier values in the resulting table.

```lua
for row in db:nrows("select n as number from t") do
    print(row.number)
end
```
]]),
                    entry("sqlite3.db:urows", "db:urows(sql [, parameters])", "method",
                        "Iterate a single-column result.",
                        [[
Return an iterator that unpacks each result row into separate values.

For a query selecting three columns, the loop variables receive those three values directly. Parameters use the same positional-or-table convention as the other row iterators.

```lua
for n, doubled in db:urows("select n, n * 2 from t") do
    print(n, doubled)
end
```
]]),
                    entry("sqlite3.db:close", "db:close()", "method",
                        "Close the database.",
                        [[
Close the database handle and release its resources.

All prepared statements should be finalized first. Returns `sqlite3.OK` on success or a numeric SQLite error code. Calling `close` on an already closed handle raises an argument error, so close each handle only once.

```lua
local db = assert(require("sqlite3").open_memory())
print(db:close()) --> 0 (sqlite3.OK)
```
]]),
                    entry("sqlite3.db:isopen", "db:isopen()", "method",
                        "Return true when the database is open.",
                        [[
Return true while the database handle is open and false after `db:close()`.

The check does not touch the database file.
]]),
                    entry("sqlite3.db:changes", "db:changes()", "method",
                        "Return the number of changed rows.",
                        [[
Return the number of rows changed, inserted or deleted by the most recent `INSERT`, `UPDATE` or `DELETE` statement.

Changes performed indirectly by triggers are not counted. Use `db:total_changes()` for the cumulative count.

```lua
db:exec("update t set n = n + 1")
print(db:changes())
```
]]),
                    entry("sqlite3.db:total_changes", "db:total_changes()", "method",
                        "Return total changed rows.",
                        [[
Return the total number of rows modified by `INSERT`, `UPDATE` or `DELETE` since the database was opened.

Unlike `db:changes()`, this includes changes made by trigger programs and accumulates across statements.
]]),
                    entry("sqlite3.db:last_insert_rowid", "db:last_insert_rowid()", "method",
                        "Return the last inserted row id.",
                        [[
Return the rowid of the most recent successful insert on this database.

If no insert has occurred, the result is `0`. Inside a trigger, the value refers to the row inserted by the trigger until the trigger finishes.
]]),
                    entry("sqlite3.db:errcode", "db:errcode()", "method",
                        "Return the last error code.",
                        [[
Return the numeric result code or extended result code of the most recent failed operation on this database.

Use `db:errmsg()` for the accompanying human-readable message. Successful operations do not necessarily reset the stored code.
]]),
                    entry("sqlite3.db:errmsg", "db:errmsg()", "method",
                        "Return the last error message.",
                        [[
Return the error message associated with the most recent failed operation on this database.

The message comes from SQLite and may include constraint or I/O details. The alias `db:error_message` is also available.
]]),
                    entry("sqlite3.db:busy_timeout", "db:busy_timeout(timeout)", "method",
                        "Set the busy timeout.",
                        [[
Set a busy timeout in milliseconds, so SQLite waits for locks instead of immediately returning `sqlite3.BUSY`.

A value less than or equal to zero disables the timeout and removes any handler installed with `db:busy_handler`. Returns a numeric result code.

```lua
db:busy_timeout(5000) -- wait up to five seconds
```
]]),
                    entry("sqlite3.db:interrupt", "db:interrupt()", "method",
                        "Interrupt the current operation.",
                        [[
Request cancellation of any pending operation on this database.

SQLite checks the flag at its next opportunity and aborts the operation, which normally surfaces as `sqlite3.INTERRUPT`. The function returns nothing and is safe to call when no operation is running.
]]),
                    entry("sqlite3.db:create_function", "db:create_function(name, nargs, func [, userdata])", "method",
                        "Register a scalar SQL function.",
                        [[
Register a scalar SQL function implemented in Lua.

`name` is the SQL name, `nargs` is the exact argument count (`-1` accepts any number), and `func` receives a callback context followed by the SQL arguments. Call `context:result_*` to return a value. An optional `userdata` argument is available through `context:user_data()`.

```lua
db:create_function("double", 1, function(ctx, n)
    ctx:result_int(n * 2)
end)
```
]]),
                    entry("sqlite3.db:create_aggregate", "db:create_aggregate(name, nargs, step, final [, userdata])", "method",
                        "Register an aggregate SQL function.",
                        [[
Register an aggregate SQL function. `step` is called once per input row and `final` once at the end.

Both callbacks receive a function context; use `context:set_aggregate_data()` and `context:get_aggregate_data()` to carry state between rows, and `context:result_*` in `final` to produce the result. An optional userdata value is exposed by `context:user_data()`.

```lua
db:create_aggregate("total", 1, function(ctx, n)
    ctx:set_aggregate_data((ctx:get_aggregate_data() or 0) + n)
end, function(ctx)
    ctx:result_int(ctx:get_aggregate_data() or 0)
end)
```
]]),
                    entry("sqlite3.db:create_collation", "db:create_collation(name, func)", "method",
                        "Register a collation.",
                        [[
Register a collation function used by SQLite for ordering and comparisons.

`func(a, b)` must return `0` when the strings compare equal, `-1` when `a` sorts before `b`, and `1` when `a` sorts after `b`. The collation name can then be used in column definitions and `ORDER BY ... COLLATE name` clauses.

```lua
db:create_collation("nocase", function(a, b)
    a, b = a:lower(), b:lower()
    return a == b and 0 or (a < b and -1 or 1)
end)
```
]]),
                    entry("sqlite3.db:trace", "db:trace(func [, userdata])", "method",
                        "Install a trace callback.",
                        [[
Install a trace callback that runs just before each SQL statement is evaluated.

The callback receives the optional userdata value followed by the SQL text. Call `db:trace(nil)` to remove the callback.

```lua
db:trace(function(_, sql) print("SQL:", sql) end)
```
]]),
                    entry("sqlite3.db:progress_handler", "db:progress_handler(n, func [, userdata])", "method",
                        "Install a progress handler.",
                        [[
Install a callback that SQLite invokes periodically during long-running `exec` or `step` calls.

The callback runs once every `n` virtual-machine operations and receives the optional userdata argument. Returning a non-zero value aborts the current query, rolls back its changes, and makes the operation return `sqlite3.INTERRUPT`. Pass `nil` as the callback to remove it.

```lua
db:progress_handler(1000, function() return 0 end)
```
]]),
                    entry("sqlite3.db:update_hook", "db:update_hook(func [, userdata])", "method",
                        "Install an update hook.",
                        [[
Install a data-change notification callback.

The callback receives optional userdata, the operation constant (`sqlite3.INSERT`, `sqlite3.UPDATE` or `sqlite3.DELETE`), the database name, the table name, and the affected rowid. Pass `nil` to remove the hook.
]]),
                    entry("sqlite3.db:commit_hook", "db:commit_hook(func [, userdata])", "method",
                        "Install a commit hook.",
                        [[
Install a callback invoked whenever a transaction is about to commit.

The callback receives the optional userdata argument. Returning `false` or `nil` allows the commit; returning any other value converts it into a rollback. Pass `nil` to remove the hook.
]]),
                    entry("sqlite3.db:rollback_hook", "db:rollback_hook(func [, userdata])", "method",
                        "Install a rollback hook.",
                        [[
Install a callback invoked whenever a transaction is rolled back.

The callback receives the optional userdata argument. Pass `nil` to remove the hook.
]]),
                    entry("sqlite3.stmt:step", "stmt:step()", "method",
                        "Advance a prepared statement.",
                        [[
Advance a prepared statement to its next result.

Returns `sqlite3.ROW` when a row is available, `sqlite3.DONE` when execution has finished, or an error code such as `sqlite3.BUSY`, `sqlite3.ERROR` or `sqlite3.MISUSE`. After `DONE` or an error, call `stmt:reset()` before executing the statement again.

```lua
local rc = stmt:step()
if rc == sqlite3.ROW then
    print(stmt:get_values()[1])
end
```
]]),
                    entry("sqlite3.stmt:reset", "stmt:reset()", "method",
                        "Reset a prepared statement.",
                        [[
Reset a prepared statement so it can be executed again.

Existing parameter bindings are retained. The function returns the current SQLite error code for the statement, usually `sqlite3.OK`.

```lua
stmt:reset()
stmt:step()
```
]]),
                    entry("sqlite3.stmt:finalize", "stmt:finalize()", "method",
                        "Finalize a prepared statement.",
                        [[
Free a prepared statement and all resources associated with it.

Returns `sqlite3.OK` when the statement was never executed or completed successfully, otherwise the last execution error code. The statement must not be used after finalization.
]]),
                    entry("sqlite3.stmt:bind", "stmt:bind(index, value)", "method",
                        "Bind a value to a parameter.",
                        [[
Bind a Lua value to parameter `index`, where statement parameters are numbered from 1.

Strings bind as text, integers as SQLite integers, other numbers as doubles, booleans as `0`/`1`, and `nil` removes any previous binding. Unsupported types raise an error. Returns `sqlite3.OK` or an error code.

```lua
stmt:bind(1, "hello")
stmt:bind(2, 42)
```
]]),
                    entry("sqlite3.stmt:bind_values", "stmt:bind_values(...)", "method",
                        "Bind positional parameters.",
                        [[
Bind one value to each statement parameter, in order from 1 to `bind_parameter_count()`.

The number of values must exactly match the parameter count, otherwise an error is raised. Returns `sqlite3.OK` or the first binding error code.

```lua
stmt:bind_values("alice", 30)
```
]]),
                    entry("sqlite3.stmt:bind_names", "stmt:bind_names(table)", "method",
                        "Bind named parameters.",
                        [[
Bind parameters from a table.

Named placeholders of the form `:name` or `$name` are looked up by the name without the leading marker. Unnamed parameters use numeric keys `1..n`. Returns `sqlite3.OK` or an error code.

```lua
stmt = db:prepare("insert into t values (:name, :age)")
stmt:bind_names { name = "alice", age = 30 }
```
]]),
                    entry("sqlite3.stmt:columns", "stmt:columns()", "method",
                        "Return result column names.",
                        [[
Return the number of columns in the statement's result set.

The value is `0` for statements that do not return rows, such as `INSERT` or `UPDATE`.
]]),
                    entry("sqlite3.stmt:get_value", "stmt:get_value(index)", "method",
                        "Return a result value.",
                        [[
Return the value of result column `index`. Column indexes start at 0.

The statement must currently be positioned on a row (`stmt:step()` returned `sqlite3.ROW`); otherwise a misuse error is raised.
]]),
                    entry("sqlite3.stmt:get_values", "stmt:get_values()", "method",
                        "Return all result values.",
                        [[
Return the current row as an array, with column `0` stored at index 1.

The statement must be positioned on a result row. Column values are converted to Lua strings, numbers, booleans or `nil` according to SQLite's types.
]]),
                    entry("sqlite3.stmt:get_type", "stmt:get_type(index)", "method",
                        "Return a result value type.",
                        [[
Return the declared SQL type of result column `index`, using a 0-based column index.

The result is the type written in the schema or query (`"INTEGER"`, `"TEXT"`, and so on), or `nil` when the column has no declared type. It is not the runtime storage class of the current value.
]]),
                    entry("sqlite3.stmt:get_types", "stmt:get_types()", "method",
                        "Return all result value types.",
                        [[
Return an array of declared SQL types for all result columns.

Index 1 describes column 0, and so on. Columns without a declared type yield `nil` entries.
]]),
                    entry("sqlite3.stmt:get_uvalue", "stmt:get_uvalue(index)", "method",
                        "Return an uncoerced result value.",
                        [[
Return a single result value without packing it into a table.

This bundled LuaSQLite3 build does not expose a singular `get_uvalue` method; use `stmt:get_values()` for an array or `stmt:get_uvalues()` for multiple return values. The entry is kept as a compatibility reference.
]]),
                    entry("sqlite3.stmt:get_uvalues", "stmt:get_uvalues()", "method",
                        "Return all uncoerced result values.",
                        [[
Return all values of the current row as multiple Lua return values.

For a three-column query, `local a, b, c = stmt:get_uvalues()` receives the three columns directly. The statement must be positioned on a result row.
]]),
                    entry("sqlite3.stmt:get_utype", "stmt:get_utype(index)", "method",
                        "Return an uncoerced result type.",
                        [[
Return a single declared column type without packing it into a table.

This bundled build does not expose a singular `get_utype` method; use `stmt:get_types()` for an array or `stmt:get_utypes()` for multiple return values. The entry is kept as a compatibility reference.
]]),
                    entry("sqlite3.stmt:get_utypes", "stmt:get_utypes()", "method",
                        "Return all uncoerced result types.",
                        [[
Return the declared types of all result columns as multiple Lua return values.

Columns without a declared type produce `nil` in the corresponding position.
]]),
                    entry("sqlite3.stmt:get_name", "stmt:get_name(index)", "method",
                        "Return a column name.",
                        [[
Return the name of result column `index`, using a 0-based column index.

The name is the column alias if one was specified, otherwise the column or expression name chosen by SQLite.
]]),
                    entry("sqlite3.stmt:get_names", "stmt:get_names()", "method",
                        "Return all column names.",
                        [[
Return an array containing the names of all result columns.

Index 1 corresponds to column 0. Names are taken from aliases when present.
]]),
                    entry("sqlite3.stmt:get_named_values", "stmt:get_named_values()", "method",
                        "Return results as a name/value table.",
                        [[
Return the current result row as a table keyed by column name.

The statement must be positioned on a row. Duplicate column names overwrite earlier values.

```lua
stmt:step()
local row = stmt:get_named_values()
print(row.name)
```
]]),
                    entry("sqlite3.stmt:get_named_types", "stmt:get_named_types()", "method",
                        "Return result types as a name/value table.",
                        [[
Return a table mapping each result column name to its declared SQL type.

Duplicate names overwrite earlier entries. Columns without a declared type map to `nil`.
]]),
                    entry("sqlite3.stmt:bind_parameter_count", "stmt:bind_parameter_count()", "method",
                        "Return the number of parameters.",
                        [[
Return the number of distinct parameters in the prepared statement.

Repeated named parameters count once, while gaps in `?NNN` numbering are reflected in the largest index returned.
]]),
                    entry("sqlite3.stmt:bind_parameter_name", "stmt:bind_parameter_name(index)", "method",
                        "Return a parameter name.",
                        [[
Return the name of parameter `index`, including its leading `:`, `$` or `@` marker.

The index is 1-based. An unnamed `?` or `?NNN` parameter yields `nil`; an out-of-range index raises an error.
]]),
                    entry("sqlite3.stmt:bind_blob", "stmt:bind_blob(index, data)", "method",
                        "Bind a blob value.",
                        [[
Bind a Lua string as a BLOB value to parameter `index`.

The entire string, including embedded NUL bytes, is copied into SQLite. The binding uses transient storage, so the Lua string may be collected after the call. Returns `sqlite3.OK` or an error code.

```lua
stmt:bind_blob(1, "\0\1\2binary")
```
]]),
                }, { upstream = "http://lua.sqlite.org/", license = "MIT" }),

                module("luaunit", "luaunit", "Unit-testing framework for Lua.", [==[
LuaUnit discovers global tables whose names begin with `Test` and functions whose
names begin with `test`.  Assertions are exported as `assert*` functions.

`luaunit.run()` runs the registered tests and returns the number of failures.
]==], {
                    entry("luaunit.run", "luaunit.run([...])", "function",
                        "Run the test suite.",
                        [[
Run the registered test suite and return the number of failures and errors (zero means success).

With no arguments, command-line options are taken from the script's `arg` table. You may instead pass option strings such as `"-v"`, `"--quiet"`, `"--shuffle"` or `"--pattern"`. LuaUnit discovers global tables named `Test*` and functions named `test*`.

```lua
local lu = require "luaunit"
Test_math = {}
function Test_math:test_addition() lu.assertEquals(1 + 1, 2) end
os.exit(lu.run())
```
]]),
                    entry("luaunit.assertEquals", "luaunit.assertEquals(actual, expected [, message])", "function",
                        "Assert equality.",
                        [[
Assert that two values are equal. Tables are compared deeply, including nested keys and values; other values use ordinary `==`.

An optional message is appended to the failure output. A mismatch fails the current test by raising an error.

```lua
lu.assertEquals({ a = 1, b = { 2, 3 } }, { b = { 2, 3 }, a = 1 })
```
]]),
                    entry("luaunit.assertNotEquals", "luaunit.assertNotEquals(actual, expected [, message])", "function",
                        "Assert inequality.",
                        [[
Assert that two values are not equal, using the same deep table comparison as `assertEquals`.

The assertion passes when the values have different types or any nested table content differs. An optional message is added to the failure.
]]),
                    entry("luaunit.assertAlmostEquals", "luaunit.assertAlmostEquals(actual, expected, margin [, message])", "function",
                        "Assert approximate equality.",
                        [[
Assert that two numbers, or two tables of numbers, are equal within `margin`.

If `margin` is omitted or `nil`, LuaUnit's `EPS` value is used. Negative margins are rejected. An optional message is appended on failure.

```lua
lu.assertAlmostEquals(0.1 + 0.2, 0.3, 1e-9)
```
]]),
                    entry("luaunit.assertItemsEquals", "luaunit.assertItemsEquals(actual, expected [, message])", "function",
                        "Assert that two tables contain the same items.",
                        [[
Assert that two tables contain the same items, ignoring order and keys.

Each value in one table must match some value in the other and vice versa, using deep equality. The comparison is O(n^2), so it is intended for small tables.
]]),
                    entry("luaunit.assertStrContains", "luaunit.assertStrContains(value, substring [, isPattern [, message]])", "function",
                        "Assert that a string contains a substring.",
                        [[
Assert that `value` contains `substring`.

By default the search is plain text. Pass `true` as `isPattern` to treat `substring` as a Lua pattern. An optional message is appended to the failure.

```lua
lu.assertStrContains("hello world", "lo wo")
lu.assertStrContains("abc123", "%d+", true)
```
]]),
                    entry("luaunit.assertStrIContains", "luaunit.assertStrIContains(value, substring [, message])", "function",
                        "Case-insensitive substring assertion.",
                        [[
Assert that `value` contains `substring`, ignoring letter case.

The search is always plain text, so pattern characters have no special meaning. An optional message is appended to the failure.

```lua
lu.assertStrIContains("Hello World", "hello")
```
]]),
                    entry("luaunit.assertNotStrContains", "luaunit.assertNotStrContains(value, substring [, isPattern [, message]])", "function",
                        "Assert that a string does not contain a substring.",
                        [[
Assert that `value` does not contain `substring`.

Plain-text matching is the default; pass `true` as `isPattern` to use a Lua pattern. An optional message is appended to the failure.
]]),
                    entry("luaunit.assertNotStrIContains", "luaunit.assertNotStrIContains(value, substring [, message])", "function",
                        "Case-insensitive negative substring assertion.",
                        [[
Assert that `value` does not contain `substring`, ignoring letter case.

The search is plain text. An optional message is appended to the failure.
]]),
                    entry("luaunit.assertStrMatches", "luaunit.assertStrMatches(value, pattern [, start [, final [, message]]])", "function",
                        "Assert a string pattern match.",
                        [[
Assert that the whole of `value`, or the range from `start` through `final`, matches the Lua pattern.

`start` defaults to 1 and `final` to the string length. The pattern must cover the entire selected range, not merely occur somewhere inside it.

```lua
lu.assertStrMatches("2026-10-24", "%d%d%d%d%-%d%d%-%d%d")
```
]]),
                    entry("luaunit.assertError", "luaunit.assertError(func, ...)", "function",
                        "Assert that a call raises an error.",
                        [[
Assert that calling `func` with the supplied arguments raises an error.

The error message and type are not checked. Extra arguments after `func` are passed to it.

```lua
lu.assertError(function() error("boom") end)
```
]]),
                    entry("luaunit.assertErrorMsgEquals", "luaunit.assertErrorMsgEquals(message, func, ...)", "function",
                        "Assert an exact error message.",
                        [[
Assert that calling `func` raises an error whose message exactly equals `message`.

File and line prefixes added by `error(..., 2)` are significant; use `assertErrorMsgContentEquals` to ignore them. Extra arguments after `func` are passed through.

```lua
lu.assertErrorMsgEquals("boom", function() error("boom", 0) end)
```
]]),
                    entry("luaunit.assertErrorMsgContentEquals", "luaunit.assertErrorMsgContentEquals(message, func, ...)", "function",
                        "Assert an error message ignoring file and line prefix.",
                        [[
Assert that `func` raises an error whose message equals `message` after removing a leading `file:line:` prefix.

This is convenient for errors raised with a level argument. Extra arguments after `func` are passed through.
]]),
                    entry("luaunit.assertErrorMsgContains", "luaunit.assertErrorMsgContains(partial, func, ...)", "function",
                        "Assert an error message contains text.",
                        [[
Assert that `func` raises an error whose message contains `partial` as plain text.

Any file and line prefix is left in place, so the substring may match anywhere in the full message. Extra arguments after `func` are passed through.
]]),
                    entry("luaunit.assertErrorMsgMatches", "luaunit.assertErrorMsgMatches(pattern, func, ...)", "function",
                        "Assert an error message matches a pattern.",
                        [[
Assert that `func` raises an error whose entire message matches the Lua pattern.

The pattern is matched against the complete message, including any file and line prefix, and must cover the whole string. Extra arguments after `func` are passed through.
]]),
                    entry("luaunit.assertEvalToTrue", "luaunit.assertEvalToTrue(value [, message])", "function",
                        "Assert that a value evaluates to true.",
                        [[
Assert that `value` evaluates to true in Lua, meaning it is neither `false` nor `nil`.

Numbers, strings and tables all pass, including `0` and the empty string. Use `assertIsTrue` when the value must be exactly `true`.
]]),
                    entry("luaunit.assertEvalToFalse", "luaunit.assertEvalToFalse(value [, message])", "function",
                        "Assert that a value evaluates to false.",
                        [[
Assert that `value` is `false` or `nil`, the only Lua values that evaluate to false.

Use `assertIsFalse` when the value must be exactly `false` rather than `nil`.
]]),
                    entry("luaunit.assertIsTrue", "luaunit.assertIsTrue(value [, message])", "function",
                        "Assert a true value.",
                        [[
Assert that `value` is exactly the boolean `true`.

Truthy non-boolean values fail this assertion; use `assertEvalToTrue` for Lua truthiness. An optional message is appended to the failure.
]], { "luaunit.assertTrue" }),
                    entry("luaunit.assertNotIsTrue", "luaunit.assertNotIsTrue(value [, message])", "function",
                        "Assert a non-true value.",
                        [[
Assert that `value` is not exactly the boolean `true`.

Both `false` and any non-boolean value pass; use `assertIsFalse` for an exact `false` check.
]]),
                    entry("luaunit.assertIsFalse", "luaunit.assertIsFalse(value [, message])", "function",
                        "Assert a false value.",
                        [[
Assert that `value` is exactly the boolean `false`.

`nil` and other falsy values fail this assertion; use `assertEvalToFalse` for Lua falsiness.
]], { "luaunit.assertFalse" }),
                    entry("luaunit.assertNotIsFalse", "luaunit.assertNotIsFalse(value [, message])", "function",
                        "Assert a non-false value.",
                        [[
Assert that `value` is not exactly the boolean `false`.

`nil`, `true` and non-boolean values all pass. An optional message is appended on failure.
]]),
                    entry("luaunit.assertIsNil", "luaunit.assertIsNil(value [, message])", "function",
                        "Assert nil.",
                        [[
Assert that `value` is `nil`.

The alias `assertNil` behaves identically. An optional message is appended to the failure.
]], { "luaunit.assertNil" }),
                    entry("luaunit.assertNotIsNil", "luaunit.assertNotIsNil(value [, message])", "function",
                        "Assert not nil.",
                        [[
Assert that `value` is not `nil`.

The alias `assertNotNil` behaves identically. An optional message is appended to the failure.
]], { "luaunit.assertNotNil" }),
                    entry("luaunit.assertIs", "luaunit.assertIs(actual, expected [, message])", "function",
                        "Assert identity.",
                        [[
Assert that `actual` and `expected` are the same value, using `==`.

For tables and functions this checks identity rather than content; use `assertEquals` for structural comparison.
]]),
                    entry("luaunit.assertNotIs", "luaunit.assertNotIs(actual, expected [, message])", "function",
                        "Assert non-identity.",
                        [[
Assert that `actual` and `expected` are not the same value.

Table contents are not compared; two distinct tables always pass even when their fields match.
]]),
                    entry("luaunit.assertIsNaN", "luaunit.assertIsNaN(value [, message])", "function",
                        "Assert NaN.",
                        [[
Assert that `value` is the NaN number value.

The check works even though NaN is not equal to itself. An optional message is appended on failure.
]]),
                    entry("luaunit.assertNotIsNaN", "luaunit.assertNotIsNaN(value [, message])", "function",
                        "Assert not NaN.",
                        [[
Assert that `value` is not NaN.

Non-number values also pass. An optional message is appended on failure.
]]),
                    entry("luaunit.assertIsInf", "luaunit.assertIsInf(value [, message])", "function",
                        "Assert infinity.",
                        [[
Assert that `value` is either positive or negative infinity.

Use `assertIsPlusInf` or `assertIsMinusInf` when the sign matters.
]]),
                    entry("luaunit.assertIsPlusInf", "luaunit.assertIsPlusInf(value [, message])", "function",
                        "Assert positive infinity.",
                        [[
Assert that `value` is positive infinity (`math.huge`).

An optional message is appended to the failure.
]]),
                    entry("luaunit.assertIsMinusInf", "luaunit.assertIsMinusInf(value [, message])", "function",
                        "Assert negative infinity.",
                        [[
Assert that `value` is negative infinity (`-math.huge`).

An optional message is appended to the failure.
]]),
                    entry("luaunit.assertNotIsInf", "luaunit.assertNotIsInf(value [, message])", "function",
                        "Assert a finite number.",
                        [[
Assert that `value` is a finite number and not positive or negative infinity.

Non-number values also pass. An optional message is appended on failure.
]]),
                    entry("luaunit.assertIsPlusZero", "luaunit.assertIsPlusZero(value [, message])", "function",
                        "Assert positive zero.",
                        [[
Assert that `value` is positive zero (`0.0`).

IEEE-754 distinguishes positive and negative zero even though `0.0 == -0.0`; this assertion checks the sign bit.
]]),
                    entry("luaunit.assertIsMinusZero", "luaunit.assertIsMinusZero(value [, message])", "function",
                        "Assert negative zero.",
                        [[
Assert that `value` is negative zero (`-0.0`).

IEEE-754 distinguishes negative zero from positive zero even though they compare equal with `==`.
]]),
                    entry("luaunit.assertTableContains", "luaunit.assertTableContains(table, expected [, message])", "function",
                        "Assert that a table contains expected entries.",
                        [[
Assert that table `t` contains `expected` as one of its values.

Every value is compared with deep equality, and keys are ignored. The table must be a table; an optional message is appended on failure.

```lua
lu.assertTableContains({ "a", "b", "c" }, "b")
```
]]),
                    entry("luaunit.assertNotTableContains", "luaunit.assertNotTableContains(table, expected [, message])", "function",
                        "Assert that a table does not contain expected entries.",
                        [[
Assert that table `t` does not contain `expected` as any of its values.

Values are compared with deep equality. An optional message is appended on failure.
]]),
                    entry("luaunit.fail", "luaunit.fail([message])", "function",
                        "Fail the current test.",
                        [[
Fail the current test immediately with `message`, or with a generic failure message when it is omitted.

The function raises an error through LuaUnit, so it is normally used inside a test function to report an unexpected branch.
]]),
                    entry("luaunit.failIf", "luaunit.failIf(condition [, message])", "function",
                        "Fail when a condition is true.",
                        [[
Fail the current test when `condition` is truthy.

`nil` and `false` do nothing. An optional message is used in the failure report.

```lua
lu.failIf(#items == 0, "expected at least one item")
```
]]),
                    entry("luaunit.skip", "luaunit.skip([message])", "function",
                        "Skip the current test.",
                        [[
Skip the current test and mark it as skipped rather than failed.

An optional message explains why the test was skipped. Execution of the test stops at the call.
]]),
                    entry("luaunit.skipIf", "luaunit.skipIf(condition [, message])", "function",
                        "Skip when a condition is true.",
                        [[
Skip the current test when `condition` is truthy.

`nil` and `false` let the test continue. An optional message is reported with the skipped test.
]]),
                    entry("luaunit.success", "luaunit.success()", "function",
                        "End the current test successfully.",
                        [[
Mark the current test as successful and stop executing it.

This is rarely needed because a test that returns normally succeeds. It is useful for early exits from tests that intentionally inspect multiple paths.
]]),
                    entry("luaunit.setVerbosity", "luaunit.setVerbosity(level)", "function",
                        "Set the runner verbosity.",
                        [[
Set the default verbosity used by later `run()` calls.

Values are integers: `0` is quiet, `1` is low, `10` is the default, and `20` is verbose. The aliases `set_verbosity` and `SetVerbosity` are also provided.

```lua
local lu = require "luaunit"
lu.setVerbosity(0)
```
]]),
                }, { upstream = "https://github.com/bluebird75/luaunit", license = "BSD" }),

                module("serpent", "serpent", "Lua serializer and pretty printer.", [==[
`serpent.serialize(value [, options])` returns a Lua expression that recreates
the value.  `serpent.line` and `serpent.block` are convenience formatters.
]==], {
                    entry("serpent.serialize", "serpent.serialize(value [, options])", "function",
                        "Serialize a value to a Lua expression.",
                        [[
Serialize a Lua value into a Lua expression that reconstructs it.

The default output is single-line unless an `indent` option is supplied. Useful options include `name` (wrap the result in a local block), `compact`, `sortkeys`, `comment`, `nocode` (skip function bodies), `sparse`, and `maxlevel`. Shared and cyclic tables are handled with local references.

```lua
local serpent = require "serpent"
print(serpent.serialize({ 1, 2, answer = 42 }))
```
]]),
                    entry("serpent.line", "serpent.line(value [, options])", "function",
                        "Serialize a value on one line.",
                        [=[
Serialize a value on one line, with sorted keys and comments enabled by default.

Pass an options table to override defaults such as `sortkeys` or `comment`. The result is a Lua expression; it is not printed.

```lua
local serpent = require "serpent"
print(serpent.line({ b = 2, a = 1 })) --> {a=1,b=2} --[[table: ...]]
```
]=]),
                    entry("serpent.block", "serpent.block(value [, options])", "function",
                        "Serialize a value in block form.",
                        [[
Serialize a value in indented block form, using two spaces by default and sorting keys.

Comments and sorting are enabled unless overridden by the options table. This is the most readable form for nested data.

```lua
local serpent = require "serpent"
print(serpent.block({ list = { 1, 2, 3 } }))
```
]]),
                    entry("serpent.dump", "serpent.dump(value [, options])", "function",
                        "Serialize a value in compact form.",
                        [[
Return a compact serialization with the root named `_`, intended for debugging output.

The output uses compact tables and includes the shared-reference prologue when needed. Pass `{ print = true }`-style options only if your application handles them; this function itself returns a string and does not print.
]]),
                    entry("serpent.load", "serpent.load(string)", "function",
                        "Load a serialized value.",
                        [[
Load a value from text produced by `serpent.serialize`.

Returns `true, value` on success. On failure it returns `false, error_message` when the text compiled but evaluation failed, or `nil, syntax_error` when the text could not be compiled. The default environment permits table construction but not function calls.

```lua
local ok, value = require("serpent").load("{ 1, 2, name = 'x' }")
assert(ok)
print(value.name)
```
]]),
                }, { upstream = "https://github.com/pkulchenko/serpent", license = "MIT" }),
            },
        },

        {
            id = "tools",
            title = "Command line tools",
            source = "zli",
            modules = {
                module("tools", "tools", "Tools shipped in the ZLI payload.", [==[
Tools are started with `zli @name`.  Compiled executables can include the same
scripts in their payload.
]==], {
                    entry("@repl", "zli @repl", "tool", "Start the interactive REPL.", "Inside the REPL, `:help` shows the documentation index and `:help <name>` looks up an entry."),
                    entry("@sqlite", "zli @sqlite", "tool", "Start the SQLite CLI.", "The CLI starts with an in-memory database.  Commands include `open`, `close`, `file`, `mode table|csv|json|lua`, and `quit`."),
                    entry("@compile", "zli @compile <config>", "tool", "Package Lua files into a standalone executable.", "The config is a Lua table (or a `return { ... }` statement) with `output_name` and `files`."),
                    entry("@test", "zli @test <file>", "tool", "Run a LuaUnit test file."),
                    entry("@manual", "zli @manual [options]", "tool", "Serve the bundled reference manual.", "Options: `--port`, `--address`, `--no-open`, `--output <file>`."),
                    entry("@help", "zli @help [options] [query]", "tool", "Look up documentation.", "Options: `--list`, `--search`, `--markdown`, `--output`."),
                    entry("@serve", "zli @serve [directory]", "tool", "Serve a directory over HTTP.", "Defaults to the current directory."),
                }),
            },
        },

        {
            id = "zli_topics",
            title = "ZLI",
            source = "zli",
            modules = {
                module("ZLI", "ZLI runtime", "Interpreter globals and configuration.", [==[
The `ZLI` table is available to every script and REPL session.
]==], {
                    entry("ZLI.version", "ZLI.version", "field", "The ZLI version string."),
                    entry("ZLI.error_handling", "ZLI.error_handling", "field", "Default error style for libraries.", "Set to `\"raise\"` before `require` to make libraries raise instead of returning `nil, message`."),
                    entry("ZLI.exe_path", "ZLI.exe_path", "field", "The real path of the running executable."),
                    entry("ZLI.dofile", "ZLI.dofile(name)", "function", "Run a script from the payload."),
                    entry("zli.init", "~/.config/zli/init.lua", "topic", "User init script.", "Executed before every script and REPL session."),
                    entry("zli.repl_init", "~/.config/zli/repl_init.lua", "topic", "REPL init script.", "Executed only when the REPL starts."),
                    entry("zli.payload", "payload", "topic", "Embedded zip payload.", "The ZLI binary carries `main.lua`, tools and documentation in an appended zip payload.  `zli @name` selects a payload script by exact name or by `name.lua`; `@dir/name` is supported.  Compiled executables replace the payload with the files listed in their config."),
                    entry("zli.argv0", "argv[0] and payload selection", "topic", "How the executable name selects a payload script.", [==[When no tool or script is given, ZLI selects a payload entry from the executable basename: `<exe-name>.lua` first, then `main.lua`, then `init.lua`.  On Windows, a trailing `.exe` is stripped from the basename.

The basename comes from `argv[0]`, so symlinks with different names can select different payload tools from the same executable.  The payload zip itself is opened through the real executable path, so the binary also works when found through `PATH`.

The Lua `arg[0]` value remains the executable name used to invoke ZLI; the selected payload script is not substituted into the argument table.  This is also true for filesystem scripts: the script path is not reflected in `arg[0]`.]==]),
                    entry("zli.compile", "compiled executables", "topic", "Standalone executables created by `@compile`.", "A compiled executable replaces the standard payload with the files listed in its config."),
                }),
            },
        },
    },
}
