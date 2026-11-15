# Prompt alternate-screen showcase

`prompt_alternative.lua` is a guided tour of the `prompt` library whose
interactive prompts and progress output all run in the alternate screen. It asks
for a fictional mission, crew details, a launch date and time, then runs a few
simulated progress bars and a spinner. Nothing is created, saved or contacted —
every step is made up.

```bash
zig build
./zig-out/bin/zli examples/prompt_alternative.lua
```

## What it demonstrates

| component | what the showcase asks for |
| --- | --- |
| `prompt.screen` | Enters the alternate screen once for the whole sequence. |
| `prompt.select` | A mission with descriptions and a disabled option. |
| `prompt.multiselect` | A set of imaginary modules, with defaults and a minimum selection. |
| `prompt.text` | A crew call sign with a placeholder, length limit and validation. |
| `prompt.multiline` | A multi-line mission motto. Enter submits; Alt+Enter inserts a newline. |
| `prompt.password` | A launch code with masked input and a confirmation prompt. |
| `prompt.date` | A launch date from the calendar, constrained to today or later. |
| `prompt.time` | A launch time using the segmented picker. |
| `prompt.datetime` | A combined crew briefing date and time. |
| `prompt.confirm` | A yes/no "authorise" step. |
| `prompt.progress` | A simulated calibration bar using `update()` and `finish()`. |
| `prompt.progress.each` | The same style of bar driven by an iterator over the modules. |
| `prompt.spinner` | A time-throttled "polishing chrome" spinner. |

The final section prints a fake launch manifest back in the normal scrollback
after the alternate screen is closed.

## Things to try

- Notice that the alternate screen is entered once and left once; prompts do not
  flash the original terminal contents between steps.
- Press Esc at any prompt to cancel the whole showcase, restore the terminal and
  return to the normal screen.
- Change a value and watch validation keep the field open (the call sign
  rejects spaces, and the multiselect requires at least one module).
- In the list, use arrows or `j`/`k` to move and Enter to accept. The library
  enables type-to-filter when a list has more entries than the page size; this
  example's four-mission list is short enough to show in full.
- The progress and spinner start at their initial state as soon as they are
  created, then advance while the script pauses between steps.

## Plain fallback

The script also works with piped input. Blank answers accept defaults, the
multiline prompt ends with a line containing only `.`, and the password is read
without masking because there is no terminal:

```bash
printf '\n\n\n.\n\n\n\n\n\n\n' | ./zig-out/bin/zli examples/prompt_alternative.lua
```

Progress and spinner updates are suppressed outside a terminal; only their
final success lines are printed.
