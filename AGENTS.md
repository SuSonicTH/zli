# ZLI — project guide for Claude

ZLI (Zig Lua Interpreter) is a portable Lua 5.5 interpreter with bundled
libraries, built as a single executable. The Zig host embeds Lua and appends a
zip "payload" containing the REPL, command-line tools, and reference
documentation.

Use this file as the map. User-facing documentation lives in:

- `README.md` — features, platforms, build, command line overview.
- `doc/README.md` — detailed CLI/tool usage, init files, payload notes.
- `doc/libraries.md` — complete library API reference (generated; do not edit).
- `src/tools/README.md` — short table of payload tools.
- `LICENSE.txt` — MIT.

## At a glance

| Item                 | Value                                                      |
| -------------------- | ---------------------------------------------------------- |
| Host language        | Zig 0.17.0, using the modern `std.Io` APIs                 |
| Lua                  | Lua 5.5.1, via the `zlua` (ziglua) dependency              |
| Package name/version | `zli`, version in `build.zig.zon` and `src/version`        |
| Native deps          | lsqlite3 + SQLite amalgamation, LPeg, lua-cjson, Crossline |
| Lua deps             | argparse, f-strings, ftcsv, luaunit, Serpent               |
| Output               | one executable with an appended zip payload                |
| Release platforms    | x86_64 Linux, aarch64 Linux, x86_64 Windows                |
| Release output       | UPX-compressed, stripped, static musl on Linux             |
| License              | MIT                                                        |

## Commands

Run from the repository root:

| Command                                            | What it does                                                                                                             |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `zig build`                                        | Debug build in `zig-out/bin/zli` (with payload).                                                                         |
| `zig build run -- <args>`                          | Build and run `zli` with arguments.                                                                                      |
| `zig build test`                                   | Build the debug binary, run `test/test.lua` through it, then run Zig unit tests in `src/strip.zig` and `src/docgen.zig`. |
| `zig build docs`                                   | Regenerate `doc/libraries.md` from `doc/libraries.lua`. Commit the result.                                               |
| `zig build native`                                 | Optimized host build, UPX-compressed.                                                                                    |
| `zig build release`                                | All three release targets, UPX-compressed, with version suffix.                                                          |
| `./clean.sh`                                       | Remove `zig-out`, `.zig-cache`, and `zig-pkg`.                                                                           |
| `zig build -Dtarget=x86_64-linux`                  | Explicit cross-target build; static musl for Linux.                                                                      |
| `./zig-out/bin/zli @test test/test_filesystem.lua` | Run one LuaUnit test file against the built payload.                                                                     |
| `./zig-out/bin/zli @help string.byte`              | Query the bundled manual.                                                                                                |
| `./zig-out/bin/zli @manual`                        | Serve the full reference manual at `http://127.0.0.1:8080/`.                                                             |
| `zig build --watch`                                | Continuous rebuild (see `watch.sh`).                                                                                     |

Notes:

- Zig must be 0.17.0 (`.zigversion`); dependencies are pinned in
  `build.zig.zon` and downloaded on the first build.
- `zig build test` is the authoritative check. It rebuilds the payload first, so
  edits to embedded Lua files are picked up.
- Plain `zig build`/`zig build native` use the host ABI and can link glibc.
  Release builds are the static, portable artifacts.
- `zig build native` and `zig build release` compress the executable with UPX.
  `file`/`ldd` may report compressed binaries incorrectly; use `upx -d` to
  inspect.

## Architecture

### Startup (`src/main.zig`)

1. Initialize `Utf8Output` (Windows console UTF-8), the Lua state
   (`std.heap.c_allocator`), and the argument list.
2. Resolve the real executable path (`executablePathAlloc`) instead of trusting
   `argv[0]`, so payload lookup works through `PATH`.
3. `libraries.openlibs` calls `lua.openLibs()`, fills `package.preload` with
   native and embedded Lua modules, and loads `auxiliary` (which extends
   `string`, `table`, `io`, `os`, and adds global helpers).
4. Open the zip payload appended to the executable and append a payload
   searcher to `package.searchers`.
5. Create the global `ZLI` table: `version`, `error_handling`, `exe_path`,
   `dofile`.
6. Select the program in this order:
   `@name` payload entry (`name` or `name.lua`), `-` stdin, existing file,
   `<executable-basename>.lua` in payload, `main.lua`, `init.lua`.
7. Build `arg` (`arg[0]` is the executable name), install a traceback message
   handler, run the embedded `src/init.lua` bootstrap, then run the selected
   chunk. Lua failures print a traceback and exit 1.

### Payload and module resolution

