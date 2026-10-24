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

Compile `source` into a callable Lua function.  The global helpers `lambda` and
`L`, and the string method `string.L`, are equivalent.  The source may read
local variables and upvalues visible where the lambda is created, even after
the creating scope has returned.

The first characters of `source` select one of these styles:

| Source style                            | Example                | Equivalent Lua function                |
| --------------------------------------- | ---------------------- | -------------------------------------- |
| Method call                             | `L(":hello")`          | `function(it) return it:hello() end`   |
| Method call with arguments (arrow form) | `L("-> it:add(2, 3)")` | `function(it) return it:add(2, 3) end` |
| Field access                            | `L(".name")`           | `function(it) return it.name end`      |
| Field call                              | `L(".hello()")`        | `function(it) return it.hello() end`   |
| Arrow expression                        | `L("-> it * 2")`       | `function(it) return it * 2 end`       |
| Bare expression                         | `L("it * 2")`          | `function(it) return it * 2 end`       |
| Parameter list                          | `L("(a, b) -> a + b")` | `function(a, b) return a + b end`      |
| No parameters                           | `L("() -> 42")`        | `function() return 42 end`             |

The method shorthand appends `()` to the rest of the source: `":hello"` becomes
`it:hello()`.  Use it for zero-argument methods, and do not include the
parentheses in the source.  Pass arguments with the arrow form, for example
`L("-> it:add(2, 3)")`.

The field shorthand appends the rest of the source to `it` without adding
parentheses: `".name"` becomes `it.name`, and `".hello()"` becomes
`it.hello()` (a plain function call, not a method call).  The arrow and bare
forms provide exactly one parameter named `it`.  The parenthesised form is the
only style that chooses its own parameter list.

A source beginning with `(` is always parsed as a parameter list and must
contain `->`.  To use an expression that starts with a parenthesis, use the
arrow form: `L("-> (it + 1) * 2")`.

For example, `L("(a, b) -> a + b")` loads a chunk equivalent to this one (with
the captured scope as its environment) and calls it to produce the lambda:

```lua
return function(a, b) return a + b end
```

The aliases can be written in several ways:

```lua
local double = L("it * 2")        -- global L
local triple = lambda("it * 3")   -- global lambda
local upper = (":upper"):L()      -- string method
local negate = L "-> -it"         -- function call sugar
```

Typical uses:

```lua
local double = L("it * 2")
print(double(21)) --> 42

local add = L("(a, b) -> a + b")
print(add(20, 22)) --> 42

local user = {
    name = "Ada",
    hello = function(self) return "Hello " .. self.name end,
}
print(L(":hello")(user)) --> Hello Ada
print(L(".name")(user))  --> Ada
```

Lambdas are also accepted as strings by helpers such as `stream:map`:

```lua
local stream = require "stream"
local multiplier = 3
local result = stream({ 1, 2, 3 }):map("it * multiplier"):toarray()
print(table.concat(result, ",")) --> 3,6,9
```

Because the source is compiled when the lambda is created, a lambda created in
a tail-call position cannot see locals from the discarded caller frame.  This
is the same limitation as the f-strings library.

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

#### `crossline.readline([prompt [, initial]])`

Read a line with editing and history.

Read one line from the terminal with editing and history.

`prompt` defaults to `"> "`. `initial` pre-fills the edit buffer and may be modified interactively; it is limited to 4095 bytes. History navigation, incremental search and completion keys are handled by the editor.

Returns the entered line as a string, or `nil` when standard input reaches end-of-file. The returned line does not include the newline.

```lua
local cl = require "crossline"
local line = cl.readline("name> ")
if line then print("hello " .. line) end
```

#### `crossline.set_prompt_color(fg [, bg])`

Set the prompt colour.

Set the foreground and background colours used for the readline prompt.

`fg` and `bg` are numeric colour values, normally selected from `crossline.color.fg` and `crossline.color.bg`; the two values are combined into one terminal colour code. Omitting either value disables that component. The setting affects subsequently printed prompts and returns nothing.

```lua
local cl = require "crossline"
cl.set_prompt_color(cl.color.fg.green, cl.color.bg.default)
local line = cl.readline("> ")
```

#### `crossline.set_color(fg [, bg])`

Set the current output colour.

Set the foreground and background colours used for subsequent terminal output.

`fg` and `bg` are numeric values from `crossline.color.fg` and `crossline.color.bg`; omitting a component leaves it at the default colour. The call returns nothing and does not change the prompt colour.

```lua
local cl = require "crossline"
cl.set_color(cl.color.fg.yellow)
print("warning")
cl.set_color(cl.color.fg.default)
```

#### `crossline.print_paged(text)`

Print long text through the pager.

Print a string or an array of lines through the pager.

Paging is temporarily enabled for the duration of the call. A string is split on newline characters; a table is printed one element per line. When the terminal reaches the bottom, the user may continue with Space or Enter or abort with another key.

Returns `true` when all output was printed and `false` when the user stopped early. Paging is disabled again before returning.

```lua
local cl = require "crossline"
cl.print_paged({ "line one", "line two", "line three" })
```

#### `crossline.screen.dimensions()`

Return the terminal width and height.

Return the current terminal size as a table.

The `x` field is the number of columns and `y` is the number of rows. The result is a fresh table and may change when the terminal is resized.

```lua
local cl = require "crossline"
local size = cl.screen.dimensions()
print(size.x, size.y)
```

#### `crossline.screen.clear()`

Clear the terminal screen.

Clear the terminal screen and leave the cursor at the home position.

The function emits the terminal control sequence directly and works on ANSI-compatible terminals. It returns nothing and does not alter history or paging state.

```lua
local cl = require "crossline"
cl.screen.clear()
```

#### `crossline.cursor.get()`

Return the current cursor position (`x`, `y`).

Return the current cursor position as a table.

The result has numeric `x` (column) and `y` (row) fields using the terminal's coordinate system. The call does not move the cursor or change terminal state.

```lua
local cl = require "crossline"
local pos = cl.cursor.get()
print(pos.x, pos.y)
```

#### `crossline.cursor.set(x, y)`

Move the cursor to a position.

Move the cursor to an absolute position.

Coordinates may be passed as two numbers (`x`, `y`) or as a table with `x` and `y` fields. The position uses the same coordinate system as `cursor.get`. The function returns nothing.

```lua
local cl = require "crossline"
cl.cursor.set(1, 1)
cl.cursor.set({ x = 10, y = 5 })
```

#### `crossline.cursor.move(x, y)`

Move the cursor relative to its current position.

Move the cursor relative to its current position.

Positive `x` moves right, positive `y` moves down; negative values move left and up. As with `cursor.set`, the arguments may be two numbers or a table with `x` and `y` fields. No value is returned.

```lua
local cl = require "crossline"
cl.cursor.move(2, 0)
cl.cursor.move({ x = -1, y = 1 })
```

#### `crossline.cursor.hide()`

Hide the cursor.

Hide the terminal cursor.

This is useful while redrawing a prompt or progress display. It returns nothing; call `cursor.show()` to restore the cursor. Showing an already hidden cursor is harmless.

```lua
local cl = require "crossline"
cl.cursor.hide()
-- draw something
cl.cursor.show()
```

#### `crossline.cursor.show()`

Show the cursor.

Show the terminal cursor after it was hidden.

The call emits the terminal control sequence and returns nothing. It does not move the cursor or restore a previous position.

```lua
local cl = require "crossline"
cl.cursor.hide()
cl.cursor.show()
```

#### `crossline.history.save(filename)`

Save the command history.

Write the in-memory command history to a file.

The file is opened for writing and overwritten; each history entry is written on its own line without numeric prefixes. If the file cannot be opened the failure is silently ignored. The function returns nothing.

```lua
local cl = require "crossline"
cl.history.save(os.home .. "/.config/zli/repl_history")
```

#### `crossline.history.load(filename)`

Load the command history.

Load command history from a file.

Non-empty lines are appended to the in-memory history with trailing CR/LF removed. A missing or unreadable file is silently ignored, making this safe to call during startup. The function returns nothing.

```lua
local cl = require "crossline"
cl.history.load(os.home .. "/.config/zli/repl_history")
```

#### `crossline.history.show()`

Print the command history.

Print the current history with sequence numbers.

Output goes to standard output and may be paged when standard input and output are terminals. The history itself is not modified. The function returns nothing.

```lua
local cl = require "crossline"
cl.history.show()
```

#### `crossline.history.clear()`

Clear the command history.

Erase all in-memory history entries.

The history file on disk is not touched; use `history.save` afterwards if the cleared state should persist. The function returns nothing.

```lua
local cl = require "crossline"
cl.history.clear()
```

#### `crossline.paging.start()`

Start paging output.

Enable paging for subsequent output.

While paging is active, `paging.print` and `paging.check` count printed lines and prompt the user when the screen is full. The function returns nothing. Calling it when paging is already active just resets the line counter.

```lua
local cl = require "crossline"
cl.paging.start()
cl.paging.print("first line")
cl.paging.stop()
```

#### `crossline.paging.stop()`

Stop paging output.

Disable paging.

Subsequent `paging.print` calls still print their text but do not pause for the user. The function returns nothing and is safe to call when paging is already off.

```lua
local cl = require "crossline"
cl.paging.stop()
```

#### `crossline.paging.check()`

Check whether paging is active.

Advance the pager by a line length and report whether output may continue.

`line_len` is the number of characters about to be displayed and is required. When paging is disabled, or input/output is not a terminal, the function immediately returns `true`. On a full screen it waits for Space or Enter and returns `true` to continue, or `false` when the user pressed another key to stop.

```lua
local cl = require "crossline"
cl.paging.start()
local keep_going = cl.paging.check(#"some output")
cl.paging.stop()
```

#### `crossline.paging.print(text)`

Print text through the pager.

Print text through the pager.

The argument may be a string, which is split on newlines, or an array of strings. Each line is written to standard output and checked against the terminal height. The function returns `true` when every line was printed, or `false` when the user stopped paging early.

```lua
local cl = require "crossline"
cl.paging.start()
local complete = cl.paging.print({ "row 1", "row 2", "row 3" })
cl.paging.stop()
print(complete)
```

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

Perform an HTTP GET request.

Returns `response, body` on success. `response` contains fields such as `status`, `status_name`, `reason`, `success`, `version`, `content_type`, `content_length`, `location` and `content_disposition` when present. GET requests cannot send a body; passing one raises an argument error.

Options include `header`, `query`, `parseJson`, `basicAuth`, `save` and `raiseError`. A table in `options.query` is URL-encoded and appended to the URL.

```lua
local http = require "httpclient"
local response, body = http.get("https://example.com", {
    query = { page = 2 },
})
print(response.status, #body)
```

#### `httpclient.head(url [, options [, body]])`

Perform a HEAD request.

Perform an HTTP HEAD request.

