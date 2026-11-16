# Prompt explorer

`prompt_explorer.lua` walks through the read-only and inspection components:

1. `prompt.file` picks a Lua or Markdown file with a live text preview.
2. `prompt.table` shows the entries of the file's directory with sortable
   columns and a picker.
3. `prompt.keyvalue` displays the selected entry's details.
4. `prompt.diff` shows a small before/after text change.

```bash
zig build
./zig-out/bin/zli examples/prompt_explorer.lua
```

The script starts the file picker in the current directory. Use the arrow keys
to move, `Right` to enter a directory, `Enter` to select a file and `/` to type
a path directly. In the table, `Left` and `Right` focus a column and `s` cycles
sorting; `Enter` returns the selected row. The two viewers close with `q`,
`Enter` or `Esc`.

## Plain fallback

With piped input each component prints its text form. The file picker reads a
path, the table reads a row number, and the key/value and diff viewers print
their content and return immediately. This input picks `README.md` from the
repository root and accepts the first table row:

```bash
printf 'README.md\n1\n' | ./zig-out/bin/zli examples/prompt_explorer.lua
```

The final line prints the selected name, kind and size so the demo is easy to
check in a script.

## Things to notice

- The file picker gets a glob filter, hidden-file filtering and a preview pane
  without any extra code in the example.
- Columns can align values and provide a `format` callback; the table sorts
  without copying or rewriting the original row tables.
- `prompt.keyvalue` keeps a deterministic order through its `order` array even
  though the data table is unordered.
- `prompt.diff` uses the bundled pure Lua diff engine, so the example works
  without `git` or another external diff program.
