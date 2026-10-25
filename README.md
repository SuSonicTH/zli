# ZLI - Zig Lua Interpreter

ZLI is a portable Lua interpreter with a large set of bundled libraries. Release builds are statically linked on non-Windows targets (musl), so a single binary can be copied from system to system without any installed libraries.

## Supported platforms

Tested by the release build:

| platform       | status |
| -------------- | ------ |
| Windows x86_64 | tested |
| Linux x86_64   | tested |
| Linux aarch64  | tested |

Other targets supported by Zig are expected to work but are not part of `zig build release` and have not been tested:

- Windows aarch64
- Linux x86, armv7a, riscv64, powerpc64le
- macOS x86_64, aarch64

## Batteries included

There are many libraries included in the ZLI binary: third-party Lua libraries, custom bindings, and libraries developed specifically for ZLI.

### Included Lua libraries

| library    | link                                        | licence | description                                                            |
| ---------- | ------------------------------------------- | ------- | ---------------------------------------------------------------------- |
| argparse   | https://github.com/mpeterv/argparse         | MIT     | Feature-rich command line parser for Lua inspired by Python's argparse |
| f-string   | https://github.com/dsidirop/f-strings       | MIT     | String interpolation for Lua, inspired by Python f-strings             |
| ftcsv      | https://github.com/FourierTransformer/ftcsv | MIT     | Fast CSV library written in pure Lua                                   |
| LPeg       | https://www.inf.puc-rio.br/~roberto/lpeg/   | MIT     | Pattern-matching library for Lua based on Parsing Expression Grammars  |
| lua-cjson  | https://github.com/openresty/lua-cjson      | MIT     | Fast JSON encoding/parsing                                             |
| LuaSQLite3 | http://lua.sqlite.org/                      | MIT     | Thin wrapper around the SQLite3 database engine                        |
| luaunit    | https://github.com/bluebird75/luaunit       | BSD     | Unit-testing framework for Lua                                         |
| Serpent    | https://github.com/pkulchenko/serpent       | MIT     | Lua serializer and pretty printer                                      |
| xml2lua    | https://github.com/manoelcampos/xml2lua     | MIT     | Pure-Lua XML parser and table-to-XML serializer                        |

### Custom bindings to third-party libraries

| library     | link                                  | licence | description                                           |
| ----------- | ------------------------------------- | ------- | ----------------------------------------------------- |
| Crossline   | https://github.com/jcwangxp/Crossline | MIT     | Small, self-contained readline/libedit replacement    |
| markdown    | https://github.com/mity/md4c          | MIT     | Markdown parser and HTML renderer based on md4c       |

### ZLI libraries

| library      | description                                                                                                 |
| ------------ | ----------------------------------------------------------------------------------------------------------- |
| auxiliary    | Extra string, table, file and OS helpers                                                                    |
| benchmark    | Small benchmark runner with nanosecond precision                                                            |
| collection   | Collection library similar to Java collections: (Hash)Set, (Hash)Map and (Array)List                        |
| filesystem   | Filesystem functions: listing/creating/changing directories, deleting/renaming/moving files and directories |
| grid         | Line-drawing text grids (tables) with per-column alignment, padding and min/max width                       |
| gzip         | Read and write gzip-compressed files                                                                       |
| httpclient   | Convenient HTTP client based on Zig's HTTP client (GET, HEAD, POST, PUT, PATCH, DELETE)                     |
| httpserver   | Convenient HTTP server based on Zig's HTTP server, with optional file caching and static file serving       |
| logger       | Very simple logging library                                                                                 |
| luastrip     | Lua source stripping/compacting library that removes comments and unnecessary whitespace                    |
| memoize      | Function result memoization/caching                                                                         |
| stream       | Stream library inspired by Java streams for functional-style Lua                                            |
| tar          | Read/write tar files (optional gzip compression) and read `.xz`/`.zstd` compressed tar files                |
| timer        | Nanosecond timer, also available as `os.nanotime`                                                           |
| unzip / zip  | Create, read, extract and append zip archives                                                              |
| uuid         | V4 and V7 UUID generation                                                                                   |
| webserver    | Concurrent HTTP/1.1 server with keep-alive, assets, server sent events and user routes                      |
| webui        | Server side component model that serves pages and calls Lua callbacks on browser events                     |
| xlsxmlwriter | Simple Excel XML writer                                                                                     |

See [doc/README.md](doc/README.md) for the command line tools and configuration and [doc/libraries.md](doc/libraries.md) for the library API reference.  The latter is generated from [doc/libraries.lua](doc/libraries.lua); do not edit it by hand.

