# ZLI library reference

<!-- Generated from doc/libraries.lua. Do not edit by hand. -->

All modules are loaded with `require`.

Libraries that support error handling return `nil, message` on failure by
default. Set `ZLI.error_handling = "raise"` before `require` to raise
instead. A loaded library can also be reconfigured in place:

```lua
local filesystem = require "filesystem"
filesystem:config { error_handling = "raise" }
```

Argument/type errors always raise. `zip`/`unzip` use their own error
returns and do not honor `ZLI.error_handling`.

The Lua language and standard-library reference is generated from the
Lua 5.5 manual and served by `zli @manual`; this file covers the bundled
ZLI, third-party and tool documentation.

## ZLI libraries

### auxiliary

Extra string, table, file and OS helpers.

The `auxiliary` module is loaded automatically.  It extends the standard
`string`, `table`, `io`, `os` and `math` tables and adds a few global helpers.

#### `arg_error(func, narg, message [, level])`

Raise a Lua argument error.

Raises `message` as a bad-argument error for argument `narg` of `func`.  `level` is passed to `error`.

#### `arg_check(func, narg, test, message)`

Raise an argument error when `test` is false.

Convenience wrapper around `arg_error`.  `func` and `narg` identify the offending argument.

#### `arg_check_type(func, narg, value, level, ...)`

Validate the type of an argument.

Accepts the value when its type is one of the types passed in `...`; otherwise raises an argument error.

#### `sorted_pairs(tbl [, comparator])`

Iterate a table in sorted key order.

Returns an iterator like `pairs`, sorted by key.  An optional comparator is passed to `table.sort`.

#### `lambda(source) / L(source)`

Create a Lua function from a short expression.

The global helper `lambda` and its aliases `L` and `string.L` compile a short lambda expression.  See the `string` helpers below.

#### `string.starts_with(value, prefix)`

Return true when a string starts with `prefix`.

Return true when the string begins with `prefix`.

The comparison is case-sensitive and literal, not a Lua pattern match. An empty prefix always matches.

```lua
print(("hello"):starts_with("he")) --> true
print(("hello"):starts_with("lo")) --> false
```

#### `string.ends_with(value, suffix)`

Return true when a string ends with `suffix`.

Return true when the string ends with `suffix`.

The comparison is case-sensitive and literal. An empty suffix always matches.

```lua
print(("hello"):ends_with("lo")) --> true
print(("hello"):ends_with("he")) --> false
```

#### `string.contains(value, needle)`

Return true when a string contains `needle`.

Return true when the string contains `needle`.

The search is plain text, so pattern characters such as `%` and `.` have no special meaning. Case is significant.

```lua
print(("hello"):contains("ell")) --> true
print(("hello"):contains("ELL")) --> false
```

#### `string.is_empty(value)`

Return true for `nil` or the empty string.

Return true when the value is `nil` or the empty string.

Any non-empty string returns false. This helper is convenient for validating optional string arguments.

```lua
print(""):is_empty()   --> true
print("x"):is_empty()  --> false
```

#### `string.is_not_empty(value)`

Return true for a non-nil, non-empty string.

Return true when the value is a non-nil, non-empty string.

The logical complement of `string.is_empty`. `nil` and `""` both return false.

```lua
print("x"):is_not_empty() --> true
print(""):is_not_empty()  --> false
```

#### `string.split(value [, separator])`

Split a string into multiple values.

Split a string into multiple return values.

`separator` defaults to a comma. The separator is literal text, not a Lua pattern, and may contain several characters. Empty fields are preserved, including leading and trailing ones.

```lua
local a, b, c = ("1,2,3"):split(",")
print(a, b, c) --> 1 2 3

local parts = table.pack(("a<>b"):split("<>"))
print(parts.n) --> 2
```

#### `string.to_table(value [, separator])`

Split a string into a table.

Split a string into an array using a literal separator.

`separator` defaults to a comma. Empty fields are preserved, and the function accepts multi-character separators. Use `string.split` when multiple return values are more convenient.

```lua
table.print(("1,2,3"):to_table()) --> { "1", "2", "3" }
```

#### `string.trim(value)`

Remove leading and trailing whitespace.

Remove leading and trailing whitespace from a string.

Whitespace includes spaces, tabs, carriage returns, newlines and NUL bytes. The argument must be a string; the result is a new string.

```lua
print(("  hello\n"):trim()) --> "hello"
```

#### `string.ltrim(value)`

Remove leading whitespace.

Remove leading whitespace from a string.

Spaces, tabs, carriage returns, newlines and NUL bytes are stripped from the start only. The trailing part of the string is left untouched.

```lua
print(("  hello  "):ltrim()) --> "hello  "
```

#### `string.rtrim(value)`

Remove trailing whitespace.

Remove trailing whitespace from a string.

Spaces, tabs, carriage returns, newlines and NUL bytes are stripped from the end only. The leading part of the string is left untouched.

```lua
print(("  hello  "):rtrim()) --> "  hello"
```

#### `string.base64encode(value)`

Encode a string as standard Base64.

Encode a string as standard Base64 using the `A-Z a-z 0-9 + /` alphabet and padding.

The argument must be a string. Binary data, including NUL bytes, is preserved. Use `base64urlEncode` when the result must be URL-safe.

```lua
print(("hello"):base64encode()) --> "aGVsbG8="
```

#### `string.base64decode(value)`

Decode a standard Base64 string.

Decode a standard Base64 string, returning the original bytes.

The input must use the standard Base64 alphabet with correct padding. Invalid input raises an error rather than returning a partial result.

```lua
print(("aGVsbG8="):base64decode()) --> "hello"
```

#### `string.base64urlEncode(value)`

Encode a string as URL-safe Base64.

Encode a string as URL-safe Base64 using the `-` and `_` characters in place of `+` and `/`.

Padding is included, so the result can be decoded with `base64urlDecode`. The input may contain arbitrary bytes.

```lua
print(("a+b/c?"):base64urlEncode())
```

#### `string.base64urlDecode(value)`

Decode a URL-safe Base64 string.

Decode a URL-safe Base64 string, accepting `-` and `_` as the last two alphabet characters.

Invalid input raises an error. Use `base64decode` for the standard alphabet.

```lua
print(("aGVsbG8="):base64urlDecode()) --> "hello"
```

#### `string.urlEncode(value)`

Percent-encode a string for use in a URL.

Percent-encode a string for use in a URL.

Letters, digits, `-`, `_`, `.` and `~` are left unchanged. Every other byte is replaced by `%XX` with uppercase hexadecimal digits, including spaces (which become `%20`).

```lua
print(("a b/c"):urlEncode()) --> "a%20b%2Fc"
```

#### `string.utf8len(value)`

Return the number of UTF-8 characters in a string.

Count the number of UTF-8 code points in a string.

The argument must be valid UTF-8; malformed input raises an error. The count is not the byte length: `"ÖÄÜ"` has length 3 even though it occupies more bytes.

```lua
print(("héllo"):utf8len()) --> 5
```

#### `table.copy(value [, copies])`

Deep-copy a table.

`copies` tracks already copied tables, which also makes the function safe for cyclic tables.

#### `table.tostring(value [, name])`

Pretty-print a table as a string.

Pretty-print a table as a Lua-like string and return it.

The output is produced by `serpent.block`, with sorted keys, four-space indentation and no comments. When `name` is supplied, the result is prefixed with `name = `.

```lua
print(table.tostring({ b = 2, a = { 1 } }))
```

#### `table.print(value [, name])`

Pretty-print a table to standard output.

Pretty-print a table to standard output.

This is equivalent to `print(table.tostring(value, name))`. The table is formatted with sorted keys and four-space indentation.

```lua
table.print({ b = 2, a = 1 }, "config")
```

#### `table.remove_if(value, predicate)`

Remove elements for which `predicate` is true.

Remove, in place, every array element for which `predicate(item)` is truthy.

The table is compacted and returned, so the original table keeps its identity. Non-array keys are not inspected.

```lua
local t = { 1, 2, 3, 4 }
table.remove_if(t, function(n) return n % 2 == 0 end)
--> t is { 1, 3 }
```

#### `table.filter(value, predicate)`

Return a new table with elements accepted by `predicate`.

Return a new array containing the elements for which `predicate(item)` is truthy.

The original table is not modified. Only the array part is visited, and the result is a new array with consecutive indexes.

#### `table.add_all(target, ...)`

Append all arguments to a table.

Append the given values to the end of a table and return that table.

Arguments that are tables are flattened one level: their array parts are appended element by element. Non-table arguments are appended directly. Non-array keys in table arguments are ignored.

```lua
local t = { 1 }
table.add_all(t, 2, { 3, 4 }, 5)
--> t is { 1, 2, 3, 4, 5 }
```

#### `table.insert_all(target, index, ...)`

Insert all arguments at a position.

Insert the given values into a table starting at `index`, shifting later elements right.

Table arguments are flattened one level, like `table.add_all`. The table is modified in place and returned.

```lua
local t = { 1, 4 }
table.insert_all(t, 2, 2, 3)
--> t is { 1, 2, 3, 4 }
```

#### `table.load(filename)`

Load a serialized table from a file.

Load a serialized table from a file and return the resulting value.

The file contents are prefixed with `return` and evaluated, so the file must contain a Lua expression rather than a statement list. `table.save` produces compatible files.

```lua
local value = table.load("config.lua")
```

#### `table.save(filename, value)`

Serialize a table to a file.

Serialize a table and write it to a file.

The output uses `table.tostring`, producing sorted keys, four-space indentation and no comments. The file is replaced if it already exists. The function returns nothing.

```lua
table.save("config.lua", { retries = 3, host = "localhost" })
```

#### `table.default(value, defaults [, error])`

Fill missing keys from a defaults table.

Returns `value`, with each missing key copied from `defaults`.  When `error` is true, unexpected keys raise an error.

#### `table.insert_sorted(value, item [, comparator])`

Insert an item while keeping a sorted table ordered.

Insert `item` into an already sorted array, keeping the array ordered.

The default comparator is `a < b`; pass a custom comparator as the third argument. The insertion position is found with a binary search, and the table is modified in place. The function returns nothing.

```lua
local t = {}
table.insert_sorted(t, 3)
table.insert_sorted(t, 1)
--> t is { 1, 3 }
```

#### `table.next(value)`

Iterator helper used by `stream`.

Return a stateless iterator over the array part of a table.

Each call to the iterator returns the next value, or `nil` when there are no more values. This is the iterator used internally by `stream` and is equivalent to `ipairs` for well-formed arrays.

```lua
for value in table.next { "a", "b" } do
    print(value)
end
```

#### `io.read_lines(filename)`

Read all lines from a file into a table.

Read a text file into an array of lines and return the array.

Line terminators are removed and empty lines are preserved. The file is opened read-only and closed before returning. An open failure raises an error through `assert`.

```lua
local lines = io.read_lines("data.txt")
print(lines[1])
```

#### `io.write_lines(filename, lines [, eol])`

Write a table of lines to a file.

Write an array of lines to a file, replacing any existing contents.

Each line is written followed by `eol`, which defaults to `"\n"`. The file is opened in binary write mode and closed afterwards. An open failure raises an error through `assert`.

```lua
io.write_lines("out.txt", { "one", "two" })
```

#### `io.read_file(filename)`

Read an entire file as a string.

Read an entire file as a string.

The file is opened in binary read mode and closed before returning. An open failure raises an error through `assert`, so check the path or wrap the call in `pcall` if missing files are expected.

#### `io.write_file(filename, data)`

Write a string to a file, replacing its contents.

Write a string to a file, replacing its previous contents.

The file is opened in binary write mode, the data is written, and the file is closed. An open failure raises an error through `assert`.

```lua
io.write_file("out.txt", "hello")
```

#### `io.append_file(filename, data)`

Append a string to a file.

Append a string to a file, creating the file if it does not exist.

The file is opened in append/update binary mode and closed afterwards. An open failure raises an error through `assert`.

#### `os.name`

Operating system name.

One of `windows`, `linux`, `macos`, or the platform name reported by the interpreter.

#### `os.home`

The current user's home directory.

The current user's home directory as a string, or `nil` when it cannot be determined.

On Windows the value is built from `HOMEDRIVE` and `HOMEPATH`; elsewhere it comes from `HOME`.

#### `os.is_windows`

True on Windows.

True when the interpreter is running on Windows, false on every other platform.

This is a boolean companion to the `os.name` string.

#### `os.is_linux`

True on Linux.

True when the interpreter is running on Linux, false on every other platform.

#### `os.is_mac`

True on macOS.

True when the interpreter is running on macOS, false on every other platform.

The field is named `is_mac` even though `os.name` uses the value `"macos"`.

#### `os.separator`

