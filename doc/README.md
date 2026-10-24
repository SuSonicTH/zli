# ZLI usage and tools

## Script execution

```bash
zli script.lua arg1 arg2
zli - < script.lua            # read the program from stdin
zli @name arg1 arg2           # run name.lua from the attached payload
zli                           # select <exe-name>.lua, main.lua or init.lua
```

Scripts are selected in this order:

1. `@name`: `name` or `name.lua` from the payload (`@dir/name` is supported).
2. `-`: read the program from stdin.
3. An existing file in the filesystem.
4. `<executable-name>.lua` from the payload. On Windows `.exe` is stripped from
   the executable name. This also works through symlinks, so one payload can
   provide several tools.
5. `main.lua` from the payload.
6. `init.lua` from the payload.

If none matches, ZLI prints an error and a short usage line. The standard
payload's `main.lua` starts the REPL, so the bundled `zli` binary starts the
REPL when no arguments are given.

Inside a script, `arg[0]` is the executable name used to invoke ZLI and
`arg[1]` onwards are the script arguments, matching the standard Lua
interpreter convention. The selected payload script is not substituted into
`arg[0]`. Local Lua files always take precedence over files with the same name
in the payload.

## Init files

| file                          | when it runs                         |
| ----------------------------- | ------------------------------------ |
| `~/.config/zli/init.lua`      | before every script and REPL session |
| `~/.config/zli/repl_init.lua` | when the REPL starts                 |

`init.lua` is useful for setting `ZLI.error_handling`, defining global helper
functions, or configuring libraries. Both files are created with a short
comment header on first use if they do not exist. This also applies to scripts
run from a compiled executable.

## REPL

```bash
zli @repl
zli                 # no arguments also starts the REPL
```

- `quit` or `exit` leaves the REPL; `Ctrl-D` also exits.
- `?expression` pretty-prints tables and strings.
- `:help` shows the documentation index; `:help <name>` looks up an entry and
  `:help --search <term>` searches all documentation.
- Incomplete statements continue on the next line.
- `F1` shows the crossline editing help.

## SQLite CLI

```bash
zli @sqlite
```

The CLI starts with an in-memory database. Statements end with `;`.

| command              | description                                             |
| -------------------- | ------------------------------------------------------- |
| `open "file.db";`    | Open a database file                                    |
| `close;`             | Close the current database and open a new in-memory one |
| `file "script.sql";` | Execute statements from a file                          |
| `mode;`              | Print the current output mode                           |
| `mode table;`        | Pretty table output (default)                           |
| `mode csv;`          | CSV output                                              |
| `mode json;`         | JSON output                                             |
| `mode lua;`          | Lua table output                                        |
| `quit;`, `exit;`     | Leave the CLI                                           |

## Static file server

```bash
zli @serve ./public
zli @serve                 # serves ./
```

The server listens on `127.0.0.1:8080`. It serves `index.html`/`index.htm` for
directories, falls back to a directory listing, and blocks `..` traversal and
percent-encoded traversal outside the web root. MIME types are taken from a
built-in table.

The manual can be served with:

```bash
zli @manual
```

`@manual` renders the bundled reference manual (the Lua 5.5 language and
standard libraries, all bundled libraries, the command line tools and ZLI
topics) and serves it at `http://127.0.0.1:8080/`.  The manual is part of the
payload; it is generated at build time from the `lua55` dependency's
`doc/manual.html` plus `doc/libraries.lua`.  Options:

| option          | description                                      |
| --------------- | ------------------------------------------------ |
| `--port <port>` | listen port (default `8080`)                     |
| `--address <a>` | bind address (default `127.0.0.1`)               |
| `--no-open`     | do not open the system browser                   |
| `--output <f>`  | write the rendered HTML manual to a file and exit |

## Documentation lookup

```bash
zli @help                      # documentation index
zli @help string.byte          # exact entry (or a ranked result list)
zli @help --search trim        # full-text search
zli @help --list               # all documented names
zli @help --markdown --output doc/libraries.md
```

Inside the REPL, `:help` shows the index, `:help <name>` looks up an entry and
`:help --search <term>` searches.  Scripts can use `require "docs"`; it exposes
`docs.find(name)`, `docs.search(query, options)`, `docs.render_markdown(text)`
and `docs.render_text(text)`.  Authored documentation uses GitHub-flavored
Markdown and is rendered by the bundled `markdown` (md4c) library.

`doc/libraries.lua` is the source of truth for bundled-library documentation.
`doc/libraries.md` is generated from it and is checked by the test suite for
freshness.  Regenerate it with `zig build docs` (or
`zli @help --markdown --output doc/libraries.md`).  The Lua manual itself is
never stored in the repository: it is extracted from the Lua dependency on every
build.

## Test tool

```bash
zli @test test/test_foo.lua
```

Runs a LuaUnit test file. The test file may define tests in global tables whose
names match `Test`.

## Compile tool

`zli @compile <config>` copies the current executable, removes any payload it
already has, and appends a new zip payload. The payload is searched for scripts
on startup.

The config file may be either a table constructor or a `return { ... }`
statement:

```lua
return {
    output_name = "myapp",          -- required
    files = {                       -- required, at least one entry
        { file = "src/main.lua", name = "main.lua" },
        { file = "assets/data.txt" }, -- name defaults to the basename
    },
}
```

or:

```lua
output_name = "myapp"
files = {
    "main.lua",
    "lib/util.lua",
}
```

Entry scripts are resolved from the payload in this order:
`<executable-name>.lua`, `main.lua`, `init.lua`. A specific script can be
selected with `zli @scriptname`; `@dir/scriptname` is also supported.

On Linux the output file is made executable (`chmod 755`). On Windows the
`.exe` suffix is added automatically.

## Payload/`argv[0]` note

The payload zip is opened through the real executable path rather than trusting
`argv[0]`, so compiled executables work when launched through `PATH`. The
`<executable-name>.lua` payload entry is selected from the basename of
`argv[0]`, which allows one payload to provide several tools through symlinks.
The Lua `arg[0]` value still reflects the name used to invoke the program.