- `src/attach_payload.zig` (a host-side build tool) copies the compiled
  executable and appends a zip. Entry names are explicit; timestamps are fixed
  for reproducible builds.
- `src/zip_reader.zig`/`src/zip_writer.zig` implement zip reading/writing on
  `std.zip` and `std.compress.flate`, with no Lua dependency so the runtime and
  `unzip` can share them.
- The standard payload contains `main.lua`, `repl.lua`, the other tools,
  `docs_manual.lua`, and `docs_libraries.lua`. See `payload_entries` in
  `build.zig`.
- `zli @tool` selects a payload script directly. `zli @scriptname` also
  supports `@dir/scriptname`; `ZLI.dofile(name)` runs a payload script from Lua.
- `require "x"` checks payload entries `x.lua` and `x/init.lua`. The payload
  searcher is appended last, so local files and normal Lua paths always win.
- `io.open`, `io.lines`, and `io.read_lines` fall back to payload files for
  read-only access when no local file exists (`src/auxiliary.lua`).
- `@compile` (`src/tools/compile.lua`) copies the running executable, removes
  an existing payload, and appends a new payload built from a Lua config table.

### Library registration

Libraries come in three flavors:

1. **Native Zig modules** (`src/filesystem.zig`, `src/zip.zig`,
   `src/httpserver.zig`, ...). `src/libraries.zig` imports each module and adds
   `luaopen_*`-style functions to `package.preload`. Modules that perform I/O
   expose `setIo(io)` and are wired in `openlibs`.
2. **C libraries** (`lsqlite3`, `lpeg`, `lua-cjson`, `crossline`). They are
   linked statically by functions in `build.zig` and registered in
   `src/libraries.zig` via `extern luaopen_*` declarations.
3. **Embedded Lua modules**. Pure-Lua library modules are listed in
   `luascripts` in `src/libraries.zig` and served by `luaopen_luascript`. All
   library Lua files (including wrappers embedded by Zig modules) are also
   listed in `lualib_list` in `build.zig` so they can be embedded and optionally
   stripped for release builds.

Naming is not always the filename: `logger.lua` is `log`, `ftcsv.lua` is `csv`,
and `collection/init.lua` is `collection` (`collection.list`, `.map`, `.set` are
submodules).

### Zig binding anatomy

Most native modules follow this pattern (see `src/filesystem.zig`,
`src/httpserver.zig`, `src/gzip.zig`):

```zig
const exported = [_]zlua.FnReg{
    .{ .name = "do_thing", .func = luaerror.wrap(do_thing) },
    .{ .name = "config", .func = luaerror.wrap(setConfig) },
};

pub fn register(lua: *Lua) !i32 {
    const config = luax.setupLibrary(lua, &exported, Config, "mymodule");
    config.errorHandling = luaerror.getGlobalHandling(lua);
    return 1;
}
```

- `luax.setupLibrary` creates the module table, stores a `Config` userdata at
  upvalue 1, installs the functions, and runs the embedded `<name>.lua` module.
  That Lua module must return `function(native_table) ... return extras end`.
- `luax.registerExtended` registers the augmented module in the Lua registry as
  `zli_<name>` (used to expose Lua helpers to Zig code).
- Modules with I/O do `var io: std.Io = undefined; pub fn setIo(_io: std.Io) void { io = _io; }`.
- Export handlers as `fn name(lua: *Lua) !i32` and wrap with `luaerror.wrap`.
  For expected failures, use `luaerror.ret` (returns `nil, message`) or
  `luaerror.raiseOrReturn(...)`; argument errors always raise.
- Use `luax` helpers (`getArgStringOrError`, `getOptionInteger`,
  `createUserDataTableSetFunctions`, `setTableString`, ...) instead of manual
  stack manipulation.
- Userdata needs a metatable registered once and a `__gc` handler that frees
  owned memory (`luax.registerUserData`, `luax.createUserDataTable`).

### Error handling

- Default is return-style: library functions return `nil, message`.
- Setting `ZLI.error_handling = "raise"` **before** `require` makes a library
  raise instead. Each library reads the global at require time and exposes
  `lib:config { error_handling = "raise" }` to change it in place.
- Wrong argument types/counts always raise; they indicate a caller bug.
- `src/luaerror.zig` centralizes formatting, the raise/return switch, and the
  wrapper used by nearly all C functions.

### Build-time pipeline

- `createDocsPayload` runs the host-side `docgen.zig` on the `lua55`
  dependency's `doc/manual.html` + `src/lua.h` and emits `docs_manual.lua`.
- `compileStep` compiles `src/main.zig` with `zlua`, Lua headers from `lua55`,
  and the static C libraries. Crossline headers are translated with
  `@cImport`-style `addTranslateC`.