## Documentation

The ZLI binary carries a complete reference manual in its payload.  It combines
the Lua 5.5 language and standard-library manual with documentation for every
bundled library, the command line tools and ZLI itself.  The Lua manual part is
extracted from the `lua55` build dependency; the rest is authored in
`doc/libraries.lua`.

```bash
zli @manual                 # browse the manual at http://127.0.0.1:8080/
zli @help string.byte       # command line lookup
zli @help --search trim     # full-text search
```

The served manual and `zli @manual --output manual.html` use the same embedded
client-side search; the exported file works from `file://` without a server.

Inside the REPL use `:help`, `:help <name>` or `:help --search <term>`.  Scripts
can `require "docs"` to use the same structured documentation (`find`, `search`
and render helpers).

## Command line

```
Usage: zli [-h|--help] [-v|--version] [@tool [arguments...]]
       zli [<script> [arguments...]]
```

| invocation             | description                                    |
| ---------------------- | ---------------------------------------------- |
| `-h`, `--help`         | Show usage                                     |
| `-v`, `--version`      | Print the version and exit                     |
| `@repl`                | Start the interactive REPL                     |
| `@sqlite`              | Start the SQLite CLI                           |
| `@compile <config>`    | Package Lua files into a standalone executable |
| `@test <file>`         | Run a LuaUnit test file                        |
| `@help [query]`        | Look up the bundled documentation              |
| `@manual`              | Serve the bundled reference manual over HTTP   |
| `@serve [directory]`   | Serve a directory over HTTP (defaults to `./`) |
| `<script>`             | Run a Lua script; use `-` to read from stdin   |

Scripts are selected in this order:

1. `zli @name [args]` runs `name` or `name.lua` from the attached payload; `@dir/name` is supported.
2. `zli - [args]` reads the program from stdin.
3. `zli script.lua [args]` runs an existing file from the filesystem.
4. `zli [args]` runs `<executable-name>.lua`, then `main.lua`, then `init.lua` from the payload.

The executable basename comes from `argv[0]` (with `.exe` stripped on Windows), so one payload can provide several tools through differently named symlinks. The bundled `main.lua` starts the REPL, which is why the standard binary starts the REPL when given no arguments. `arg[0]` remains the executable name used to invoke ZLI; the selected payload script is not substituted into the argument table.

The ZLI binary itself carries a payload containing `main.lua` and the command line tools. Compiled executables replace that payload with their own files.

Two configuration files are read automatically when they exist:

- `~/.config/zli/init.lua` — executed before every script and REPL session
- `~/.config/zli/repl_init.lua` — executed only when the REPL starts

## Error handling

ZLI libraries that can fail at runtime can either return an error or raise one. Returning errors is the default:

```lua
local filesystem = require "filesystem"
local text, err = filesystem.read_all("missing.txt")
if not text then
    print("error:", err)
end
```

For simple scripts that should fail early, set the global before requiring the library:

```lua
ZLI.error_handling = "raise"
local filesystem = require "filesystem"
local text = filesystem.read_all("missing.txt") -- raises on failure
```

Notes:

- The setting is read when a library module is required. Set it before `require`.
- A loaded library can be reconfigured in place: `filesystem:config { error_handling = "raise" }`. This returns the same table.
- Argument errors (wrong types, missing required arguments) always raise, as they indicate a bug in the calling script.

## Build

The build is tested under Linux and Windows for x86_64 and on Linux aarch64. It needs `zig` 0.17.0 on the `PATH`; the first build downloads the dependencies.

```bash
git clone https://github.com/SuSonicTH/zli.git
cd zli
zig build
```

This creates a debug build in `zig-out/bin`. Run the included test suite with:

```bash
zig build test
```

For an optimized build for your native architecture:

```bash
zig build native
```

For optimized builds of all release targets (UPX-compressed, statically linked on Linux):

```bash
zig build release
```

Release binaries are written to `zig-out/bin` with a platform and version suffix (for example `zli-x86_64-linux-0.2.0`).

> A plain `zig build` and `zig build native` use the host ABI and may link against the host's shared libc (glibc on Linux). Use `zig build release` or pass an explicit target, such as `zig build -Dtarget=x86_64-linux`, for a static musl binary. Note that `zig build native` always uses the host target and ignores `-Dtarget`.
>
> `zig build native` and `zig build release` UPX-compress their output. Tools such as `file` and `ldd` may report a compressed native binary as statically linked because UPX removes section headers; unpack it with `upx -d` to inspect its original linking.
