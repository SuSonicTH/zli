# calc

A basic calculator with a browser UI that evaluates the keys with the usual
arithmetic precedence: `=` works on the whole expression instead of applying
each operation as it is pressed, so `2 + 3 * 4 =` is `14`.

All arithmetic happens in Lua. Every key press posts an event to the server,
which updates the calculator state and re-renders the page, so the browser never
holds any of the numbers itself. The display shows the expression as it is
typed, right aligned, with the memory indicator on its left.

```bash
zli calc.lua
zli calc.lua --port 9000 --no-open
```

| option             | description                                            |
| ------------------ | ------------------------------------------------------ |
| `--port <port>`    | listen port; `0` picks a free port (default `8080`)    |
| `--address <addr>` | bind address (default `127.0.0.1`)                     |
| `--no-open`        | do not open the system browser                         |
| `--token <t>`      | fixed session token (tests and automation)             |
| `--stop-path <p>`  | POST path that stops the server (tests and automation) |
| `-h`, `--help`     | print the generated usage and options                  |

The options are parsed with the bundled `argparse`: `--help` prints the
generated usage, and an unknown option, a missing value or a malformed port
prints the usage plus an error and exits with status `1`.

The calculator is driven with the mouse or a touch screen. This build of
`webui` does not bind keyboard events, so typing on the keyboard has no effect
on the pad.

## No page style

This example uses the components `webui` already ships and adds no page
stylesheet: the buttons are the default buttons, the display is a label above a
divider with the one inline style `text-align: right`, and the keypad is a
stack of horizontal layouts whose keys grow to the same width. Two things
follow from that:

- Below a `640px` viewport the default stylesheet stacks horizontal layouts, so
  the keypad turns into a column of full width keys. A small page style block
  (`page = ui.page { css = ... }`) is all it takes to keep the pad in a row at
  every width.
- The page is `380px` wide, which is what keeps the keys a sensible size on a
  desktop screen; a window narrower than that scrolls sideways.

## Keys

| key    | what it does                                                        |
| ------ | ------------------------------------------------------------------- |
| `0`–`9`| append a digit to the number being typed (at most 32 digits)        |
| `.`    | append a decimal point, starting `0.` when no number is in progress |
| `+/-`  | change the sign of the number being typed                           |
| `←`    | delete the last character, or undo the last operator                |
| `CE`   | clear the number being typed, keeping the expression so far         |
| `C`    | clear the display and any error; keeps memory                       |
| `MC`   | clear memory                                                        |
| `MR`   | put the memory value into the display                               |
| `MS`   | store the displayed number in memory                                |
| `M+`   | add the displayed number to memory                                  |
| `√`    | square root of the current number                                   |
| `1/x`  | reciprocal of the current number                                    |
| `%`    | percentage, see below                                               |
| `+ - * /` | add the operator to the expression                              |
| `=`    | evaluate the expression                                             |

`←` is two keys in one: while a number is being typed it deletes a character,
and after an operator it removes that operator and hands its left hand number
back to the entry, so `2 + 3 * ←` shows `2+3` again. Deleting the last digit of
a number removes the number itself, so `2 + 3 * 4 ← ←` also shows `2+3`.

## Arithmetic rules

`=` evaluates the expression with `*` and `/` binding tighter than `+` and `-`,
and with equal precedence evaluated left to right:

| keys            | result |
| --------------- | ------ |
| `2 + 3 * 4 =`   | `14`   |
| `2 * 3 + 4 =`   | `10`   |
| `10 - 2 * 3 =`  | `4`    |
| `8 / 4 / 2 =`   | `1`    |

Pressing an operator twice in a row replaces the pending one (`2 + * 3 =` is
`6`). Pressing `=` while the expression ends with an operator applies that
operator to the number on its left, so `2 + =` is `4`.

`=` remembers the last operation of the expression and repeats it on the result:

