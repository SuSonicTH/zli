# Prompt demo

`prompt_demo.lua` is a small project setup wizard built from the `prompt`
library. It shows the procedural style the library is designed for: each
component runs to completion and returns a value, so no event loop or callback
scaffolding is needed.

```bash
zig build
./zig-out/bin/zli examples/prompt_demo.lua
```

## What it asks for

1. A single-select target environment with descriptions and a default.
2. A multiselect list of features with at least one required selection.
3. A project name with a placeholder and a validation callback.
4. A release date from the calendar picker.
5. A yes/no confirmation.
6. A progress bar while the selected features are "applied".
7. A spinner while caches are "warmed".

The final line prints the collected values.

## Trying the plain fallback

The same script works without a terminal. When stdin or stdout is not a TTY the
components print numbered or prompted plain-text questions instead of drawing
a live UI:

```bash
printf '2\n1,3\nDemo\n2027-01-15\ny\n' | ./zig-out/bin/zli examples/prompt_demo.lua
```

Blank answers accept the default; end of input also uses the default when one
exists.

## Things to notice

- `prompt.select` returns the item's `value`, which can differ from its label.
- `prompt.multiselect` returns values in item order.
- `validate` returns `true` or `nil, message`; a rejected value keeps the field
  open and shows the message underneath.
- `prompt.date` returns `YYYY-MM-DD` here because of `as = "string"`.
- `progress:advance()` and `spinner:step()` are called from the normal working
  loop. No background thread is involved, so the spinner only animates when
  the loop reaches the next `step`.
- Pressing Esc or Ctrl+C cancels and restores the terminal; this script exits
  cleanly instead of carrying a `nil` value into the later steps.
