# ZLI library reference

All modules are loaded with `require`.

```lua
local filesystem = require "filesystem"
local stream     = require "stream"
local collection = require "collection"
```

Libraries that support error handling return `nil, message` on failure by
default. Set `ZLI.error_handling = "raise"` before `require` to raise instead.
A loaded library can also be reconfigured in place:

```lua
local filesystem = require "filesystem"
filesystem:config { error_handling = "raise" } -- returns the same table
```

Argument/type errors always raise. `zip`/`unzip` use their own error returns
and do not honor `ZLI.error_handling`.

---

## filesystem

```lua
local fs = require "filesystem"
```

### Paths

A _path object_ is a table with `path`, `name`, `full_path` and path methods.
Path objects are accepted everywhere a path string is accepted.

```lua
local p = fs.path("src/version")
p.full_path        --> "src/version"
p:exists()
p:size()
p:is_file()
p:is_directory()
```

Path normalization keeps relative paths relative and absolute paths absolute:

| expression        | result              |
| ----------------- | ------------------- |
| `fs.path("a/b")`  | `a/b`               |
| `fs.path("./a")`  | `<cwd>/a`           |
| `fs.path("../a")` | `<parent-of-cwd>/a` |
| `fs.path("/a/b")` | `/a/b`              |

### Path methods

`dir`, `list`, `stat`, `is_file`, `is_directory`, `size`, `size_hr`,
`access_time`, `create_time`, `modify_time`, `access_time_ms`,
`create_time_ms`, `modify_time_ms`, `access_time_stamp`,
`create_time_stamp`, `modify_time_stamp`, `mode`, `mode_flags`, `open`,
`exists`, `rename`/`mv`, `delete`/`rm`, `change_directory`/`cd`,
`create_directory`/`mkdir`, `read_all`, `read_lines`, `lines`, `iterate`,
`delete_tree`, `walk`, `parent`, `child`, `sibling`, `stream`, `stream_tree`,
`tree`, `to_relative`, `chmod`, `chown`.

`lines(path)` yields `index, line` (use `for _, line in fs.lines(path) do`).
`list(path)` returns an array of path objects; `dir(path)` returns a map keyed
by name.

### Module functions

| function                                  | description                                              |
| ----------------------------------------- | -------------------------------------------------------- |
| `cwd()` / `current_directory()`           | Current working directory as a string                    |
| `create_path(path, name)`                 | Build a path object                                      |
| `create_tree(path)`                       | Create a directory and all missing parents               |
| `absolute(path)`                          | Absolute path string, or `nil` if it does not exist      |
| `size_to_hr(bytes)`                       | Human-readable size                                      |
| `path(...)`                               | Normalize/build a path object                            |
| `ensure_path(path)`                       | Accept a string or path object and return a path object  |
| `concat_path(path, file)`                 | Join a path (string or component table) with a file name |
| `get_path(path)`                          | Extract the path string from a string/path object        |
| `split_path(path)`                        | Split a path into components                             |
| `is_empty(path)`                          | True if a directory has no entries                       |
| `tree_size(path)`, `tree_size_hr(path)`   | Recursive size                                           |
| `chmod(path, mode)`, `chown(path, owner)` | POSIX helpers (Linux only)                               |
| `open(path, mode)`                        | `io.open` with path-object support                       |

`access_time_ms`, `create_time_ms` and `modify_time_ms` return milliseconds.
On Linux `create_time` is the inode change time (`ctime`), not the file birth
time.

---

## collection

```lua
local collection = require "collection"
local set  = collection.set
local map  = collection.map
local list = collection.list
```

```lua
local s = set:new { 1, 2, 3 }
s:add(4):remove(2)
s:contains(3)          --> true
s:to_array()

local m = map:new { a = 1 }
m:put("b", 2)
m:get("a")             --> 1
m:compute_if_absent("c", function() return 3 end)

local l = list:new { "a", "b" }
l:add("c"); l:insert(1, "first"); l:remove("b")
```

Ordered variants: `set:new_ordered()` and `map:new_ordered()` preserve
insertion order for `iterate`, `to_array`, `values`, `key_set` and
`entry_set`.

Common methods: `size`, `is_empty`, `add`/`put`, `add_all`/`put_all`,
`remove`, `remove_all`, `contains`, `contains_all`, `copy`, `union`,
`intersection`, `difference`, `equals`, `iterate`, `iterate_indexed`,
`iterator`, `for_each`, `to_array`, `stream`.