- `luaLibs` embeds Lua files as anonymous imports. In non-debug modes library
  Lua and payload scripts pass through `src/strip.zig` (comments and
  unnecessary whitespace are removed); only entries whose name ends in `.lua`
  are stripped, so JavaScript and CSS assets ship byte-identical. The
  generated/authored documentation entries are attached as-is.
- `attachPayload` appends the zip. Release builds UPX-pack the executable
  **before** attaching the payload and name it
  `zli-<target>-<src/version>`.

## Repository map

| Path                                                                                 | Purpose                                                                                                                                                |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `build.zig`                                                                          | Build graph, payload manifest (`payload_entries`), embedded Lua manifest (`lualib_list`), C/Zig library compilation, release targets, docs generation. |
| `build.zig.zon`                                                                      | Dependencies and package version.                                                                                                                      |
| `src/main.zig`                                                                       | Entrypoint: startup, program selection, payload loader, module searcher, `ZLI` table, `arg`.                                                           |
| `src/libraries.zig`                                                                  | `package.preload` registration for native modules and embedded Lua modules; `setIo` wiring.                                                            |
| `src/file_reader.zig`                                                                | Shared local-filesystem-first/payload-fallback whole-file reader.                                                                                      |
| `src/markdown.zig`                                                                   | `markdown` module: md4c event parser and md4c-html renderer.                                                                                           |
| `src/luax.zig`                                                                       | Lua stack/table/userdata/config helpers used by bindings.                                                                                              |
| `src/luaerror.zig`                                                                   | Raise-vs-return error handling and `luaerror.wrap`.                                                                                                    |
| `src/init.lua`                                                                       | Embedded bootstrap: creates `~/.config/zli`, runs user init, reloads `filesystem`.                                                                     |
| `src/main.lua`                                                                       | Payload fallback for `-h`/`--help` and `-v`/`--version`; starts the REPL when there are no arguments, otherwise prints usage.                          |
| `src/tools/*.lua`                                                                    | Payload tools: `repl`, `sqlite`, `compile`, `test`, `manual`, `serve`, `help`; `serve_lib.lua` is internal.                                            |
| `src/auxiliary.{zig,lua}`                                                            | Always-loaded helpers: string/table/io/os extensions, lambdas, payload-aware `io` functions.                                                           |
| `src/filesystem.{zig,lua}`                                                           | `filesystem` module and the path-object abstraction.                                                                                                   |
| `src/docs.lua`                                                                       | Structured documentation index, search, text/HTML/Markdown rendering, manual assembly.                                                                 |
| `src/docs_markdown.lua`                                                              | Markdown helpers shared by all doc output; md4c renders HTML/text blocks, small inline helpers handle titles.                                          |
| `src/docgen.zig`                                                                     | Build-time extraction of the Lua manual into `docs_manual.lua`; excludes the C API and grammar-only chapter.                                           |
| `src/strip.zig`                                                                      | Lua source stripper used for release payloads; also has Zig unit tests.                                                                                |
| `src/attach_payload.zig`                                                             | Host tool that appends the zip payload to an executable.                                                                                               |
| `src/zip_reader.zig`, `src/zip_writer.zig`                                           | Lua-free zip primitives used by the runtime, `zip`, `unzip`, and `@compile`.                                                                           |
| `src/zip.{zig,lua}`, `src/unzip.{zig,lua}`                                           | Lua-facing zip modules and high-level helpers.                                                                                                         |
| `src/gzip.zig`, `src/tar.zig`, `src/tar.lua`                                         | Compression and tar support.                                                                                                                           |
| `src/httpclient.{zig,lua}`, `src/httpserver.{zig,lua}`                               | HTTP client/server bindings.                                                                                                                           |
| `src/uuid.zig`, `src/luastrip.zig`, `src/crossline.zig`, `src/xlsxmlwriter.lua`, ... | Individual libraries; see `doc/libraries.md`.                                                                                                          |
| `src/collection/*.lua`                                                               | Pure-Lua collection submodules.                                                                                                                        |
| `doc/libraries.lua`                                                                  | Authored structured documentation, source of truth for all bundled-library docs.                                                                       |
| `doc/libraries.md`                                                                   | Generated Markdown mirror; never edit by hand.                                                                                                         |
| `doc/README.md`                                                                      | CLI, tools, init files, payload behavior.                                                                                                              |
| `test/`                                                                              | LuaUnit suites, auto-discovered; `support.lua` has shared helpers.                                                                                     |
| `test/temp/`                                                                         | Scratch directory cleaned before/after the suite (`.gitignore` tracked).                                                                               |
| `benchmark/`                                                                         | Standalone benchmark scripts run by `require "benchmark"`.                                                                                             |
| `zig-pkg/`, `.zig-cache/`, `zig-out/`                                                | Generated/downloaded; ignored, do not edit.                                                                                                            |

