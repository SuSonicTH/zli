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
                        "```lua\n(\"hello\"):starts_with(\"he\") --> true\n```"),
                    entry("string.ends_with", "string.ends_with(value, suffix)", "method",
                        "Return true when a string ends with `suffix`.",
                        "```lua\n(\"hello\"):ends_with(\"lo\") --> true\n```"),
                    entry("string.contains", "string.contains(value, needle)", "method",
                        "Return true when a string contains `needle`.",
                        "Uses a plain-text search, not a Lua pattern."),
                    entry("string.is_empty", "string.is_empty(value)", "method",
                        "Return true for `nil` or the empty string.",
                        "Complements `string.is_not_empty`."),
                    entry("string.is_not_empty", "string.is_not_empty(value)", "method",
                        "Return true for a non-nil, non-empty string.",
                        "Complements `string.is_empty`."),
                    entry("string.split", "string.split(value [, separator])", "method",
                        "Split a string into a table.",
                        "The default separator is a single space."),
                    entry("string.to_table", "string.to_table(value [, separator])", "method",
                        "Split a string into a table.",
                        "Alias-like helper for `string.split`."),
                    entry("string.trim", "string.trim(value)", "method",
                        "Remove leading and trailing whitespace."),
                    entry("string.ltrim", "string.ltrim(value)", "method",
                        "Remove leading whitespace."),
                    entry("string.rtrim", "string.rtrim(value)", "method",
                        "Remove trailing whitespace."),
                    entry("string.base64encode", "string.base64encode(value)", "method",
                        "Encode a string as standard Base64."),
                    entry("string.base64decode", "string.base64decode(value)", "method",
                        "Decode a standard Base64 string."),
                    entry("string.base64urlEncode", "string.base64urlEncode(value)", "method",
                        "Encode a string as URL-safe Base64."),
                    entry("string.base64urlDecode", "string.base64urlDecode(value)", "method",
                        "Decode a URL-safe Base64 string."),
                    entry("string.urlEncode", "string.urlEncode(value)", "method",
                        "Percent-encode a string for use in a URL."),
                    entry("string.utf8len", "string.utf8len(value)", "method",
                        "Return the number of UTF-8 characters in a string."),
                    entry("table.copy", "table.copy(value [, copies])", "function",
                        "Deep-copy a table.",
                        "`copies` tracks already copied tables, which also makes the function safe for cyclic tables."),
                    entry("table.tostring", "table.tostring(value [, name])", "function",
                        "Pretty-print a table as a string.",
                        "Recursively formats tables.  `name` is used as the root label."),
                    entry("table.print", "table.print(value [, name])", "function",
                        "Pretty-print a table to standard output.",
                        "Equivalent to `print(table.tostring(value, name))`."),
                    entry("table.remove_if", "table.remove_if(value, predicate)", "function",
                        "Remove elements for which `predicate` is true."),
                    entry("table.filter", "table.filter(value, predicate)", "function",
                        "Return a new table with elements accepted by `predicate`."),
                    entry("table.add_all", "table.add_all(target, ...)", "function",
                        "Append all arguments to a table."),
                    entry("table.insert_all", "table.insert_all(target, index, ...)", "function",
                        "Insert all arguments at a position."),
                    entry("table.load", "table.load(filename)", "function",
                        "Load a serialized table from a file.",
                        "Uses `serpent` to deserialize the file."),
                    entry("table.save", "table.save(filename, value)", "function",
                        "Serialize a table to a file.",
                        "Uses `serpent` to produce a readable Lua representation."),
                    entry("table.default", "table.default(value, defaults [, error])", "function",
                        "Fill missing keys from a defaults table.",
                        "Returns `value`, with each missing key copied from `defaults`.  When `error` is true, unexpected keys raise an error."),
                    entry("table.insert_sorted", "table.insert_sorted(value, item [, comparator])", "function",
                        "Insert an item while keeping a sorted table ordered."),
                    entry("table.next", "table.next(value)", "function",
                        "Iterator helper used by `stream`.",
                        "Returns a stateless iterator over the array part of a table."),
                    entry("io.read_lines", "io.read_lines(filename)", "function",
                        "Read all lines from a file into a table."),
                    entry("io.write_lines", "io.write_lines(filename, lines [, eol])", "function",
                        "Write a table of lines to a file."),
                    entry("io.read_file", "io.read_file(filename)", "function",
                        "Read an entire file as a string."),
                    entry("io.write_file", "io.write_file(filename, data)", "function",
                        "Write a string to a file, replacing its contents."),
                    entry("io.append_file", "io.append_file(filename, data)", "function",
                        "Append a string to a file."),
                    entry("os.name", "os.name", "field",
                        "Operating system name.",
                        "One of `windows`, `linux`, `macos`, or the platform name reported by the interpreter."),
                    entry("os.home", "os.home", "field",
                        "The current user's home directory."),
                    entry("os.is_windows", "os.is_windows", "field",
                        "True on Windows."),
                    entry("os.is_linux", "os.is_linux", "field",
                        "True on Linux."),
                    entry("os.is_mac", "os.is_mac", "field",
                        "True on macOS."),
                    entry("os.separator", "os.separator", "field",
                        "The platform path separator (`\\` or `/`)."),
                    entry("os.nanotime", "os.nanotime()", "function",
                        "Return a monotonic timestamp in nanoseconds.",
                        "Used by `timer` and `benchmark`."),
                    entry("math.round", "math.round(value)", "function",
                        "Round a number to the nearest integer."),
                    entry("math.maxdouble", "math.maxdouble", "field",
                        "The largest finite double."),
                    entry("math.mindouble", "math.mindouble", "field",
                        "The smallest positive normalized double."),
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
`stream`, `union`, `intersection`, `difference` and `to_array`.
]==], {
                    entry("collection:size", "collection:size()", "method", "Return the number of elements."),
                    entry("collection:is_empty", "collection:is_empty()", "method", "Return true when the collection has no elements."),
                    entry("collection:add_all", "collection:add_all(items)", "method", "Add all items from another collection or table."),
                    entry("collection:remove_all", "collection:remove_all(items)", "method", "Remove all items found in another collection or table."),
                    entry("collection:contains_all", "collection:contains_all(items)", "method", "Return true when every item is present."),
                    entry("collection:equals", "collection:equals(other)", "method", "Compare two collections for equal contents."),
                    entry("collection:copy", "collection:copy()", "method", "Return a shallow copy."),
                    entry("collection:stream", "collection:stream()", "method", "Return a `stream` over the collection."),
                    entry("collection:union", "collection:union(...)", "method", "Return the union with other collections."),
                    entry("collection:intersection", "collection:intersection(...)", "method", "Return the intersection with other collections."),
                    entry("collection:difference", "collection:difference(...)", "method", "Return the difference with other collections."),
                    entry("collection:to_array", "collection:to_array()", "method", "Return the contents as an array."),
                }),

                module("collection.list", "collection.list", "Ordered list collection.", [==[
A list is an ordered sequence.  Methods that mutate a list return the list, so
calls can be chained.
]==], {
                    entry("collection.list.new", "collection.list.new([initial])", "function",
                        "Create a new list.", "`initial` may be an array or another collection."),
                    entry("collection.list.new_sorted", "collection.list.new_sorted([initial [, comparator]])", "function",
                        "Create a list that keeps its elements sorted."),
                    entry("collection.list:add", "list:add([index,] item, ...)", "method",
                        "Add one or more items, optionally at an index."),
                    entry("collection.list:add_all", "list:add_all([index,] items)", "method",
                        "Add all items from a table or collection."),
                    entry("collection.list:clear", "list:clear([size])", "method",
                        "Remove all items.", "The optional size is a capacity hint."),
                    entry("collection.list:contains", "list:contains(item)", "method",
                        "Return true when the item is present."),
                    entry("collection.list:get", "list:get(index)", "method",
                        "Return the item at an index."),
                    entry("collection.list:set", "list:set(index, item)", "method",
                        "Replace the item at an index."),
                    entry("collection.list:index_of", "list:index_of(item)", "method",
                        "Return the first index of an item, or nil."),
                    entry("collection.list:last_index_of", "list:last_index_of(item)", "method",
                        "Return the last index of an item, or nil."),
                    entry("collection.list:remove", "list:remove(item)", "method",
                        "Remove the first occurrence of an item."),
                    entry("collection.list:remove_index", "list:remove_index(index)", "method",
                        "Remove and return the item at an index."),
                    entry("collection.list:retain_all", "list:retain_all(items)", "method",
                        "Keep only items present in another collection."),
                    entry("collection.list:sublist", "list:sublist(from, to)", "method",
                        "Return a new list containing the given range."),
                    entry("collection.list:for_each", "list:for_each(func)", "method",
                        "Call `func` for every item."),
                    entry("collection.list:for_each_index", "list:for_each_index(func)", "method",
                        "Call `func(index, item)` for every item."),
                    entry("collection.list:iterate", "list:iterate()", "method",
                        "Return an iterator over items."),
                    entry("collection.list:iterate_indexed", "list:iterate_indexed()", "method",
                        "Return an iterator over indexes and items."),
                    entry("collection.list:iterator", "list:iterator(func)", "method",
                        "Create a stateless iterator from a function."),
                    entry("collection.list:iterator_indexed", "list:iterator_indexed(func)", "method",
                        "Create an indexed stateless iterator."),
                }),

                module("collection.map", "collection.map", "Key-value map collection.", [==[
Maps preserve key/value associations and provide ordered variants through
`new_ordered`.
]==], {
                    entry("collection.map.new", "collection.map.new([initial])", "function",
                        "Create a new map."),
                    entry("collection.map.new_ordered", "collection.map.new_ordered([initial])", "function",
                        "Create a map that iterates in insertion order."),
                    entry("collection.map:put", "map:put(key, value)", "method",
                        "Associate a key with a value."),
                    entry("collection.map:get", "map:get(key)", "method",
                        "Return the value for a key, or nil."),
                    entry("collection.map:get_or_default", "map:get_or_default(key, default)", "method",
                        "Return a value or a default."),
                    entry("collection.map:put_all", "map:put_all(table)", "method",
                        "Copy all key/value pairs from a table or map."),
                    entry("collection.map:put_if_absent", "map:put_if_absent(key, value)", "method",
                        "Insert a key only when it is not present."),
                    entry("collection.map:remove", "map:remove(key [, value])", "method",
                        "Remove a key, optionally only when it has a given value."),
                    entry("collection.map:merge", "map:merge(key, value, func)", "method",
                        "Merge a value into an existing key using `func`."),
                    entry("collection.map:replace", "map:replace(key, old, new)", "method",
                        "Replace a value when it currently equals `old`."),
                    entry("collection.map:contains_key", "map:contains_key(key)", "method",
                        "Return true when a key exists."),
                    entry("collection.map:contains_value", "map:contains_value(value)", "method",
                        "Return true when a value exists."),
                    entry("collection.map:entry_set", "map:entry_set()", "method",
                        "Return the entries as a set."),
                    entry("collection.map:key_set", "map:key_set()", "method",
                        "Return the keys as a set."),
                    entry("collection.map:values", "map:values()", "method",
                        "Return the values as a collection."),
                    entry("collection.map:equals", "map:equals(other)", "method",
                        "Compare two maps for equal contents."),
                    entry("collection.map:compute", "map:compute(key, func)", "method",
                        "Compute a new value for a key."),
                    entry("collection.map:compute_if_absent", "map:compute_if_absent(key, func)", "method",
                        "Compute a value only when the key is absent."),
                    entry("collection.map:compute_if_present", "map:compute_if_present(key, func)", "method",
                        "Compute a value only when the key is present."),
                    entry("collection.map:for_each", "map:for_each(func)", "method",
                        "Call `func(key, value)` for every entry."),
                    entry("collection.map:iterate", "map:iterate()", "method",
                        "Return an iterator over keys and values."),
                    entry("collection.map:iterator", "map:iterator(func)", "method",
                        "Create a stateless iterator from a function."),
                    entry("collection.map:size", "map:size()", "method",
                        "Return the number of entries."),
                    entry("collection.map:is_empty", "map:is_empty()", "method",
                        "Return true when the map has no entries."),
                }),

                module("collection.set", "collection.set", "Set collection with optional insertion order.", [==[
A set stores unique values.  `new_ordered` preserves insertion order during
iteration.
]==], {
                    entry("collection.set.new", "collection.set.new([initial])", "function",
                        "Create a new set."),
                    entry("collection.set.new_ordered", "collection.set.new_ordered([initial])", "function",
                        "Create an insertion-ordered set."),
                    entry("collection.set:add", "set:add(item, ...)", "method",
                        "Add one or more unique values."),
                    entry("collection.set:remove", "set:remove(item)", "method",
                        "Remove a value."),
                    entry("collection.set:contains", "set:contains(item)", "method",
                        "Return true when a value is present."),
                    entry("collection.set:retain_all", "set:retain_all(items)", "method",
                        "Keep only values also present in another collection."),
                    entry("collection.set:for_each", "set:for_each(func)", "method",
                        "Call `func(value)` for every value."),
                    entry("collection.set:iterate", "set:iterate()", "method",
                        "Return an iterator over values."),
                    entry("collection.set:iterate_indexed", "set:iterate_indexed()", "method",
                        "Return an iterator over indexes and values."),
                    entry("collection.set:iterator", "set:iterator(func)", "method",
                        "Create a stateless iterator from a function."),
                    entry("collection.set:iterator_indexed", "set:iterator_indexed(func)", "method",
                        "Create an indexed stateless iterator."),
                    entry("collection.set:size", "set:size()", "method",
                        "Return the number of values."),
                    entry("collection.set:is_empty", "set:is_empty()", "method",
                        "Return true when the set is empty."),
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
                        "Return the current working directory."),
                    entry("filesystem.create_path", "fs.create_path(path, name)", "function",
                        "Create a path object from a directory and file name."),
                    entry("filesystem.path", "fs.path(...)", "function",
                        "Normalize components into a path object.",
                        "Accepts strings, path objects and path component tables.  Relative paths stay relative; paths beginning with `.` or `..` are resolved against the current directory."),
                    entry("filesystem.ensure_path", "fs.ensure_path(path)", "function",
                        "Return a path object, converting a string when needed."),
                    entry("filesystem.get_path", "fs.get_path(path)", "function",
                        "Return the underlying path string of a path object."),
                    entry("filesystem.absolute", "fs.absolute(path)", "function",
                        "Return the absolute path, or nil when it does not exist."),
                    entry("filesystem.concat_path", "fs.concat_path(path, file)", "function",
                        "Join a path with a file name."),
                    entry("filesystem.split_path", "fs.split_path(path)", "function",
                        "Split a path into components."),
                    entry("filesystem.create_tree", "fs.create_tree(path)", "function",
                        "Create a directory and all missing parents."),
                    entry("filesystem.delete_tree", "fs.delete_tree(path)", "function",
                        "Delete a directory tree recursively."),
                    entry("filesystem.list", "path:list()", "method",
                        "Return the directory entries as an array of path objects."),
                    entry("filesystem.dir", "path:dir()", "method",
                        "Return the directory entries keyed by name."),
                    entry("filesystem.iterate", "fs.iterate(path [, sorted])", "method",
                        "Iterate the entries of a directory."),
                    entry("filesystem.walk", "fs.walk(path, func [, dir_first])", "function",
                        "Walk a directory tree, calling `func(path)` for each entry."),
                    entry("filesystem.tree", "fs.tree(path [, dir_first])", "function",
                        "Return all paths in a directory tree."),
                    entry("filesystem.tree_size", "fs.tree_size(path)", "function",
                        "Return the total size of files in a tree."),
                    entry("filesystem.tree_size_hr", "fs.tree_size_hr(path)", "function",
                        "Return a human-readable tree size."),
                    entry("filesystem.stream", "fs.stream(path)", "function",
                        "Create a stream over directory entries."),
                    entry("filesystem.stream_tree", "fs.stream_tree(path [, dir_first])", "function",
                        "Create a stream over a directory tree."),
                    entry("filesystem.read_all", "fs.read_all(path)", "function",
                        "Read an entire file as a string."),
                    entry("filesystem.read_lines", "fs.read_lines(path [, mode])", "function",
                        "Read a file into an array of lines."),
                    entry("filesystem.lines", "fs.lines(path [, mode])", "function",
                        "Iterate the lines of a file.",
                        "Yields `index, line`.  Use `for _, line in fs.lines(path) do`."),
                    entry("filesystem.parent", "fs.parent(path)", "function",
                        "Return the parent path."),
                    entry("filesystem.child", "fs.child(path, name)", "function",
                        "Return a child path."),
                    entry("filesystem.sibling", "fs.sibling(path, name)", "function",
                        "Return a sibling path."),
                    entry("filesystem.to_relative", "fs.to_relative(path, base [, include_top])", "function",
                        "Return a path relative to a base path."),
                    entry("filesystem.is_empty", "fs.is_empty(path)", "function",
                        "Return true when a directory has no entries."),
                    entry("filesystem.chmod", "fs.chmod(path, mode)", "function",
                        "Change file permissions on Linux.",
                        "Returns true on success.  The mode is an octal string such as `\"755\"`."),
                    entry("filesystem.chown", "fs.chown(path, owner)", "function",
                        "Change file ownership on Linux."),
                    entry("filesystem.size_to_hr", "fs.size_to_hr(bytes)", "function",
                        "Format a byte count as a human-readable size."),
                    entry("filesystem.config", "fs:config(options)", "method",
                        "Configure a loaded filesystem module.",
                        "Accepts `{ error_handling = \"return\" | \"raise\" }` and returns the same module table."),

                    entry("filesystem.path:exists", "path:exists()", "method", "Return true when the path exists."),
                    entry("filesystem.path:is_file", "path:is_file()", "method", "Return true for a regular file."),
                    entry("filesystem.path:is_directory", "path:is_directory()", "method", "Return true for a directory."),
                    entry("filesystem.path:size", "path:size()", "method", "Return the file size in bytes."),
                    entry("filesystem.path:size_hr", "path:size_hr()", "method", "Return a human-readable size."),
                    entry("filesystem.path:stat", "path:stat()", "method", "Return file metadata."),
                    entry("filesystem.path:access_time", "path:access_time()", "method", "Return the last access time."),
                    entry("filesystem.path:create_time", "path:create_time()", "method", "Return the creation time."),
                    entry("filesystem.path:modify_time", "path:modify_time()", "method", "Return the last modification time."),
                    entry("filesystem.path:access_time_ms", "path:access_time_ms()", "method", "Return access time in milliseconds."),
                    entry("filesystem.path:create_time_ms", "path:create_time_ms()", "method", "Return creation time in milliseconds."),
                    entry("filesystem.path:modify_time_ms", "path:modify_time_ms()", "method", "Return modification time in milliseconds."),
                    entry("filesystem.path:access_time_stamp", "path:access_time_stamp()", "method", "Return a formatted access timestamp."),
                    entry("filesystem.path:create_time_stamp", "path:create_time_stamp()", "method", "Return a formatted creation timestamp."),
                    entry("filesystem.path:modify_time_stamp", "path:modify_time_stamp()", "method", "Return a formatted modification timestamp."),
                    entry("filesystem.path:mode", "path:mode()", "method", "Return the file mode."),
                    entry("filesystem.path:mode_flags", "path:mode_flags()", "method", "Return the file mode flags."),
                    entry("filesystem.path:open", "path:open([mode])", "method", "Open the file and return a file handle."),
                    entry("filesystem.path:rename", "path:rename(new_path) / path:mv(new_path)", "method", "Rename or move the path."),
                    entry("filesystem.path:delete", "path:delete() / path:rm()", "method", "Delete the file or empty directory."),
                    entry("filesystem.path:change_directory", "path:change_directory() / path:cd()", "method", "Change the current directory to this path."),
                    entry("filesystem.path:create_directory", "path:create_directory() / path:mkdir()", "method", "Create the directory."),
                    entry("filesystem.path:read_all", "path:read_all()", "method", "Read the file as a string."),
                    entry("filesystem.path:read_lines", "path:read_lines([mode])", "method", "Read the file into an array of lines."),
                    entry("filesystem.path:lines", "path:lines([mode])", "method", "Iterate the lines of the file."),
                    entry("filesystem.path:iterate", "path:iterate([sorted])", "method", "Iterate directory entries."),
                    entry("filesystem.path:delete_tree", "path:delete_tree()", "method", "Delete the directory tree."),
                    entry("filesystem.path:walk", "path:walk(func [, dir_first])", "method", "Walk the directory tree."),
                    entry("filesystem.path:parent", "path:parent()", "method", "Return the parent path."),
                    entry("filesystem.path:child", "path:child(name)", "method", "Return a child path."),
                    entry("filesystem.path:sibling", "path:sibling(name)", "method", "Return a sibling path."),
                    entry("filesystem.path:stream", "path:stream()", "method", "Create a stream over directory entries."),
                    entry("filesystem.path:stream_tree", "path:stream_tree([dir_first])", "method", "Create a stream over the tree."),
                    entry("filesystem.path:tree", "path:tree([dir_first])", "method", "Return the tree as an array of paths."),
                    entry("filesystem.path:to_relative", "path:to_relative(base [, include_top])", "method", "Return a relative path."),
                    entry("filesystem.path:chmod", "path:chmod(mode)", "method", "Change permissions."),
                    entry("filesystem.path:chown", "path:chown(owner)", "method", "Change ownership."),
                }, { aliases = { "fs" } }),

                module("grid", "grid", "Line-drawing text grids (tables).", [==[
`grid.new(config [, rows])` creates a text table.  `config` is an array of column
definitions: `{ name, align, min_width, max_width, fixed_width }`.  The table
configuration may also set `show_header` and `padding`.
]==], {
                    entry("grid.new", "grid.new(config [, rows])", "function",
                        "Create a grid.", "Accepts either `grid.new(config)` or `grid:new(config)`."),
                    entry("grid:add_row", "grid:add_row(...) / grid:add_row(table)", "method",
                        "Add a row of values."),
                    entry("grid:add_rows", "grid:add_rows(rows)", "method", "Add multiple rows."),
                    entry("grid:header_string", "grid:header_string()", "method", "Return the header lines."),
                    entry("grid:row_string", "grid:row_string(...)", "method", "Return one rendered row."),
                    entry("grid:last_string", "grid:last_string()", "method", "Return the bottom border."),
                    entry("grid:print_header", "grid:print_header()", "method", "Print the header."),
                    entry("grid:print_row", "grid:print_row(...)", "method", "Print one row."),
                    entry("grid:print_last", "grid:print_last()", "method", "Print the bottom border."),
                    entry("grid:tostring", "grid:tostring()", "method", "Render the complete table as a string."),
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
                    entry("luastrip.string", "luastrip.string(source)", "function", "Strip a Lua source string."),
                    entry("luastrip.file", "luastrip.file(input, output)", "function", "Strip a Lua source file into another file."),
                    entry("luastrip.config", "luastrip:config(options)", "method", "Configure a loaded luastrip module."),
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
                    entry("stream.stream", "stream(iterator)", "function", "Create a stream from an iterator, table or function."),
                    entry("stream.of", "stream.of(...)", "function", "Create a stream from values."),
                    entry("stream:map", "stream:map(func)", "method", "Transform each value."),
                    entry("stream:peek", "stream:peek(func)", "method", "Inspect each value without changing it."),
                    entry("stream:filter", "stream:filter(func)", "method", "Keep values accepted by `func`."),
                    entry("stream:skip", "stream:skip(count)", "method", "Skip the first `count` values."),
                    entry("stream:limit", "stream:limit(count)", "method", "Limit the stream to `count` values."),
                    entry("stream:reverse", "stream:reverse()", "method", "Reverse the remaining values."),
                    entry("stream:sort", "stream:sort([comparator])", "method", "Sort the remaining values."),
                    entry("stream:maptonumber", "stream:maptonumber()", "method", "Convert each value to a number."),
                    entry("stream:distinct", "stream:distinct()", "method", "Drop duplicate values."),
                    entry("stream:split", "stream:split(func)", "method", "Split into matching and non-matching streams."),
                    entry("stream:join", "stream:join(...)", "method", "Concatenate streams."),
                    entry("stream:foreach", "stream:foreach(func)", "method", "Consume the stream, calling `func` for each value."),
                    entry("stream:toarray", "stream:toarray()", "method", "Consume the stream into an array."),
                    entry("stream:tosortedarray", "stream:tosortedarray([comparator])", "method", "Consume into a sorted array."),
                    entry("stream:print", "stream:print()", "method", "Print each value."),
                    entry("stream:concat", "stream:concat([separator])", "method", "Join values into a string."),
                    entry("stream:allmatch", "stream:allmatch(func)", "method", "Return true when every value matches."),
                    entry("stream:firstmatch", "stream:firstmatch(func)", "method", "Return the first matching value."),
                    entry("stream:nonmatch", "stream:nonmatch(func)", "method", "Return true when no value matches."),
                    entry("stream:anymatch", "stream:anymatch(func)", "method", "Return true when any value matches."),
                    entry("stream:first", "stream:first()", "method", "Return the first value."),
                    entry("stream:last", "stream:last()", "method", "Return the last value."),
                    entry("stream:count", "stream:count()", "method", "Count the remaining values."),
                    entry("stream:sum", "stream:sum()", "method", "Sum numeric values."),
                    entry("stream:average", "stream:average()", "method", "Average numeric values."),
                    entry("stream:median", "stream:median()", "method", "Median numeric value."),
                    entry("stream:iterator", "stream:iterator()", "method", "Return the underlying iterator."),
                    entry("stream:collector", "stream:collector(func)", "method", "Apply a collector function."),
                    entry("stream:reduce", "stream:reduce(state, func)", "method", "Fold the stream into a value."),
                    entry("stream:min", "stream:min([comparator])", "method", "Return the minimum value."),
                    entry("stream:max", "stream:max([comparator])", "method", "Return the maximum value."),
                    entry("stream:groupby", "stream:groupby(func)", "method", "Group values by a key function."),
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
                    entry("timer.new", "timer.new([start])", "function", "Create a timer."),
                    entry("timer:start", "timer:start()", "method", "Start or restart the timer."),
                    entry("timer:lap", "timer:lap()", "method", "Record a lap and return the lap time."),
                    entry("timer:stop", "timer:stop()", "method", "Stop the timer and return the elapsed time."),
                    entry("timer:time", "timer:time()", "method", "Return the last measured time."),
                    entry("timer:elapsed", "timer:elapsed()", "method", "Return the time since the timer started."),
                    entry("timer:lap_elapsed", "timer:lap_elapsed()", "method", "Return the time since the last lap."),
                    entry("timer:reset", "timer:reset()", "method", "Reset the timer and its laps."),
                }),

                module("uuid", "uuid", "UUID generation.", [==[
The `uuid` module generates RFC 9562 UUIDs.  `uuid.v4()` generates a random
UUID and `uuid.v7()` a time-ordered UUID.
]==], {
                    entry("uuid.v4", "uuid.v4()", "function", "Generate a version 4 (random) UUID."),
                    entry("uuid.v7", "uuid.v7()", "function", "Generate a version 7 (time-ordered) UUID."),
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
                    entry("xlsxmlwriter:newSheet", "workbook:newSheet([name])", "method", "Start a new worksheet."),
                    entry("xlsxmlwriter:closeSheet", "workbook:closeSheet()", "method", "Close the current worksheet."),
                    entry("xlsxmlwriter:nextRow", "workbook:nextRow(...)", "method", "Start a new row, optionally with cells."),
                    entry("xlsxmlwriter:endRow", "workbook:endRow()", "method", "End the current row."),
                    entry("xlsxmlwriter:addRow", "workbook:addRow(values)", "method", "Add a complete row from a table."),
                    entry("xlsxmlwriter:cells", "workbook:cells(...)", "method", "Append cells to the current row."),
                    entry("xlsxmlwriter:addCells", "workbook:addCells(values)", "method", "Append cells from a table."),
                    entry("xlsxmlwriter:cell", "workbook:cell(value)", "method", "Append a single cell."),
                    entry("xlsxmlwriter:close", "workbook:close()", "method", "Finish the workbook and close the file."),
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
                    entry("csv.parse", "csv.parse(input [, delimiter [, options]])", "function", "Parse CSV data."),
                    entry("csv.parseLine", "csv.parseLine(line [, delimiter [, options]])", "function", "Parse a single CSV line."),
                    entry("csv.encode", "csv.encode(table [, delimiter [, options]])", "function", "Encode a table as CSV."),
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
                    entry("sqlite3.open", "sqlite3.open(filename [, flags])", "function", "Open a database file."),
                    entry("sqlite3.open_memory", "sqlite3.open_memory()", "function", "Open an in-memory database."),
                    entry("sqlite3.open_ptr", "sqlite3.open_ptr(pointer)", "function", "Open a database from a raw pointer."),
                    entry("sqlite3.version", "sqlite3.version()", "function", "Return the SQLite version."),
                    entry("sqlite3.lversion", "sqlite3.lversion()", "function", "Return the LuaSQLite3 version."),
                    entry("sqlite3.complete", "sqlite3.complete(sql)", "function", "Return true when a SQL string is complete."),
                    entry("sqlite3.temp_directory", "sqlite3.temp_directory([path])", "function", "Get or set the temporary directory."),
                    entry("sqlite3.backup_init", "sqlite3.backup_init(destination, source [, name])", "function", "Create an online backup object."),
                    entry("sqlite3.db:exec", "db:exec(sql)", "method", "Execute SQL statements."),
                    entry("sqlite3.db:execute", "db:execute(sql)", "method", "Execute SQL and return prepared statement results."),
                    entry("sqlite3.db:prepare", "db:prepare(sql)", "method", "Prepare a SQL statement."),
                    entry("sqlite3.db:rows", "db:rows(sql [, parameters])", "method", "Iterate result rows as arrays."),
                    entry("sqlite3.db:nrows", "db:nrows(sql [, parameters])", "method", "Iterate result rows as name/value tables."),
                    entry("sqlite3.db:urows", "db:urows(sql [, parameters])", "method", "Iterate a single-column result."),
                    entry("sqlite3.db:close", "db:close()", "method", "Close the database."),
                    entry("sqlite3.db:isopen", "db:isopen()", "method", "Return true when the database is open."),
                    entry("sqlite3.db:changes", "db:changes()", "method", "Return the number of changed rows."),
                    entry("sqlite3.db:total_changes", "db:total_changes()", "method", "Return total changed rows."),
                    entry("sqlite3.db:last_insert_rowid", "db:last_insert_rowid()", "method", "Return the last inserted row id."),
                    entry("sqlite3.db:errcode", "db:errcode()", "method", "Return the last error code."),
                    entry("sqlite3.db:errmsg", "db:errmsg()", "method", "Return the last error message."),
                    entry("sqlite3.db:busy_timeout", "db:busy_timeout(timeout)", "method", "Set the busy timeout."),
                    entry("sqlite3.db:interrupt", "db:interrupt()", "method", "Interrupt the current operation."),
                    entry("sqlite3.db:create_function", "db:create_function(name, nargs, func)", "method", "Register a scalar SQL function."),
                    entry("sqlite3.db:create_aggregate", "db:create_aggregate(name, nargs, step, final)", "method", "Register an aggregate SQL function."),
                    entry("sqlite3.db:create_collation", "db:create_collation(name, func)", "method", "Register a collation."),
                    entry("sqlite3.db:trace", "db:trace(func)", "method", "Install a trace callback."),
                    entry("sqlite3.db:progress_handler", "db:progress_handler(n, func)", "method", "Install a progress handler."),
                    entry("sqlite3.db:update_hook", "db:update_hook(func)", "method", "Install an update hook."),
                    entry("sqlite3.db:commit_hook", "db:commit_hook(func)", "method", "Install a commit hook."),
                    entry("sqlite3.db:rollback_hook", "db:rollback_hook(func)", "method", "Install a rollback hook."),
                    entry("sqlite3.stmt:step", "stmt:step()", "method", "Advance a prepared statement."),
                    entry("sqlite3.stmt:reset", "stmt:reset()", "method", "Reset a prepared statement."),
                    entry("sqlite3.stmt:finalize", "stmt:finalize()", "method", "Finalize a prepared statement."),
                    entry("sqlite3.stmt:bind", "stmt:bind(index, value)", "method", "Bind a value to a parameter."),
                    entry("sqlite3.stmt:bind_values", "stmt:bind_values(...)", "method", "Bind positional parameters."),
                    entry("sqlite3.stmt:bind_names", "stmt:bind_names(table)", "method", "Bind named parameters."),
                    entry("sqlite3.stmt:columns", "stmt:columns()", "method", "Return result column names."),
                    entry("sqlite3.stmt:get_value", "stmt:get_value(index)", "method", "Return a result value."),
                    entry("sqlite3.stmt:get_values", "stmt:get_values()", "method", "Return all result values."),
                    entry("sqlite3.stmt:get_type", "stmt:get_type(index)", "method", "Return a result value type."),
                    entry("sqlite3.stmt:get_types", "stmt:get_types()", "method", "Return all result value types."),
                    entry("sqlite3.stmt:get_uvalue", "stmt:get_uvalue(index)", "method", "Return an uncoerced result value."),
                    entry("sqlite3.stmt:get_uvalues", "stmt:get_uvalues()", "method", "Return all uncoerced result values."),
                    entry("sqlite3.stmt:get_utype", "stmt:get_utype(index)", "method", "Return an uncoerced result type."),
                    entry("sqlite3.stmt:get_utypes", "stmt:get_utypes()", "method", "Return all uncoerced result types."),
                    entry("sqlite3.stmt:get_name", "stmt:get_name(index)", "method", "Return a column name."),
                    entry("sqlite3.stmt:get_names", "stmt:get_names()", "method", "Return all column names."),
                    entry("sqlite3.stmt:get_named_values", "stmt:get_named_values()", "method", "Return results as a name/value table."),
                    entry("sqlite3.stmt:get_named_types", "stmt:get_named_types()", "method", "Return result types as a name/value table."),
                    entry("sqlite3.stmt:bind_parameter_count", "stmt:bind_parameter_count()", "method", "Return the number of parameters."),
                    entry("sqlite3.stmt:bind_parameter_name", "stmt:bind_parameter_name(index)", "method", "Return a parameter name."),
                    entry("sqlite3.stmt:bind_blob", "stmt:bind_blob(index, data [, destructor])", "method", "Bind a blob value."),
                }, { upstream = "http://lua.sqlite.org/", license = "MIT" }),

                module("luaunit", "luaunit", "Unit-testing framework for Lua.", [==[
LuaUnit discovers global tables whose names begin with `Test` and functions whose
names begin with `test`.  Assertions are exported as `assert*` functions.

`luaunit.run()` runs the registered tests and returns the number of failures.
]==], {
                    entry("luaunit.run", "luaunit.run([...])", "function", "Run the test suite."),
                    entry("luaunit.assertEquals", "luaunit.assertEquals(actual, expected [, message])", "function", "Assert equality."),
                    entry("luaunit.assertNotEquals", "luaunit.assertNotEquals(actual, expected [, message])", "function", "Assert inequality."),
                    entry("luaunit.assertAlmostEquals", "luaunit.assertAlmostEquals(actual, expected, margin [, message])", "function", "Assert approximate equality."),
                    entry("luaunit.assertItemsEquals", "luaunit.assertItemsEquals(actual, expected [, message])", "function", "Assert that two tables contain the same items."),
                    entry("luaunit.assertStrContains", "luaunit.assertStrContains(value, substring [, isPattern [, message]])", "function", "Assert that a string contains a substring."),
                    entry("luaunit.assertStrIContains", "luaunit.assertStrIContains(value, substring [, message])", "function", "Case-insensitive substring assertion."),
                    entry("luaunit.assertNotStrContains", "luaunit.assertNotStrContains(value, substring [, isPattern [, message]])", "function", "Assert that a string does not contain a substring."),
                    entry("luaunit.assertNotStrIContains", "luaunit.assertNotStrIContains(value, substring [, message])", "function", "Case-insensitive negative substring assertion."),
                    entry("luaunit.assertStrMatches", "luaunit.assertStrMatches(value, pattern [, start [, final [, message]]])", "function", "Assert a string pattern match."),
                    entry("luaunit.assertError", "luaunit.assertError(func, ...)", "function", "Assert that a call raises an error."),
                    entry("luaunit.assertErrorMsgEquals", "luaunit.assertErrorMsgEquals(message, func, ...)", "function", "Assert an exact error message."),
                    entry("luaunit.assertErrorMsgContentEquals", "luaunit.assertErrorMsgContentEquals(message, func, ...)", "function", "Assert an error message ignoring file and line prefix."),
                    entry("luaunit.assertErrorMsgContains", "luaunit.assertErrorMsgContains(partial, func, ...)", "function", "Assert an error message contains text."),
                    entry("luaunit.assertErrorMsgMatches", "luaunit.assertErrorMsgMatches(pattern, func, ...)", "function", "Assert an error message matches a pattern."),
                    entry("luaunit.assertEvalToTrue", "luaunit.assertEvalToTrue(value [, message])", "function", "Assert that a value evaluates to true."),
                    entry("luaunit.assertEvalToFalse", "luaunit.assertEvalToFalse(value [, message])", "function", "Assert that a value evaluates to false."),
                    entry("luaunit.assertIsTrue", "luaunit.assertIsTrue(value [, message])", "function", "Assert a true value.", nil, { "luaunit.assertTrue" }),
                    entry("luaunit.assertNotIsTrue", "luaunit.assertNotIsTrue(value [, message])", "function", "Assert a non-true value."),
                    entry("luaunit.assertIsFalse", "luaunit.assertIsFalse(value [, message])", "function", "Assert a false value.", nil, { "luaunit.assertFalse" }),
                    entry("luaunit.assertNotIsFalse", "luaunit.assertNotIsFalse(value [, message])", "function", "Assert a non-false value."),
                    entry("luaunit.assertIsNil", "luaunit.assertIsNil(value [, message])", "function", "Assert nil.", nil, { "luaunit.assertNil" }),
                    entry("luaunit.assertNotIsNil", "luaunit.assertNotIsNil(value [, message])", "function", "Assert not nil.", nil, { "luaunit.assertNotNil" }),
                    entry("luaunit.assertIs", "luaunit.assertIs(actual, expected [, message])", "function", "Assert identity."),
                    entry("luaunit.assertNotIs", "luaunit.assertNotIs(actual, expected [, message])", "function", "Assert non-identity."),
                    entry("luaunit.assertIsNaN", "luaunit.assertIsNaN(value [, message])", "function", "Assert NaN."),
                    entry("luaunit.assertNotIsNaN", "luaunit.assertNotIsNaN(value [, message])", "function", "Assert not NaN."),
                    entry("luaunit.assertIsInf", "luaunit.assertIsInf(value [, message])", "function", "Assert infinity."),
                    entry("luaunit.assertIsPlusInf", "luaunit.assertIsPlusInf(value [, message])", "function", "Assert positive infinity."),
                    entry("luaunit.assertIsMinusInf", "luaunit.assertIsMinusInf(value [, message])", "function", "Assert negative infinity."),
                    entry("luaunit.assertNotIsInf", "luaunit.assertNotIsInf(value [, message])", "function", "Assert a finite number."),
                    entry("luaunit.assertIsPlusZero", "luaunit.assertIsPlusZero(value [, message])", "function", "Assert positive zero."),
                    entry("luaunit.assertIsMinusZero", "luaunit.assertIsMinusZero(value [, message])", "function", "Assert negative zero."),
                    entry("luaunit.assertTableContains", "luaunit.assertTableContains(table, expected [, message])", "function", "Assert that a table contains expected entries."),
                    entry("luaunit.assertNotTableContains", "luaunit.assertNotTableContains(table, expected [, message])", "function", "Assert that a table does not contain expected entries."),
                    entry("luaunit.fail", "luaunit.fail([message])", "function", "Fail the current test."),
                    entry("luaunit.failIf", "luaunit.failIf(condition [, message])", "function", "Fail when a condition is true."),
                    entry("luaunit.skip", "luaunit.skip([message])", "function", "Skip the current test."),
                    entry("luaunit.skipIf", "luaunit.skipIf(condition [, message])", "function", "Skip when a condition is true."),
                    entry("luaunit.success", "luaunit.success()", "function", "End the current test successfully."),
                    entry("luaunit.setVerbosity", "luaunit.setVerbosity(level)", "function", "Set the runner verbosity."),
                }, { upstream = "https://github.com/bluebird75/luaunit", license = "BSD" }),

                module("serpent", "serpent", "Lua serializer and pretty printer.", [==[
`serpent.serialize(value [, options])` returns a Lua expression that recreates
the value.  `serpent.line` and `serpent.block` are convenience formatters.
]==], {
                    entry("serpent.serialize", "serpent.serialize(value [, options])", "function", "Serialize a value to a Lua expression."),
                    entry("serpent.line", "serpent.line(value [, options])", "function", "Serialize a value on one line."),
                    entry("serpent.block", "serpent.block(value [, options])", "function", "Serialize a value in block form."),
                    entry("serpent.dump", "serpent.dump(value [, options])", "function", "Serialize and print a value."),
                    entry("serpent.load", "serpent.load(string)", "function", "Load a serialized value."),
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