| keys                | result |
| ------------------- | ------ |
| `2 + 3 * 4 =`       | `14`   |
| `2 + 3 * 4 = =`     | `56`   |
| `2 + 3 =`           | `5`    |
| `2 + 3 = =`         | `8`    |

After `=` a digit starts a new expression, while an operator continues from the
result (`2 + 3 = + 4 =` is `9`).

The unary keys work on the number being typed. When an operator is pending they
work on the operand on the left of that operator and put the result into the
entry, so `2 + 9 √` shows `2+3`. `+/-` flips the number being typed; with an
operator pending and no number typed after it there is nothing to flip, so it
is ignored.

`%` depends on the pending operator:

| pending operation | `%` of the entry                                                |
| ----------------- | --------------------------------------------------------------- |
| `+` or `-`        | a percentage of what is already there: `100 + 10 % =` is `110`   |
| `*` or `/`        | the entry divided by 100: `100 * 10 % =` is `10`                 |
| none              | the entry divided by 100: `50 %` is `0.5`                        |

The memory keys always use the number on the display; they never evaluate the
expression, so `5 + 3 MS` stores `3`. Press `=` first when the result is what
should be remembered. `C` keeps the memory value, `MC` clears it. The `M` beside
the display is visible while memory is not zero.

## Errors and precision

Three messages can be shown in the display:

| message                  | cause                                                  |
| ------------------------ | ------------------------------------------------------ |
| `Cannot divide by zero.` | a division by zero, including `1/x` of zero            |
| `Invalid input.`         | `√` of a negative number                               |
| `Overflow.`              | a result that does not fit in a double                 |

While a message is shown, only `C`, `CE` and the digit keys (including `.`)
react: `C` and `CE` clear the message, and typing a digit or the decimal point
starts a new calculation. All other keys are ignored so a stale expression
cannot be evaluated by accident.

Numbers are Lua doubles, so results are exact for integers up to 2^53 and carry
about 15 significant digits otherwise. Displayed results use integer notation
when the value is a whole number that also fits in an integer, and the shortest
`%.15g` form otherwise, so very large whole results such as `1e+64` keep
exponent notation. That form hides binary rounding noise (`0.1 + 0.2` shows
`0.3`). Results are not padded or grouped with thousands separators.

## What to look at in the source

- `state` holds the committed expression in `tokens`, the number being typed in
  `entry`, whether that number is live in `typing`, memory, the error and the
  operation `=` repeats.  The transitions that belong to the state itself are
  methods on it (`state:blocked()`, `state:fail(message)`,
  `state:clear_all()`, `state:clear_entry()`), so they act on `self` instead of
  reaching for an upvalue.
- `evaluate` folds the token list in two passes: `*` and `/` left to right into
  the values, then `+` and `-` left to right over the results. That is the usual
  precedence without a parser stack. `apply` performs one operation and reports
  division by zero and overflow.
- `display_text` joins the committed tokens and, when a number is being typed or
  the expression is empty, the entry — which is why pressing an operator shows
  `2+3*` and pressing a digit shows `2+3*4`.
- Every key handler mutates `state` (the digit and operator handlers are passed
  straight to `key`, which gives each action its own label); `create_page` wires
  each button to one of them and calls `redraw`, which pushes the display text,
  the error and the memory indicator into the component tree.
- The keypad has no CSS: `row` builds a horizontal layout of buttons with
  `grow = 1`, and the top row starts with a single spacer that grows three times
  as wide, so `←`, `CE` and `C` line up with the last three columns.
- Values that are computed rather than typed go through `set_entry`, which
  formats them, reports a non-finite result as `Overflow.` and keeps the entry a
  plain decimal literal, so the digit keys can extend it again. `number_token`
  asserts that invariant instead of silently treating an odd entry as zero.
- `argparse` builds the command line: `port_number` converts `--port` and
  rejects anything outside `0`–`65535`, `:default()` supplies the defaults and
  `--help` is generated.  The resulting table is handed to `ui.serve`, which
  starts the server.