## Documentation system

`doc/libraries.lua` is authoritative. It returns `{ schema = 1, groups = ... }`
with four groups: `zli`, `third_party`, `tools`, `zli_topics` (the last two are
`flat = true`, rendered as single chapters). Helpers:

```lua
module(name, title, summary, markdown, entries, { upstream=, license=, aliases= })
entry(name, signature, kind, summary, markdown, aliases)
```

- `src/docs.lua` merges `docs_manual.lua` (Lua 5.5 manual) with
  `docs_libraries.lua` (same content as `doc/libraries.lua`, shipped in the
  payload). It builds `docs.entries`, `docs.by_name`, `docs.groups`,
  `docs.modules`, `docs.toc`, and provides `find`, `search`,
  `render_entry`, `render_manual_html`, `render_libraries_markdown`, etc.
- The manual is served by `@manual`; `@help` and the REPL `:help` use the same
  data. Flat groups still get module anchors for deep links.
- `doc/libraries.md` is produced by `zli @help --markdown --output doc/libraries.md`
  (`zig build docs`). `test/test_docs.lua` compares the rendered output with
  the committed file, so always regenerate and commit it with the source change.
- Always document every exposed flag or dialect with a description. When a
  group has more than two entries, use a Markdown table with the flag or
  dialect name in the first column and its description in the second. Keep
  flags and dialects in `doc/libraries.lua` in sync with the names exported by
  the module.
- Documentation tests also:
  - parse the library tables in `README.md` and require every listed module to
    have an entry;
  - require non-empty module descriptions and >=80-character bodies for
    function/method entries in modules listed in `completed_doc_modules`;
  - reject TODO/TBD/FIXME/??? placeholders in those modules;
  - enforce unique entry names and anchors;
  - spot-check `upstream` and `license` attribution for representative
    third-party modules;
  - ensure the C API is absent from the manual.
- `.gitattributes` forces LF for `doc/libraries.md`; the freshness test
  normalizes CRLF, but keep the file LF.

## Testing

- Tests are LuaUnit suites named `test/test_*.lua`; `test/test.lua` deletes
  `test/temp/*` (except `.gitignore`), sets `RUN_ALL = true`, requires every
  matching file, runs LuaUnit verbosely, then cleans up again and prints wall
  time.
- Every suite ends with:

  ```lua
  if not RUN_ALL then
      os.exit(lu.LuaUnit.run('-v'))
  end
  ```

  `zli @test file.lua` appends its own LuaUnit run, so this makes a suite work
  both standalone and under the full runner.

- `test/support.lua` provides `temp_path`, `temp_dir`, `temp_file`, `quote`,
  and `run(args, options)`. `run` captures stdout+stderr and status, supports
  `HOME=` overrides and stdin, and defaults to `ZLI.exe_path`/`arg[0]` as the
  executable.
- Always isolate `HOME` for tests that exercise the binary's config/init
  behavior; otherwise a developer's `~/.config/zli/init.lua` can print noise or
  change behavior.
- Tests intentionally cover externally created zip/gzip files, malformed
  archives, payload shadowing, symlink selection, and command-line tools.
- Zig unit tests live next to the code (`src/strip.zig`, `src/docgen.zig`) and
  are attached to `zig build test`.

## Change playbooks

### Add a pure-Lua module `foo`

1. Create `src/foo.lua` returning a module table.
2. Add it to `lualib_list` in `build.zig` (`.input = "src/foo.lua"`,
   `.name = "foo.lua"`) so it is embedded and stripped.
3. Add it to `luascripts` in `src/libraries.zig`
   (`.name = "foo", .source = @embedFile("foo.lua")`). Remember the require
   name need not match the filename (`logger.lua` → `log`).
4. Add the module to a library table in `README.md`.
5. Document it in `doc/libraries.lua`, add it to `completed_doc_modules` in
   `test/test_docs.lua`, then run `zig build docs`.
6. Add `test/test_foo.lua` and run `zig build test`.

### Add a Zig-backed module `foo`

1. Create `src/foo.zig` with an `FnReg` table, `register(lua) !i32`, and (if
   needed) `var io` + `setIo`. Use `luax.setupLibrary` and `luaerror.wrap`.
2. If it has a Lua wrapper `src/foo.lua`, add both files to `lualib_list` in
   `build.zig`.