Map-only: `get`, `get_or_default`, `put_if_absent`, `remove(key, value)`,
`merge`, `replace`, `contains_key`, `contains_value`, `entry_set`, `key_set`,
`values`, `compute`, `compute_if_absent`, `compute_if_present`.

List-only: `add(index, item)`, `add_all(index, items)`, `new_sorted`,
`remove_index`, `get`, `set`, `index_of`, `last_index_of`, `retain_all`,
`sublist`, `for_each_index`.

Set-only: `retain_all`.

`nil` cannot be stored in a set; `nil` values remove map entries.

---

## stream

```lua
local stream = require "stream"

stream({ 1, 2, 3, 4 })
    :filter(function(v) return v % 2 == 0 end)
    :map(function(v) return v * 10 end)
    :toarray()  --> { 20, 40 }
```

Intermediate operations: `map`, `peek`, `filter`, `skip`, `limit`, `reverse`,
`sort`, `maptonumber`, `distinct`, `split`, `join`.

Terminal operations: `foreach`, `toarray`, `tosortedarray`, `print`, `concat`,
`allmatch`, `firstmatch`, `nonmatch`, `anymatch`, `first`, `last`, `count`,
`sum`, `average`, `median`, `iterator`, `collector`, `reduce`, `min`, `max`,
`groupby`.

`false` is a valid stream value and does not terminate the stream; only `nil`
does.

Strings passed where a function is expected are treated as lambdas
(`":upper"`, `"-> v + 1"`, `"(a,b) -> a+b"`); `L` / `lambda` / `string:L` are
also available.

---

## grid

```lua
local grid = require "grid"

local g = grid.new {
    { name = "name",  align = "left",  max_width = 20 },
    { name = "value", align = "right", fixed_width = 10 },
}
g:add_row("foo", 42)
print(g:tostring())
```

Both `grid.new(config, rows)` and `grid:new(config, rows)` are accepted.
Columns support `name`, `align` (`left`/`right`), `min_width`, `max_width`,
`fixed_width`. The table supports `show_header` and `padding`.

Methods: `add_row`, `add_rows`, `row`, `row_string`, `header_string`,
`print_row`, `print_header`, `print_last`, `last_string`, `tostring`.
`tostring(grid)` and empty grids are supported.

---

## tar

```lua
local tar = require "tar"

tar.create("archive.tar.gz")
    :add_dir("src")
    :add_file("README.md", "README.md")
    :add_file_bytes("generated.txt", "hello")
    :close()

for file in tar.open("archive.tar.gz") do
    print(file.name, file.size, file.type)
    if file.is_file then
        local bytes = file:bytes()
        file:extract("output/path")
    end
end

tar.extract("archive.tar", "output/")
```

`create` understands `.gz`/`.tgz` compression; `open` supports `.gz`,
`.tgz`, `.xz`, `.txz`, `.zst`, `.tzst` and `.zstd`.

Writer methods: `setRoot`, `add_dir`, `add_file`, `add_file_bytes`,
`add_link`, `close`, and `archive_path` (add a directory tree).
Reader entries expose `name`, `type`, `size`, `size_hr`, `link_name`, `mode`,
`mode_flags`, `is_directory`, `is_file`, `is_link`, `extract`, `bytes`.

---

## zip / unzip

```lua
local zip = require "zip"
local unzip = require "unzip"

local z = zip.create("archive.zip")
z:add_file("README.md", "README.md")
z:create_directory("docs/")
z:open("docs/out.txt")       -- start a new entry
z:write("hello")             -- write to the current entry
z:close()                    -- finish current entry
z:close_zip("comment")       -- finish archive

for _, entry in ipairs(unzip.open("archive.zip"):list()) do
    print(entry.full_path, entry.uncompressed_size)
    entry:extract("output/" .. entry.name)
end

-- or extract everything
unzip.extract("archive.zip", "output/")
```

Zip handles: `add_file`, `create_directory`/`mkdir`, `open`, `write`,
`close`, `close_zip`, `add_directory` (from `zip.lua`).
Zip compression levels: `zip.level.store`, `fastest`, `fast`, `normal`,
`default`, `high`, `max`.

Unzip handles: `list`, `dir`, `info`, `extract(entry, destination)`,
`read_all(entry)`, `lines(entry)`, `close`.
Entries additionally provide `read_all`, `open`, `lines`, `extract`.

`zip`/`unzip` currently always return `nil, message` on failure; they do not
honor `ZLI.error_handling`.

---

## httpclient

```lua
local http = require "httpclient"

local response, body = http.get("https://example.com/api", {
    query = { page = 1, q = "hello world" },
    header = { ["X-Token"] = "secret" },
    parseJson = true,
})

if response.success then
    print(body)
end
```

