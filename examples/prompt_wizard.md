# Prompt wizard

`prompt_wizard.lua` builds a project setup flow from `prompt.wizard`. It shows
the step form, review page and the supporting live components that go with a
longer interactive script.

```bash
zig build
./zig-out/bin/zli examples/prompt_wizard.lua
```

## What it asks for

1. **Basics** — a validated project name and an environment selector.
2. **Features** — a multiselect with a minimum, a multiline notes field and a
   confirmation. The step-level `validate` rejects the combination of enabling
   the project with all three optional features.
3. **Schedule** — a date and time pair returned as strings.
4. **Review** — an automatically generated summary of every step.

After the review the script waits for a key, applies the settings with a
multi-item progress bar, shows a success toast and prints the collected values.

## Trying the plain fallback

Without a terminal the wizard prompts every step in order and prints the review
block. Blank answers accept defaults; the multiline notes field keeps blank
lines and ends on a line containing only `.` (or at end of input). This input
accepts every default and leaves the notes empty:

```bash
printf '\n\n\n\n.\n\n\n\n' | ./zig-out/bin/zli examples/prompt_wizard.lua
```

The seven prompts are the name, environment, features, notes terminator, the
enable confirmation, the release date and the release time. Each component in
the flow keeps its own fallback: `prompt.pause` prints its message once,
`prompt.progress.multi` prints one start line per item and the final status,
and `prompt.toast` prints the notice once.

## Things to notice

- `prompt.wizard` merges the field values of every step into one table, so a
  later step can validate against values collected earlier.
- `review = true` appends a generated page after the last step. Enter submits
  from the review page; Alt+Left or `b` goes back to the last step. Ctrl+Enter
  opens the review page from any step and then submits from the review page.
- Values survive going backwards: the page objects keep their editors, so
  returning to a step shows the text that was typed, not the original default.
- In a form, Tab and Shift+Tab move between fields, Enter advances to the next
  field (or submits the last one), and Ctrl+Enter submits from anywhere. Inside
  a multiline field Enter inserts a newline and Alt+Enter advances. Ctrl+T
  switches the date and time sections of the date-time field.
- The Esc confirmation only appears after a value has changed, which keeps a
  quick cancel cheap when nothing was edited.
- `prompt.progress.multi` uses one segmented bar with a legend when
  `stacked = true`, and one line per item otherwise.