Returns the response metadata and an empty body. HEAD, like GET, cannot send a body. On a transport failure the function returns `nil, message` unless `options.raiseError` is true, in which case it raises.

```lua
local http = require "httpclient"
local response = http.head("https://example.com")
print(response.status, response.content_length)
```

#### `httpclient.post(url [, options [, body]])`

Perform a POST request.

Perform an HTTP POST request.

The optional body may be a string or a table. A table is encoded with cjson and the request gains `content_type: application/json` unless the caller already supplied one. Returns `response, body`.

The usual options apply, including headers, query parameters, JSON response parsing, authentication, saving the response and raising on transport errors.

```lua
local http = require "httpclient"
local response, body = http.post("https://example.com/api", nil, {
    name = "zli",
})
print(response.status)
```

#### `httpclient.put(url [, options [, body]])`

Perform a PUT request.

Perform an HTTP PUT request.

The body rules are the same as for `post`: strings are sent as-is and tables are JSON-encoded with an automatic content type. Returns `response, body`, or `nil, message` on transport failure unless `raiseError` is set.

```lua
local http = require "httpclient"
local response, body = http.put("https://example.com/item/1", nil, "new value")
print(response.success)
```

#### `httpclient.patch(url [, options [, body]])`

Perform a PATCH request.

Perform an HTTP PATCH request.

Accepts an optional string or table body, just like `post` and `put`. The response body is returned as the second result and may be decoded with `options.parseJson`.

```lua
local http = require "httpclient"
local response, body = http.patch("https://example.com/item/1", nil, { done = true })
print(response.status, type(body))
```

#### `httpclient.delete(url [, options [, body]])`

Perform a DELETE request.

Perform an HTTP DELETE request.

DELETE cannot send a body; supplying one raises an argument error. It returns `response, body` and supports the same options as the other convenience methods, including JSON parsing and response saving.

```lua
local http = require "httpclient"
local response, body = http.delete("https://example.com/item/1")
print(response.success)
```

#### `httpclient.call(method, url [, options [, body]])`

Perform a request with an explicit method.

Perform a request with an explicit HTTP method.

`method` is an upper-case method name such as `"GET"`, `"POST"`, `"PATCH"` or `"OPTIONS"`. `options` must be a table; the low-level call understands `header` and `privileged_headers` but not the Lua-level conveniences such as `query`, `basicAuth`, `parseJson`, `save` or `raiseError`. For POST, PUT and PATCH, `body` must already be a string.

Returns `response, body` on success. Failures follow the module `error_handling` setting: `nil, message` by default, or a raised error when configured to raise.

```lua
local http = require "httpclient"
local response, body = http.call("GET", "https://example.com", {
    header = { ["user-agent"] = "zli" },
})
print(response.status)
```

#### `httpclient:config(options)`

Configure a loaded httpclient module.

Configure the loaded httpclient module.

The supported option is `error_handling`, set to `"return"` or `"raise"`. It affects the low-level `call` function; the convenience request functions already honour `options.raiseError`.

Use colon syntax so the module table is passed first, then the options table. The module table is returned.

```lua
local http = require "httpclient"
http:config({ error_handling = "raise" })
assert(http.error_handling == "raise")
```

### httpserver

HTTP server based on Zig's HTTP server.

`httpserver.serve(options)` starts a server.  Options include `address`, `port`,
`web_root`, `cache_web_root`, method route tables (`GET`, `POST`, ...) and a
`*` route table used for every method.

A route value may be a response string or a function `(options, request)`
returning a string, a response table, or a table that is encoded as JSON.
Request tables contain `method`, `target`, `version`, `body` and other request
metadata; message headers are available as named fields.  Responses use
`{ status, body, header }`.

#### `httpserver.serve(options)`

Start an HTTP server.

Start the HTTP server and process requests until the process is stopped.

`serve` accepts one options table and blocks while listening. The fields are:

- `address` — bind address, default `"127.0.0.1"`.
- `port` — TCP port, default `8080`.
- `web_root` — directory used for `GET` requests that no route matched.
- `cache_web_root` — cache lifetime for `web_root` responses, or `false` to
  disable caching.
- `GET`, `POST`, ... — tables mapping a request target to a route value.
- `*` — route table used for every method without a method-specific match.

A target is matched exactly or as a Lua pattern that consumes the whole target.
A route may be a response string or a function. The function receives
`(options, request)` and may return a string, a response table, or a data table
that is encoded as JSON. The request table contains `method`, `target`,
`version`, `body` and request metadata; message headers are available as named
fields. Responses use `{ status, body, header }`; `status` defaults to `200`
and a JSON body gets a JSON content type.

The call does not return during normal operation. Invalid options raise an
argument error, and address or bind failures are reported according to the
module's `error_handling` setting.

```lua
local http = require "httpserver"
http.serve {
    address = "127.0.0.1",
    port = 8080,
    GET = { ["/"] = "hello" },
    POST = { ["/echo"] = function(_, request)
        return { status = http.status.created, body = request.body }
    end },
}
```

#### `httpserver:config(options)`

Configure a loaded httpserver module.

Configure the loaded module in place.

The supported option is `error_handling`, set to `"return"` or `"raise"`. It
controls failures in the native binding, such as an invalid address or a port
that cannot be bound; argument errors still raise. The options table may be the
first or second argument, and the module table is returned, so calls can be
chained.

```lua
local http = require "httpserver"
http:config { error_handling = "raise" }
assert(http.error_handling == "raise")
```

#### `httpserver.serve_file(path)`

Serve a file from disk.

Turn a file on disk into a response table.

A regular file is read in binary mode and returned as
`{ status = 200, body = ..., header = { content_type = ... } }`. If the path is
a directory, `index.html` or `index.htm` is served when present; otherwise a
generated HTML directory listing is returned. A missing or unreadable file
returns `{ status = 404 }` instead of raising.

```lua
local http = require "httpserver"
local response = http.serve_file("doc/README.md")
assert(response.status == http.status.ok)
assert(response.body:find("ZLI", 1, true))
```

#### `httpserver.resolve_web_path(root, target)`

Resolve a URL path inside a web root.

Turn a request target into a path below a web root.

The root gets a trailing slash if needed. Query strings and fragments are
removed, percent-escapes are decoded, and backslashes are treated as
separators. `.` components are dropped and `..` removes the previous component;
leading `..` cannot climb above the root because there is no previous component
to remove.

The function only normalizes the path. `httpserver.serve` separately checks the
resolved file against the web root before serving it, so traversal attempts are
rejected with `403`.

```lua
local http = require "httpserver"
assert(http.resolve_web_path("/srv/", "/a/../a") == "/srv/a")
assert(http.resolve_web_path("/srv/", "/%61?x=1") == "/srv/a")
assert(http.resolve_web_path("/srv/", "/../../etc/passwd") == "/srv/etc/passwd")
```

#### `httpserver.content_type(filename)`

Look up a MIME type by file extension.

Return the MIME type for a file name.

The extension after the last dot is lower-cased and looked up in the built-in
MIME table. Returns `nil` when the name has no extension or the extension is
unknown. The file does not need to exist.

```lua
local http = require "httpserver"
assert(http.content_type("index.HTML") == "text/html")
assert(http.content_type("archive.unknown") == nil)
```

#### `httpserver.cache(func [, time])`

Cache a route handler's result.

Wrap a route handler so its response is reused for a while.

The optional `time` is the lifetime in seconds; `nil` or `true` keeps the
response until it is cleared or evicted by a cache sweep. A value of `0`
refreshes on every request. Entries are keyed by `request.target`, so do not
share one wrapper between methods whose responses differ. Expired entries are
removed by `free_cache` and by the periodic sweep configured with
`cache_free_cycle`.

The returned function has the same `(options, request)` signature as the
handler.

```lua
local http = require "httpserver"
local calls = 0
local handler = http.cache(function()
    calls = calls + 1
    return "value"
end, 60)
assert(handler({}, { target = "/a" }) == "value")
assert(handler({}, { target = "/a" }) == "value")
assert(calls == 1)
```

#### `httpserver.status`

HTTP status code table.

Numeric HTTP status codes indexed by lower-case names.

`ok`, `created`, `not_found`, `internal_server_error` and the other standard
codes are available. Lookup is case-insensitive through a metatable, so
`status.NOT_FOUND` also works. Treat the table as read-only.

```lua
local http = require "httpserver"
print(http.status.ok)        --> 200
print(http.status.not_found) --> 404
```

#### `httpserver.cache_free_cycle([seconds])`

Set the cache expiry cycle.

Set how often expired entries are swept automatically.

`seconds` is the interval between sweeps performed during `httpserver.cache`
lookups. Passing `nil` or `0` disables automatic sweeping; entries are then
only removed by `httpserver.free_cache`. The default at startup is `300`
seconds. Returns nothing.

```lua
local http = require "httpserver"
http.cache_free_cycle(60)
http.cache_free_cycle(0) -- disable automatic sweeps
```

#### `httpserver.free_cache([cycle])`

Free expired cache entries.

Remove cached responses older than a number of seconds.

`cycle` defaults to the value configured by `httpserver.cache_free_cycle`.
Entries whose age is strictly greater than `cycle` are discarded; pass `-1` to
expire everything that has a cached response. The function also resets the
timestamp used by the automatic sweep and returns nothing.

```lua
local http = require "httpserver"
http.free_cache(-1)
```

#### `httpserver.clear_cache()`

Clear the content cache.

Discard every cached response and reset the automatic sweep timer.

Call this between tests or after changing a handler that is behind
`httpserver.cache`. Returns nothing.

```lua
local http = require "httpserver"
http.clear_cache()
```

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

Log a fatal-level message.

The message is emitted when both this logger's level and the root logger's level are at least `FATAL`. It is passed to every appender attached to this logger and, for named child loggers, also to the root appenders. The function returns nothing.

```lua
local log = require "log"
log:fatal("unrecoverable configuration error")
```

#### `log:error(message)`

Log an error message.

Log an error-level message.

Errors are emitted when the effective level allows `ERROR` or anything more verbose. The message is written by all applicable appenders with a timestamp and level tag. The function returns nothing.

```lua
local log = require "log"
log:error("request failed")
```

#### `log:warn(message)`

Log a warning.

Log a warning.

The record is emitted when the logger and root thresholds both allow `WARN`. Appender failures propagate normally; no status value is returned.

```lua
local log = require "log"
log:warn("using the fallback configuration")
```

#### `log:info(message)`

Log an informational message.

Log an informational message.

This is the default threshold for both root and child loggers, so `info` records are visible until a stricter level is set. The message may be a string or any value accepted by the appender's `write` call; convert structured values to text first.

```lua
local log = require "log"
log:info("service started")
```

#### `log:debug(message)`

Log a debug message.

Log a debug-level message.

Debug records are hidden at the default `INFO` level and appear after lowering the relevant logger threshold. No value is returned.