3. Import it in `src/libraries.zig`, add a `package.preload` entry, and call
   `foo.setIo(io)` in `openlibs` when it uses I/O.
4. Follow the documentation/test steps above.

### Add a CLI tool `@foo`

1. Create `src/tools/foo.lua`; it receives `arg[1..]` and can `require` any
   bundled library.
2. Add `.{ .input = "src/tools/foo.lua", .name = "foo.lua" }` to
   `payload_entries` in `build.zig`.
3. Mention `@foo` in `src/main.lua`'s usage text, `README.md`, and
   `doc/README.md`; document it in the `tools` module in `doc/libraries.lua`.
4. Add a CLI test in `test/test_cli.lua` using `support.run` with an isolated
   `HOME`. Run `zig build docs` and `zig build test`.

### Bump the version

Keep these in sync:

- `src/version` — no trailing newline; embedded as `ZLI.version` and used in
  release filenames.
- `build.zig.zon` — package `.version`.
- `doc/libraries.lua` (`ZLI.version` example) and regenerated
  `doc/libraries.md`.
- `test/test_filesystem.lua` — it asserts the exact version string.
- `README.md` release binary example.

### Change public behavior

Update in one change: implementation, `doc/libraries.lua`, regenerated
`doc/libraries.md`, `README.md`/`doc/README.md` when user-facing, and tests.
The documentation tests are strict by design.

## Conventions and invariants

- Zig style: 4 spaces, `c_allocator` in runtime code, explicit `std.Io` values,
  `!i32` Lua handlers, `luaerror` for failures, `luax` for stack work.
- Lua style: 4 spaces, localize hot functions, return module tables, keep
  comments only where behavior is non-obvious.
- Cross-platform code must handle Windows path separators, `.exe` suffixes,
  and shell quoting; use `builtin.os.tag`/`os.is_windows` and test helpers
  rather than assuming POSIX.
- Local files always take precedence over payload entries. Preserve that rule
  in `io.open`/`io.lines` and the module searcher.
- Payload order and timestamps are deterministic. Do not introduce timestamps,
  random ordering, or build paths into payload entries.
- Release library/payload Lua is stripped: do not rely on comments surviving in
  the binary (documentation payload files are exempt).
- Do not edit generated/vendor directories (`zig-pkg/`, `.zig-cache/`,
  `zig-out/`) or `doc/libraries.md` by hand.
- Use `zig fmt` for edited Zig files; keep the existing import ordering and
  helper patterns.
- Never add `.h` files under `src/` when the same setup can be expressed in
  `build.zig`. Point `addTranslateC` at an existing dependency header and add
  the required include paths there instead.

## Gotchas

1. A new library usually needs **three** registration points: `lualib_list`
   and/or `payload_entries` in `build.zig`, plus `preload`/`luascripts` in
   `src/libraries.zig`. Missing one produces a module that works in debug but
   not release, or vice versa.
2. `doc/libraries.md` freshness is a test, not a suggestion.
3. `test_docs.lua` parses `README.md` tables; a library missing from README
   fails the suite even if it is documented elsewhere.
4. `completed_doc_modules` must be updated for new authored modules, otherwise
   the depth checks silently skip them.
5. Tests execute the built binary and its payload. After editing an embedded
   Lua file, rebuild (`zig build test`) before invoking `zig-out/bin/zli`.
6. `src/version` has no newline; `test_filesystem.lua` reads it as a line.
7. Zig 0.17's `std.Io` API differs from older Zig examples: file operations
   take an `io` parameter and `main` receives `std.process.Init`. Match the
   surrounding code.
8. The plain debug binary is large and dynamically linked; use release builds
   when checking portability or size.
9. `webui` ships its browser assets both as payload entries and as `@embedFile`
   data in `src/webserver.zig`; changing `src/webui/app.js` or `app.css`
   therefore needs a rebuild, not just a payload refresh. `assets_dir` is the
   development escape hatch.
10. `webserver` is concurrent and non-blocking for connections, but all Lua
    callbacks still run on the `serve` task: a slow callback stalls every
    client. `httpserver` is the older blocking server; do not mix them up.
11. `@compile`/payload entry selection is based on the executable basename and
   payload lookup order, not on the selected script's position in `arg`;
   preserve `ZLI.exe_path` behavior when touching startup.
10. `docgen.zig` intentionally drops the Lua C API and grammar-only chapter.
    Do not add them back when regenerating docs.

## Maintaining this guide

Update this file when the build/payload manifests, library/tool registration,
or documentation/test pipeline changes. Keep it navigation-focused: point to
the source of truth instead of duplicating API details that already live in
`doc/libraries.lua` and `README.md`.
