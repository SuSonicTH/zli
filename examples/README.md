# ZLI examples

This directory collects small, self-contained programs that show how ZLI can be
used. Every example is a plain Lua script that runs directly with the
executable: there is nothing to install and no payload to build.

```bash
zig build
./zig-out/bin/zli examples/graphcalc.lua
```

The examples cover different parts of the runtime — command line programs,
browser UIs built on `webui`, and scripts that lean on the bundled libraries.
Each script has a companion Markdown file with the same basename that describes
what it does, how to run it and what to look at in the source
(`graphcalc.lua` ↔ `graphcalc.md`).

Arguments after the script name are passed to the script in `arg`, exactly like
the standard Lua interpreter, so the commands shown in an example's Markdown
can be shortened when you are already inside this directory (`cd examples`).

## Examples

| example                          | description                                                                                                                                     |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| [`graphcalc.lua`](graphcalc.lua) | Graphical calculator with a browser UI built on `webui`. Plots several `f(x)` curves, supports zooming and exports SVG. [Details](graphcalc.md) |