```lua
local log = require "log"
log:setLevel(log.level.DEBUG)
log:debug("cache hit")
```

#### `log:trace(message)`

Log a trace message.

Log a trace-level message.

Trace is the most verbose level. It is emitted only when both the logger and the root logger are configured for `TRACE`. The call returns nothing.

```lua
local log = require "log"
log:setLevel(log.level.TRACE)
log:trace("entering parser")
```

#### `log:setLevel(level)`

Set the logger level.

Set the threshold for this logger.

`level` should be one of the numeric values in `log.level` (`OFF` through `TRACE`). Records below the threshold are suppressed. A child logger is also capped by the root logger's threshold, so lowering only the child is not enough when the root is stricter.

Returns nothing.

```lua
local log = require "log"
local child = log["worker"]
child:setLevel(log.level.DEBUG)
```

#### `log:setAppender(appender)`

Replace the logger appender.

Replace all appenders attached to this logger with one appender.

An appender is any table with an `append(logger, level, message)` method. The built-in constructors are in `log.appender`. Root appenders are still used for child loggers after their own appenders run.

Returns nothing.

```lua
local log = require "log"
log:setAppender(log.appender.file("/tmp/app.log"))
```

#### `log:addAppender(appender)`

Add an appender.

Add an appender without removing the existing ones.

Appenders run in insertion order. Child loggers call their own appenders first and then the root logger's appenders, so the same record can be written to several destinations.

Returns nothing.

```lua
local log = require "log"
log:addAppender(log.appender.file("/tmp/audit.log", "w"))
```

#### `log.level`

Logger level constants.

The table of numeric logger levels.

Both upper-case and lower-case keys are present: `OFF`, `FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE` and the same names in lower case. Numeric values increase with verbosity, and thresholds are compared with `>=`, so a larger level enables more messages.

This field is a table; treat it as read-only.

#### `log.appender`

Built-in appenders: `stdout`, `file`, `none`.

The built-in appender constructors and the no-op appender.

`log.appender.stdout` is a function returning an appender for standard output. `log.appender.file(filename [, mode])` opens a file and returns an appender, raising an error if the file cannot be opened; `mode` defaults to `"a"`. `log.appender.none` is a ready-made appender that discards messages.

This field is a table of functions and one appender object.

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

Open a tar archive and return an iterator over its entries.

The file may be plain tar or compressed with gzip, xz or zstd; the compression is detected from the stream. Each iteration returns an entry table with the fields and methods documented below, and returns `nil` after the last entry. Opening or reading failures follow the module error policy.

```lua
local tar = require "tar"
for entry in tar.open("backup.tar.gz") do
    print(entry.type, entry.name, entry.size_hr)
end
```

#### `tar.create(filename [, level])`

Create a tar archive for writing.

Create a tar archive and return a writer object.

The output is uncompressed unless the filename ends in `.gz` or `.tgz`, in which case gzip compression is used. `level` selects gzip compression and accepts `"default"`, `"fastest"`, `"best"` or a digit string from `"1"` to `"9"`; it is ignored for uncompressed archives.

On failure the module error policy applies: with the default `"return"` policy the result is `nil, message`; with `"raise"` an error is raised.

```lua
local tar = require "tar"
local writer = tar.create("backup.tar.gz", "best")
writer:add_file_bytes("hello.txt", "hello")
writer:close()
```

#### `tar.extract(filename, destination)`

Extract an entire archive into a directory.

Extract an archive's files and directories into an existing destination directory.

The archive may be plain tar or compressed with gzip, xz or zstd; compression is detected automatically. The destination must already exist. On success the function returns `true`; failures follow the module error policy and return `nil, message` by default. Support for special entry kinds such as symbolic links depends on the platform.

```lua
local tar = require "tar"
local ok, err = tar.extract("backup.tar.gz", "restore")
assert(ok, err)
```

#### `tar:config(options)`

Configure a loaded tar module.

Configure the loaded tar module.

The only supported option is `error_handling`, whose value is `"return"` or `"raise"`. It controls whether failures in module and writer operations return `nil, message` or raise a Lua error. The option may be passed directly or through the module table when using colon syntax.

The module table is returned and the option is stored back into it.

```lua
local tar = require "tar"
tar:config({ error_handling = "raise" })
assert(tar.error_handling == "raise")
```

#### `writer:setRoot(root)`

Set the root directory written into the archive.

Set the path prefix stripped from archive member names.

When a path passed to `add_dir` or `add_file` starts with this prefix, the prefix is removed before the entry is written. This lets an absolute workspace path produce clean relative names inside the archive. Backslashes are normalised to `/`.

Returns the writer for chaining.

```lua
local tar = require "tar"
local w = tar.create("out.tar")
w:setRoot("/tmp/project")
w:add_dir("/tmp/project/src")
w:close()
```

#### `writer:add_dir(path)`

Add a directory entry.

Write a directory entry to the archive.

The path is converted to an archive name with forward slashes and with the root prefix from `setRoot` removed. This function adds only the directory entry itself; it does not recurse into the directory.

Returns the writer so calls can be chained.

```lua
local tar = require "tar"
tar.create("dirs.tar"):add_dir("docs"):add_dir("docs/api"):close()
```

#### `writer:add_file(path, archive_path)`

Add a file.

Add a file from disk to the archive.

`path` is the existing filesystem path. `archive_path` is the name stored in the tar, with backslashes normalised and the configured root prefix removed. Both arguments are required. The file is streamed, so large inputs do not need to fit in memory.

Returns the writer for chaining. I/O failures follow the module error policy.

```lua
local tar = require "tar"
tar.create("src.tar")
    :add_file("src/main.lua", "main.lua")
    :close()
```

#### `writer:add_file_bytes(path, data)`

Add a file from memory.

Add an in-memory string as a regular file.

`path` is the member name inside the archive and `data` is its complete contents. No filesystem access occurs. Returns the writer for chaining.

```lua
local tar = require "tar"
tar.create("config.tar")
    :add_file_bytes("config/app.ini", "debug = true\n")
    :close()
```

#### `writer:add_link(path, target)`

Add a symbolic link.

Write a symbolic-link entry.

`path` is the link's name inside the archive and `target` is the link target stored in the entry. The target does not need to exist on disk. Returns the writer for chaining.

```lua
local tar = require "tar"
tar.create("links.tar")
    :add_link("latest", "releases/v1")
    :close()
```

#### `writer:close()`

Finish and close the archive.

Finish the archive and close the output file.

For gzip archives this writes the compression trailer before closing. The writer must not be used after this call; the returned value is empty. A writer that is garbage-collected without `close` also attempts to flush, but calling `close` explicitly reports failures at a predictable point.

```lua
local tar = require "tar"
local w = tar.create("one.tar")
w:add_file_bytes("a.txt", "a")
w:close()
```

#### `entry.name`

The path stored in the archive.

The member path stored in the archive, as a string.

Directory entries may or may not end with `/`, depending on how the archive was created. Use `is_directory` rather than inspecting the name when classifying an entry.

This field is read-only.

#### `entry.type`

The tar entry type (`file`, `directory`, `sym_link`, ...).

The tar entry kind as a string.

Common values are `"file"`, `"directory"` and `"sym_link"`; other tar kinds are reported by their standard names. Prefer the boolean helpers `is_file`, `is_directory` and `is_link` when only those three categories matter.

This field is read-only.

#### `entry.size`

Uncompressed size in bytes.

The uncompressed size of the current entry in bytes.

Directories usually report zero. For a regular file this is the exact number of bytes that `bytes` or `extract` will read.

This field is read-only.

#### `entry.size_hr`

Human-readable size.

The entry size formatted for humans, for example `"1.5 KB"`.

The value is produced by the filesystem module's human-readable size helper and is intended for display only. Use `size` for arithmetic.

This field is read-only.

#### `entry.link_name`

Symbolic-link target.

The target of a symbolic-link entry.

For entries that are not links this is the empty string. The target is exactly the text stored in the archive and is not resolved.

This field is read-only.

#### `entry.mode_flags`

POSIX mode string.

The POSIX permission bits rendered as a ten-character string.

The first character describes the entry kind (`-`, `d`, `l`, and so on), followed by the owner, group and other `rwx` triples, for example `"-rw-r--r--"`. Unknown mode bits produce `?` for the kind.

This field is read-only.

#### `entry.is_file`

True for a regular file.

True when the current entry is a regular file.

Only regular-file entries support `bytes()` and `extract()`. The field is a boolean snapshot of the entry that was just yielded.

This field is read-only.

#### `entry.is_directory`

True for a directory.

True when the current entry is a directory.

Directory entries normally carry no payload, although `extract` on the whole archive creates the corresponding directory. This is a boolean snapshot.

This field is read-only.

#### `entry.is_link`

True for a symbolic link.

True when the current entry is a symbolic link.

The target text is available in `link_name`. This is a boolean snapshot and does not check whether the target exists.

This field is read-only.

#### `entry:bytes()`

Read the current regular file into a string.

Read the current regular-file entry into a string.

The function streams the remaining payload of the entry and returns it. It may only be called for a file entry created by `tar.open`; calling it for a directory or link fails according to the module error policy.

```lua
local tar = require "tar"
for entry in tar.open("src.tar") do
    if entry.is_file then
        print(entry.name, #entry:bytes())
    end
end
```

#### `entry:extract(destination)`

Extract the current regular file.

Extract the current regular-file entry to a filesystem path.

`destination` is the full output path. Parent directories are not created automatically, so they must already exist. The entry payload is streamed to the new file and the function returns nothing on success. Non-file entries fail according to the module error policy.

```lua
local tar = require "tar"
for entry in tar.open("src.tar") do
    if entry.name == "main.lua" then
        entry:extract("main.lua")
    end
end
```

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

Create a new zip archive for writing.

The file is truncated if it already exists. The returned writer supports `add_file`, `create_directory`, streaming `open`/`write`/`close`, and `close_zip`. On failure the module returns `nil, message`; configure `error_handling` to raise instead.

```lua
local zip = require "zip"
local z = zip.create("bundle.zip")
z:add_file("README.md", "README.md")
z:close_zip()
```

#### `zip.open(filename)`

Open an existing zip archive for appending.

Open an existing zip archive so entries can be appended.

The archive must already exist and contain a valid central directory. New entries are added after the existing ones; existing entries are not rewritten. Returns a writer or `nil, message`.

```lua
local zip = require "zip"
local z = zip.open("bundle.zip")
z:add_file("src/version", "version.txt")
z:close_zip()
```

#### `zip.create_after(filename)`

Create a zip archive after existing file data.

Create a zip archive after existing non-zip file data.

This is used to append a zip payload to an executable or another container: the current file contents are preserved and the new zip starts at the end. The path must already exist. Returns a writer or `nil, message`.

