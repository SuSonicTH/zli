# graphcalc

Start a graphical calculator served by the `webui` component model.

The page plots one or more `f(x)` expressions and refreshes the plot while you
type. Functions can be added, hidden and removed, the window can be zoomed or
typed in, and the y axis either scales automatically or uses an explicit range.
The current plot can be downloaded from the page as a self-contained SVG.

Expressions use numbers, `x` (also `t`), the constants `pi`, `tau`, `e`, `phi`,
`inf` and `nan`, the operators `+ - * / % ^` (also `**`), parentheses and
implicit multiplication (`2x`, `3sin(x)`). Unary minus binds looser than the
power, so `-2^2` is `-4`. Available functions: `sin`, `cos`, `tan`, `asin`,
`acos`, `atan`, `atan2`, `sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh`,
`sqrt`, `cbrt`, `exp`, `ln`, `log` (natural logarithm, optional base), `log2`,
`log10`, `abs`, `sign`, `floor`, `ceil`, `round`, `trunc`, `fract`, `pow`,
`hypot`, `mod`, `min`, `max`, `clamp`, `deg` and `rad`. Curves are clipped to
the frame and discontinuities such as `tan(x)` are not joined across
asymptotes.

| option             | description                                               |
| ------------------ | --------------------------------------------------------- |
| `--port <port>`    | listen port; `0` picks a free port (default `8080`)       |
| `--address <addr>` | bind address (default `127.0.0.1`)                        |
| `--expr <f(x)>`    | start with this expression (repeatable, default `sin(x)`) |
| `--xmin <n>`       | initial left edge of the window (default `-10`)           |
| `--xmax <n>`       | initial right edge of the window (default `10`)           |
| `--no-open`        | do not open the system browser                            |
| `--eval <f(x)>`    | print `f(x)` at `--at` and exit                           |
| `--at <n>`         | x value for `--eval` (default `0`)                        |
| `--svg <file>`     | write the plot as a standalone SVG and exit               |
| `--token <t>`      | fixed session token (tests and automation)                |
| `--stop-path <p>`  | POST path that stops the server (tests and automation)    |

`--eval` and `--svg` make the calculator scriptable: they print or write their
result and do not start a server. A syntax error prints a message with the
position and exits with status `1`; invalid options exit with status `2`.

```bash
zli graphcalc.lua --expr "sin(x)" --expr "x^2/10" --port 9000
zli graphcalc.lua --eval "sin(pi/2)"
zli graphcalc.lua --expr "sin(x)" --svg plot.svg
```