The platform path separator (`\` or `/`).

The platform's path separator: `\` on Windows and `/` elsewhere.

This is a one-character string intended for building paths, and it matches the separator used by the `filesystem` module.

#### `os.nanotime()`

Return a monotonic timestamp in nanoseconds.

Return a monotonic timestamp in nanoseconds.

The value is suitable for measuring elapsed time, not for displaying wall-clock dates. It is used by `timer` and `benchmark`.

```lua
local start = os.nanotime()
-- work
print(os.nanotime() - start)
```

#### `math.round(value)`

Round a number to the nearest integer.

Round a number to the nearest integer.

Exact halves are rounded to the nearest even integer (banker's rounding): `0.5` becomes `0`, `1.5` becomes `2`, and `-2.5` becomes `-2`. Non-half values round to the nearest integer. The argument must be a number.

```lua
math.round(2.4) --> 2
math.round(2.5) --> 2
math.round(42.6) --> 43
```

#### `math.maxdouble`

The largest finite double.

The largest finite IEEE-754 double-precision value, approximately `1.7976931348623157e308`.

This is a constant number, useful as an initial value for minimum searches.

#### `math.mindouble`

The smallest positive normalized double.

The smallest positive normalized IEEE-754 double-precision value, approximately `2.2250738585072014e-308`.

Denormalized values are smaller. This constant is useful as an initial value for maximum searches.

### benchmark

Small benchmark runner with nanosecond precision.

`benchmark.run(table [, iterations])` runs every function in a benchmark table and
prints per-run timings and memory use.

Special keys `before_all`, `before_each`, `after_each` and `after_all` are called
around the run.  A key `before_<name>` or `after_<name>` is called around the
matching benchmark function.  The optional `iterations` argument overrides the
`iter` field of the benchmark table (default 3).

#### `benchmark.run(bench [, iterations])`

Run a benchmark table and print the summary.

The benchmark table contains functions to measure plus optional setup and teardown hooks.

### collection

Java-style collections: lists, maps and sets.

`collection` provides `list`, `map` and `set` factories.  All collections support
`size`, `is_empty`, `add_all`, `remove_all`, `contains_all`, `equals`, `copy`,
`stream`, `union`, `intersection` and `difference`.  Lists and sets also support
`to_array`; use `map:values():to_array()` for maps.

#### `collection:size()`

Return the number of elements.

Return the number of elements in the collection.

The value is maintained by the collection implementation, so it is O(1) for lists, maps and sets. Use `#collection` where the metatable provides a length operator.

#### `collection:is_empty()`

Return true when the collection has no elements.

Return true when the collection contains no elements.

This is equivalent to `collection:size() == 0` and is O(1).

#### `collection:add_all(items)`

Add all items from another collection or table.

Add every element from another collection or table.

For a collection, its iterator is used, so values (not indexes) are added. For a plain table, the array part is traversed with `next`. Returns the collection itself for chaining.

```lua
local list = require("collection").list
local l = list:new():add_all { 1, 2 }
```

#### `collection:remove_all(items)`

Remove all items found in another collection or table.

Remove every element supplied by another collection or table.

For plain tables the array values are used. The return value follows the first removal attempt: it is true when that first item was present and removed, otherwise false. This means callers should not rely on the result as an "any removed" flag.

```lua
local set = require("collection").set
local s = set:new { 1, 2, 3 }
s:remove_all { 2, 3 }
```

#### `collection:contains_all(items)`

Return true when every item is present.

Return true when every element in the supplied collection or table is present in this collection.

The check stops at the first missing element. An empty input returns true. The input may be any collection or a plain array-like table.

#### `collection:equals(other)`

Compare two collections for equal contents.

Compare this collection with another collection or plain table for equal contents.

Every element of the other object must be contained in this one, and the element counts must match. Element order is not significant, and duplicate values are compared by simple membership.

```lua
local set = require("collection").set
local s = set:new { 1, 2 }
print(s:equals { 2, 1 }) --> true
```

#### `collection:copy()`

Return a shallow copy.

Return a shallow copy of the collection.

A new collection of the same kind is created with the current elements. The elements themselves are not copied, so nested tables are shared with the original. Ordered maps and sets are rebuilt through their ordinary constructor, so the copy may not preserve insertion order.

```lua
local l = list:new():add_all { { 1 }, 2 }
local copy = l:copy()
print(copy:get(1) == l:get(1)) --> true (same nested table)
```

#### `collection:stream()`

Return a `stream` over the collection.

Return a `stream` over the collection's elements.

The stream is built from the collection's iterator, so sets and ordered maps preserve their iteration order. The collection itself is not modified.

```lua
local sum = require("collection").list:new{1,2,3}:stream():sum()
```

#### `collection:union(...)`

Return the union with other collections.

Return a new collection containing this collection's elements plus all elements from the given collections or tables.

The receiver is not modified. The result is created with `self:new(self)`, so it has the same collection type. Ordered variants are rebuilt through their ordinary constructor and may not preserve insertion order. Duplicate values follow the rules of that type (sets deduplicate, lists keep duplicates).

#### `collection:intersection(...)`

Return the intersection with other collections.

Return a new collection containing only elements that are present in this collection and in every given collection or table.

The receiver is unchanged. The result is a copy of the receiver reduced with `retain_all` for each argument, so type-specific behavior is preserved, but ordered variants may lose insertion order.

#### `collection:difference(...)`

Return the difference with other collections.

Return a new collection containing the receiver's elements that are not present in any of the given collections or tables.

The receiver is unchanged. The result starts as a copy and removes each argument's elements in turn. Because the copy uses the ordinary constructor, ordered variants may lose insertion order.

#### `collection:to_array()`

Return the contents as an array.

Return the collection's elements as a plain array.

The array is built from `iterate_indexed`, so lists and sets produce consecutive indexes. The bundled map implementation does not define indexed iteration; use `map:values():to_array()` for maps instead of calling this method on a map.

```lua
local items = require("collection").list:new{ "a", "b" }:to_array()
--> { "a", "b" }
```

### collection.list

Ordered list collection.

A list is an ordered sequence.  Methods that mutate a list return the list, so
calls can be chained.

#### `collection.list.new([initial])`

Create a new list.

Create a new empty list, optionally populated from an array or another collection.

The initial values are added through `add_all`, so they become the list's elements in iteration order. A plain list keeps insertion order; use `new_sorted` for automatic sorting.

```lua
local list = require("collection").list
local l = list:new { "a", "b" }
print(l:size()) --> 2
```

#### `collection.list.new_sorted([initial [, comparator]])`

Create a list that keeps its elements sorted.

Create a list that keeps its elements in sorted order.

The optional comparator receives two values and returns true when the first sorts before the second; the default is `a < b`. The optional initial array or collection is inserted one element at a time in sorted position.

```lua
local list = require("collection").list
local l = list:new_sorted { "c", "a", "b" }
print(l:get(1)) --> "a"
```

#### `list:add([index,] item)`

Add one item, optionally at an index.

Add one item to the list, optionally at a 1-based index.

With one argument the item is appended, or inserted in sorted position for a sorted list. With two arguments the first is an index and the second is the item; inserting by index is not allowed in a sorted list. Passing more than two arguments raises an error. Returns the list.

```lua
local l = list:new():add("b"):add(1, "a")
--> { "a", "b" }
```

#### `list:add_all([index,] items)`

Add all items from a table or collection.

Add every item from an array or collection.

With one argument the items are appended (or inserted in sorted order for a sorted list). With two arguments the first is a starting index and the second is the collection; items are inserted from that index onward. Returns the list.

#### `list:clear([size])`

Remove all items.

Remove all items from the list and reset its size to zero.

The optional argument is a size or capacity hint; the bundled implementation accepts a number but does not preallocate storage. Passing a table clears the list and then adds that table's items. Other argument types raise an error. Returns the list.

```lua
local l = list:new { 1, 2, 3 }:clear()
print(l:is_empty()) --> true
```

#### `list:contains(item)`

Return true when the item is present.

Return true when the list contains the given value.

Comparison uses `==`, so table values are found by identity. The search is linear from the beginning of the list.

#### `list:get(index)`

Return the item at an index.

Return the item at a 1-based index, or `nil` when the index is outside the list.

A non-number index raises an argument error. Negative and zero indexes simply produce `nil`.

#### `list:set(index, item)`

Replace the item at an index.

Replace the item at a 1-based index and return the previous value.

A non-number index raises an argument error. Setting an index outside the current list stores the value there without changing the size; only `add` maintains the list length.

#### `list:index_of(item)`

Return the first index of an item, or 0.

Return the 1-based index of the first occurrence of an item, or `0` when it is absent.

Comparison uses `==`. The alias semantics are those of a linear forward search.

```lua
local l = list:new { "a", "b", "a" }
print(l:index_of("a")) --> 1
print(l:index_of("z")) --> 0
```

#### `list:last_index_of(item)`

Return the last index of an item, or 0.

Return the 1-based index of the last occurrence of an item, or `0` when it is absent.

The whole list is scanned, with later matches replacing earlier ones.

#### `list:remove(item)`

Remove the first occurrence of an item.

Remove the first occurrence of an item from the list.

Returns true when an item was removed and false when it was not found. Later elements shift down to fill the gap, and the size is decremented.

#### `list:remove_index(index)`

Remove the item at an index.

Remove the item at a 1-based index.

The list is compacted and its size is decremented. Returns the list itself, not the removed value, so the call can be chained.

```lua
local l = list:new { "a", "b", "c" }:remove_index(2)
--> { "a", "c" }
```

#### `list:retain_all(items)`

Keep only items present in another collection.

Keep only items that are present in another collection or array-like table.

The list is modified in place, preserving the relative order of survivors, and is returned. A plain table is converted to a set for fast membership tests.

#### `list:sublist(from, to)`

Return a new list containing the given range.

Return a new list containing the inclusive range from `from` through `to`.

Both indexes must be numbers. The result is a new list; the original is unchanged. Values outside the list's current range may leave holes, so callers should pass valid indexes.

```lua
list:new{ "a", "b", "c" }:sublist(2, 3):to_array() --> { "b", "c" }
```

#### `list:for_each(func)`

Call `func` for every item.

Call `func(item)` for every item in list order.

Returns the list for chaining. Mutating the list during iteration has unspecified results.

#### `list:for_each_index(func)`

Call `func(index, item)` for every item.

Call `func(index, item)` for every item, with 1-based indexes.

Returns the list for chaining. This is useful when the position matters as well as the value.

```lua
list:new{ "a", "b" }:for_each_index(function(i, v) print(i, v) end)
```

#### `list:iterate()`

Return an iterator over items.

Return an iterator over the list's values.

Each call returns the next value, or `nil` at the end. Values are produced in array order.

```lua
for value in list:new{ "a", "b" }:iterate() do print(value) end
```

#### `list:iterate_indexed()`

Return an iterator over indexes and items.

Return an iterator over indexes and values.

Each call yields a 1-based index followed by the corresponding value. This is a thin wrapper over `ipairs` on the internal array.

#### `list:iterator(func)`

Call a function for every item until it returns false.

Call `func(item)` for every item until the callback returns `false` or `nil`.

Returns true when every callback returned a non-false value, false when iteration stopped early. This is a traversal helper, not an iterator factory.

```lua
local ok = list:new{ 1, 2, 3 }:iterator(function(v) return v < 3 end)
--> false
```

#### `list:iterator_indexed(func)`

Call an indexed function for every item until it returns false.

Call `func(index, item)` for every item until the callback returns `false` or `nil`.

Returns true when every callback returned a non-false value, false when iteration stopped early.

### collection.map

Key-value map collection.

Maps preserve key/value associations and provide ordered variants through
`new_ordered`.

#### `collection.map.new([initial])`

Create a new map.

Create a map from an optional table or existing map.

A plain table's key/value pairs are copied; an existing map's entries are copied through `put_all`. Iteration follows native table order. Use `new_ordered` when insertion order matters.

```lua
local map = require("collection").map
local m = map:new { a = 1, b = 2 }
print(m:get("a")) --> 1
```

#### `collection.map.new_ordered([initial])`

Create a map that iterates in insertion order.

Create a map that remembers insertion order for iteration.

The optional initial table or map is copied in its iteration order. Updating an existing key keeps its original position; removing and re-inserting a key moves it to the end.

```lua
local map = require("collection").map
local m = map:new_ordered { a = 1, b = 2 }
m:put("c", 3)
for k in m:iterate() do print(k) end --> a, b, c
```

#### `map:put(key, value)`

Associate a key with a value.

Associate `key` with `value` and return the previous value for that key, or `nil`.

If `value` is `nil`, the key is removed instead of stored. Adding a new non-nil key increments the size; in an ordered map it is appended to the insertion order.

```lua
local m = map:new()
print(m:put("a", 1)) --> nil
print(m:put("a", 2)) --> 1
```

#### `map:get(key)`

Return the value for a key, or nil.

Return the value associated with `key`, or `nil` when the key is absent.

Because `nil` is also used for missing entries, `contains_key` is the reliable existence test.

#### `map:get_or_default(key, default)`

Return a value or a default.

Return the value for `key`, or `default` when the key is absent.

A stored `false` value is returned as `false`, not replaced by the default.

#### `map:put_all(table)`

Copy all key/value pairs from a table or map.

Copy all key/value pairs from a plain table or another map into this map.

A collection argument must be a map; other collection types raise an argument error. Existing keys are overwritten, and the map itself is returned.

```lua
local m = map:new():put_all { a = 1, b = 2 }
```

#### `map:put_if_absent(key, value)`

Insert a key only when it is not present.

Insert `value` only when `key` is not already present.

Returns `nil` when the value was inserted, or the existing value when the key was already present. A `nil` value is not inserted. Ordered maps append newly inserted keys.

#### `map:remove(key [, value])`

Remove a key, optionally only when it has a given value.

Remove `key`, optionally only when its current value equals `value`.

With one argument, returns the removed value, or `nil` when the key was absent. With two arguments, returns true when the value matched and was removed, false when it did not, and `nil` when the key was absent. Removing the last key shrinks the size; ordered maps also remove it from the order.

#### `map:merge(key, value, func)`

Merge a value into an existing key using `func`.

Merge a new value into `key` using a callback.

When the key exists, `func(key, value, old_value)` computes the replacement and `func` is required. When the key is absent, `value` is stored as-is and the callback is not called. Returns the final value, which may be `nil` to remove the key.

```lua
local m = map:new()
m:merge("count", 1) --> 1
m:merge("count", 2, function(_, new, old) return new + old end) --> 3
```

#### `map:replace(key, old, new)`

Replace a value when it currently equals `old`.

Replace an existing value, in either conditional or unconditional form.

`m:replace(key, old, new)` replaces the value only when it currently equals `old`, and returns the old value. `m:replace(key, value)` sets the key to `value` unconditionally; if `value` is `nil`, the key is removed. In both forms the previous value is returned, or `nil` when the key was absent.

#### `map:contains_key(key)`

Return true when a key exists.

Return true when the map has a non-nil value for `key`.

This is the correct existence check when values may legitimately be `false`.

#### `map:contains_value(value)`

Return true when a value exists.

Return true when any entry in the map has the given value.

Comparison uses `==`, so table values are matched by identity rather than deep content. The search is linear.

#### `map:entry_set()`

Return the entries as a set.

Return a set of tables, one per entry, each with `key` and `value` fields.

The set contains newly created entry tables, not references to the map. Entries are added to the set in the map's iteration order, but the returned value is an ordinary set.

```lua
for entry in map:new{ a = 1 }:entry_set():iterate() do
    print(entry.key, entry.value)
end
```

#### `map:key_set()`

Return the keys as a set.

Return a set containing every key in the map.

The returned set is independent of the map; modifying it does not affect the map. Iteration order follows the source map.

#### `map:values()`

Return the values as a collection.

Return a list containing every value in the map.

Values appear in the map's iteration order: insertion order for ordered maps, native table order otherwise. The returned list is independent of the map.

#### `map:equals(other)`

Compare two maps for equal contents.

Compare this map with another map or plain table for equal key/value pairs.

A collection argument must be a map with the same size. Every key in the other object must exist here with an equal (not deep-equal) value, and the total counts must match.

#### `map:compute(key, func)`

Compute a new value for a key.

Compute a new value for `key` with `func(key, old_value)` and store the result.

The callback is called even when the key is absent, with `nil` as the old value. If it returns `nil`, the key is removed; otherwise the value is stored. The computed value is returned.

#### `map:compute_if_absent(key, func)`

Compute a value only when the key is absent.

Compute and store a value only when `key` is absent.

The callback receives the key and its return value is stored when non-nil. If the key already exists, the existing value is returned without calling the callback.

```lua
local m = map:new()
print(m:compute_if_absent("a", function() return "A" end)) --> "A"
print(m:compute_if_absent("a", function() return "Z" end)) --> "A"
```

#### `map:compute_if_present(key, func)`

Compute a value only when the key is present.

Recompute a value only when `key` is present.

The callback receives `(key, old_value)`. A non-nil result replaces the value; `nil` removes the key. Returns the new value, or `nil` when the key was absent.

#### `map:for_each(func)`

Call `func(key, value)` for every entry.

Call `func(key, value)` for every entry in the map.

Iteration follows insertion order for ordered maps and native table order otherwise. Returns the map for chaining.

#### `map:iterate()`

Return an iterator over keys and values.

Return an iterator yielding `key, value` pairs.

Ordered maps iterate in insertion order; ordinary maps use `pairs`. Returns the standard iterator triple suitable for a generic `for` loop.

```lua
for key, value in map:new{ a = 1 }:iterate() do print(key, value) end
```

#### `map:iterator(func)`

Call a function for every entry until it returns false.

Call `func(key, value)` for every entry until the callback returns `false` or `nil`.

Returns true when all callbacks returned a non-false value, false when iteration stopped early. This is a traversal helper, not an iterator factory.

#### `map:size()`

Return the number of entries.

Return the number of key/value entries in the map.

The count is maintained by `put` and `remove`, so it is O(1) and does not scan the table.

#### `map:is_empty()`

Return true when the map has no entries.

Return true when the map contains no entries.

This is equivalent to `map:size() == 0`.

### collection.set

Set collection with optional insertion order.

A set stores unique values.  `new_ordered` preserves insertion order during
iteration.

#### `collection.set.new([initial])`

Create a new set.

Create a set from an optional initial collection or array-like table.

Duplicate values are stored only once, and element order follows the native table iteration order unless `new_ordered` is used. The initial table is copied, not referenced.

```lua
local set = require("collection").set
local s = set:new { 1, 2, 2, 3 }
print(s:size()) --> 3
```

#### `collection.set.new_ordered([initial])`

Create an insertion-ordered set.

Create a set that preserves insertion order during iteration.

The optional initial collection or array is added in order. Removing and re-adding a value places it at the end of the order. Use `iterate`, `iterate_indexed` or `for_each` to observe the order.

```lua
local s = require("collection").set:new_ordered { "b", "a" }
s:add("c")
for v in s:iterate() do print(v) end --> b, a, c
```

#### `set:add(item)`

Add one unique value.

Add a value to the set and return the set.

Adding a value that is already present leaves the set unchanged. `nil` is not a valid set element and raises an argument error, as does passing more than one value. Use `set:add_all` to add several items at once.

```lua
local s = require("collection").set:new()
s:add("x"):add("x") --> size remains 1
```

#### `set:remove(item)`

Remove a value.

Remove a value from the set.

Returns true when the value was present and removed, false otherwise. Removing an absent value is harmless. Ordered sets keep the relative order of their remaining values.

#### `set:contains(item)`

Return true when a value is present.

Return true when the set contains the given value.

Lookup is a direct table-key test, so it is O(1) on average. Values must be valid Lua table keys.

#### `set:retain_all(items)`

Keep only values also present in another collection.

Keep only values that are also present in the supplied collection or table.

The set is modified in place and returned. For ordered sets, the surviving values retain their insertion order. Plain array-like tables and other collections are both accepted.

#### `set:for_each(func)`

Call `func(value)` for every value.

Call `func(value)` for every value in the set.

The iteration order is insertion order for ordered sets and native table order otherwise. Returns the set for chaining. Mutating the set during iteration has unspecified results.

#### `set:iterate()`

Return an iterator over values.

Return an iterator over the set's values.

Each call to the iterator returns the next value, or `nil` when exhausted. Ordered sets preserve insertion order; ordinary sets follow native table order.

```lua
for value in set:new{ "a", "b" }:iterate() do print(value) end
```

#### `set:iterate_indexed()`

Return an iterator over indexes and values.

Return an iterator over indexes and values.

Each call yields a consecutive 1-based index and the corresponding value. Ordered sets iterate their insertion-order array; ordinary sets count values in native table order.

#### `set:iterator(func)`

Call a function for every value until it returns false.

Call `func(value)` for every value until the callback returns `false` or `nil`.

Returns true when every callback returned a non-false value, false when iteration stopped early. This is a traversal helper, not an iterator factory.

```lua
local s = require("collection").set:new { 1, 2, 3 }
local ok = s:iterator(function(v) return v < 3 end) --> false, because 3 fails the predicate
```

#### `set:iterator_indexed(func)`

Call an indexed function for every value until it returns false.

Call `func(index, value)` for every value until the callback returns `false` or `nil`.

Returns true when every callback returned a non-false value, false when iteration stopped early. Indexes start at 1.

#### `set:size()`

Return the number of values.

Return the number of unique values in the set.

The count is maintained as values are added and removed, so it is O(1) and does not scan the set.

#### `set:is_empty()`

Return true when the set is empty.

Return true when the set contains no values.

This is equivalent to `set:size() == 0`.

### crossline

Readline, screen, cursor, history and paging helpers.

Upstream: https://github.com/jcwangxp/Crossline

License: MIT

`crossline` is a small self-contained readline replacement.  The module exposes
the low-level screen and cursor helpers plus history and paging functions used by
the REPL.

#### `crossline.readline(prompt)`

Read a line with editing and history.

#### `crossline.set_prompt_color(color)`

Set the prompt colour.

#### `crossline.set_color(color)`

Set the current output colour.

Use values from `crossline.color.fg` and `crossline.color.bg`.

#### `crossline.print_paged(text)`

Print long text through the pager.

#### `crossline.screen.dimensions()`

Return the terminal width and height.

Returns a table with `x` and `y` fields.

#### `crossline.screen.clear()`

Clear the terminal screen.

#### `crossline.cursor.get()`

Return the current cursor position (`x`, `y`).

#### `crossline.cursor.set(x, y)`

Move the cursor to a position.

#### `crossline.cursor.move(x, y)`

Move the cursor relative to its current position.

#### `crossline.cursor.hide()`

Hide the cursor.

#### `crossline.cursor.show()`

Show the cursor.

#### `crossline.history.save(filename)`

Save the command history.

#### `crossline.history.load(filename)`

Load the command history.

#### `crossline.history.show()`

Print the command history.

#### `crossline.history.clear()`

Clear the command history.

#### `crossline.paging.start()`

Start paging output.

#### `crossline.paging.stop()`

Stop paging output.

#### `crossline.paging.check()`

Check whether paging is active.

#### `crossline.paging.print(text)`

Print text through the pager.

### filesystem

Filesystem and path manipulation.

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

#### `fs.cwd() / fs.current_directory()`

Return the current working directory.

Return the absolute path of the current working directory as a string. The path is resolved through the operating system, so it has no trailing separator and no `.` or `..` components.

On failure the function follows the module's error-handling mode: it returns `nil, message` by default, or raises when `fs:config { error_handling = "raise" }` was applied.

```lua
local fs = require "filesystem"
print(fs.cwd())
```

#### `fs.create_path(path, name)`

Create a path object from a directory and file name.

Build a path object from a directory part and a final name, without normalizing either component.

`path` is stored in the `path` field, `name` in the `name` field, and the joined result in `full_path`. A separator is inserted when `path` does not already end with one. Both arguments must be strings.

```lua
local p = require("filesystem").create_path("src", "version")
print(p.full_path) --> "src/version"
print(p.name)      --> "version"
```

#### `fs.path(...)`

Normalize components into a path object.

Accepts strings, path objects and path component tables.  Relative paths stay relative; paths beginning with `.` or `..` are resolved against the current directory.

#### `fs.ensure_path(path)`

Return a path object, converting a string when needed.

Return a path object for `path`. A string is converted with `fs.path`; a table that already has a `full_path` field is returned unchanged.

Any other value raises an error, regardless of the module error-handling mode, because the check protects later filesystem calls from malformed path objects.

#### `fs.get_path(path)`

Return the underlying path string of a path object.

Return the path string stored in a path object, or the argument itself when it is already a string.

The function only extracts the value; it does not check existence or normalize the path. It is useful when passing a path object to another library.

```lua
local fs = require "filesystem"
local p = fs.path("src/version")
print(fs.get_path(p)) --> "src/version"
```

#### `fs.absolute(path)`

Return the absolute path, or nil when it does not exist.

Resolve `path` to its absolute, canonical form, following symbolic links. The path must exist.

Returns `nil` when the path cannot be resolved, for example because it is missing or a component is not accessible. It does not raise in the default error-handling mode.

```lua
local fs = require "filesystem"
print(fs.absolute("src/version"))
```

#### `fs.concat_path(path, file)`

Join a path with a file name.

Join a directory path and a file name without normalizing the result.

`path` may be a string or an array of components; component arrays are joined with `fs.separator`. If `file` is `nil` or empty, `path` is returned unchanged. A separator is added when `path` does not already end in `/` or `\`.

```lua
local fs = require "filesystem"
print(fs.concat_path("src", "main.lua")) --> "src/main.lua"
```

#### `fs.split_path(path)`

Split a path into components.

Split a path into its slash- or backslash-separated components and return them as an array.

Separators and repeated separators are discarded, but `.` and `..` components are preserved. A leading root separator or drive letter is not included in the result.

```lua
local fs = require "filesystem"
table.print(fs.split_path("/usr/local/bin")) --> { "usr", "local", "bin" }
```

#### `fs.create_tree(path)`

Create a directory and all missing parents.

Create `path` and every missing parent directory. Existing directories are left alone, so the call is idempotent.

`path` may be a string or a path object. Directory creation errors follow the module's error-handling mode.

```lua
local fs = require "filesystem"
fs.create_tree("build/cache/data")
```

#### `fs.delete_tree(path)`

Delete a directory tree recursively.

Recursively delete a directory tree, including the directory named by `path` itself.

Children are removed before their containing directory, and symbolic-link cycles are not followed. Deletion errors follow the module's error-handling mode.

```lua
require("filesystem").delete_tree("build/cache")
```

#### `path:list()`

Return the directory entries as an array of path objects.

Return the entries of a directory as an array of path objects. The returned paths are absolute, with `path` set to the directory and `name` set to the entry name.

`path` may be a path object or a string; with no argument the current directory is listed. Directory-open and traversal errors follow the module's error-handling mode.

```lua
local fs = require "filesystem"
for _, entry in ipairs(fs.path("src"):list()) do
    print(entry.name)
end
```

#### `path:dir()`

Return the directory entries keyed by name.

Return the entries of a directory as a table keyed by entry name. Each value is a path object whose `full_path` points at the entry.

This is the keyed counterpart of `path:list()`. Errors are reported according to the module's error-handling mode.

```lua
local fs = require "filesystem"
local entries = fs.path("src"):dir()
print(entries["main.lua"].full_path)
```

#### `fs.iterate(path [, sorted])`

Iterate the entries of a directory.

Iterate the entries of a directory, yielding the entry name and its path object.

By default the order is the native directory order. Pass `true` as `sorted` to iterate names in sorted order. This is normally used as `for name, entry in fs.iterate(path) do ... end` or `path:iterate()`.

```lua
local fs = require "filesystem"
for name, entry in fs.path("src"):iterate(true) do
    print(name, entry.full_path)
end
```

#### `fs.walk(path, func [, dir_first])`

Walk a directory tree, calling `func(path)` for each entry.

Walk a directory tree, calling `func(path)` once for every entry, including the starting path.

When `dir_first` is true, a directory is passed to `func` before its children. Otherwise children are visited first and the directory is reported on the way out. Symbolic-link targets are resolved and each real directory is visited at most once, which prevents cycles.

A string path must exist; the function then walks its absolute form. Errors opening or traversing a directory follow the module's error-handling mode.

```lua
local fs = require "filesystem"
fs.walk("src", function(path)
    print(path.full_path)
end, true)
```

#### `fs.tree(path [, dir_first])`

Return all paths in a directory tree.

Return every path in a directory tree as an array, including the starting directory.

The order matches `fs.walk`: children before their directory by default, or directories first when `dir_first` is true. The starting path must exist.

```lua
local fs = require "filesystem"
local paths = fs.tree("src", true)
print(#paths)
```

#### `fs.tree_size(path)`

Return the total size of files in a tree.

Return the combined size in bytes of all regular files below `path`. Directories and symbolic links do not add to the total.

The starting path is included in the walk, so a regular file passed directly contributes its own size. Errors follow the module's error-handling mode.

#### `fs.tree_size_hr(path)`

Return a human-readable tree size.

Return the total size of a directory tree formatted by `fs.size_to_hr`, for example `"12.40 KB"`.

This is a convenience wrapper around `fs.tree_size(path)`; it uses the same walk and error behavior.

#### `fs.stream(path)`

Create a stream over directory entries.

Create a `stream` over the directory entries returned by `fs.list(path)`.

The stream yields path objects in native directory order. It does not recurse; use `fs.stream_tree` for a recursive stream.

```lua
local fs = require "filesystem"
local names = fs.path("src"):stream():map(function(p) return p.name end):toarray()
```

#### `fs.stream_tree(path [, dir_first])`

Create a stream over a directory tree.

Create a `stream` over all paths returned by `fs.tree(path, dir_first)`.

`dir_first` controls whether directories are yielded before their children, matching the corresponding `fs.walk` option. The stream includes the starting path.

```lua
local fs = require "filesystem"
local count = fs.stream_tree("src"):filter(function(p) return p:is_file() end):count()
```

#### `fs.read_all(path)`

Read an entire file as a string.

Read an entire file as a string and return it. The file is opened in text mode and closed before returning.

On failure the function follows the module's error-handling mode and returns `nil, message` by default. The path may be a string or a path object.

```lua
local text = require("filesystem").read_all("src/version")
```

#### `fs.read_lines(path [, mode])`

Read a file into an array of lines.

Read a file into an array of lines. `mode` is passed to the underlying `file:lines` call and defaults to `"l"` (line without the terminator). Use `"L"` to keep newline characters.

On failure the function returns `nil, message` by default, or raises in raise mode.

```lua
local lines = require("filesystem").read_lines("src/version")
print(lines[1])
```

#### `fs.lines(path [, mode])`

Iterate the lines of a file.

Iterate the lines of a file, yielding a 1-based index and the line text.

The optional `mode` is passed to `file:read` and defaults to `"l"` (line without its terminator); use `"L"` to keep newline characters. The file is closed automatically when the loop finishes. An open failure follows the module's error-handling mode.

```lua
local fs = require "filesystem"
for i, line in fs.lines("src/version") do
    print(i, line)
end
```

#### `fs.parent(path)`

Return the parent path.

Return the parent directory of `path` as a path object, or `nil` when there is no parent.

Trailing separators are ignored. A root or drive root has no parent. A relative single-component path such as `"file"` resolves to the current directory because `fs.path(".")` is used as its parent.

```lua
local fs = require "filesystem"
print(fs.path("src/main.lua"):parent().full_path) --> "src"
```

#### `fs.child(path, name)`

Return a child path.

Return a new path object formed by joining `path` and `name`. No existence check is performed.

`name` must be a non-empty string; otherwise the function raises an error. The result is normalized by `fs.path`.

```lua
local fs = require "filesystem"
print(fs.path("src"):child("version").full_path) --> "src/version"
```

#### `fs.sibling(path, name)`

Return a sibling path.

Return a path in the same directory as `path` but with `name` as its final component. No existence check is performed.

A missing or empty name raises an error. For a path without a separator, the result is simply `fs.path(name)`.

```lua
local fs = require "filesystem"
print(fs.path("src/version"):sibling("main.lua").full_path)
```

#### `fs.to_relative(path, base [, include_top])`

Return a path relative to a base path.

Return `path` expressed relative to `base`. Relative inputs are first resolved to absolute paths, so they must exist.

When `include_top` is true, the parent of `base` is used as the anchor, so `base` itself appears in the result. A trailing `/` is added when the result names a directory. If `path` is not below the anchor, its normalized full path is returned unchanged.

```lua
local fs = require "filesystem"
print(fs.to_relative("test/temp", "test")) --> "temp/"
```

#### `fs.is_empty(path)`

Return true when a directory has no entries.

Return true when the directory named by `path` contains no entries. The path is converted with `fs.ensure_path` first.

The directory must exist and be readable. A failed listing raises a Lua error even in the default return-error mode, because the failure value is not a directory listing.

#### `fs.chmod(path, mode)`

Change file permissions on Linux.

Change a path's permissions on Linux using an octal mode string such as `"755"` or `"644"`.

The path may be a string or a path object. Returns true when the `chmod` command succeeds. It returns false on non-Linux systems, when the mode contains anything other than octal digits, or when the command fails. The function never raises.

```lua
local fs = require "filesystem"
assert(fs.chmod("script.sh", "755"))
```

#### `fs.chown(path, owner)`

Change file ownership on Linux.

Change the owner of a file or directory on Linux using the system `chown` command.

`owner` is a string such as `"user"`, `"user:group"` or `"1000:1000"`; only letters, digits, `_`, `.`, `:`, and `-` are accepted. Returns true on success and false on non-Linux systems, invalid input, or command failure. It never raises.

#### `fs.size_to_hr(bytes)`

Format a byte count as a human-readable size.

Format a byte count as a human-readable string using binary units (`KB`, `MB`, `GB`, `TB`).

Values below 1024 are returned as an integer followed by `" B"`; larger values use two decimal places. The argument must be an integer, otherwise an argument error is raised.

```lua
local fs = require "filesystem"
print(fs.size_to_hr(2048)) --> "2.00 KB"
```

#### `fs:config(options)`

Configure a loaded filesystem module.

Accepts `{ error_handling = "return" | "raise" }` and returns the same module table.

#### `path:exists()`

Return true when the path exists.

Return true when the path names an existing file or directory, and false otherwise.

The check is a direct open attempt, so permission failures and broken symbolic links also produce false. It does not raise for a missing path.

#### `path:is_file()`

Return true for a regular file.

Return true when the path currently refers to a regular file.

The path is examined with a stat call; missing paths and other filesystem errors follow the module's error-handling mode.

#### `path:is_directory()`

Return true for a directory.

Return true when the path currently refers to a directory.

The path is examined with a stat call; missing paths and other filesystem errors follow the module's error-handling mode.

#### `path:size()`

Return the file size in bytes.

Return the size of the file or directory in bytes as an integer.

The value comes from the platform stat call. A missing path or stat failure follows the module's error-handling mode.

#### `path:size_hr()`

Return a human-readable size.

Return the size of the path formatted with binary units, such as `"4.20 MB"`.

This combines `path:size()` with `fs.size_to_hr`; stat errors follow the module's error-handling mode.

#### `path:stat()`

Return file metadata.

Return a table of metadata for the path. The table always contains `is_file`, `is_directory`, `size`, `size_hr`, `create_time`, `create_time_ms`, `create_time_stamp`, `modify_time`, `modify_time_ms`, `modify_time_stamp`, `mode` and `mode_flags`.

When the platform reports an access time, `access_time`, `access_time_ms` and `access_time_stamp` are also present. The `create_time` fields reflect the platform's creation/change timestamp and may have platform-specific semantics. A stat failure follows the module's error-handling mode.

```lua
local st = require("filesystem").path("src/version"):stat()
print(st.size, st.mode_flags)
```

#### `path:access_time()`

Return the last access time.

Return the last access time as a Unix timestamp in seconds, or `nil` when the platform does not report it.

Stat errors follow the module's error-handling mode.

#### `path:create_time()`

Return the creation time.

Return the platform's creation/change time as a Unix timestamp in seconds.

On POSIX systems this is usually the inode change time (`ctime`), not the original creation time. Stat errors follow the module's error-handling mode.

#### `path:modify_time()`

Return the last modification time.

Return the last modification time as a Unix timestamp in seconds.

Stat errors follow the module's error-handling mode.

#### `path:access_time_ms()`

Return access time in milliseconds.

Return the last access time as a Unix timestamp in milliseconds, or `nil` when the platform does not expose an access time.

Stat errors follow the module's error-handling mode.

#### `path:create_time_ms()`

Return creation time in milliseconds.

Return the platform's creation/change time in milliseconds since the Unix epoch.

This is the millisecond form of `path:create_time()`; stat errors follow the module's error-handling mode.

#### `path:modify_time_ms()`

Return modification time in milliseconds.

Return the last modification time in milliseconds since the Unix epoch.

This is the millisecond form of `path:modify_time()`; stat errors follow the module's error-handling mode.

#### `path:access_time_stamp()`

Return a formatted access timestamp.

Return the last access time formatted as `YYYY/MM/DD HH:MM:SS` in local time, or `nil` when no access time is available.

Stat errors follow the module's error-handling mode.

#### `path:create_time_stamp()`

Return a formatted creation timestamp.

Return the platform's creation/change time formatted as `YYYY/MM/DD HH:MM:SS` in local time.

This is the formatted form of `path:create_time()`; stat errors follow the module's error-handling mode.

#### `path:modify_time_stamp()`

Return a formatted modification timestamp.

Return the last modification time formatted as `YYYY/MM/DD HH:MM:SS` in local time.

This is the formatted form of `path:modify_time()`; stat errors follow the module's error-handling mode.

#### `path:mode()`

Return the file mode.

Return the file permission bits as an integer, directly from the platform stat call.

Use `path:mode_flags()` for a readable `drwxr-xr-x`-style string. Stat errors follow the module's error-handling mode.

#### `path:mode_flags()`

Return the file mode flags.

Return the file type and permissions as a POSIX-style 10-character string, for example `"-rw-r--r--"` or `"drwxr-xr-x"`.

On Windows the permission bits are reported as all enabled. Stat errors follow the module's error-handling mode.

#### `path:open([mode])`

Open the file and return a file handle.

Open the path with `io.open` and return a Lua file handle plus the usual second result from `io.open`.

`mode` defaults to `"r"`. A missing file or permission failure therefore returns `nil, message` exactly as `io.open` does.

```lua
local p = require("filesystem").path("src/version")
local f = assert(p:open("r"))
print(f:read("a"))
f:close()
```

#### `path:rename(new_path) / path:mv(new_path)`

Rename or move the path.

Rename or move the path to `new_path`. The aliases `path:mv` and `fs`-style names refer to the same operation.

The destination may be a string or a path object. On success there is no return value; errors follow the module's error-handling mode.

#### `path:delete() / path:rm()`

Delete the file or empty directory.

Delete the file or empty directory named by the path. Non-empty directories are not removed recursively; use `path:delete_tree()` for that.

The aliases `path:rm` and `path:delete` are equivalent. Errors follow the module's error-handling mode.

#### `path:change_directory() / path:cd()`

Change the current directory to this path.

Change the process working directory to this path. The aliases `path:cd` and `path:change_directory` are equivalent.

The path must be an existing directory. Errors follow the module's error-handling mode; on success there is no return value.

#### `path:create_directory() / path:mkdir()`

Create the directory.

Create this directory as a single filesystem operation. Missing parents are not created and an existing directory is an error; use `fs.create_tree` for recursive creation.

The aliases `path:mkdir` and `path:create_directory` are equivalent. Errors follow the module's error-handling mode.

#### `path:read_all()`

Read the file as a string.

Read the file named by the path as a string.

This is the method form of `fs.read_all`; open and read errors follow the module's error-handling mode.

#### `path:read_lines([mode])`

Read the file into an array of lines.

Read the file named by the path into an array of lines. The optional `mode` is passed to `file:lines` and defaults to `"l"`.

This is the method form of `fs.read_lines`; open and read errors follow the module's error-handling mode.

#### `path:lines([mode])`

Iterate the lines of the file.

Iterate the lines of the file named by the path, yielding `index, line`.

The optional `mode` defaults to `"l"`; use `"L"` to keep line terminators. The underlying file is closed automatically when iteration finishes. Open errors follow the module's error-handling mode.

```lua
local p = require("filesystem").path("src/version")
for i, line in p:lines() do
    print(i, line)
end
```

#### `path:iterate([sorted])`

Iterate directory entries.

Iterate the directory entries, yielding entry names and path objects. Pass `true` as `sorted` for name order; the default is native directory order.

This is the method form of `fs.iterate`; directory errors follow the module's error-handling mode.

#### `path:delete_tree()`

Delete the directory tree.

Recursively delete this directory tree, including the directory itself.

This is the method form of `fs.delete_tree`; deletion errors follow the module's error-handling mode.

#### `path:walk(func [, dir_first])`

Walk the directory tree.

Walk this directory tree, calling `func(path)` for each entry including the starting directory.

`dir_first` controls whether a directory is reported before or after its contents. Symbolic-link cycles are avoided by visiting each real directory once.

```lua
require("filesystem").path("src"):walk(function(p)
    if p:is_file() then print(p.full_path) end
end)
```

#### `path:parent()`

Return the parent path.

Return the parent directory as a path object, or `nil` at a filesystem root.

This is the method form of `fs.parent`; trailing separators are ignored and relative single-component paths resolve against the current directory.

#### `path:child(name)`

Return a child path.

Return a new path object formed by appending `name` to this path.

`name` must be a non-empty string. The result is normalized; no existence check is made.

#### `path:sibling(name)`

Return a sibling path.

Return a path in the same directory with `name` as its final component.

A missing or empty name raises an error. No existence check is performed.

#### `path:stream()`

Create a stream over directory entries.

Create a `stream` over this directory's entries.

The stream yields path objects from `fs.list`; it does not recurse. Directory errors follow the module's error-handling mode.

#### `path:stream_tree([dir_first])`

Create a stream over the tree.

Create a `stream` over this directory tree, including the starting path.

`dir_first` controls whether directories are yielded before their contents. The stream is built from `fs.tree`.

```lua
local files = require("filesystem").path("src"):stream_tree():filter(function(p)
    return p:is_file()
end):count()
```

#### `path:tree([dir_first])`

Return the tree as an array of paths.

Return every path in this directory tree as an array, including the starting directory.

`dir_first` controls the order. The path must exist; otherwise errors follow the module's error-handling mode.

#### `path:to_relative(base [, include_top])`

Return a relative path.

Return this path expressed relative to `base`, optionally including `base` itself when `include_top` is true.

Both paths are resolved to absolute paths first, so relative inputs must exist. A trailing `/` is added for directories. If the path is not below the anchor, its normalized full path is returned.

```lua
local fs = require "filesystem"
print(fs.path("test/temp"):to_relative("test")) --> "temp/"
```

#### `path:chmod(mode)`

Change permissions.

Change this path's permissions on Linux using an octal mode string such as `"755"` or `"644"`.

Returns true on success and false on non-Linux systems, invalid modes, or command failure. It never raises.

```lua
local p = require("filesystem").path("script.sh")
p:chmod("755")
```

#### `path:chown(owner)`

Change ownership.

Change this path's owner on Linux. `owner` is a user name, `user:group` pair, or numeric uid/gid pair.

Returns true on success and false on non-Linux systems, invalid input, or command failure. It never raises.

### grid

Line-drawing text grids (tables).

`grid.new(config [, rows])` creates a text table.  `config` is an array of column
definitions: `{ name, align, min_width, max_width, fixed_width }`.  The table
configuration may also set `show_header` and `padding`.

#### `grid.new(config [, rows])`

Create a grid.

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

#### `grid:add_row(...) / grid:add_row(table)`

Add a row of values.

Add a row of values to the grid.

Values may be passed as separate arguments or as one array table. Each value is converted with `tostring`, and column widths grow to fit the content up to each column's `max_width`. The row is stored for later rendering; the method returns nothing.

```lua
local g = require("grid").new { { name = "item" }, { name = "qty" } }
g:add_row("apple", 3)
```

#### `grid:add_rows(rows)`

Add multiple rows.

Add multiple rows to the grid.

`rows` must be an array of rows, where each row is itself an array of cell values (or a single table passed to `add_row`). Each row is added with `grid:add_row`; the method returns nothing.

#### `grid:header_string()`

Return the header lines.

Return the rendered header block as a string.

The block contains the top border and, when `show_header` is enabled, the header row. If the grid has no rows yet, this also initializes the column widths used by later row rendering.

#### `grid:row_string(...)`

Return one rendered row.

Return one rendered row as a string, including the separator border.

The values are formatted but not stored in the grid. If this is the first rendering call, the header block is included before the border and the row.

```lua
print(g:row_string("banana", 5))
```

#### `grid:last_string()`

Return the bottom border.

Return the bottom border of the grid as a string.

Column widths are calculated first if they have not been initialized. This is the same border printed by `grid:print_last` and appended by `grid:tostring`.

#### `grid:print_header()`

Print the header.

Print the header block returned by `grid:header_string`.

The output includes the top border and, when configured, the header row.

#### `grid:print_row(...)`

Print one row.

Print one rendered row returned by `grid:row_string`.

The values are formatted for display but are not added to the grid's stored rows.

#### `grid:print_last()`

Print the bottom border.

Print the bottom border of the grid.

This is equivalent to `print(grid:last_string())`; the return value is that of `print`.

#### `grid:tostring()`

Render the complete table as a string.

Render the complete grid as a string.

The result includes the top border, optional header row, all stored rows with separator borders, and the bottom border. The grid's `__tostring` metamethod calls this method, so `tostring(grid)` works too.

```lua
local g = require("grid").new { { name = "name" } }
g:add_row("value")
print(g:tostring())
```

### httpclient

HTTP client based on Zig's HTTP client.

Every request function returns `response, body`.  `response` contains the status
line, headers and convenience fields.  On transport failure the functions return
`nil, message` unless `options.raiseError` is set.

Options include `header`, `query`, `parseJson`, `basicAuth`, `save` and
`raiseError`.  A table body is encoded as JSON automatically.

#### `httpclient.get(url [, options [, body]])`

Perform a GET request.

#### `httpclient.head(url [, options [, body]])`

Perform a HEAD request.

#### `httpclient.post(url [, options [, body]])`

Perform a POST request.

#### `httpclient.put(url [, options [, body]])`

Perform a PUT request.

#### `httpclient.patch(url [, options [, body]])`

Perform a PATCH request.

#### `httpclient.delete(url [, options [, body]])`

Perform a DELETE request.

#### `httpclient.call(method, url [, options [, body]])`

Perform a request with an explicit method.

#### `httpclient:config(options)`

Configure a loaded httpclient module.

### httpserver

HTTP server based on Zig's HTTP server.

`httpserver.serve(options)` starts a server.  Options include `address`, `port`,
`web_root`, `cache_web_root`, method route tables (`GET`, `POST`, ...) and a
`*` route table used for every method.

A route value may be a response string or a function `(options, request)`
returning a string, a response table, or a table that is encoded as JSON.
Request tables contain `method`, `target`, `version`, `header`, `body` and
other request metadata.  Responses use `{ status, body, header }`.

#### `httpserver.serve(options)`

Start an HTTP server.

#### `httpserver:config(options)`

Configure a loaded httpserver module.

#### `httpserver.serve_file(path)`

Serve a file from disk.

#### `httpserver.resolve_web_path(root, target)`

Resolve a URL path inside a web root.

#### `httpserver.content_type(filename)`

Look up a MIME type by file extension.

#### `httpserver.cache(func [, time])`

Cache a route handler's result.

#### `httpserver.status`

HTTP status code table.

#### `httpserver.cache_free_cycle([seconds])`

Set the cache expiry cycle.

#### `httpserver.free_cache([cycle])`

Free expired cache entries.

#### `httpserver.clear_cache()`

Clear the content cache.

### log

Simple logging library.

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

#### `log:fatal(message)`

Log a fatal message.

#### `log:error(message)`

Log an error message.

#### `log:warn(message)`

Log a warning.

#### `log:info(message)`

Log an informational message.

#### `log:debug(message)`

Log a debug message.

#### `log:trace(message)`

Log a trace message.

#### `log:setLevel(level)`

Set the logger level.

#### `log:setAppender(appender)`

Replace the logger appender.

#### `log:addAppender(appender)`

Add an appender.

#### `log.level`

Logger level constants.

#### `log.appender`

Built-in appenders: `stdout`, `file`, `none`.

### luastrip

Lua source stripper/compactor.

`luastrip` removes comments and unnecessary whitespace while preserving Lua
semantics.  Malformed or unterminated input is handled without aborting the
interpreter.

#### `luastrip.string(source)`

Strip a Lua source string.

Remove comments and unnecessary whitespace from a Lua source string and return the compacted source.

The stripper preserves token boundaries and string literals. Malformed or unterminated input is handled without crashing the interpreter; the function may return a partially stripped string or an error according to the module's error-handling mode.

```lua
local luastrip = require "luastrip"
print(luastrip.string("local a = 1 -- note")) --> "local a=1"
```

#### `luastrip.file(input, output)`

Strip a Lua source file into another file.

Read a Lua source file, strip comments and unnecessary whitespace, and write the result to another file.

Returns `true` on success. `input` and `output` may be path objects or strings. I/O and stripping errors follow the module's error-handling mode (`nil, message` by default, or a raised error in raise mode).

#### `luastrip:config(options)`

Configure a loaded luastrip module.

Configure a loaded `luastrip` module and return it.

The options table accepts `error_handling = "return"` or `"raise"`. The setting controls whether `luastrip.string` and `luastrip.file` return errors or raise them.

```lua
local luastrip = require("luastrip"):config { error_handling = "raise" }
```

### memoize

Function result memoization.

`memoize(func)` returns a wrapper that caches results.  Cache keys are the
arguments; cached values are held weakly.

### stream

Functional-style streams inspired by Java streams.

`stream(iterator)` wraps an iterator, table or function.  Most operations return a
new stream; terminal operations consume it.

Named functions can be passed as strings when a function has been registered with
the `lambda` helper.

#### `stream(iterator)`

Create a stream from an iterator, table or function.

Create a stream from an iterator, an array-like table, or a Lua iterator function.

A table containing a `next` field is treated as an existing stream and wrapped directly; any other table is iterated over its array part with `table.next`. A function may be passed with its state and control values as additional arguments. A non-function, non-table value becomes a one-element stream.

```lua
local stream = require "stream"
print(stream({ 1, 2, 3 }):sum()) --> 6
for n in stream(ipairs { "a", "b" }) do print(n) end
```

#### `stream():of(...)`

Create a stream from values.

Create a stream over the values passed as arguments. The method is available on a stream instance, so the usual form is `stream():of(...)`.

The values are stored in an array and iterated in order. This is a convenient alternative to writing `stream { ... }`.

```lua
local stream = require "stream"
print(stream():of(1, 2, 3):concat(",")) --> "1,2,3"
```

#### `stream:map(func)`

Transform each value.

Return a lazy stream that applies `func` to every value.

The function may be a Lua function or a string accepted by the `lambda` helper. `false` results are treated as ordinary values, not as end-of-stream. The source stream is consumed as the mapped stream is consumed.

```lua
stream({ 1, 2, 3 }):map(function(n) return n * 2 end):toarray() --> { 2, 4, 6 }
```

#### `stream:peek(func)`

Inspect each value without changing it.

Return a lazy stream that calls `func(value)` for each value and passes the original value through unchanged.

This is intended for debugging or side effects. `func` may be a function or a registered lambda string.

#### `stream:filter(func)`

Keep values accepted by `func`.

Return a lazy stream containing only values for which `func(value)` is truthy.

The stream pulls values from its source until it finds a match, so filters can be chained efficiently. `false` and `nil` are rejected; other values are kept.

```lua
stream({ 1, 2, 3, 4 }):filter(function(n) return n % 2 == 0 end):toarray() --> { 2, 4 }
```

#### `stream:skip(count)`

Skip the first `count` values.

Skip the first `count` values and return the same stream, now positioned after them.

This operation is eager: it consumes the skipped values immediately. Negative counts behave like zero.

```lua
stream({ 1, 2, 3, 4 }):skip(2):toarray() --> { 3, 4 }
```

#### `stream:limit(count)`

Limit the stream to `count` values.

Return a stream that yields at most `count` values from the source.

The limit is applied lazily and the source is not advanced beyond the requested values until another value is requested. A count of zero produces an empty stream.

#### `stream:reverse()`

Reverse the remaining values.

Consume the remaining values and return a new stream that yields them in reverse order.

The entire source is read into memory first, so this cannot be used on an infinite stream. The original stream is exhausted by the call.

#### `stream:sort([comparator])`

Sort the remaining values.

Consume the remaining values and return a new stream sorted by the optional comparator.

The default comparator is `a < b`. Sorting requires reading the whole source into memory, so the original stream is exhausted.

```lua
stream({ 3, 1, 2 }):sort():toarray() --> { 1, 2, 3 }
```

#### `stream:maptonumber()`

Convert each value to a number.

Return a lazy stream that converts each value with `tonumber`.

Values that cannot be converted become `nil`; because `nil` also marks the end of a stream, a failed conversion effectively terminates that stream.

#### `stream:distinct()`

Drop duplicate values.

Return a lazy stream that drops duplicate values, keeping the first occurrence of each.

Duplicate detection uses the value itself as a table key, so values must be usable as Lua table keys. Encounter order is preserved.

#### `stream:split(func)`

Split into matching and non-matching streams.

Split the stream into two lazy streams according to a predicate.

The first stream yields values for which `func(value)` is truthy; the second yields the remaining values. Both streams share the same source, so consuming one advances the other. Pull values from both in parallel for predictable results.

```lua
local odd, even = stream({ 1, 2, 3, 4 }):split(function(n) return n % 2 == 1 end)
print(odd:concat(","))  --> "1,3"
print(even:concat(",")) --> "2,4"
```

#### `stream:join(...)`

Concatenate streams.

Return a lazy stream that concatenates this stream with the given streams.

The extra arguments must be stream objects. Each stream is consumed in turn. This is useful for chaining the two results of `split` back together.

```lua
local a, b = stream({ 1, 2 }):split(function(n) return n == 1 end)
print(a:join(b):concat(",")) --> "1,2"
```

#### `stream:foreach(func)`

Consume the stream, calling `func` for each value.

Consume the stream, calling `func(value)` for every value.

This is a terminal operation: the source is exhausted. It returns nothing. `func` may be a function or a registered lambda string.

#### `stream:toarray()`

Consume the stream into an array.

Consume the stream and return its values as a new array in encounter order.

This is a terminal operation. `false` values are retained; only `nil` ends the stream.

#### `stream:tosortedarray([comparator])`

Consume into a sorted array.

Consume the stream into an array and sort it with the optional comparator.

The default comparator is `a < b`. This is a terminal operation, and the entire stream is read into memory.

```lua
stream({ "b", "a" }):tosortedarray() --> { "a", "b" }
```

#### `stream:print()`

Print each value.

Consume the stream, printing each value with `print`.

This is a terminal operation intended for quick inspection. Like `toarray`, it exhausts the source.

#### `stream:concat([separator])`

Join values into a string.

Consume the stream and join its values into a string.

`separator` is passed to `table.concat` and defaults to an empty string. Non-string values must be convertible by `table.concat`.

```lua
stream({ 1, 2, 3 }):concat("-") --> "1-2-3"
```

#### `stream:allmatch(func)`

Return true when every value matches.

Return true when every value in the stream satisfies `func`, and false as soon as one does not.

An empty stream returns true. This is a terminal operation, but it stops early on the first non-match.

#### `stream:firstmatch(func)`

Return the first matching value.

Return the first value for which `func(value)` is truthy, or `nil` when none matches.

Matching stops at the first hit. This is a terminal operation and leaves earlier values consumed.

#### `stream:nonmatch(func)`

Return true when no value matches.

Return true when no value in the stream satisfies `func`.

This is the negation of `stream:anymatch`; it stops at the first match. An empty stream returns true.

#### `stream:anymatch(func)`

Return true when any value matches.

Return true when at least one value in the stream satisfies `func`, and false otherwise.

Evaluation stops at the first match. This is a terminal operation.

#### `stream:first()`

Return the first value.

Return the first value of the stream, or `nil` when the stream is empty.

This consumes one value, plus any values skipped by earlier lazy stages.

#### `stream:last()`

Return the last value.

Consume the stream and return its final value, or `nil` when it is empty.

The entire source is read to find the last value.

#### `stream:count()`

Count the remaining values.

Consume the stream and return the number of remaining values.

This is implemented as a reduction and reads the whole source.

#### `stream:sum()`

Sum numeric values.

Consume the stream and return the sum of its numeric values.

An empty stream produces `0`. Non-numeric values cause an arithmetic error.

#### `stream:average()`

Average numeric values.

Consume the stream and return the arithmetic mean of its numeric values.

An empty stream returns `0`; otherwise the result is the sum divided by the count.

#### `stream:median()`

Median numeric value.

Consume the stream and return its median after sorting the values.

For an even number of values the two middle values are averaged. An empty stream returns `0`. The optional argument is accepted for compatibility but is not used.

#### `stream:iterator()`

Return the underlying iterator.

Return the underlying iterator function for this stream.

The iterator yields one value per call and returns `nil` when exhausted. Passing it to `stream` wraps the remaining values in a new stream object.

#### `stream:collector(func)`

Apply a collector function.

Call a collector function with the stream's iterator and return the collector's result.

`func` receives the underlying `next` function and can consume it in any way. A string lambda may also be supplied. This is a terminal operation if the collector consumes the iterator.

#### `stream:reduce(state, func)`

Fold the stream into a value.

Fold the remaining values into an accumulator and return the final state.

`func(state, value)` is called for every value, starting with `state`. The function may be a function or a registered lambda string. An empty stream returns the initial state unchanged.

```lua
stream({ 1, 2, 3 }):reduce(0, function(sum, n) return sum + n end) --> 6
```

#### `stream:min([comparator])`

Return the minimum value.

Consume the stream and return its minimum value using the optional comparator.

The default comparator is `a < b`. An empty stream returns `nil`.

```lua
stream({ 4, 1, 3 }):min() --> 1
```

#### `stream:max([comparator])`

Return the maximum value.

Consume the stream and return its maximum value using the optional comparator.

The default comparator is `a < b`. An empty stream returns `nil`.

```lua
stream({ 4, 1, 3 }):max() --> 4
```

#### `stream:groupby(func)`

Group values by a key function.

Consume the stream and group values into a plain table keyed by `func(value)`.

Each key maps to an array of the values that produced it. The function may be a function or a registered lambda string. This is a terminal operation.

```lua
local groups = stream({ "ant", "ape", "bee" }):groupby(function(s) return s:sub(1, 1) end)
print(#groups.a) --> 2
```

### tar

Read and write tar archives.

The tar module supports uncompressed tar plus gzip, xz and zstd-compressed tar
files when the corresponding support is available.

`tar.open(filename)` returns a reader.  `tar.create(filename)` returns a writer.
`tar.extract(archive, destination)` extracts an archive.

#### `tar.open(filename)`

Open a tar archive for reading.

Returns an iterator function.  Iterate with `for entry in tar.open(path) do ... end`.

#### `tar.create(filename)`

Create a tar archive for writing.

#### `tar.extract(filename, destination)`

Extract an entire archive into a directory.

The archive may be plain tar or compressed with gzip, xz or zstd.

#### `tar:config(options)`

Configure a loaded tar module.

#### `writer:setRoot(root)`

Set the root directory written into the archive.

#### `writer:add_dir(path)`

Add a directory entry.

#### `writer:add_file(path [, archive_path])`

Add a file.

#### `writer:add_file_bytes(path, data)`

Add a file from memory.

#### `writer:add_link(path, target)`

Add a symbolic link.

#### `writer:close()`

Finish and close the archive.

#### `entry.name`

The path stored in the archive.

#### `entry.type`

The tar entry type (`file`, `directory`, `sym_link`, ...).

#### `entry.size`

Uncompressed size in bytes.

#### `entry.size_hr`

Human-readable size.

#### `entry.link_name`

Symbolic-link target.

#### `entry.mode_flags`

POSIX mode string.

#### `entry.is_file`

True for a regular file.

#### `entry.is_directory`

True for a directory.

#### `entry.is_link`

True for a symbolic link.

#### `entry:bytes()`

Read the current regular file into a string.

#### `entry:extract(destination)`

Extract the current regular file.

### timer

Nanosecond timer.

`timer.new([start])` creates a timer and optionally starts it immediately.
Timers use `os.nanotime` and are monotonic.

#### `timer.new([start])`

Create a timer.

Create a nanosecond-resolution timer backed by the monotonic `os.nanotime` clock.

When `start` is truthy the timer is started immediately; otherwise call `timer:start()` before measuring. The object exposes the timer methods and a `laps` array.

```lua
local timer = require "timer"
local t = timer.new(true)
-- work
print(t:stop())
```

#### `timer:start()`

Start or restart the timer.

Start or restart the timer, using the current monotonic time as the new origin.

Returns the timer object. Existing lap timestamps and the previous stop time are not cleared; call `timer:reset()` for a completely fresh timer.

#### `timer:lap()`

Record a lap and return the lap time.

Record a lap at the current time and return the duration since the previous lap, or since the start for the first lap.

The timestamp is appended to `timer.laps`. The timer must have been started. Returns a duration in nanoseconds.

#### `timer:stop()`

Stop the timer and return the elapsed time.

Stop the timer at the current time and return the elapsed duration since it was started.

The stop time is remembered by `timer:time()`. Stopping again updates the stop time and the reported duration.

#### `timer:time()`

Return the last measured time.

Return the last measured `stop - start` duration, or `nil` if the timer has not been stopped.

Starting the timer again does not immediately change this value; it changes when `stop()` is called again.

#### `timer:elapsed()`

Return the time since the timer started.

Return the duration from the start time to now, without stopping the timer.

Returns `nil` when the timer has not been started. The value is in nanoseconds and comes from the monotonic clock.

#### `timer:lap_elapsed()`

Return the time since the last lap.

Return the time elapsed since the most recent lap, or since the start when no lap has been recorded.

The timer is not stopped and no lap is recorded. Calling this before `timer:start()` is an error.

#### `timer:reset()`

Reset the timer and its laps.

Clear the start time, stop time and all recorded laps.

The timer becomes unstarted, so `timer:time()` and `timer:elapsed()` return `nil` until `start()` is called again. The function does not return the timer.

### uuid

UUID generation.

The `uuid` module generates RFC 9562 UUIDs.  `uuid.v4()` generates a random
UUID and `uuid.v7()` a time-ordered UUID.

#### `uuid.v4()`

Generate a version 4 (random) UUID.

Generate a version 4 (random) UUID and return it as a lowercase 36-character string.

The version and variant bits are set according to RFC 9562. Each call uses random data, so values are not ordered.

```lua
local uuid = require "uuid"
print(uuid.v4()) --> "f47ac10b-58cc-4372-a567-0e02b2c3d479" (example)
```

#### `uuid.v7()`

Generate a version 7 (time-ordered) UUID.

Generate a version 7 (time-ordered) UUID and return it as a lowercase 36-character string.

The first 48 bits contain a Unix millisecond timestamp, so UUIDs created in the same millisecond share a prefix and later values generally sort after earlier ones. Random bits fill the remainder.

```lua
local uuid = require "uuid"
local id = uuid.v7()
```

### xlsxmlwriter

Simple Excel XML writer.

`require "xlsxmlwriter"` returns a constructor.  Calling it with a filename
creates a workbook object.

```lua
local workbook = require("xlsxmlwriter")("book.xml")
workbook:newSheet("Data")
workbook:addRow { "name", 42, { year = 2026, month = 10, day = 23 } }
workbook:close()
```

#### `workbook:newSheet([name])`

Start a new worksheet.

Start a new worksheet in the workbook, closing the current worksheet first.

If `name` is omitted, a name such as `"Sheet1"` is generated from the sheet count. The name is XML-escaped. Returns the workbook object so calls can be chained.

```lua
local workbook = require("xlsxmlwriter")("book.xml")
workbook:newSheet("Data")
```

#### `workbook:closeSheet()`

Close the current worksheet.

End the current row, if one is open, and close the current worksheet.

If no worksheet is open the call does nothing. Returns the workbook for chaining.

#### `workbook:nextRow(...)`

Start a new row, optionally with cells.

End any open row and start a new row, optionally filling it with cells.

Additional arguments are passed to `workbook:cells`. The row counter is incremented and the workbook is returned.

```lua
workbook:nextRow("name", "count")
```

#### `workbook:endRow()`

End the current row.

Close the currently open row.

If no row is open the call does nothing. Returns the workbook for chaining.

#### `workbook:addRow(values)`

Add a complete row from a table.

Add a complete row from an array of cell values.

The table is unpacked and passed to `nextRow`, so nested arrays are not flattened and the table must be an array. Returns the workbook.

```lua
workbook:addRow { "alice", 42 }
```

#### `workbook:cells(...)`

Append cells to the current row.

Append one or more cell values to the current row, opening a row first if necessary.

Each value is written by `workbook:cell`. Returns the workbook.

#### `workbook:addCells(values)`

Append cells from a table.

Append all values from an array table to the current row.

The table is unpacked and passed to `cells`. Returns the workbook.

#### `workbook:cell(value)`

Append a single cell.

Append a single value to the current row, opening a row if needed.

Strings become string cells and numbers become numeric cells. A table with `year`, `month` and `day` becomes a date cell; adding `hour`, `min` and `sec` makes it a date-time cell; a table with only the time fields becomes a time cell. Other values are converted with `tostring` and written as strings. XML special characters are escaped.

```lua
workbook:cell("text"):cell(3.14):cell { year = 2026, month = 10, day = 24 }
```

#### `workbook:close()`

Finish the workbook and close the file.

Close the current worksheet, write the closing workbook tag, and close the output file.

After this call the workbook should not be used further. Returns the workbook object.

### zip

Create zip archives.

Upstream: https://zlib.net/

License: MIT

`zip.create(filename)` creates a zip archive.  The writer supports files,
in-memory data, directories and nested archives.  `zip.add_directory` adds a
filesystem directory tree.

#### `zip.create(filename)`

Create a zip archive for writing.

#### `zip.open(filename)`

Open an existing zip archive for appending.

#### `zip.create_after(filename)`

Create a zip archive after existing file data.

#### `zip.add_directory(writer, path [, include_top [, level]])`

Add a directory tree to an archive.

#### `zip.level`

Compression level constants.

#### `writer:add_file(path [, archive_path [, level]])`

Add a file.

#### `writer:create_directory(path)`

Add a directory entry.

#### `writer:open(path)`

Open an entry for streaming writes.

#### `writer:write(data)`

Write data to the current entry.

#### `writer:close()`

Close the current entry.

#### `writer:close_zip()`

Finish and close the archive.

### unzip

Read and extract zip archives.

Upstream: https://zlib.net/

License: MIT

`unzip.open(filename)` returns an archive object.  Archives expose entries as
tables with `name`, `path`, `full_path`, `is_file`, `is_directory`, sizes,
timestamps and `extract`.

#### `unzip.open(filename)`

Open a zip archive.

#### `unzip.extract(archive, destination)`

Extract an archive to a directory.

#### `archive:list()`

Return entries as an array.

#### `archive:dir()`

Return entries keyed by path.

#### `archive:info()`

Return archive information.

#### `archive:extract(destination)`

Extract the archive.

#### `archive:read_all(name)`

Read an entry as a string.

#### `archive:lines(name)`

Iterate the lines of an entry.

#### `archive:payload_start()`

Return the offset of an appended zip payload.

#### `archive:close()`

Close the archive.

#### `entry:read_all()`

Read the entry as a string.

#### `entry:lines()`

Iterate the entry's lines.

#### `entry:extract(destination)`

Extract the entry.

## Third-party libraries

### argparse

Feature-rich command-line parser.

Upstream: https://github.com/luarocks/argparse

License: MIT

`argparse` is a feature-rich command-line parser inspired by Python's argparse.
The entry point is `argparse(name, description)`.

```lua
local parser = require("argparse")("myprog", "does something useful")
parser:argument("input", "input file")
parser:flag("-v --verbose", "verbose output")
local args = parser:parse()
```

#### `parser:argument(name [, description [, default]])`

Add a positional argument.

#### `parser:option(name [, description [, default]])`

Add an option.

#### `parser:flag(name [, description])`

Add a boolean flag.

#### `parser:command(name [, description])`

Add a subcommand.

#### `parser:mutex(...)`

Create a mutually exclusive group.

#### `parser:group(name, ...)`

Create an argument group.

#### `parser:parse([args])`

Parse command-line arguments.

#### `parser:pparse([args])`

Parse arguments, returning an error message instead of raising.

#### `parser:get_usage()`

Return the generated usage string.

#### `parser:get_help()`

Return the generated help text.

#### `parser:add_help_command([value])`

Add a help command.

#### `parser:add_complete([value])`

Add shell completion support.

#### `parser:get_bash_complete()`

Generate a bash completion script.

#### `parser:get_zsh_complete()`

Generate a zsh completion script.

#### `parser:get_fish_complete()`

Generate a fish completion script.

#### `parser:error(message [, ...])`

Raise a parser error.

#### `argument:args(...)`

Set or get the argument's target names.

#### `argument:count(count)`

Set how many values the argument consumes.

#### `argument:default(value)`

Set the default value.

#### `argument:target(name)`

Set the result field name.

#### `argument:convert(func)`

Set a value conversion function.

#### `argument:choices(...)`

Restrict values to a set of choices.

#### `argument:argname(name)`

Set the display name in help output.

#### `argument:show_default(boolean)`

Control whether the default is shown in help.

#### `argument:hidden(boolean)`

Hide the argument from help output.

#### `argument:overwrite(boolean)`

Control overwriting of repeated results.

### F

String interpolation inspired by Python f-strings.

Upstream: https://github.com/dsidirop/f-strings

License: MIT

`require "F"` returns a tagged string function.  Expressions inside `{}` are
evaluated and formatted.

```lua
local F = require "F"
print(F"1 + 2 = {1 + 2}")
```

### csv (ftcsv)

Fast CSV parser and writer.

Upstream: https://github.com/FourierTransformer/ftcsv

License: MIT

`require "csv"` is the bundled `ftcsv` library.  It parses CSV strings and files
and encodes Lua tables as CSV.

#### `csv.parse(input [, delimiter [, options]])`

Parse CSV data.

Parse a CSV file or string and return an array of rows plus the final header list.

`input` is normally a filename. Set `options.loadFromString = true` to parse the string directly. The delimiter must be one character and defaults to `,`.

With the default `headers = true`, each row is a table keyed by the header row. Set `headers = false` to receive arrays. Other options include `rename` (map original headers to new names), `fieldsToKeep`, `headerFunc`, and `ignoreQuotes`.

```lua
local csv = require "csv"
local rows = csv.parse("a,b\n1,2\n", ",", { loadFromString = true })
print(rows[1].a, rows[1].b) --> 1 2
```

#### `csv.parseLine(line [, delimiter [, options]])`

Parse a single CSV line.

Parse a CSV file incrementally and return an iterator over its rows.

Each iteration yields a 1-based row number and the parsed row (a table when `headers` is true, otherwise an array). The first result may include the header row depending on the options.

Options are the same as `csv.parse`, except that `loadFromString` is not supported and `bufferSize` may be set to control the read chunk size. A buffer that is too small for a row raises an error.

```lua
local csv = require "csv"
for i, row in csv.parseLine("data.csv") do
    print(i, row.name)
end
```

#### `csv.encode(table [, delimiter [, options]])`

Encode a table as CSV.

Encode an array of row tables as a CSV string.

Headers are taken from the keys of the first row (sorted), or from `options.fieldsToKeep`. By default every field is quoted and rows end with `\r\n`. Options include `allowMissingKeys`, `onlyRequiredQuotes`, and `encodeNilAs`.

```lua
local csv = require "csv"
local text = csv.encode({ { name = "alice", age = 30 }, { name = "bob", age = 41 } })
print(text)
```

### lpeg

Parsing Expression Grammars for Lua.

Upstream: https://www.inf.puc-rio.br/~roberto/lpeg/

License: MIT

LPeg provides pattern matching and parsing based on PEGs.  Patterns are combined
with arithmetic operators: `*` (sequence), `+` (choice), `-` (difference),
`^` (repetition), `#` (and predicate), `-p` (not predicate).  Captures use the
`C*` functions.

The complete LPeg manual is authoritative; this reference lists the public
constructors and capture helpers.

#### `lpeg.match(pattern, subject [, init])`

Match a pattern against a string.

#### `lpeg.P(value)`

Create a literal pattern or convert a value.

#### `lpeg.R(...)`

Create a pattern matching ranges of characters.

#### `lpeg.S(set)`

Create a pattern matching any character in a set.

#### `lpeg.V(name)`

Reference a grammar rule.

#### `lpeg.B(pattern)`

Match a pattern behind the current position.

#### `lpeg.C(pattern)`

Capture the matched substring.

#### `lpeg.Cc(...)`

Produce constant captures.

#### `lpeg.Cmt(pattern, function)`

Match-time capture.

#### `lpeg.Cb(name)`

Back-reference capture.

#### `lpeg.Carg(n)`

Capture an extra argument.

#### `lpeg.Cp()`

Capture the current position.

#### `lpeg.Cs(pattern)`

Substitution capture.

#### `lpeg.Ct(pattern)`

Table capture.

#### `lpeg.Cf(pattern, function)`

Fold capture.

#### `lpeg.Cg(pattern [, name])`

Group capture.

#### `lpeg.type(value)`

Return the LPeg type of a value.

#### `lpeg.version()`

Return the LPeg version.

#### `lpeg.setmaxstack(size)`

Set the maximum backtracking stack size.

#### `lpeg.locale([table])`

Create locale-aware patterns.

#### `lpeg.utfR(...)`

Create UTF-8 aware range patterns.

### re

Regular expressions built on LPeg.

Upstream: https://www.inf.puc-rio.br/~roberto/lpeg/re.html

License: MIT

`re` implements a regular-expression syntax on top of LPeg.  Patterns can be
matched, searched, substituted and used in grammars.

#### `re.match(subject, pattern [, init])`

Match a pattern against a string.

#### `re.find(subject, pattern [, init])`

Find the first match.

#### `re.gmatch(subject, pattern)`

Iterate matches.

#### `re.gsub(subject, pattern, replacement)`

Replace matches.

#### `re.compile(pattern [, definition])`

Compile a pattern.

### cjson

Fast JSON encoding and decoding.

Upstream: https://github.com/openresty/lua-cjson

License: MIT

`cjson.encode(value)` and `cjson.decode(string)` are the common entry points.
The module also exposes configuration functions for number precision, invalid
numbers, sparse arrays, maximum depth and indentation.

#### `cjson.encode(value)`

Encode a Lua value as JSON.

#### `cjson.decode(string)`

Decode a JSON string.

#### `cjson.new()`

Create a separate cjson instance.

#### `cjson.encode_empty_table_as_object(boolean)`

Control empty-table encoding.

#### `cjson.decode_array_with_array_mt(boolean)`

Control array metatables.

#### `cjson.decode_allow_comment(boolean)`

Allow comments while decoding.

#### `cjson.encode_sparse_array(convert, ratio, safe)`

Configure sparse-array handling.

#### `cjson.encode_max_depth(depth)`

Set the maximum encode depth.

#### `cjson.decode_max_depth(depth)`

Set the maximum decode depth.

#### `cjson.encode_number_precision(precision)`

Set number precision.

#### `cjson.encode_keep_buffer(boolean)`

Keep the encode buffer between calls.

#### `cjson.encode_invalid_numbers(boolean)`

Control encoding of NaN and infinity.

#### `cjson.decode_invalid_numbers(boolean)`

Control decoding of NaN and infinity.

#### `cjson.encode_escape_forward_slash(boolean)`

Escape forward slashes.

#### `cjson.encode_skip_unsupported_value_types(boolean)`

Skip unsupported values.

#### `cjson.encode_indent(value)`

Pretty-print JSON with indentation.

### zlib

Lua binding to zlib.

Upstream: https://github.com/brimworks/lua-zlib

License: MIT

`zlib.deflate()` and `zlib.inflate()` return streaming compressor/decompressor
functions.  `zlib.compress` and `zlib.decompress` are one-shot helpers.  Checksum
helpers `adler32` and `crc32` are also available.

#### `zlib.deflate([level [, window_bits [, mem_level [, strategy]]]])`

Create a streaming deflate function.

#### `zlib.inflate([window_bits])`

Create a streaming inflate function.

#### `zlib.compress(data [, level])`

Compress a string in one call.

#### `zlib.decompress(data [, window_bits])`

Decompress a string in one call.

#### `zlib.adler32(data [, previous])`

Compute an Adler-32 checksum.

#### `zlib.crc32(data [, previous])`

Compute a CRC-32 checksum.

#### `zlib.version()`

Return the zlib version.

### sqlite3

LuaSQLite3 binding.

Upstream: http://lua.sqlite.org/

License: MIT

The `sqlite3` module provides database, statement and result objects.  The most
common entry points are `sqlite3.open`, `db:exec`, `db:prepare`, `stmt:bind` and
the row iterators `db:nrows`, `db:rows` and `db:urows`.

#### `sqlite3.open(filename [, flags])`

Open a database file.

Open an existing SQLite database or create it when it does not exist, and return a database handle.

The optional `flags` argument is passed to `sqlite3_open_v2`; it defaults to `sqlite3.OPEN_READWRITE + sqlite3.OPEN_CREATE`. Constants such as `OPEN_READONLY`, `OPEN_SHAREDCACHE` and `OPEN_NOMUTEX` are available on the module.

On failure it returns `nil, error_code, error_message` rather than raising.

```lua
local sqlite3 = require "sqlite3"
local db = assert(sqlite3.open("app.sqlite3"))
db:exec("create table if not exists notes (body text)")
db:close()
```

#### `sqlite3.open_memory()`

Open an in-memory database.

Open a private in-memory SQLite database and return its handle. The database disappears when the handle is closed or garbage-collected.

On failure it returns `nil, error_code, error_message`. This is convenient for tests and temporary caches.

```lua
local sqlite3 = require "sqlite3"
local db = assert(sqlite3.open_memory())
db:exec("create table t (n integer)")
```

#### `sqlite3.open_ptr(pointer)`

Open a database from a raw pointer.

Wrap an existing raw `sqlite3 *` pointer, passed as light userdata, in a Lua database handle.

The pointer is validated with a lightweight SQLite call; an invalid pointer raises an argument error. Use `db:get_ptr()` on another handle to obtain a compatible pointer when moving a database between Lua states.

```lua
local db = assert(sqlite3.open("app.sqlite3"))
local ptr = db:get_ptr()
local same = sqlite3.open_ptr(ptr)
```

#### `sqlite3.version()`

Return the SQLite version.

Return the version string of the SQLite library that is linked into the interpreter, for example `"3.45.1"`.

The result comes from `sqlite3_libversion` and does not allocate or raise.

#### `sqlite3.lversion()`

Return the LuaSQLite3 version.

Return the version of the bundled LuaSQLite3 binding, such as `"0.9.6"`.

This identifies the Lua wrapper, not the underlying SQLite engine; use `sqlite3.version()` for the engine version.

#### `sqlite3.complete(sql)`

Return true when a SQL string is complete.

Return true when `sql` contains one or more complete SQL statements, and false when another statement terminator is still needed.

The check uses SQLite's own parser and is useful for interactive input buffering.

```lua
local sqlite3 = require "sqlite3"
print(sqlite3.complete("select 1;")) --> true
print(sqlite3.complete("select 1"))  --> false
```

#### `sqlite3.temp_directory([path])`

Get or set the temporary directory.

Get or set the directory SQLite uses for temporary files.

With no argument it returns the current directory string (possibly `nil`). With a string it sets the directory and returns the previous value; passing `nil` explicitly clears the setting. The setter is unavailable on Windows in this binding.

```lua
local sqlite3 = require "sqlite3"
sqlite3.temp_directory("/tmp")
```

#### `sqlite3.backup_init(target_db, target_name, source_db, source_name)`

Create an online backup object.

Start an online backup from a source database to a destination database and return a backup object.

The databases are passed as open handles, together with the source and destination database names (`"main"`, `"temp"`, or an attached name). Source and target must be different. On failure the function returns `nil`; details are stored on the destination handle and are available through `db:errcode()` and `db:errmsg()`.

```lua
local dst = assert(sqlite3.open("copy.sqlite3"))
local backup = sqlite3.backup_init(dst, "main", src, "main")
backup:step(-1)
backup:finish()
```

#### `db:exec(sql)`

Execute SQL statements.

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

#### `db:execute(sql)`

Alias for `db:exec`.

Alias for `db:exec`. It compiles and runs all statements in the SQL string and returns `sqlite3.OK` or an error code.

The optional row callback and userdata argument have the same behavior as in `db:exec`.

#### `db:prepare(sql)`

Prepare a SQL statement.

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

#### `db:rows(sql [, parameters])`

Iterate result rows as arrays.

Return an iterator over the result rows as packed arrays. Index `1` is the first selected column.

Optional parameters may be supplied as individual values matching the statement's placeholders, or as one table whose numeric or named fields provide them. Preparation and binding errors are raised as Lua errors.

```lua
for row in db:rows("select n, n * 2 from t where n > ?", 1) do
    print(row[1], row[2])
end
```

#### `db:nrows(sql [, parameters])`

Iterate result rows as name/value tables.

Return an iterator over the result rows as tables keyed by column name.

Parameters are supplied in the same way as for `db:rows`: either positional values or a single table. Duplicate column names overwrite earlier values in the resulting table.

```lua
for row in db:nrows("select n as number from t") do
    print(row.number)
end
```

#### `db:urows(sql [, parameters])`

Iterate a single-column result.

Return an iterator that unpacks each result row into separate values.

For a query selecting three columns, the loop variables receive those three values directly. Parameters use the same positional-or-table convention as the other row iterators.

```lua
for n, doubled in db:urows("select n, n * 2 from t") do
    print(n, doubled)
end
```

#### `db:close()`

Close the database.

Close the database handle and release its resources.

All prepared statements should be finalized first. Returns `sqlite3.OK` on success or a numeric SQLite error code. Calling `close` on an already closed handle raises an argument error, so close each handle only once.

```lua
local db = assert(require("sqlite3").open_memory())
print(db:close()) --> 0 (sqlite3.OK)
```

#### `db:isopen()`

Return true when the database is open.

Return true while the database handle is open and false after `db:close()`.

The check does not touch the database file.

#### `db:changes()`

Return the number of changed rows.

Return the number of rows changed, inserted or deleted by the most recent `INSERT`, `UPDATE` or `DELETE` statement.

Changes performed indirectly by triggers are not counted. Use `db:total_changes()` for the cumulative count.

```lua
db:exec("update t set n = n + 1")
print(db:changes())
```

#### `db:total_changes()`

Return total changed rows.

Return the total number of rows modified by `INSERT`, `UPDATE` or `DELETE` since the database was opened.

Unlike `db:changes()`, this includes changes made by trigger programs and accumulates across statements.

#### `db:last_insert_rowid()`

Return the last inserted row id.

Return the rowid of the most recent successful insert on this database.

If no insert has occurred, the result is `0`. Inside a trigger, the value refers to the row inserted by the trigger until the trigger finishes.

#### `db:errcode()`

Return the last error code.

Return the numeric result code or extended result code of the most recent failed operation on this database.

Use `db:errmsg()` for the accompanying human-readable message. Successful operations do not necessarily reset the stored code.

#### `db:errmsg()`

Return the last error message.

Return the error message associated with the most recent failed operation on this database.

The message comes from SQLite and may include constraint or I/O details. The alias `db:error_message` is also available.

#### `db:busy_timeout(timeout)`

Set the busy timeout.

Set a busy timeout in milliseconds, so SQLite waits for locks instead of immediately returning `sqlite3.BUSY`.

A value less than or equal to zero disables the timeout and removes any handler installed with `db:busy_handler`. Returns a numeric result code.

```lua
db:busy_timeout(5000) -- wait up to five seconds
```

#### `db:interrupt()`

Interrupt the current operation.

Request cancellation of any pending operation on this database.

SQLite checks the flag at its next opportunity and aborts the operation, which normally surfaces as `sqlite3.INTERRUPT`. The function returns nothing and is safe to call when no operation is running.

#### `db:create_function(name, nargs, func [, userdata])`

Register a scalar SQL function.

Register a scalar SQL function implemented in Lua.

`name` is the SQL name, `nargs` is the exact argument count (`-1` accepts any number), and `func` receives a callback context followed by the SQL arguments. Call `context:result_*` to return a value. An optional `userdata` argument is available through `context:user_data()`.

```lua
db:create_function("double", 1, function(ctx, n)
    ctx:result_int(n * 2)
end)
```

#### `db:create_aggregate(name, nargs, step, final [, userdata])`

Register an aggregate SQL function.

Register an aggregate SQL function. `step` is called once per input row and `final` once at the end.

Both callbacks receive a function context; use `context:set_aggregate_data()` and `context:get_aggregate_data()` to carry state between rows, and `context:result_*` in `final` to produce the result. An optional userdata value is exposed by `context:user_data()`.

```lua
db:create_aggregate("total", 1, function(ctx, n)
    ctx:set_aggregate_data((ctx:get_aggregate_data() or 0) + n)
end, function(ctx)
    ctx:result_int(ctx:get_aggregate_data() or 0)
end)
```

#### `db:create_collation(name, func)`

Register a collation.

Register a collation function used by SQLite for ordering and comparisons.

`func(a, b)` must return `0` when the strings compare equal, `-1` when `a` sorts before `b`, and `1` when `a` sorts after `b`. The collation name can then be used in column definitions and `ORDER BY ... COLLATE name` clauses.

```lua
db:create_collation("nocase", function(a, b)
    a, b = a:lower(), b:lower()
    return a == b and 0 or (a < b and -1 or 1)
end)
```

#### `db:trace(func [, userdata])`

Install a trace callback.

Install a trace callback that runs just before each SQL statement is evaluated.

The callback receives the optional userdata value followed by the SQL text. Call `db:trace(nil)` to remove the callback.

```lua
db:trace(function(_, sql) print("SQL:", sql) end)
```

#### `db:progress_handler(n, func [, userdata])`

Install a progress handler.

Install a callback that SQLite invokes periodically during long-running `exec` or `step` calls.

The callback runs once every `n` virtual-machine operations and receives the optional userdata argument. Returning a non-zero value aborts the current query, rolls back its changes, and makes the operation return `sqlite3.INTERRUPT`. Pass `nil` as the callback to remove it.

```lua
db:progress_handler(1000, function() return 0 end)
```

#### `db:update_hook(func [, userdata])`

Install an update hook.

Install a data-change notification callback.

The callback receives optional userdata, the operation constant (`sqlite3.INSERT`, `sqlite3.UPDATE` or `sqlite3.DELETE`), the database name, the table name, and the affected rowid. Pass `nil` to remove the hook.

#### `db:commit_hook(func [, userdata])`

Install a commit hook.

Install a callback invoked whenever a transaction is about to commit.

The callback receives the optional userdata argument. Returning `false` or `nil` allows the commit; returning any other value converts it into a rollback. Pass `nil` to remove the hook.

#### `db:rollback_hook(func [, userdata])`

Install a rollback hook.

Install a callback invoked whenever a transaction is rolled back.

The callback receives the optional userdata argument. Pass `nil` to remove the hook.

#### `stmt:step()`

Advance a prepared statement.

Advance a prepared statement to its next result.

Returns `sqlite3.ROW` when a row is available, `sqlite3.DONE` when execution has finished, or an error code such as `sqlite3.BUSY`, `sqlite3.ERROR` or `sqlite3.MISUSE`. After `DONE` or an error, call `stmt:reset()` before executing the statement again.

```lua
local rc = stmt:step()
if rc == sqlite3.ROW then
    print(stmt:get_values()[1])
end
```

#### `stmt:reset()`

Reset a prepared statement.

Reset a prepared statement so it can be executed again.

Existing parameter bindings are retained. The function returns the current SQLite error code for the statement, usually `sqlite3.OK`.

```lua
stmt:reset()
stmt:step()
```

#### `stmt:finalize()`

Finalize a prepared statement.

Free a prepared statement and all resources associated with it.

Returns `sqlite3.OK` when the statement was never executed or completed successfully, otherwise the last execution error code. The statement must not be used after finalization.

#### `stmt:bind(index, value)`

Bind a value to a parameter.

Bind a Lua value to parameter `index`, where statement parameters are numbered from 1.

Strings bind as text, integers as SQLite integers, other numbers as doubles, booleans as `0`/`1`, and `nil` removes any previous binding. Unsupported types raise an error. Returns `sqlite3.OK` or an error code.

```lua
stmt:bind(1, "hello")
stmt:bind(2, 42)
```

#### `stmt:bind_values(...)`

Bind positional parameters.

Bind one value to each statement parameter, in order from 1 to `bind_parameter_count()`.

The number of values must exactly match the parameter count, otherwise an error is raised. Returns `sqlite3.OK` or the first binding error code.

```lua
stmt:bind_values("alice", 30)
```

#### `stmt:bind_names(table)`

Bind named parameters.

Bind parameters from a table.

Named placeholders of the form `:name` or `$name` are looked up by the name without the leading marker. Unnamed parameters use numeric keys `1..n`. Returns `sqlite3.OK` or an error code.

```lua
stmt = db:prepare("insert into t values (:name, :age)")
stmt:bind_names { name = "alice", age = 30 }
```

#### `stmt:columns()`

Return result column names.

Return the number of columns in the statement's result set.

The value is `0` for statements that do not return rows, such as `INSERT` or `UPDATE`.

#### `stmt:get_value(index)`

Return a result value.

Return the value of result column `index`. Column indexes start at 0.

The statement must currently be positioned on a row (`stmt:step()` returned `sqlite3.ROW`); otherwise a misuse error is raised.

#### `stmt:get_values()`

Return all result values.

Return the current row as an array, with column `0` stored at index 1.

The statement must be positioned on a result row. Column values are converted to Lua strings, numbers, booleans or `nil` according to SQLite's types.

#### `stmt:get_type(index)`

Return a result value type.

Return the declared SQL type of result column `index`, using a 0-based column index.

The result is the type written in the schema or query (`"INTEGER"`, `"TEXT"`, and so on), or `nil` when the column has no declared type. It is not the runtime storage class of the current value.

#### `stmt:get_types()`

Return all result value types.

Return an array of declared SQL types for all result columns.

Index 1 describes column 0, and so on. Columns without a declared type yield `nil` entries.

#### `stmt:get_uvalue(index)`

Return an uncoerced result value.

Return a single result value without packing it into a table.

This bundled LuaSQLite3 build does not expose a singular `get_uvalue` method; use `stmt:get_values()` for an array or `stmt:get_uvalues()` for multiple return values. The entry is kept as a compatibility reference.

#### `stmt:get_uvalues()`

Return all uncoerced result values.

Return all values of the current row as multiple Lua return values.

For a three-column query, `local a, b, c = stmt:get_uvalues()` receives the three columns directly. The statement must be positioned on a result row.

#### `stmt:get_utype(index)`

Return an uncoerced result type.

Return a single declared column type without packing it into a table.

This bundled build does not expose a singular `get_utype` method; use `stmt:get_types()` for an array or `stmt:get_utypes()` for multiple return values. The entry is kept as a compatibility reference.

#### `stmt:get_utypes()`

Return all uncoerced result types.

Return the declared types of all result columns as multiple Lua return values.

Columns without a declared type produce `nil` in the corresponding position.

#### `stmt:get_name(index)`

Return a column name.

Return the name of result column `index`, using a 0-based column index.

The name is the column alias if one was specified, otherwise the column or expression name chosen by SQLite.

#### `stmt:get_names()`

Return all column names.

Return an array containing the names of all result columns.

Index 1 corresponds to column 0. Names are taken from aliases when present.

#### `stmt:get_named_values()`

Return results as a name/value table.

Return the current result row as a table keyed by column name.

The statement must be positioned on a row. Duplicate column names overwrite earlier values.

```lua
stmt:step()
local row = stmt:get_named_values()
print(row.name)
```

#### `stmt:get_named_types()`

Return result types as a name/value table.

Return a table mapping each result column name to its declared SQL type.

Duplicate names overwrite earlier entries. Columns without a declared type map to `nil`.

#### `stmt:bind_parameter_count()`

Return the number of parameters.

Return the number of distinct parameters in the prepared statement.

Repeated named parameters count once, while gaps in `?NNN` numbering are reflected in the largest index returned.

#### `stmt:bind_parameter_name(index)`

Return a parameter name.

Return the name of parameter `index`, including its leading `:`, `$` or `@` marker.

The index is 1-based. An unnamed `?` or `?NNN` parameter yields `nil`; an out-of-range index raises an error.

#### `stmt:bind_blob(index, data)`

Bind a blob value.

Bind a Lua string as a BLOB value to parameter `index`.

The entire string, including embedded NUL bytes, is copied into SQLite. The binding uses transient storage, so the Lua string may be collected after the call. Returns `sqlite3.OK` or an error code.

```lua
stmt:bind_blob(1, "\0\1\2binary")
```

### luaunit

Unit-testing framework for Lua.

Upstream: https://github.com/bluebird75/luaunit

License: BSD

LuaUnit discovers global tables whose names begin with `Test` and functions whose
names begin with `test`.  Assertions are exported as `assert*` functions.

`luaunit.run()` runs the registered tests and returns the number of failures.

#### `luaunit.run([...])`

Run the test suite.

Run the registered test suite and return the number of failures and errors (zero means success).

With no arguments, command-line options are taken from the script's `arg` table. You may instead pass option strings such as `"-v"`, `"--quiet"`, `"--shuffle"` or `"--pattern"`. LuaUnit discovers global tables named `Test*` and functions named `test*`.

```lua
local lu = require "luaunit"
Test_math = {}
function Test_math:test_addition() lu.assertEquals(1 + 1, 2) end
os.exit(lu.run())
```

#### `luaunit.assertEquals(actual, expected [, message])`

Assert equality.

Assert that two values are equal. Tables are compared deeply, including nested keys and values; other values use ordinary `==`.

An optional message is appended to the failure output. A mismatch fails the current test by raising an error.

```lua
lu.assertEquals({ a = 1, b = { 2, 3 } }, { b = { 2, 3 }, a = 1 })
```

#### `luaunit.assertNotEquals(actual, expected [, message])`

Assert inequality.

Assert that two values are not equal, using the same deep table comparison as `assertEquals`.

The assertion passes when the values have different types or any nested table content differs. An optional message is added to the failure.

#### `luaunit.assertAlmostEquals(actual, expected, margin [, message])`

Assert approximate equality.

Assert that two numbers, or two tables of numbers, are equal within `margin`.

If `margin` is omitted or `nil`, LuaUnit's `EPS` value is used. Negative margins are rejected. An optional message is appended on failure.

```lua
lu.assertAlmostEquals(0.1 + 0.2, 0.3, 1e-9)
```

#### `luaunit.assertItemsEquals(actual, expected [, message])`

Assert that two tables contain the same items.

Assert that two tables contain the same items, ignoring order and keys.

Each value in one table must match some value in the other and vice versa, using deep equality. The comparison is O(n^2), so it is intended for small tables.

#### `luaunit.assertStrContains(value, substring [, isPattern [, message]])`

Assert that a string contains a substring.

Assert that `value` contains `substring`.

By default the search is plain text. Pass `true` as `isPattern` to treat `substring` as a Lua pattern. An optional message is appended to the failure.

```lua
lu.assertStrContains("hello world", "lo wo")
lu.assertStrContains("abc123", "%d+", true)
```

#### `luaunit.assertStrIContains(value, substring [, message])`

Case-insensitive substring assertion.

Assert that `value` contains `substring`, ignoring letter case.

The search is always plain text, so pattern characters have no special meaning. An optional message is appended to the failure.

```lua
lu.assertStrIContains("Hello World", "hello")
```

#### `luaunit.assertNotStrContains(value, substring [, isPattern [, message]])`

Assert that a string does not contain a substring.

Assert that `value` does not contain `substring`.

Plain-text matching is the default; pass `true` as `isPattern` to use a Lua pattern. An optional message is appended to the failure.

#### `luaunit.assertNotStrIContains(value, substring [, message])`

Case-insensitive negative substring assertion.

Assert that `value` does not contain `substring`, ignoring letter case.

The search is plain text. An optional message is appended to the failure.

#### `luaunit.assertStrMatches(value, pattern [, start [, final [, message]]])`

Assert a string pattern match.

Assert that the whole of `value`, or the range from `start` through `final`, matches the Lua pattern.

`start` defaults to 1 and `final` to the string length. The pattern must cover the entire selected range, not merely occur somewhere inside it.

```lua
lu.assertStrMatches("2026-10-24", "%d%d%d%d%-%d%d%-%d%d")
```

#### `luaunit.assertError(func, ...)`

Assert that a call raises an error.

Assert that calling `func` with the supplied arguments raises an error.

The error message and type are not checked. Extra arguments after `func` are passed to it.

```lua
lu.assertError(function() error("boom") end)
```

#### `luaunit.assertErrorMsgEquals(message, func, ...)`

Assert an exact error message.

Assert that calling `func` raises an error whose message exactly equals `message`.

File and line prefixes added by `error(..., 2)` are significant; use `assertErrorMsgContentEquals` to ignore them. Extra arguments after `func` are passed through.

```lua
lu.assertErrorMsgEquals("boom", function() error("boom", 0) end)
```

#### `luaunit.assertErrorMsgContentEquals(message, func, ...)`

Assert an error message ignoring file and line prefix.

Assert that `func` raises an error whose message equals `message` after removing a leading `file:line:` prefix.

This is convenient for errors raised with a level argument. Extra arguments after `func` are passed through.

#### `luaunit.assertErrorMsgContains(partial, func, ...)`

Assert an error message contains text.

Assert that `func` raises an error whose message contains `partial` as plain text.

Any file and line prefix is left in place, so the substring may match anywhere in the full message. Extra arguments after `func` are passed through.

#### `luaunit.assertErrorMsgMatches(pattern, func, ...)`

Assert an error message matches a pattern.

Assert that `func` raises an error whose entire message matches the Lua pattern.

The pattern is matched against the complete message, including any file and line prefix, and must cover the whole string. Extra arguments after `func` are passed through.

#### `luaunit.assertEvalToTrue(value [, message])`

Assert that a value evaluates to true.

Assert that `value` evaluates to true in Lua, meaning it is neither `false` nor `nil`.

Numbers, strings and tables all pass, including `0` and the empty string. Use `assertIsTrue` when the value must be exactly `true`.

#### `luaunit.assertEvalToFalse(value [, message])`

Assert that a value evaluates to false.

Assert that `value` is `false` or `nil`, the only Lua values that evaluate to false.

Use `assertIsFalse` when the value must be exactly `false` rather than `nil`.

#### `luaunit.assertIsTrue(value [, message])`

Assert a true value.

Assert that `value` is exactly the boolean `true`.

Truthy non-boolean values fail this assertion; use `assertEvalToTrue` for Lua truthiness. An optional message is appended to the failure.

#### `luaunit.assertNotIsTrue(value [, message])`

Assert a non-true value.

Assert that `value` is not exactly the boolean `true`.

Both `false` and any non-boolean value pass; use `assertIsFalse` for an exact `false` check.

#### `luaunit.assertIsFalse(value [, message])`

Assert a false value.

Assert that `value` is exactly the boolean `false`.

`nil` and other falsy values fail this assertion; use `assertEvalToFalse` for Lua falsiness.

#### `luaunit.assertNotIsFalse(value [, message])`

Assert a non-false value.

Assert that `value` is not exactly the boolean `false`.

`nil`, `true` and non-boolean values all pass. An optional message is appended on failure.

#### `luaunit.assertIsNil(value [, message])`

Assert nil.

Assert that `value` is `nil`.

The alias `assertNil` behaves identically. An optional message is appended to the failure.

#### `luaunit.assertNotIsNil(value [, message])`

Assert not nil.

Assert that `value` is not `nil`.

The alias `assertNotNil` behaves identically. An optional message is appended to the failure.

#### `luaunit.assertIs(actual, expected [, message])`

Assert identity.

Assert that `actual` and `expected` are the same value, using `==`.

For tables and functions this checks identity rather than content; use `assertEquals` for structural comparison.

#### `luaunit.assertNotIs(actual, expected [, message])`

Assert non-identity.

Assert that `actual` and `expected` are not the same value.

Table contents are not compared; two distinct tables always pass even when their fields match.

#### `luaunit.assertIsNaN(value [, message])`

Assert NaN.

Assert that `value` is the NaN number value.

The check works even though NaN is not equal to itself. An optional message is appended on failure.

#### `luaunit.assertNotIsNaN(value [, message])`

Assert not NaN.

Assert that `value` is not NaN.

Non-number values also pass. An optional message is appended on failure.

#### `luaunit.assertIsInf(value [, message])`

Assert infinity.

Assert that `value` is either positive or negative infinity.

Use `assertIsPlusInf` or `assertIsMinusInf` when the sign matters.

#### `luaunit.assertIsPlusInf(value [, message])`

Assert positive infinity.

Assert that `value` is positive infinity (`math.huge`).

An optional message is appended to the failure.

#### `luaunit.assertIsMinusInf(value [, message])`

Assert negative infinity.

Assert that `value` is negative infinity (`-math.huge`).

An optional message is appended to the failure.

#### `luaunit.assertNotIsInf(value [, message])`

Assert a finite number.

Assert that `value` is a finite number and not positive or negative infinity.

Non-number values also pass. An optional message is appended on failure.

#### `luaunit.assertIsPlusZero(value [, message])`

Assert positive zero.

Assert that `value` is positive zero (`0.0`).

IEEE-754 distinguishes positive and negative zero even though `0.0 == -0.0`; this assertion checks the sign bit.

#### `luaunit.assertIsMinusZero(value [, message])`

Assert negative zero.

Assert that `value` is negative zero (`-0.0`).

IEEE-754 distinguishes negative zero from positive zero even though they compare equal with `==`.

#### `luaunit.assertTableContains(table, expected [, message])`

Assert that a table contains expected entries.

Assert that table `t` contains `expected` as one of its values.

Every value is compared with deep equality, and keys are ignored. The table must be a table; an optional message is appended on failure.

```lua
lu.assertTableContains({ "a", "b", "c" }, "b")
```

#### `luaunit.assertNotTableContains(table, expected [, message])`

Assert that a table does not contain expected entries.

Assert that table `t` does not contain `expected` as any of its values.

Values are compared with deep equality. An optional message is appended on failure.

#### `luaunit.fail([message])`

Fail the current test.

Fail the current test immediately with `message`, or with a generic failure message when it is omitted.

The function raises an error through LuaUnit, so it is normally used inside a test function to report an unexpected branch.

#### `luaunit.failIf(condition [, message])`

Fail when a condition is true.

Fail the current test when `condition` is truthy.

`nil` and `false` do nothing. An optional message is used in the failure report.

```lua
lu.failIf(#items == 0, "expected at least one item")
```

#### `luaunit.skip([message])`

Skip the current test.

Skip the current test and mark it as skipped rather than failed.

An optional message explains why the test was skipped. Execution of the test stops at the call.

#### `luaunit.skipIf(condition [, message])`

Skip when a condition is true.

Skip the current test when `condition` is truthy.

`nil` and `false` let the test continue. An optional message is reported with the skipped test.

#### `luaunit.success()`

End the current test successfully.

Mark the current test as successful and stop executing it.

This is rarely needed because a test that returns normally succeeds. It is useful for early exits from tests that intentionally inspect multiple paths.

#### `luaunit.setVerbosity(level)`

Set the runner verbosity.

Set the default verbosity used by later `run()` calls.

Values are integers: `0` is quiet, `1` is low, `10` is the default, and `20` is verbose. The aliases `set_verbosity` and `SetVerbosity` are also provided.

```lua
local lu = require "luaunit"
lu.setVerbosity(0)
```

### serpent

Lua serializer and pretty printer.

Upstream: https://github.com/pkulchenko/serpent

License: MIT

`serpent.serialize(value [, options])` returns a Lua expression that recreates
the value.  `serpent.line` and `serpent.block` are convenience formatters.

#### `serpent.serialize(value [, options])`

Serialize a value to a Lua expression.

Serialize a Lua value into a Lua expression that reconstructs it.

The default output is single-line unless an `indent` option is supplied. Useful options include `name` (wrap the result in a local block), `compact`, `sortkeys`, `comment`, `nocode` (skip function bodies), `sparse`, and `maxlevel`. Shared and cyclic tables are handled with local references.

```lua
local serpent = require "serpent"
print(serpent.serialize({ 1, 2, answer = 42 }))
```

#### `serpent.line(value [, options])`

Serialize a value on one line.

Serialize a value on one line, with sorted keys and comments enabled by default.

Pass an options table to override defaults such as `sortkeys` or `comment`. The result is a Lua expression; it is not printed.

```lua
local serpent = require "serpent"
print(serpent.line({ b = 2, a = 1 })) --> {a=1,b=2} --[[table: ...]]
```

#### `serpent.block(value [, options])`

Serialize a value in block form.

Serialize a value in indented block form, using two spaces by default and sorting keys.

Comments and sorting are enabled unless overridden by the options table. This is the most readable form for nested data.

```lua
local serpent = require "serpent"
print(serpent.block({ list = { 1, 2, 3 } }))
```

#### `serpent.dump(value [, options])`

Serialize a value in compact form.

Return a compact serialization with the root named `_`, intended for debugging output.

The output uses compact tables and includes the shared-reference prologue when needed. Pass `{ print = true }`-style options only if your application handles them; this function itself returns a string and does not print.

#### `serpent.load(string)`

Load a serialized value.

Load a value from text produced by `serpent.serialize`.

Returns `true, value` on success. On failure it returns `false, error_message` when the text compiled but evaluation failed, or `nil, syntax_error` when the text could not be compiled. The default environment permits table construction but not function calls.

```lua
local ok, value = require("serpent").load("{ 1, 2, name = 'x' }")
assert(ok)
print(value.name)
```

## Command line tools

### tools

Tools shipped in the ZLI payload.

Tools are started with `zli @name`.  Compiled executables can include the same
scripts in their payload.

#### `zli @repl`

Start the interactive REPL.

Inside the REPL, `:help` shows the documentation index and `:help <name>` looks up an entry.

#### `zli @sqlite`

Start the SQLite CLI.

The CLI starts with an in-memory database.  Commands include `open`, `close`, `file`, `mode table|csv|json|lua`, and `quit`.

#### `zli @compile <config>`

Package Lua files into a standalone executable.

The config is a Lua table (or a `return { ... }` statement) with `output_name` and `files`.

#### `zli @test <file>`

Run a LuaUnit test file.

#### `zli @manual [options]`

Serve the bundled reference manual.

Options: `--port`, `--address`, `--no-open`, `--output <file>`.

#### `zli @help [options] [query]`

Look up documentation.

Options: `--list`, `--search`, `--markdown`, `--output`.

#### `zli @serve [directory]`

Serve a directory over HTTP.

Defaults to the current directory.

## ZLI

### ZLI runtime

Interpreter globals and configuration.

The `ZLI` table is available to every script and REPL session.

#### `ZLI.version`

The ZLI version string.

#### `ZLI.error_handling`

Default error style for libraries.

Set to `"raise"` before `require` to make libraries raise instead of returning `nil, message`.

#### `ZLI.exe_path`

The real path of the running executable.

#### `ZLI.dofile(name)`

Run a script from the payload.

#### `~/.config/zli/init.lua`

User init script.

Executed before every script and REPL session.

#### `~/.config/zli/repl_init.lua`

REPL init script.

Executed only when the REPL starts.

#### `payload`

Embedded zip payload.

The ZLI binary carries `main.lua`, tools and documentation in an appended zip payload.  `zli @name` selects a payload script by exact name or by `name.lua`; `@dir/name` is supported.  Compiled executables replace the payload with the files listed in their config.

#### `argv[0] and payload selection`

How the executable name selects a payload script.

When no tool or script is given, ZLI selects a payload entry from the executable basename: `<exe-name>.lua` first, then `main.lua`, then `init.lua`.  On Windows, a trailing `.exe` is stripped from the basename.

The basename comes from `argv[0]`, so symlinks with different names can select different payload tools from the same executable.  The payload zip itself is opened through the real executable path, so the binary also works when found through `PATH`.

The Lua `arg[0]` value remains the executable name used to invoke ZLI; the selected payload script is not substituted into the argument table.  This is also true for filesystem scripts: the script path is not reflected in `arg[0]`.

#### `compiled executables`

Standalone executables created by `@compile`.

A compiled executable replaces the standard payload with the files listed in its config.