```lua
local zip = require "zip"
local z = zip.create_after("app.bin")
z:add_file("config.lua", "config.lua")
z:close_zip()
```

#### `zip.add_directory(writer, path [, include_top [, level]])`

Add a directory tree to an archive.

Recursively add a filesystem directory tree to an archive.

Files are added with paths relative to `path`. When `include_top` is true the top directory name is included in the archive paths; otherwise its contents are placed at the archive root. Empty directories are written explicitly. `level` defaults to `zip.level.default`.

Returns the number of entries added. Files inside non-empty directories count individually; the parent directory itself is implied by the file paths.

```lua
local zip = require "zip"
local z = zip.create("src.zip")
local count = zip.add_directory(z, "src", true)
z:close_zip()
print(count > 0) --> true
```

#### `zip.level`

Compression level constants.

A table of named compression levels.

The fields are `store` (0), `fastest` (1), `fast` (3), `normal` (5), `default` (6), `high` (7) and `max` (9). Any integer from 0 to 9 is also accepted by the writer. Higher values produce smaller archives at the cost of CPU time.

This field is a table; treat it as read-only.

#### `writer:add_file(path, archive_path [, level [, comment]])`

Add a file.

Add a file from disk to the archive.

`path` is the source file. `archive_path` is required and becomes the member name. `level` defaults to 6 and must be between 0 and 9; `comment` optionally sets the per-entry comment. The file is streamed into the archive.

Returns `true` on success. On failure the call returns `nil, message` or raises according to the configured error policy.

```lua
local zip = require "zip"
local z = zip.create("out.zip")
z:add_file("src/version", "version.txt", zip.level.max, "version file")
z:close_zip()
```

#### `writer:create_directory(path)`

Add a directory entry.

Add an explicit directory entry to the archive.

A trailing `/` is added when missing. Empty directories need this call because adding files does not create standalone directory records. The function returns nothing.

```lua
local zip = require "zip"
local z = zip.create("dirs.zip")
z:create_directory("empty")
z:close_zip()
```

#### `writer:open(path [, level [, comment]])`

Open an entry for streaming writes.

Start a new archive entry for streaming writes.

`path` is the member name. `level` defaults to 6 and `comment` optionally sets the entry comment. Any entry already being written is closed first. After opening, use `write` one or more times and then `close` or `close_zip`.

Returns the writer for chaining.

```lua
local zip = require "zip"
local z = zip.create("stream.zip")
z:open("notes.txt"):write("first line\n"):write("second line\n"):close()
z:close_zip()
```

#### `writer:write(data)`

Write data to the current entry.

Write one or more strings to the currently open entry.

All arguments from the first onward are converted to strings and appended to the entry. Numbers are accepted. The call does not close the entry; use `close` when finished.

Returns the writer for chaining. Writing without an open entry, or after the archive is closed, follows the configured error policy.

```lua
local zip = require "zip"
local z = zip.create("numbers.zip")
z:open("values.txt"):write("one ", "two ", 3):close()
z:close_zip()
```

#### `writer:close()`

Close the current entry.

Close the entry currently being written.

The archive remains open so another entry can be opened or added. Closing when no entry is active is harmless. Returns the writer for chaining, or `nil, message` when the archive is already closed.

```lua
local zip = require "zip"
local z = zip.create("out.zip")
z:open("a.txt"):write("a"):close()
z:add_file("src/version", "version.txt")
z:close_zip()
```

#### `writer:close_zip()`

Finish and close the archive.

Finish the archive and close the underlying zip file.

Any open entry is closed first. An optional `comment` string is stored as the archive comment in the central directory. After this call the writer must not be used again; entries added later are not guaranteed to be written.

Returns nothing. The writer is also finalized during garbage collection, but explicit closing surfaces errors.

```lua
local zip = require "zip"
local z = zip.create("final.zip")
z:add_file("README.md", "README.md")
z:close_zip("built by ZLI")
```

### unzip

Read and extract zip archives.

Upstream: https://zlib.net/

License: MIT

`unzip.open(filename)` returns an archive object.  Archives expose entries as
tables with `name`, `path`, `full_path`, `is_file`, `is_directory`, sizes,
timestamps and `extract`.

#### `unzip.open(filename)`

Open a zip archive.

Open a zip archive for reading.

