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

```lua
("hello"):starts_with("he") --> true
```

#### `string.ends_with(value, suffix)`

Return true when a string ends with `suffix`.

```lua
("hello"):ends_with("lo") --> true
```

#### `string.contains(value, needle)`

Return true when a string contains `needle`.

Uses a plain-text search, not a Lua pattern.

#### `string.is_empty(value)`

Return true for `nil` or the empty string.

Complements `string.is_not_empty`.

#### `string.is_not_empty(value)`

Return true for a non-nil, non-empty string.

Complements `string.is_empty`.

#### `string.split(value [, separator])`

Split a string into a table.

The default separator is a single space.

#### `string.to_table(value [, separator])`

Split a string into a table.

Alias-like helper for `string.split`.

#### `string.trim(value)`

Remove leading and trailing whitespace.

#### `string.ltrim(value)`

Remove leading whitespace.

#### `string.rtrim(value)`

Remove trailing whitespace.

#### `string.base64encode(value)`

Encode a string as standard Base64.

#### `string.base64decode(value)`

Decode a standard Base64 string.

#### `string.base64urlEncode(value)`

Encode a string as URL-safe Base64.

#### `string.base64urlDecode(value)`

Decode a URL-safe Base64 string.

#### `string.urlEncode(value)`

Percent-encode a string for use in a URL.

#### `string.utf8len(value)`

Return the number of UTF-8 characters in a string.

#### `table.copy(value [, copies])`

Deep-copy a table.

`copies` tracks already copied tables, which also makes the function safe for cyclic tables.

#### `table.tostring(value [, name])`

Pretty-print a table as a string.

Recursively formats tables.  `name` is used as the root label.

#### `table.print(value [, name])`

Pretty-print a table to standard output.

Equivalent to `print(table.tostring(value, name))`.

#### `table.remove_if(value, predicate)`

Remove elements for which `predicate` is true.

#### `table.filter(value, predicate)`

Return a new table with elements accepted by `predicate`.

#### `table.add_all(target, ...)`

Append all arguments to a table.

#### `table.insert_all(target, index, ...)`

Insert all arguments at a position.

#### `table.load(filename)`

Load a serialized table from a file.

Uses `serpent` to deserialize the file.

#### `table.save(filename, value)`

Serialize a table to a file.

Uses `serpent` to produce a readable Lua representation.

#### `table.default(value, defaults [, error])`

Fill missing keys from a defaults table.

Returns `value`, with each missing key copied from `defaults`.  When `error` is true, unexpected keys raise an error.

#### `table.insert_sorted(value, item [, comparator])`

Insert an item while keeping a sorted table ordered.

#### `table.next(value)`

Iterator helper used by `stream`.

Returns a stateless iterator over the array part of a table.

#### `io.read_lines(filename)`

Read all lines from a file into a table.

#### `io.write_lines(filename, lines [, eol])`

Write a table of lines to a file.

#### `io.read_file(filename)`

Read an entire file as a string.

#### `io.write_file(filename, data)`

Write a string to a file, replacing its contents.

#### `io.append_file(filename, data)`

Append a string to a file.

#### `os.name`

Operating system name.

One of `windows`, `linux`, `macos`, or the platform name reported by the interpreter.

#### `os.home`

The current user's home directory.

#### `os.is_windows`

True on Windows.

#### `os.is_linux`

True on Linux.

#### `os.is_mac`

True on macOS.

#### `os.separator`