Functions: `get`, `head`, `post`, `put`, `patch`, `delete`, `call`.

Options:

| option               | description                                       |
| -------------------- | ------------------------------------------------- |
| `query`              | Table of query parameters (URL-encoded)           |
| `header`             | Request headers                                   |
| `privileged_headers` | Headers preserved across redirects                |
| `basicAuth`          | `{ user = "...", pass = "..." }`                  |
| `parseJson`          | Decode a successful JSON response                 |
| `save`               | Save a GET response to a file (name or directory) |
| `raiseError`         | Raise instead of returning `nil, message`         |

The response table contains `version`, `status`, `status_name`, `reason`,
`success`, `location`, `content_type`, `content_disposition`,
`content_length`.

---

## httpserver

```lua
local server = require "httpserver"

server.serve {
    address = "127.0.0.1",
    port = 8080,
    web_root = "./public",
    cache_web_root = 300,       -- seconds, optional
    ["*"] = {
        ["/api/hello"] = function(options, request)
            return { body = "hello", header = { content_type = "text/plain" } }
        end,
        ["/api/user/(%d+)"] = function(options, request)
            return { name = "user" }  -- tables without body are JSON-encoded
        end,
    },
}
```

Routes can be keyed by method (`GET`, `POST`, ...) or `"*"`. `web_root` serves
files for GET requests. The request table contains `method`, `target`,
`version`, `expect`, `content_type`, `content_length`, `transfer_encoding`,
`transfer_compression`, `keep_alive`, `body`, and all request headers.

Responses can be:

- a string (sent as the body)
- a table with `body` and optional `status`/`header`
- a response object with `status`/`header` but no body
- any other table (JSON-encoded as the body)

Other functions: `status` (HTTP status name table), `serve_file`,
`resolve_web_path`, `content_type(path)`, `cache`, `cache_free_cycle`,
`free_cache`, `clear_cache`.
`..` and percent-encoded traversal outside `web_root` is blocked, including
symlinks that resolve outside the root.

---

## logger

```lua
local log = require "log"

log:info("hello")
log:setLevel(log.level.DEBUG)
log:addAppender(log.appender.file("/tmp/app.log"))

local child = log["worker"]
child:warn("from a named logger")
```

Levels: `OFF`, `FATAL`, `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`.
Appenders: `stdout`, `file`, `none`, or any object with
`append(logger, level, message)`.

---

## luastrip

```lua
local luastrip = require "luastrip"

local compact = luastrip.string(source)
luastrip.file("input.lua", "output.lua")
```

Removes comments and unnecessary whitespace. Malformed/unterminated input is
handled without aborting the interpreter.

---

## memoize

```lua
local memoize = require "memoize"
local slow = memoize(function(a, b) return a + b end)
slow(1, 2)  -- computed once
```

---

## auxiliary

The `auxiliary` module is loaded automatically. Extensions include:

- `string.split`, `string.to_table`, `string.trim/ltrim/rtrim`,
  `string.starts_with/ends_with/contains`, `string.is_empty/is_not_empty`,
  `string.base64encode/decode`, `string.base64urlEncode/Decode`,
  `string.urlEncode`, `string.utf8len`, `string.L`
- `table.copy`, `table.tostring`, `table.print`, `table.filter`,
  `table.remove_if`, `table.add_all`, `table.insert_all`, `table.load/save`,
  `table.default`, `table.insert_sorted`, `table.next`
- `io.read_file/write_file/append_file/read_lines/write_lines`
- `os.name`, `os.home`, `os.is_windows`, `os.is_linux`, `os.is_mac`,
  `os.separator`, `os.nanotime`
- global helpers `lambda`/`L`, `sorted_pairs`, `arg_check`,
  `arg_check_type`, `arg_error`
- `math.round`, `math.maxdouble`, `math.mindouble`

---

## Other modules

- `uuid` — `uuid.v4()`, `uuid.v7()`
- `timer` — `timer.new(start)`, `:start`, `:lap`, `:stop`, `:time`,
  `:elapsed`, `:lap_elapsed`, `:reset`
- `xlsxmlwriter` — `require("xlsxmlwriter")("file.xml")` returns a workbook
  object with `newSheet`, `closeSheet`, `nextRow`, `addRow`, `cells`,
  `addCells`, `cell`, `close`
- `crossline` — readline, screen, cursor, history, paging and color helpers
  (`screen.dimensions()`)
- `benchmark` — `require("benchmark").run(bench_table, iterations)`