Returns an archive object with `list`, `dir`, `info`, `read_all`, `lines`, `extract`, `payload_start` and `close` methods. On failure it returns `nil, message`; the message includes the path that could not be opened.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
print(#archive:list())
archive:close()
```

#### `unzip.extract(filename, destination)`

Extract an archive to a directory.

Extract every entry of an archive into a directory.

`filename` is the archive path and `destination` is the output directory. Missing directories are created, and directory entries are recreated. Returns `true` when the archive was opened and processed, or `nil, message` when it could not be opened.

```lua
local unzip = require "unzip"
local ok, err = unzip.extract("bundle.zip", "out")
assert(ok, err)
```

#### `archive:list()`

Return entries as an array.

Return an array of entry tables.

The order is the order stored in the archive's central directory. An empty archive returns an empty table. Each entry carries name, path, size, CRC, timestamp and extraction helpers; see the entry methods below. A closed archive or invalid central directory follows the module error policy.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
for _, entry in ipairs(archive:list()) do
    print(entry.full_path, entry.uncompressed_size)
end
```

#### `archive:dir()`

Return entries keyed by path.

Return entry tables keyed by their full archive path.

This is convenient when looking up a known member without scanning the array from `list`. Directory keys end with `/`. An empty archive returns an empty table.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
local entry = archive:dir()["src/main.lua"]
print(entry and entry.is_file)
```

#### `archive:info()`

Return archive information.

Return archive-level information.

The result contains `entries`, the number of members, and `comment`, the archive comment (an empty string when absent). Corrupt metadata raises an internal error; a closed archive returns `nil, message`.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
local info = archive:info()
print(info.entries, info.comment)
```

#### `archive:extract(name [, destination])`

Extract one archive member.

Extract one member of the archive.

`name` is the member's full path in the archive. `destination` is optional and defaults to the same path, relative to the current directory. Parent directories are not created. Returns `true` on success, or `nil, message` when the member cannot be found or opened.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
archive:extract("src/main.lua", "main.lua")
archive:close()
```

#### `archive:read_all(name)`

Read an entry as a string.

Read a named member into a string.

Returns the complete uncompressed contents. A missing member, a closed archive, or an unreadable stream produces `nil, message` under the default error policy.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
local text = archive:read_all("README.md")
print(#text)
```

#### `archive:lines(name)`

Iterate the lines of an entry.

Iterate over the lines of a named member.

Returns an iterator suitable for a `for` loop. Lines are returned without their line-ending characters, matching `io.lines`. Missing members and closed archives follow the module error policy.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
for line in archive:lines("README.md") do
    print(line)
end
```

#### `archive:payload_start()`

Return the offset of an appended zip payload.

Return the byte offset where an appended zip payload starts.

The value is the offset of the first local file header in the underlying file, so it points at the beginning of the zip data rather than at the first compressed byte. It is used by the compiler to replace an existing payload. An empty archive returns `nil`.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("app.bin"))
local offset = archive:payload_start()
print(offset)
archive:close()
```

#### `archive:close()`

Close the archive.

Close the archive and release its file handle.

Calling `close` more than once is safe. The method returns nothing. After closing, other archive methods report that the archive is closed.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
archive:close()
```

#### `entry:read_all()`

Read the entry as a string.

Read this entry's complete contents into a string.

The entry must be a regular file. A directory entry or a closed archive follows the module error policy. The archive remains open for further reads.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
local entry = archive:dir()["README.md"]
print(entry:read_all())
```

#### `entry:lines()`

Iterate the entry's lines.

Iterate over this entry's lines.

Returns an iterator that yields each line without its newline characters. This is equivalent to reading through `entry:open()` and calling `read("l")` repeatedly, but simpler for scripts.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
local entry = archive:dir()["README.md"]
for line in entry:lines() do
    print(line)
end
```

#### `entry:extract([destination])`

Extract the entry.

Extract this entry to a file.

`destination` is optional; when omitted the entry's stored `full_path` is used relative to the current directory. Parent directories are not created automatically. Returns `true` on success, or `nil, message` if the file or directory cannot be written.

```lua
local unzip = require "unzip"
local archive = assert(unzip.open("bundle.zip"))
local entry = archive:dir()["src/main.lua"]
entry:extract("main.lua")
```

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

Add a positional argument and return its `Argument` object so settings can be chained.

`name` is used both as the help label and as the default result key. `description` appears in the generated help. A string `default` is used when the argument is absent and is shown in the help text.

Positional arguments are consumed in declaration order. A missing required value makes parsing fail through the parser's error handler.

```lua
local parser = require("argparse")("copy", "copy a file")
parser:argument("source", "file to read")
parser:argument("destination", "file to write"):default("out.txt")
local args = parser:parse({ "in.txt" })
print(args.source, args.destination) --> in.txt out.txt
```

#### `parser:option(name [, description [, default]])`

Add an option.

Add a named option and return its `Option` object.

`name` is a whitespace-separated list of aliases, for example `"-o --output"`. The default result key comes from the long alias when one exists, otherwise from the short alias; hyphens become underscores. `description` is shown in help and a string `default` is reported there as well.

An option that takes a value consumes the next command-line word. Options may be written as `--name=value` or as bundled short flags. Missing or unknown options cause the parser to report an error.

```lua
local parser = require("argparse")("example")
parser:option("-o --output", "output file", "a.out")
local args = parser:parse({ "--output=result.txt" })
print(args.output) --> result.txt
```

#### `parser:flag(name [, description])`

Add a boolean flag.

Add a boolean option that consumes no value.

This is shorthand for `parser:option(name, description):args(0)`. When the flag appears more than once the normal option overwrite rules apply. If the flag is absent its result is `nil`, not `false`.

```lua
local parser = require("argparse")("example")
parser:flag("-v --verbose", "show details")
local args = parser:parse({ "-v" })
print(args.verbose) --> true
```

#### `parser:command(name [, description])`

Add a subcommand.

Add a subcommand and return its parser object.

The returned command is a full parser: it can have its own arguments, options and nested commands. When the command name is seen, the result field named after the command (or its `target`) is set to `true`, and parsing continues with the command's parser.

By default a parser with commands requires one to be present. Use `:require_command(false)` on the parent when the command is optional.

```lua
local parser = require("argparse")("tool")
local build = parser:command("build", "build the project")
build:flag("--release", "optimised build")
local args = parser:parse({ "build", "--release" })
print(args.build, args.release) --> true true
```

#### `parser:mutex(...)`

Create a mutually exclusive group.

Create a mutually exclusive group from options and positional arguments.

Pass already-created `Option` or `Argument` objects. During parsing at most one element from the group may be used; using two reports an error. The group also affects the generated usage line. Returns the parser so calls can be chained.

```lua
local parser = require("argparse")("tool")
local quiet = parser:flag("-q --quiet")
local loud = parser:flag("-l --loud")
parser:mutex(quiet, loud)
```

#### `parser:group(name, ...)`

Create an argument group.

Create a named help group.

The first argument is the heading shown in `get_help()`. The remaining arguments are existing options, positional arguments or commands. Grouping only changes help layout; parsing behavior is unchanged.

Passing anything other than those element types raises an assertion error. Returns the parser for chaining.

```lua
local parser = require("argparse")("tool")
local input = parser:argument("input")
local verbose = parser:flag("-v --verbose")
parser:group("Input", input)
parser:group("Output", verbose)
```

#### `parser:parse([args])`

Parse command-line arguments.

Parse command-line arguments and return a table of results.

`args` defaults to the global `arg` table. The result contains one field per argument or option plus `true` for each command seen. Defaults and custom actions are applied before the table is returned.

Parse errors are not exceptions: `parse` prints the usage and an error message to stderr and exits with status 1. Use `pparse` when the caller must handle errors.

```lua
local parser = require("argparse")("echo")
parser:argument("text")
local args = parser:parse({ "hello" })
print(args.text) --> hello
```

#### `parser:pparse([args])`

Parse arguments, returning an error message instead of raising.

Parse arguments without terminating the process on a parse error.

Returns `true, result` on success, or `false, message` when the command line is invalid. The error message is the same text that `parse` would print; no usage block is written to stderr.

Errors raised by user callbacks and other non-parser failures are re-raised rather than converted into a `false` result.

```lua
local parser = require("argparse")("tool")
parser:argument("count"):convert(tonumber)
local ok, result = parser:pparse({ "many" })
print(ok, result:match("malformed") ~= nil) --> false true
```

#### `parser:get_usage()`

Return the generated usage string.

Return the generated one-line (or wrapped) usage string.

The text starts with `Usage:` and lists options, positional arguments, mutex groups and commands in a stable order. A custom string assigned through the parser's `usage` property is returned unchanged.

The result is a string and has no side effects; it is also included at the top of `get_help()`.

```lua
local parser = require("argparse")("tool")
parser:add_help(false)
parser:argument("file")
print(parser:get_usage()) --> Usage: tool <file>
```

#### `parser:get_help()`

Return the generated help text.

Return the complete generated help text as a string.

The text contains the usage line, the parser description, grouped arguments, options and commands, and the optional epilog. Hidden elements are omitted. Line wrapping follows the configured help margins and maximum width.

The function does not print or exit. Printing the result is the caller's responsibility.

```lua
local parser = require("argparse")("tool", "does useful work")
parser:flag("-v --verbose", "show details")
print(parser:get_help())
```

#### `parser:add_help_command([value])`

Add a help command.

Add a `help` subcommand to the parser.

The command prints help for the parser when invoked without an argument, or for a named command when given one, then exits with status 0. An unknown command name is reported as an error.

Pass a string or table to customise the command through the usual command properties. Returns the parser.

```lua
local parser = require("argparse")("tool")
parser:add_help_command()
parser:command("build")
-- running "tool help build" prints the build command's help
```

#### `parser:add_complete([value])`

Add shell completion support.

Add a `--completion <shell>` option that emits a completion script.

Accepted shells are `bash`, `zsh` and `fish`. The generated script is written to stdout and the process exits with status 0, so the option must be handled before other work.

Pass a string or table to customise the option object. Returns the parser.

```lua
local parser = require("argparse")("tool")
parser:add_complete()
-- "tool --completion bash" prints a bash completion script
```

#### `parser:get_bash_complete()`

Generate a bash completion script.

Return a bash completion script for this parser as a string.

The script completes option names and, for parsers with commands, command names and their options. The parser name must be shell-safe: characters outside letters, digits, `_`, `-`, `+` and `.` make the internal safety assertion fail.

This function is normally called indirectly by `add_complete`; it neither prints nor exits.

```lua
local parser = require("argparse")("mytool")
parser:flag("--verbose")
local script = parser:get_bash_complete()
assert(script:match("complete"))
```

#### `parser:get_zsh_complete()`

Generate a zsh completion script.

Return a zsh completion script for this parser.

The result starts with a `#compdef` line followed by the completion function and any per-command helpers. As with the bash generator, the parser name and option aliases must be shell-safe.

Calling the function has no output or exit side effects.

```lua
local parser = require("argparse")("mytool")
parser:option("--output")
local script = parser:get_zsh_complete()
assert(script:match("#compdef mytool"))
```

#### `parser:get_fish_complete()`

Generate a fish completion script.

Return a fish completion script for this parser.

The script defines command-detection helpers plus completions for options, arguments and subcommands. Shell-unsafe names trigger the same assertion as the other completion generators.

The returned string is not printed automatically.

```lua
local parser = require("argparse")("mytool")
parser:flag("--verbose")
local script = parser:get_fish_complete()
assert(script:match("complete"))
```

#### `parser:error(message [, ...])`

Raise a parser error.

Report a parser error and terminate the program.

The current usage string is written to stderr, followed by a blank line and `Error: ` plus the formatted message. `...` are passed to `string.format`. The function then calls `os.exit(1)`, so it never returns.

Use `pparse` or a custom action if the caller needs to recover from invalid input.

```lua
local parser = require("argparse")("tool")
parser:error("invalid value '%s'", "x")
-- prints usage and "Error: invalid value 'x'", then exits 1
```

#### `argument:args(...)`

Set or get the argument's target names.

Set how many values one occurrence of an element consumes.

The argument may be a number, a table boundary string such as `"2"`, `"2-4"`, `"2+"`, `"*"`, `"+"` or `"?"`, or another supported range form. It updates both the minimum and maximum value counts and returns the element.

For options, the value is the number of words after the option. For positional arguments it controls how many command-line words the argument collects.

```lua
local parser = require("argparse")("tool")
local point = parser:argument("coords"):args(2)
local args = parser:parse({ "10", "20" })
print(args.coords[1], args.coords[2]) --> 10 20
```

#### `argument:count(count)`

Set how many values the argument consumes.

Set how many times an option may occur on the command line.

The value uses the same boundary syntax as `args`: a number, `"n-m"`, `"n+"`, `"*"`, `"+"` or `"?"`. A minimum greater than zero makes the option required; a maximum limits repetition. Returns the element.

This setting is primarily useful on options. Combine it with `:args` when each occurrence also takes several values.

```lua
local parser = require("argparse")("tool")
local include = parser:option("-I --include"):count("*")
local args = parser:parse({ "-I", "one", "-I", "two" })
print(#args.include) --> 2
```

#### `argument:default(value)`

Set the default value.

Set the value used when the element is not supplied.

A string default is stored as the displayed default and is inserted when the argument or option is unused. A non-string default (number, table, boolean, or `nil`) is used as the initial result value and is not shown in help.

For options, defaults participate in usage rendering and in `show_default`. Returns the element.

```lua
local parser = require("argparse")("tool")
parser:option("--retries", "attempts", "3"):convert(tonumber)
local args = parser:parse({})
print(args.retries) --> 3
```

#### `argument:target(name)`

Set the result field name.

Choose the result-table field written by this element.

By default a positional argument uses its name and an option derives a name from its aliases, replacing `-` with `_`. Setting a target overrides that choice and is useful when several elements share a name or when the Lua identifier would be inconvenient.

Returns the element.

```lua
local parser = require("argparse")("tool")
parser:flag("--dry-run"):target("dry_run")
local args = parser:parse({ "--dry-run" })
print(args.dry_run) --> true
```

#### `argument:convert(func)`

Set a value conversion function.

Set a conversion applied to each raw command-line value.

`func` may be a function, a table whose numeric index selects a converter for the corresponding value position, or a lookup table. A function receives the raw string and returns the converted value; returning `nil, message` reports a parse error. Choices are checked before conversion.

Returns the element.

```lua
local parser = require("argparse")("tool")
parser:argument("count"):convert(tonumber)
local args = parser:parse({ "42" })
print(math.type(args.count)) --> integer
```

#### `argument:choices(...)`

Restrict values to a set of choices.

Restrict accepted values to a fixed set.

Pass an array of strings. A value outside the set causes a parse error that lists the allowed choices; the choices also replace the usual placeholder in usage and help. Conversion runs after the choice check.

Returns the element.

```lua
local parser = require("argparse")("tool")
parser:argument("mode"):choices({ "fast", "safe" })
local ok = parser:pparse({ "slow" })
print(ok) --> false
```

#### `argument:argname(name)`

Set the display name in help output.

Set the placeholder used for this element in usage and help output.

The value may be a string or an array of strings, one per consumed value. It does not change parsing or the result key. Returns the element.

```lua
local parser = require("argparse")("tool")
parser:add_help(false)
parser:argument("file"):argname("PATH")
print(parser:get_usage()) --> Usage: tool PATH
```

#### `argument:show_default(boolean)`

Control whether the default is shown in help.

Control whether a string default is displayed in help output.

`boolean` defaults to `true`. When enabled and a string default is set, help appends `(default: value)` to the description. Non-string defaults are initial values and are never shown. Returns the element.

```lua
local parser = require("argparse")("tool")
parser:option("--level", "log level", "info"):show_default(false)
assert(not parser:get_help():find("default: info", 1, true))
```

#### `argument:hidden(boolean)`

Hide the argument from help output.

Hide this element from usage and help output.

The element is still parsed and still produces a result; only its documentation is suppressed. This is useful for compatibility options and internal switches. Returns the element.

```lua
local parser = require("argparse")("tool")
parser:flag("--internal"):hidden(true)
assert(not parser:get_help():find("--internal", 1, true))
```

#### `argument:overwrite(boolean)`

Control overwriting of repeated results.

Control what happens when an option is repeated more often than allowed.

With `true` (the default for options), later occurrences overwrite earlier results according to the action: `store` keeps the last value, `append` drops the oldest element, and `count` keeps its current count. With `false`, exceeding the maximum count raises a parse error. Returns the element.

```lua
local parser = require("argparse")("tool")
local tag = parser:option("--tag"):overwrite(false)
local ok = parser:pparse({ "--tag", "a", "--tag", "b" })
print(ok) --> false
```

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

Match a pattern against a subject string.

Matching is anchored at `init`: the pattern must match a prefix of the subject starting there, not an arbitrary substring. `init` defaults to 1 and may be negative to count from the end.

On success the function returns the position just after the match, or all captured values when the pattern captures anything. On failure it returns `nil`. This is the function form of the `:match` pattern method.

```lua
local lpeg = require "lpeg"
print(lpeg.match(lpeg.P("abc"), "abcdef")) --> 4
print(lpeg.match(lpeg.C(lpeg.R("09")^1), "123x")) --> 123
```

#### `lpeg.P(value)`

Create a literal pattern or convert a value.

Convert a Lua value into an LPeg pattern.

Strings become literal matches, non-negative numbers match exactly that many characters, negative numbers succeed only when fewer than that many characters remain, and booleans always succeed or fail. A table is treated as a grammar, while a function becomes a match-time capture on the empty string. Existing patterns are returned unchanged.

```lua
local lpeg = require "lpeg"
print(lpeg.P("abc"):match("abcdef")) --> 4
print(lpeg.P(2):match("xy")) --> 3
print(lpeg.P(-1):match("")) --> 1
```

#### `lpeg.R(...)`

Create a pattern matching ranges of characters.

Create a pattern matching one character from one or more inclusive ranges.

Each argument is a two-character string such as `"09"` or `"az"`. The resulting pattern matches a single character whose code lies in any range. With no arguments it always fails. The `utfR` constructor handles Unicode code points.

```lua
local lpeg = require "lpeg"
local hex = lpeg.R("09", "af", "AF")^1
print(hex:match("BEEF")) --> 5
```

#### `lpeg.S(set)`

Create a pattern matching any character in a set.

Create a pattern matching any single character in a set.

The argument is the complete set as a string, so `S("+-*/")` accepts one arithmetic operator. An empty set always fails. For a one-character string, `S(c)` is equivalent to `P(c)`.

```lua
local lpeg = require "lpeg"
local op = lpeg.S("+-*/")
print(op:match("+")) --> 2
print(op:match("x")) --> nil
```

#### `lpeg.V(name)`

Reference a grammar rule.

Create a non-terminal reference for use inside a grammar.

The argument is the rule name or numeric index in the enclosing grammar table. References are resolved when that table is converted to a pattern with `lpeg.P`, which allows recursive grammars. A `V` reference used outside a grammar is an error.

```lua
local lpeg = require "lpeg"
local p = lpeg.P{ "(" * lpeg.V(1)^0 * ")" }
print(p:match("(())")) --> 5
```

#### `lpeg.B(pattern)`

Match a pattern behind the current position.

Create a behind predicate that checks text before the current position.

The pattern matches only when `pattern` matches immediately before the current position, and it never consumes input. The referenced pattern must have a fixed length and must not contain captures.

```lua
local lpeg = require "lpeg"
local p = lpeg.B("ab") * lpeg.P("cd")
print(p:match("abcd", 3)) --> 5
```

#### `lpeg.C(pattern)`

Capture the matched substring.

Create a simple capture around a pattern.

The capture value is the substring matched by `pattern`. If the inner pattern also captures values, those values follow the substring in the result. A failing pattern produces no capture.

```lua
local lpeg = require "lpeg"
local word = lpeg.C(lpeg.R("az")^1)
print(word:match("hello")) --> hello
```

#### `lpeg.Cc(...)`

Produce constant captures.

Create a constant capture that produces the given values.

The pattern matches the empty string and returns every argument unchanged. Constants are useful for tagging grammar results or providing fixed fields in table captures.

```lua
local lpeg = require "lpeg"
local tag = lpeg.Cc("number") * lpeg.C(lpeg.R("09")^1)
local kind, value = tag:match("42")
print(kind, value) --> number 42
```

#### `lpeg.Cmt(pattern, function)`

Match-time capture.

Create a match-time capture.

`function` is called immediately as `function(subject, position, ...captures)`. Returning a number moves the match position to that number; returning `true` succeeds without consuming input; returning `false`, `nil` or nothing fails the match. Any additional return values become capture values.

Unlike ordinary captures, the function runs while matching and may depend on the subject.

```lua
local lpeg = require "lpeg"
local p = lpeg.Cmt(lpeg.P(1)^0, function(s, i)
    return i > #s, #s
end)
print(p:match("abc")) --> 3
```

#### `lpeg.Cb(name)`

Back-reference capture.

Create a back-reference capture.

It matches the empty string and returns the values produced by the most recent complete, outermost group capture with the given key. The key may be any non-nil Lua value. Named groups are created with `lpeg.Cg(pattern, name)`.

```lua
local lpeg = require "lpeg"
local p = lpeg.Cg(lpeg.Cc("tag"), "kind") * lpeg.Cb("kind")
print(p:match("")) --> tag
```

#### `lpeg.Carg(n)`

Capture an extra argument.

Create an argument capture.

It matches the empty string and returns the `n`-th extra argument passed to `lpeg.match` after the initial position. This lets a pattern read contextual values without globals.

```lua
local lpeg = require "lpeg"
print(lpeg.match(lpeg.Carg(1), "", 1, "context")) --> context
```

#### `lpeg.Cp()`

Capture the current position.

Create a position capture.

It matches the empty string and returns the current 1-based subject position as a number. Wrapping a pattern with two `Cp` captures is a convenient way to find both ends of a match.

```lua
local lpeg = require "lpeg"
local p = lpeg.Cp() * lpeg.P("ab") * lpeg.Cp()
print(p:match("xab")) --> nil
print(p:match("abx")) --> 1 3
```

#### `lpeg.Cs(pattern)`

Substitution capture.

Create a substitution capture.

The result is the substring matched by `pattern`, with the text of every inner capture replaced by that capture's value. Inner values must therefore be strings. Non-captured text is copied unchanged.

```lua
local lpeg = require "lpeg"
local p = lpeg.Cs((lpeg.R("az")^1 / string.upper) * lpeg.P(1)^0)
print(p:match("hello world")) --> HELLO world
```

#### `lpeg.Ct(pattern)`

Table capture.

Create a table capture.

Anonymous capture values are stored in successive integer keys, while named groups created with `lpeg.Cg` are stored under their names. The single result is the new table. Captures that produce no value are omitted.

```lua
local lpeg = require "lpeg"
local p = lpeg.Ct(lpeg.C(lpeg.R("az")^1) * lpeg.P("=") * lpeg.C(lpeg.R("09")^1))
local t = p:match("age=42")
print(t[1], t[2]) --> age 42
```

#### `lpeg.Cf(pattern, function)`

Fold capture.

Create a fold capture.

`function` receives the accumulated value followed by the values captured by `pattern`, and its first return value replaces the accumulator. This construction is deprecated in LPeg 1.1 in favour of the `%` accumulator capture, but remains available.

```lua
local lpeg = require "lpeg"
local number = lpeg.R("09")^1 / tonumber
local add = function(a, b) return a + b end
local sum = lpeg.Cf(number * ("," * number)^0, add)
print(sum:match("10,30,43")) --> 83
```

#### `lpeg.Cg(pattern [, name])`

Group capture.

Group the captures produced by a pattern into one capture.

Without a name the values are joined into a single capture. With a name the group is also stored under that key by an enclosing `lpeg.Ct`, and can be retrieved later with `lpeg.Cb`. A named group usually produces no value by itself.

```lua
local lpeg = require "lpeg"
local p = lpeg.Ct(lpeg.Cg(lpeg.C(lpeg.R("az")^1), "name"))
local t = p:match("lua")
print(t.name) --> lua
```

#### `lpeg.type(value)`

Return the LPeg type of a value.

Return the LPeg type name for a value.

Patterns return the string `"pattern"`. Every other Lua value returns `nil`. This is useful for APIs that accept either a pattern or a value that can be converted with `lpeg.P`.

```lua
local lpeg = require "lpeg"
print(lpeg.type(lpeg.P("x"))) --> pattern
print(lpeg.type("x")) --> nil
```

#### `lpeg.version`

The running LPeg version string.

The running LPeg version as a string such as `"LPeg 1.1.0"`.

This field is a string, not a callable function. Read it directly when reporting diagnostics or checking for features.

```lua
local lpeg = require "lpeg"
print(lpeg.version) --> LPeg 1.1.0
```

#### `lpeg.setmaxstack(size)`

Set the maximum backtracking stack size.

Set the maximum size of LPeg's backtracking stack.

The default limit is 400 entries. Deeply recursive grammars or heavily backtracking patterns may need a larger value; well-written patterns usually do not. The function returns nothing.

```lua
local lpeg = require "lpeg"
lpeg.setmaxstack(1000)
```

#### `lpeg.locale([table])`

Create locale-aware patterns.

Create a table of locale-aware character-class patterns.

The fields are `alnum`, `alpha`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`, `space`, `upper` and `xdigit`, each matching one character in that class. When a table is supplied, the fields are added to it and the same table is returned; calling `lpeg.locale(lpeg)` therefore adds `lpeg.alpha`, `lpeg.digit` and the others directly to the module.

```lua
local lpeg = require "lpeg"
lpeg.locale(lpeg)
local word = lpeg.alpha^1
print(word:match("hello")) --> 6
```

#### `lpeg.utfR(...)`

Create UTF-8 aware range patterns.

Create a pattern matching one UTF-8 encoded code point in a range.

`cp1` and `cp2` are numeric code points with inclusive bounds. The pattern validates the UTF-8 byte sequence as well as the code-point range. The Unicode maximum is 0x10FFFF; surrogate code points are allowed by the range check.

```lua
local lpeg = require "lpeg"
local ascii_printable = lpeg.utfR(0x20, 0x7E)^1
print(ascii_printable:match("hello")) --> 6
```

### re

Regular expressions built on LPeg.

Upstream: https://www.inf.puc-rio.br/~roberto/lpeg/re.html

License: MIT

`re` implements a regular-expression syntax on top of LPeg.  Patterns can be
matched, searched, substituted and used in grammars.

#### `re.match(subject, pattern [, init])`

Match a pattern against a string.

Match a regular-expression pattern against a subject.

The pattern may be a string or an already compiled LPeg pattern. `init` optionally selects the starting position. The result is the sequence of captures produced by the pattern; if the pattern captures nothing, it is the position after the match. A failed match returns `nil`.

```lua
local re = require "re"
print(re.match("the number 423 is odd", "({%a+} / .)*"))
--> the number is odd
```

#### `re.find(subject, pattern [, init])`

Find the first match.

Search for the first occurrence of a pattern in a subject.

Returns the 1-based index where the match starts and the index where it ends, inclusive. Both values are `nil` when no match exists. The optional `init` gives a starting position, with negative values counted from the end.

```lua
local re = require "re"
local first, last = re.find("the number 423 is odd", "[0-9]+")
print(first, last) --> 12 14
```

#### `re.updatelocale()`

Refresh the locale-dependent character classes.

Re-read the current C locale and update the predefined character classes used by `%a`, `%c`, `%d`, `%g`, `%l`, `%p`, `%s`, `%u`, `%w` and `%x` (and their uppercase complements).

Call this after changing the process locale. The function returns nothing and does not affect already compiled patterns.

```lua
local re = require "re"
re.updatelocale()
```

#### `re.gsub(subject, pattern, replacement)`

Replace matches.

Replace every occurrence of a pattern in a subject.

`replacement` follows LPeg capture rules, so it may be a string with `%1`-style references, a function, a table, or a number selecting a capture. The whole subject is returned with all matches replaced.

```lua
local re = require "re"
print(re.gsub("hello World", "[aeiou]", "."))
--> h.ll. W.rld
```

#### `re.compile(pattern [, defs])`

Compile a pattern.

Compile a regular-expression string into an LPeg pattern.

The optional `defs` table supplies Lua values for named definitions used by the expression. If the argument is already an LPeg pattern it is returned unchanged. Invalid syntax raises an error containing `incorrect pattern`.

```lua
local re = require "re"
local number = re.compile("%d+")
print(number:match("123")) --> 4
```

### cjson

Fast JSON encoding and decoding.

Upstream: https://github.com/openresty/lua-cjson

License: MIT

`cjson.encode(value)` and `cjson.decode(string)` are the common entry points.
The module also exposes configuration functions for number precision, invalid
numbers, sparse arrays, maximum depth and indentation.

#### `cjson.encode(value)`

Encode a Lua value as JSON.

Serialise a Lua value as a JSON string.

Booleans, numbers, strings, `nil` and tables are supported. Tables with only consecutive positive integer keys become JSON arrays; other tables become objects with string keys. Unsupported values such as functions, threads and non-null userdata raise an error unless the skip option is enabled.

Encoding is controlled by the module configuration functions, including maximum depth, number precision, sparse-array handling and invalid numbers.

```lua
local cjson = require "cjson"
print(cjson.encode({ true, { foo = "bar" } }))
--> [true,{"foo":"bar"}]
```

#### `cjson.decode(string)`

Decode a JSON string.

Deserialise a JSON string into a Lua value.

Objects become tables, arrays become integer-keyed tables, and JSON `null` becomes the light userdata value `cjson.null`. Numeric object keys are converted to strings. Invalid numbers are accepted by default; see `decode_invalid_numbers`.

Syntax errors raise a Lua error rather than returning `nil`.

```lua
local cjson = require "cjson"
local value = cjson.decode('[true,{"n":1}]')
print(value[1], value[2].n) --> true 1
print(cjson.decode("null") == cjson.null) --> true
```

#### `cjson.new()`

Create a separate cjson instance.

Create an independent cjson instance.

The new module has its own configuration and encoding buffer, so changing one instance does not affect another. This is useful for threads or for keeping a strict encoder separate from a permissive one.

```lua
local cjson = require "cjson"
local pretty = cjson.new()
pretty.encode_indent("  ")
print(pretty.encode({ a = 1 }))
```

#### `cjson.encode_empty_table_as_object(boolean)`

Control empty-table encoding.

Control how empty Lua tables are encoded.

With `true` (the default) an empty table becomes `{}`. With `false` it becomes `[]`. Tables carrying `cjson.empty_array_mt` or `cjson.array_mt` are always arrays. The function returns the current setting and changes it only when an argument is supplied.

```lua
local cjson = require "cjson"
cjson.encode_empty_table_as_object(false)
print(cjson.encode({})) --> []
```

#### `cjson.decode_array_with_array_mt(boolean)`

Control array metatables.

Control whether decoded JSON arrays carry `cjson.array_mt`.

The default is `false`. When enabled, arrays produced by `decode` get the array metatable, which lets a later `encode` preserve the array type even for empty arrays.

The function returns the current setting and only changes it when given an argument.

```lua
local cjson = require "cjson"
cjson.decode_array_with_array_mt(true)
local value = cjson.decode("[]")
print(getmetatable(value) == cjson.array_mt) --> true
```

#### `cjson.decode_allow_comment(boolean)`

Allow comments while decoding.

Allow `//` and `/* ... */` comments while decoding.

Comments are disabled by default. When enabled they may appear wherever whitespace is allowed. Unterminated block comments still produce a decode error.

Returns the current setting; the value changes only when an argument is provided.

```lua
local cjson = require "cjson"
cjson.decode_allow_comment(true)
print(cjson.decode('{ // note\n "a": 1 }').a) --> 1
```

#### `cjson.encode_sparse_array(convert, ratio, safe)`

Configure sparse-array handling.

Configure how sparse Lua arrays are encoded.

`convert` controls whether an excessively sparse array becomes a JSON object instead of raising an error. `ratio` and `safe` determine the threshold: an array is excessively sparse when its maximum index exceeds both `safe` and `item_count * ratio`. Defaults are `false`, `2` and `10`.

All three current settings are returned. Missing arguments leave the corresponding setting unchanged.

```lua
local cjson = require "cjson"
cjson.encode_sparse_array(true)
print(cjson.encode({ [1000] = "x" }))
--> {"1000":"x"}
```

#### `cjson.encode_max_depth(depth)`

Set the maximum encode depth.

Set the maximum nesting depth accepted by `encode`.

The default is 1000. Exceeding the limit raises an error, preventing recursive or extremely deep tables from exhausting the stack. The value must be a positive integer.

Returns the current setting; it changes only when an argument is supplied.

```lua
local cjson = require "cjson"
local depth = cjson.encode_max_depth(50)
print(depth) --> 50
```

#### `cjson.decode_max_depth(depth)`

Set the maximum decode depth.

Set the maximum nesting depth accepted by `decode`.

The default is 1000. Deeper JSON arrays or objects are rejected with an error. This limits stack use on hostile input. The value must be a positive integer.

Returns the current setting; it changes only when an argument is supplied.

```lua
local cjson = require "cjson"
print(cjson.decode_max_depth(200)) --> 200
```

#### `cjson.encode_number_precision(precision)`

Set number precision.

Set the number of significant digits used when encoding numbers.

The default is 14 and the accepted range is 1 to 16. Lower values trade accuracy for speed when serialising large amounts of numeric data. Returns the current setting.

```lua
local cjson = require "cjson"
cjson.encode_number_precision(6)
print(cjson.encode({ math.pi })) --> [3.14159]
```

#### `cjson.encode_keep_buffer(boolean)`

Keep the encode buffer between calls.

Control whether the encoder keeps its reusable buffer between calls.

Keeping the buffer (the default) avoids repeated allocations and is fastest. Disabling it frees the buffer after every `encode` call, which is useful when the buffer would otherwise retain a large peak allocation.

Returns the current setting; the value changes only when an argument is provided.

```lua
local cjson = require "cjson"
cjson.encode_keep_buffer(false)
local keep = cjson.encode_keep_buffer()
print(keep) --> false
```

#### `cjson.encode_invalid_numbers(boolean)`

Control encoding of NaN and infinity.

Control how NaN and infinity are encoded.

`false` (the default) raises an error. `true` writes the non-standard tokens `NaN` and `Infinity`. The string `"null"` writes JSON `null`, keeping the output standards-compliant. Returns the current setting in the same form.

```lua
local cjson = require "cjson"
cjson.encode_invalid_numbers("null")
print(cjson.encode({ 0 / 0 })) --> [null]
```

#### `cjson.decode_invalid_numbers(boolean)`

Control decoding of NaN and infinity.

Control whether non-standard numeric tokens are accepted while decoding.

The default is `true`, so NaN, infinity and hexadecimal numbers are decoded. Set it to `false` to reject them. The current setting is returned and changes only when an argument is supplied.

```lua
local cjson = require "cjson"
cjson.decode_invalid_numbers(false)
local ok = pcall(cjson.decode, "NaN")
print(ok) --> false
```

#### `cjson.encode_escape_forward_slash(boolean)`

Escape forward slashes.

Control whether `/` is escaped as `\/` in encoded strings.

Escaping is enabled by default in this build. Disabling it produces shorter, still valid JSON. Returns the current setting.

```lua
local cjson = require "cjson"
cjson.encode_escape_forward_slash(false)
print(cjson.encode({ "a/b" })) --> ["a/b"]
```

#### `cjson.encode_skip_unsupported_value_types(boolean)`

Skip unsupported values.

Control what happens when encoding unsupported Lua types.

The default is `false`: functions, threads and userdata raise an error. When enabled, values that cannot be represented are omitted instead of aborting the whole encode operation. Returns the current setting.

```lua
local cjson = require "cjson"
cjson.encode_skip_unsupported_value_types(true)
print(cjson.encode({ 1, print, 2 })) --> [1,2]
```

#### `cjson.encode_indent(value)`

Pretty-print JSON with indentation.

Set the indentation used for pretty-printed JSON.

Pass a string such as `"  "` or `"\t"`. The empty string disables indentation. Returns the current indent, or `""` when pretty-printing is off. Arrays and objects gain newlines and the requested indentation.

```lua
local cjson = require "cjson"
cjson.encode_indent("  ")
print(cjson.encode({ a = 1 }))
--> {
-->   "a": 1
--> }
```

### zlib

Lua binding to zlib.

Upstream: https://github.com/brimworks/lua-zlib

License: MIT

`zlib.deflate()` and `zlib.inflate()` return streaming compressor/decompressor
functions.  `zlib.compress` and `zlib.decompress` are one-shot helpers.  Checksum
helpers `adler32` and `crc32` are also available.

#### `zlib.deflate([level [, window_bits]])`

Create a streaming deflate function.

Create a streaming deflate function.

`level` defaults to zlib's default compression level (`-1`), and `window_bits` defaults to 15. A negative window size requests raw deflate output without the zlib wrapper. The returned closure accepts a string chunk and an optional flush mode (`"none"`, `"sync"`, `"full"` or `"finish"`), and returns the compressed chunk, an end-of-stream flag, and total input/output byte counts.

Passing `nil` or no input finishes the stream. After `"finish"` the closure must not be called with more data.

```lua
local zlib = require "zlib"
local deflate = zlib.deflate()
local compressed = deflate("hello world", "finish")
print(#compressed > 0) --> true
```

#### `zlib.inflate([window_bits])`

Create a streaming inflate function.

Create a streaming inflate function.

`window_bits` defaults to 15 plus automatic gzip/zlib header detection. The returned closure accepts compressed input and returns the decompressed chunk, an end-of-stream flag, and total input/output byte counts. It accepts input split at arbitrary byte boundaries.

After the stream reports end-of-input, further calls with data raise an error.

```lua
local zlib = require "zlib"
local deflate = zlib.deflate()
local inflate = zlib.inflate()
local packed = deflate("hello", "finish")
print(inflate(packed)) --> hello
```

#### `zlib.compress(data [, level])`

Compress a string in one call.

Compress a complete string in one call.

`level` defaults to the zlib default and may be `zlib.BEST_SPEED` through `zlib.BEST_COMPRESSION`. The result is a zlib-wrapped compressed string. On success a second return value carries the zlib status code; initialisation failure returns `nil, code`.

```lua
local zlib = require "zlib"
local packed, status = zlib.compress("hello world", zlib.BEST_SPEED)
print(type(packed), type(status)) --> string number
```

#### `zlib.decompress(data [, window_bits])`

Decompress a string in one call.

Decompress a complete zlib stream in one call.

`window_bits` defaults to 15 and must match the stream format. Invalid or truncated input raises an error rather than returning a partial string.

```lua
local zlib = require "zlib"
local packed = zlib.compress("hello")
print(zlib.decompress(packed)) --> hello
```

#### `zlib.adler32([previous, data])`

Compute an Adler-32 checksum.

Create or update an Adler-32 checksum.

Called with no arguments it returns a checksum function; each call of that function accepts a string and returns the running checksum. In compatibility mode you may instead call `zlib.adler32(previous, data)` with a numeric starting checksum and a string, which returns the updated number directly.

```lua
local zlib = require "zlib"
local checksum = zlib.adler32()
checksum("one")
print(type(checksum(" two"))) --> number
```

#### `zlib.crc32([previous, data])`

Compute a CRC-32 checksum.

Create or update a CRC-32 checksum.

Called with no arguments it returns a stateful checksum function that accepts strings and returns the running CRC. Compatibility mode also accepts `zlib.crc32(previous, data)` and returns the updated number immediately.

```lua
local zlib = require "zlib"
local checksum = zlib.crc32()
print(type(checksum("hello"))) --> number
```

#### `zlib.version()`

Return the zlib version.

Return the linked zlib version as a numeric tuple.

The results are the major, minor and optional patch components, for example `1, 3, 1`. The patch value is `nil` when the version string omits it. This differs from some other zlib bindings that return a version string.

```lua
local zlib = require "zlib"
local major, minor, patch = zlib.version()
print(major, minor, patch)
```

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

Start the interactive Read-Eval-Print Loop.

The REPL runs `~/.config/zli/init.lua`, then `~/.config/zli/repl_init.lua`,
before showing the prompt. The generated `repl_init.lua` preloads common modules
such as `csv`, `cjson`, `log`, `lpeg`, `luaunit`, `re`, `filesystem`,
`sqlite3`, `stream`, `zip`, `zlib`, `crossline` and `collection`; edit that file
to change the defaults. History is kept in `~/.config/zli/repl_history`.

Enter `quit` or `exit`, or press Ctrl-D, to leave. `?expression` pretty-prints
tables and strings, `:help` shows the index, and `:help <name>` or
`:help --search <term>` looks up documentation. Incomplete statements continue
on the next line, and F1 shows the editing help. Running `zli` with no arguments
also starts the REPL.

```bash
zli @repl
```

#### `zli @sqlite`

Start the SQLite CLI.

Start the interactive SQLite command line.

The session begins with an in-memory database. A statement is executed when a
line contains `;`; continuation lines use the `>>` prompt. SQL errors are
printed and the session continues.

Commands are also terminated with `;`:

- `open "file.db";` closes the current database and opens a file.
- `close;` closes the current database and starts a new in-memory one.
- `file "script.sql";` executes statements from a file.
- `mode;` prints the current output mode.
- `mode table|csv|json|lua;` selects pretty table, CSV, JSON or Lua-table
  output.
- `quit;` or `exit;` leaves the CLI; Ctrl-D also exits.

History is stored in `~/.config/zli/sqlite_history`.

```bash
zli @sqlite
```

#### `zli @compile <config>`

Package Lua files into a standalone executable.

Create an executable that carries the listed files in its own payload.

The config is required. It may be a table constructor, for example
`output_name = "app"` plus `files = { ... }`, or a chunk that returns such a
table. `output_name` is required. `files` must be a non-empty list; each item is
either a path string or a table with `file` and an optional `name`. The entry
name defaults to the file's basename. Every source file must exist.

The tool copies the running executable, removes an existing payload, appends
the new zip payload and exits. On Windows `.exe` is added to `output_name` when
missing; on Linux the result is made executable (`755`). Errors are printed and
cause exit status `1`.

```lua
return {
    output_name = "myapp",
    files = {
        { file = "src/main.lua", name = "main.lua" },
        { file = "assets/data.txt" },
    },
}
```

#### `zli @test <file>`

Run a LuaUnit test file.

Execute a LuaUnit suite from the command line.

The file is read and executed, then LuaUnit runs every test whose name matches
`Test`; the process exits with LuaUnit's status. Test files can define global
tables named `Test...` or use LuaUnit directly. The normal ZLI init script runs
first, so configuration from `~/.config/zli/init.lua` is active. A missing file
argument prints an error and exits with status `1`.

```bash
zli @test test/test_stream.lua
```

#### `zli @manual [options]`

Serve the bundled reference manual.

Serve the bundled reference manual over HTTP.

The manual combines the Lua language and standard-library reference with all
authored library, tool and ZLI documentation. It listens on `127.0.0.1:8080`
by default and opens a browser using the platform launcher unless `--no-open`
is given. `/` (also `/index.html` and `/manual.html`) serves the manual,
`/search...` serves search results, and `/favicon.ico` returns `204`.

Options are `--port <port>`, `--address <address>`, `--no-open` and
`--output <file>`. `--output` writes the complete HTML manual to the file and
exits instead of starting the server. Invalid options or values print usage and
exit with status `2`.

```bash
zli @manual --port 9000 --no-open
zli @manual --output /tmp/manual.html
```

#### `zli @help [options] [query]`

Look up documentation.

Look up bundled documentation from the command line.

With a query, an exact entry name is shown first; otherwise a ranked result
list is printed. `--search` forces the ranked list, `--list` prints every
documented module and entry (including the Lua standard library), and
`--markdown` emits the generated library reference. A query may be split across
several arguments and is joined with spaces. With no query, a short index is
printed.

`--output <file>` writes the selected output to a file instead of stdout.
`--search` without a query is an error (status `2`), and a query with no matches
prints an error and exits with status `1`.

```bash
zli @help string.byte
zli @help --search trim
zli @help --list
zli @help --markdown --output doc/libraries.md
```

#### `zli @serve [directory]`

Serve a directory over HTTP.

Start a static file server for a directory.

The directory defaults to `./`. The tool listens on `127.0.0.1:8080`, prints
the URL, tries to open a browser on Windows or Linux, and serves the tree with
caching of static files disabled. Directories use `index.html` or `index.htm`
when present and otherwise produce a listing. Path traversal outside the web
root is rejected and MIME types come from the built-in `httpserver` table.

Only the first argument is used; the server blocks until the process is
stopped.

```bash
zli @serve ./public
zli @serve
```

## ZLI

### ZLI runtime

Interpreter globals and configuration.

The `ZLI` table is available to every script and REPL session.

#### `ZLI.version`

The ZLI version string.

Version string of the running ZLI build.

The value comes from the version file embedded in the binary, for example
`"0.1.9"`. It is a string and should be treated as read-only.

```lua
print(ZLI.version)
```

#### `ZLI.error_handling`

Default error style for libraries.

Set to `"raise"` before `require` to make libraries raise instead of returning `nil, message`.

#### `ZLI.exe_path`

The real path of the running executable.

Real filesystem path of the running executable.

ZLI resolves the executable path at startup instead of trusting `argv[0]`, so
the value remains usable when the binary is found through `PATH` or invoked
through a symlink. `@compile` uses it as the source binary to copy. The field is
a string and is read-only.

```lua
print(ZLI.exe_path)
```

#### `ZLI.dofile(name)`

Run a script from the payload.

Run a Lua script stored in the attached payload.

`name` is looked up as written and then with a `.lua` suffix, so both `tool` and
`tool.lua` work; `dir/tool` is supported. The script runs with the current
global environment and `arg` table. Errors, including a missing payload or
missing script, are raised; the function does not return a value.

This is the mechanism behind startup selection and is available to scripts that
want to invoke another payload entry.

```lua
local ok, err = pcall(ZLI.dofile, "does-not-exist")
print(ok, err) --> false  script 'does-not-exist' not found in payload
```

#### `~/.config/zli/init.lua`

User init script.

User init script, executed before every script and REPL session.

The file lives at `~/.config/zli/init.lua`. ZLI creates the configuration
directory and a commented starter file on first use. The script runs in the
global environment after the standard libraries and the `ZLI` table are
available, so it can set `ZLI.error_handling`, define helper globals, or preload
modules; anything it leaves global is visible to the selected program. An error
in this file aborts startup.

```lua
-- ~/.config/zli/init.lua
ZLI.error_handling = "raise"
function greet(name)
    return "hello " .. name
end
```

#### `~/.config/zli/repl_init.lua`

REPL init script.

REPL-only init script.

The file lives at `~/.config/zli/repl_init.lua` and is executed by `@repl`
after the global `init.lua`. If missing, the REPL creates it with assignments
for commonly used modules (`csv`, `cjson`, `log`, `lpeg`, `luaunit`, `re`,
`filesystem`, `sqlite3`, `stream`, `zip`, `zlib`, `crossline`, `collection`).
Use it for prompt helpers and other state that should exist only in interactive
sessions; errors abort the REPL.

```lua
-- ~/.config/zli/repl_init.lua
function reload(name)
    package.loaded[name] = nil
    return require(name)
end
```

#### `payload`

Embedded zip payload.

The zip archive appended to the ZLI executable.

The payload holds `main.lua`, the command line tools, library modules and
documentation. `zli @name` runs `name` or `name.lua` from it, and `@dir/name`
is supported. Lua's `require` also searches the payload for `name.lua` and
`name/init.lua`, so bundled modules load without being extracted. The payload
is opened through the real executable path, which keeps it available when the
binary is reached through `PATH` or a symlink.

Compiled executables created by `@compile` replace the standard payload with
the files listed in their config. A binary without an attached payload cannot
run `@` tools or `ZLI.dofile`.

```bash
zli @repl
zli @help string.byte
```

#### `argv[0] and payload selection`

How the executable name selects a payload script.

When no tool or script is given, ZLI selects a payload entry from the executable basename: `<exe-name>.lua` first, then `main.lua`, then `init.lua`.  On Windows, a trailing `.exe` is stripped from the basename.

The basename comes from `argv[0]`, so symlinks with different names can select different payload tools from the same executable.  The payload zip itself is opened through the real executable path, so the binary also works when found through `PATH`.

The Lua `arg[0]` value remains the executable name used to invoke ZLI; the selected payload script is not substituted into the argument table.  This is also true for filesystem scripts: the script path is not reflected in `arg[0]`.

#### `compiled executables`

Standalone executables created by `@compile`.

Standalone executables produced by `@compile`.

A compiled executable is a copy of ZLI with its standard payload replaced by
the files in the compile config. At startup it still runs
`~/.config/zli/init.lua`; then it selects `<executable-name>.lua`, `main.lua` or
`init.lua` from the new payload. A specific payload entry can be started with
`zli @name`, including `@dir/name`. On Windows the executable suffix is added
automatically; on Linux the output is marked executable.

The executable remains a full ZLI binary: standard libraries and native
bindings are available, but the bundled documentation and tools are only
present if their files were included in the config.

```bash
zli @compile myapp.lua
./myapp
```