The platform path separator (`\` or `/`).

#### `os.nanotime()`

Return a monotonic timestamp in nanoseconds.

Used by `timer` and `benchmark`.

#### `math.round(value)`

Round a number to the nearest integer.

#### `math.maxdouble`

The largest finite double.

#### `math.mindouble`

The smallest positive normalized double.

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
`stream`, `union`, `intersection`, `difference` and `to_array`.

#### `collection:size()`

Return the number of elements.

#### `collection:is_empty()`

Return true when the collection has no elements.

#### `collection:add_all(items)`

Add all items from another collection or table.

#### `collection:remove_all(items)`

Remove all items found in another collection or table.

#### `collection:contains_all(items)`

Return true when every item is present.

#### `collection:equals(other)`

Compare two collections for equal contents.

#### `collection:copy()`

Return a shallow copy.

#### `collection:stream()`

Return a `stream` over the collection.

#### `collection:union(...)`

Return the union with other collections.

#### `collection:intersection(...)`

Return the intersection with other collections.

#### `collection:difference(...)`

Return the difference with other collections.

#### `collection:to_array()`

Return the contents as an array.

### collection.list

Ordered list collection.

A list is an ordered sequence.  Methods that mutate a list return the list, so
calls can be chained.

#### `collection.list.new([initial])`

Create a new list.

`initial` may be an array or another collection.

#### `collection.list.new_sorted([initial [, comparator]])`

Create a list that keeps its elements sorted.

#### `list:add([index,] item, ...)`

Add one or more items, optionally at an index.

#### `list:add_all([index,] items)`

Add all items from a table or collection.

#### `list:clear([size])`

Remove all items.

The optional size is a capacity hint.

#### `list:contains(item)`

Return true when the item is present.

#### `list:get(index)`

Return the item at an index.

#### `list:set(index, item)`

Replace the item at an index.

#### `list:index_of(item)`

Return the first index of an item, or nil.

#### `list:last_index_of(item)`

Return the last index of an item, or nil.

#### `list:remove(item)`

Remove the first occurrence of an item.

#### `list:remove_index(index)`

Remove and return the item at an index.

#### `list:retain_all(items)`

Keep only items present in another collection.

#### `list:sublist(from, to)`

Return a new list containing the given range.

#### `list:for_each(func)`

Call `func` for every item.

#### `list:for_each_index(func)`

Call `func(index, item)` for every item.

#### `list:iterate()`

Return an iterator over items.

#### `list:iterate_indexed()`

Return an iterator over indexes and items.

#### `list:iterator(func)`

Create a stateless iterator from a function.

#### `list:iterator_indexed(func)`

Create an indexed stateless iterator.

### collection.map

Key-value map collection.

Maps preserve key/value associations and provide ordered variants through
`new_ordered`.

#### `collection.map.new([initial])`

Create a new map.

#### `collection.map.new_ordered([initial])`

Create a map that iterates in insertion order.

#### `map:put(key, value)`

Associate a key with a value.

#### `map:get(key)`

Return the value for a key, or nil.

#### `map:get_or_default(key, default)`

Return a value or a default.

#### `map:put_all(table)`

Copy all key/value pairs from a table or map.

#### `map:put_if_absent(key, value)`

Insert a key only when it is not present.

#### `map:remove(key [, value])`

Remove a key, optionally only when it has a given value.

#### `map:merge(key, value, func)`

Merge a value into an existing key using `func`.

#### `map:replace(key, old, new)`

Replace a value when it currently equals `old`.

#### `map:contains_key(key)`

Return true when a key exists.

#### `map:contains_value(value)`

Return true when a value exists.

#### `map:entry_set()`

Return the entries as a set.

#### `map:key_set()`

Return the keys as a set.

#### `map:values()`

Return the values as a collection.

#### `map:equals(other)`

Compare two maps for equal contents.

#### `map:compute(key, func)`

Compute a new value for a key.

#### `map:compute_if_absent(key, func)`

Compute a value only when the key is absent.

#### `map:compute_if_present(key, func)`

Compute a value only when the key is present.

#### `map:for_each(func)`

Call `func(key, value)` for every entry.

#### `map:iterate()`

Return an iterator over keys and values.

#### `map:iterator(func)`

Create a stateless iterator from a function.

#### `map:size()`

Return the number of entries.

#### `map:is_empty()`

Return true when the map has no entries.

### collection.set

Set collection with optional insertion order.

A set stores unique values.  `new_ordered` preserves insertion order during
iteration.

#### `collection.set.new([initial])`

Create a new set.

#### `collection.set.new_ordered([initial])`

Create an insertion-ordered set.

#### `set:add(item, ...)`

Add one or more unique values.

#### `set:remove(item)`

Remove a value.

#### `set:contains(item)`

Return true when a value is present.

#### `set:retain_all(items)`

Keep only values also present in another collection.

#### `set:for_each(func)`

Call `func(value)` for every value.

#### `set:iterate()`

Return an iterator over values.

#### `set:iterate_indexed()`

Return an iterator over indexes and values.

#### `set:iterator(func)`

Create a stateless iterator from a function.

#### `set:iterator_indexed(func)`

Create an indexed stateless iterator.

#### `set:size()`

Return the number of values.

#### `set:is_empty()`

Return true when the set is empty.

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

#### `fs.create_path(path, name)`

Create a path object from a directory and file name.

#### `fs.path(...)`

Normalize components into a path object.

Accepts strings, path objects and path component tables.  Relative paths stay relative; paths beginning with `.` or `..` are resolved against the current directory.

#### `fs.ensure_path(path)`

Return a path object, converting a string when needed.

#### `fs.get_path(path)`

Return the underlying path string of a path object.

#### `fs.absolute(path)`

Return the absolute path, or nil when it does not exist.

#### `fs.concat_path(path, file)`

Join a path with a file name.

#### `fs.split_path(path)`

Split a path into components.

#### `fs.create_tree(path)`

Create a directory and all missing parents.

#### `fs.delete_tree(path)`

Delete a directory tree recursively.

#### `path:list()`

Return the directory entries as an array of path objects.

#### `path:dir()`

Return the directory entries keyed by name.

#### `fs.iterate(path [, sorted])`

Iterate the entries of a directory.

#### `fs.walk(path, func [, dir_first])`

Walk a directory tree, calling `func(path)` for each entry.

#### `fs.tree(path [, dir_first])`

Return all paths in a directory tree.

#### `fs.tree_size(path)`

Return the total size of files in a tree.

#### `fs.tree_size_hr(path)`

Return a human-readable tree size.

#### `fs.stream(path)`

Create a stream over directory entries.

#### `fs.stream_tree(path [, dir_first])`

Create a stream over a directory tree.

#### `fs.read_all(path)`

Read an entire file as a string.

#### `fs.read_lines(path [, mode])`

Read a file into an array of lines.

#### `fs.lines(path [, mode])`

Iterate the lines of a file.

Yields `index, line`.  Use `for _, line in fs.lines(path) do`.

#### `fs.parent(path)`

Return the parent path.

#### `fs.child(path, name)`

Return a child path.

#### `fs.sibling(path, name)`

Return a sibling path.

#### `fs.to_relative(path, base [, include_top])`

Return a path relative to a base path.

#### `fs.is_empty(path)`

Return true when a directory has no entries.

#### `fs.chmod(path, mode)`

Change file permissions on Linux.

Returns true on success.  The mode is an octal string such as `"755"`.

#### `fs.chown(path, owner)`

Change file ownership on Linux.

#### `fs.size_to_hr(bytes)`

Format a byte count as a human-readable size.

#### `fs:config(options)`

Configure a loaded filesystem module.

Accepts `{ error_handling = "return" | "raise" }` and returns the same module table.

#### `path:exists()`

Return true when the path exists.

#### `path:is_file()`

Return true for a regular file.

#### `path:is_directory()`

Return true for a directory.

#### `path:size()`

Return the file size in bytes.

#### `path:size_hr()`

Return a human-readable size.

#### `path:stat()`

Return file metadata.

#### `path:access_time()`

Return the last access time.

#### `path:create_time()`

Return the creation time.

#### `path:modify_time()`

Return the last modification time.

#### `path:access_time_ms()`

Return access time in milliseconds.

#### `path:create_time_ms()`

Return creation time in milliseconds.

#### `path:modify_time_ms()`

Return modification time in milliseconds.

#### `path:access_time_stamp()`

Return a formatted access timestamp.

#### `path:create_time_stamp()`

Return a formatted creation timestamp.

#### `path:modify_time_stamp()`

Return a formatted modification timestamp.

#### `path:mode()`

Return the file mode.

#### `path:mode_flags()`

Return the file mode flags.

#### `path:open([mode])`

Open the file and return a file handle.

#### `path:rename(new_path) / path:mv(new_path)`

Rename or move the path.

#### `path:delete() / path:rm()`

Delete the file or empty directory.

#### `path:change_directory() / path:cd()`

Change the current directory to this path.

#### `path:create_directory() / path:mkdir()`

Create the directory.

#### `path:read_all()`

Read the file as a string.

#### `path:read_lines([mode])`

Read the file into an array of lines.

#### `path:lines([mode])`

Iterate the lines of the file.

#### `path:iterate([sorted])`

Iterate directory entries.

#### `path:delete_tree()`

Delete the directory tree.

#### `path:walk(func [, dir_first])`

Walk the directory tree.

#### `path:parent()`

Return the parent path.

#### `path:child(name)`

Return a child path.

#### `path:sibling(name)`

Return a sibling path.

#### `path:stream()`

Create a stream over directory entries.

#### `path:stream_tree([dir_first])`

Create a stream over the tree.

#### `path:tree([dir_first])`

Return the tree as an array of paths.

#### `path:to_relative(base [, include_top])`

Return a relative path.

#### `path:chmod(mode)`

Change permissions.

#### `path:chown(owner)`

Change ownership.

### grid

Line-drawing text grids (tables).

`grid.new(config [, rows])` creates a text table.  `config` is an array of column
definitions: `{ name, align, min_width, max_width, fixed_width }`.  The table
configuration may also set `show_header` and `padding`.

#### `grid.new(config [, rows])`

Create a grid.

Accepts either `grid.new(config)` or `grid:new(config)`.

#### `grid:add_row(...) / grid:add_row(table)`

Add a row of values.

#### `grid:add_rows(rows)`

Add multiple rows.

#### `grid:header_string()`

Return the header lines.

#### `grid:row_string(...)`

Return one rendered row.

#### `grid:last_string()`

Return the bottom border.

#### `grid:print_header()`

Print the header.

#### `grid:print_row(...)`

Print one row.

#### `grid:print_last()`

Print the bottom border.

#### `grid:tostring()`

Render the complete table as a string.

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

#### `luastrip.file(input, output)`

Strip a Lua source file into another file.

#### `luastrip:config(options)`

Configure a loaded luastrip module.

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

#### `stream.of(...)`

Create a stream from values.

#### `stream:map(func)`

Transform each value.

#### `stream:peek(func)`

Inspect each value without changing it.

#### `stream:filter(func)`

Keep values accepted by `func`.

#### `stream:skip(count)`

Skip the first `count` values.

#### `stream:limit(count)`

Limit the stream to `count` values.

#### `stream:reverse()`

Reverse the remaining values.

#### `stream:sort([comparator])`

Sort the remaining values.

#### `stream:maptonumber()`

Convert each value to a number.

#### `stream:distinct()`

Drop duplicate values.

#### `stream:split(func)`

Split into matching and non-matching streams.

#### `stream:join(...)`

Concatenate streams.

#### `stream:foreach(func)`

Consume the stream, calling `func` for each value.

#### `stream:toarray()`

Consume the stream into an array.

#### `stream:tosortedarray([comparator])`

Consume into a sorted array.

#### `stream:print()`

Print each value.

#### `stream:concat([separator])`

Join values into a string.

#### `stream:allmatch(func)`

Return true when every value matches.

#### `stream:firstmatch(func)`

Return the first matching value.

#### `stream:nonmatch(func)`

Return true when no value matches.

#### `stream:anymatch(func)`

Return true when any value matches.

#### `stream:first()`

Return the first value.

#### `stream:last()`

Return the last value.

#### `stream:count()`

Count the remaining values.

#### `stream:sum()`

Sum numeric values.

#### `stream:average()`

Average numeric values.

#### `stream:median()`

Median numeric value.

#### `stream:iterator()`

Return the underlying iterator.

#### `stream:collector(func)`

Apply a collector function.

#### `stream:reduce(state, func)`

Fold the stream into a value.

#### `stream:min([comparator])`

Return the minimum value.

#### `stream:max([comparator])`

Return the maximum value.

#### `stream:groupby(func)`

Group values by a key function.

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

#### `timer:start()`

Start or restart the timer.

#### `timer:lap()`

Record a lap and return the lap time.

#### `timer:stop()`

Stop the timer and return the elapsed time.

#### `timer:time()`

Return the last measured time.

#### `timer:elapsed()`

Return the time since the timer started.

#### `timer:lap_elapsed()`

Return the time since the last lap.

#### `timer:reset()`

Reset the timer and its laps.

### uuid

UUID generation.

The `uuid` module generates RFC 9562 UUIDs.  `uuid.v4()` generates a random
UUID and `uuid.v7()` a time-ordered UUID.

#### `uuid.v4()`

Generate a version 4 (random) UUID.

#### `uuid.v7()`

Generate a version 7 (time-ordered) UUID.

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

#### `workbook:closeSheet()`

Close the current worksheet.

#### `workbook:nextRow(...)`

Start a new row, optionally with cells.

#### `workbook:endRow()`

End the current row.

#### `workbook:addRow(values)`

Add a complete row from a table.

#### `workbook:cells(...)`

Append cells to the current row.

#### `workbook:addCells(values)`

Append cells from a table.

#### `workbook:cell(value)`

Append a single cell.

#### `workbook:close()`

Finish the workbook and close the file.

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

#### `csv.parseLine(line [, delimiter [, options]])`

Parse a single CSV line.

#### `csv.encode(table [, delimiter [, options]])`

Encode a table as CSV.

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

#### `sqlite3.open_memory()`

Open an in-memory database.

#### `sqlite3.open_ptr(pointer)`

Open a database from a raw pointer.

#### `sqlite3.version()`

Return the SQLite version.

#### `sqlite3.lversion()`

Return the LuaSQLite3 version.

#### `sqlite3.complete(sql)`

Return true when a SQL string is complete.

#### `sqlite3.temp_directory([path])`

Get or set the temporary directory.

#### `sqlite3.backup_init(destination, source [, name])`

Create an online backup object.

#### `db:exec(sql)`

Execute SQL statements.

#### `db:execute(sql)`

Execute SQL and return prepared statement results.

#### `db:prepare(sql)`

Prepare a SQL statement.

#### `db:rows(sql [, parameters])`

Iterate result rows as arrays.

#### `db:nrows(sql [, parameters])`

Iterate result rows as name/value tables.

#### `db:urows(sql [, parameters])`

Iterate a single-column result.

#### `db:close()`

Close the database.

#### `db:isopen()`

Return true when the database is open.

#### `db:changes()`

Return the number of changed rows.

#### `db:total_changes()`

Return total changed rows.

#### `db:last_insert_rowid()`

Return the last inserted row id.

#### `db:errcode()`

Return the last error code.

#### `db:errmsg()`

Return the last error message.

#### `db:busy_timeout(timeout)`

Set the busy timeout.

#### `db:interrupt()`

Interrupt the current operation.

#### `db:create_function(name, nargs, func)`

Register a scalar SQL function.

#### `db:create_aggregate(name, nargs, step, final)`

Register an aggregate SQL function.

#### `db:create_collation(name, func)`

Register a collation.

#### `db:trace(func)`

Install a trace callback.

#### `db:progress_handler(n, func)`

Install a progress handler.

#### `db:update_hook(func)`

Install an update hook.

#### `db:commit_hook(func)`

Install a commit hook.

#### `db:rollback_hook(func)`

Install a rollback hook.

#### `stmt:step()`

Advance a prepared statement.

#### `stmt:reset()`

Reset a prepared statement.

#### `stmt:finalize()`

Finalize a prepared statement.

#### `stmt:bind(index, value)`

Bind a value to a parameter.

#### `stmt:bind_values(...)`

Bind positional parameters.

#### `stmt:bind_names(table)`

Bind named parameters.

#### `stmt:columns()`

Return result column names.

#### `stmt:get_value(index)`

Return a result value.

#### `stmt:get_values()`

Return all result values.

#### `stmt:get_type(index)`

Return a result value type.

#### `stmt:get_types()`

Return all result value types.

#### `stmt:get_uvalue(index)`

Return an uncoerced result value.

#### `stmt:get_uvalues()`

Return all uncoerced result values.

#### `stmt:get_utype(index)`

Return an uncoerced result type.

#### `stmt:get_utypes()`

Return all uncoerced result types.

#### `stmt:get_name(index)`

Return a column name.

#### `stmt:get_names()`

Return all column names.

#### `stmt:get_named_values()`

Return results as a name/value table.

#### `stmt:get_named_types()`

Return result types as a name/value table.

#### `stmt:bind_parameter_count()`

Return the number of parameters.

#### `stmt:bind_parameter_name(index)`

Return a parameter name.

#### `stmt:bind_blob(index, data [, destructor])`

Bind a blob value.

### luaunit

Unit-testing framework for Lua.

Upstream: https://github.com/bluebird75/luaunit

License: BSD

LuaUnit discovers global tables whose names begin with `Test` and functions whose
names begin with `test`.  Assertions are exported as `assert*` functions.

`luaunit.run()` runs the registered tests and returns the number of failures.

#### `luaunit.run([...])`

Run the test suite.

#### `luaunit.assertEquals(actual, expected [, message])`

Assert equality.

#### `luaunit.assertNotEquals(actual, expected [, message])`

Assert inequality.

#### `luaunit.assertAlmostEquals(actual, expected, margin [, message])`

Assert approximate equality.

#### `luaunit.assertItemsEquals(actual, expected [, message])`

Assert that two tables contain the same items.

#### `luaunit.assertStrContains(value, substring [, isPattern [, message]])`

Assert that a string contains a substring.

#### `luaunit.assertStrIContains(value, substring [, message])`

Case-insensitive substring assertion.

#### `luaunit.assertNotStrContains(value, substring [, isPattern [, message]])`

Assert that a string does not contain a substring.

#### `luaunit.assertNotStrIContains(value, substring [, message])`

Case-insensitive negative substring assertion.

#### `luaunit.assertStrMatches(value, pattern [, start [, final [, message]]])`

Assert a string pattern match.

#### `luaunit.assertError(func, ...)`

Assert that a call raises an error.

#### `luaunit.assertErrorMsgEquals(message, func, ...)`

Assert an exact error message.

#### `luaunit.assertErrorMsgContentEquals(message, func, ...)`

Assert an error message ignoring file and line prefix.

#### `luaunit.assertErrorMsgContains(partial, func, ...)`

Assert an error message contains text.

#### `luaunit.assertErrorMsgMatches(pattern, func, ...)`

Assert an error message matches a pattern.

#### `luaunit.assertEvalToTrue(value [, message])`

Assert that a value evaluates to true.

#### `luaunit.assertEvalToFalse(value [, message])`

Assert that a value evaluates to false.

#### `luaunit.assertIsTrue(value [, message])`

Assert a true value.

#### `luaunit.assertNotIsTrue(value [, message])`

Assert a non-true value.

#### `luaunit.assertIsFalse(value [, message])`

Assert a false value.

#### `luaunit.assertNotIsFalse(value [, message])`

Assert a non-false value.

#### `luaunit.assertIsNil(value [, message])`

Assert nil.

#### `luaunit.assertNotIsNil(value [, message])`

Assert not nil.

#### `luaunit.assertIs(actual, expected [, message])`

Assert identity.

#### `luaunit.assertNotIs(actual, expected [, message])`

Assert non-identity.

#### `luaunit.assertIsNaN(value [, message])`

Assert NaN.

#### `luaunit.assertNotIsNaN(value [, message])`

Assert not NaN.

#### `luaunit.assertIsInf(value [, message])`

Assert infinity.

#### `luaunit.assertIsPlusInf(value [, message])`

Assert positive infinity.

#### `luaunit.assertIsMinusInf(value [, message])`

Assert negative infinity.

#### `luaunit.assertNotIsInf(value [, message])`

Assert a finite number.

#### `luaunit.assertIsPlusZero(value [, message])`

Assert positive zero.

#### `luaunit.assertIsMinusZero(value [, message])`

Assert negative zero.

#### `luaunit.assertTableContains(table, expected [, message])`

Assert that a table contains expected entries.

#### `luaunit.assertNotTableContains(table, expected [, message])`

Assert that a table does not contain expected entries.

#### `luaunit.fail([message])`

Fail the current test.

#### `luaunit.failIf(condition [, message])`

Fail when a condition is true.

#### `luaunit.skip([message])`

Skip the current test.

#### `luaunit.skipIf(condition [, message])`

Skip when a condition is true.

#### `luaunit.success()`

End the current test successfully.

#### `luaunit.setVerbosity(level)`

Set the runner verbosity.

### serpent

Lua serializer and pretty printer.

Upstream: https://github.com/pkulchenko/serpent

License: MIT

`serpent.serialize(value [, options])` returns a Lua expression that recreates
the value.  `serpent.line` and `serpent.block` are convenience formatters.

#### `serpent.serialize(value [, options])`

Serialize a value to a Lua expression.

#### `serpent.line(value [, options])`

Serialize a value on one line.

#### `serpent.block(value [, options])`

Serialize a value in block form.

#### `serpent.dump(value [, options])`

Serialize and print a value.

#### `serpent.load(string)`

Load a serialized value.

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
