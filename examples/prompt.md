# Prompt showcase

`prompt.lua` is a guided tour of the `prompt` library. It asks for a fictional
mission, crew details, a launch date and time, then runs a few simulated
progress bars and a spinner. Nothing is created, saved or contacted — every
step is made up.

```bash
zig build
./zig-out/bin/zli examples/prompt.lua
```

## What it demonstrates

| component | what the showcase asks for |
| --- | --- |
| `prompt.select` | Inline or alternate presentation, then a mission with descriptions and a disabled option. |
| `prompt.multiselect` | A set of imaginary modules, with defaults and a minimum selection. |
| `prompt.text` | A crew call sign with a placeholder, length limit and validation. |
| `prompt.multiline` | A multi-line mission motto. Enter submits; Alt+Enter inserts a newline. |
| `prompt.password` | A launch code with a confirmation prompt and masked summary. |
| `prompt.date` | A launch date from the calendar, constrained to today or later. |
| `prompt.time` | A launch time using the segmented picker. |
| `prompt.datetime` | A combined crew briefing date and time. |
| `prompt.confirm` | A yes/no "authorise" step. |
| `prompt.progress` | A simulated calibration bar using `update()` and `finish()`. |
| `prompt.progress.each` | The same style of bar driven by an iterator over the modules. |
| `prompt.spinner` | A time-throttled "polishing chrome" spinner. |

The final section prints a fake launch manifest so the collected values are
visible.

## Things to try

- Choose **Alternate screen** at the start to see the full-screen presentation.
  `prompt.screen` enters the alternate screen once for the whole sequence, so
  prompts do not flash the original terminal contents between steps.  The final
  manifest is printed back in the normal scrollback.
- Press Esc at any prompt to cancel the whole showcase and restore the
  terminal.
- Change a value and watch validation keep the field open (the call sign
  rejects spaces, and the multiselect requires at least one module).
- In the list, use arrows or `j`/`k` to move and Enter to accept. Missions that
  have many entries switch to type-to-filter automatically.

## Plain fallback

The script also works with piped input. Blank answers accept defaults, the
multiline prompt ends with a line containing only `.`, and the password is read
without masking because there is no terminal. For example:

```bash
printf '\n\n\n\n.\n\n\n\n\n\n\n\n' | ./zig-out/bin/zli examples/prompt.lua
```

Progress and spinner updates are suppressed outside a terminal; only their
final success lines are printed.
