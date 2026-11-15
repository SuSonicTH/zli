# Suggested PR title

Add bracketed paste events, end-of-input handling and cursor/resize fixes

# Summary

This branch turns several terminal behaviours that were previously undefined,
blocking or platform-inconsistent into explicit API results. It adds bracketed
paste support, reports end of input, normalises resize and cursor coordinates,
and fixes the VT cursor-addressing and cursor-restore sequences.

The changes are driven by a line editor that needs bracketed paste, reliable
multiline input, EOF handling and a correct cursor anchor. The parser remains
allocation-free; the new paste path uses a fixed buffer inside `Input`.

# Changes

## Bracketed paste

- `Event` gains `Paste: []const u8`.
- `Parser` recognises `CSI 200~` / `CSI 201~` as internal `paste_begin` /
  `paste_end` events.
- `Input` collects paste bytes into a fixed 16 KiB buffer and returns them as
  `Event.Paste`. Pastes larger than the buffer are split into several events.
  The terminator is detected across read boundaries and an `ESC` that is not
  part of `ESC[201~` is preserved as pasted content.
- `Terminal.enableBracketedPaste()` / `disableBracketedPaste()` emit
  `CSI ?2004h` / `CSI ?2004l`. On Windows consoles without VT output the
  helpers are no-ops.
- The slice in `Paste` points into the originating `Input` and is valid until
  the next `read`, `poll` or `queryCursorPosition` on that instance; this is
  documented on the event.

## End of input

- Unix: `Input.read` now returns `error.EndOfInput` when the tty read returns
  zero bytes instead of polling and re-reading forever.
- Windows: `ReadConsoleInputW` failures with `ERROR_BROKEN_PIPE` or
  `ERROR_HANDLE_EOF` are reported as `error.EndOfInput`; other failures remain
  `error.FailedToReadEvent`.

## Resize

- `Event.Resize` is now a named struct: `{ columns: u16, rows: u16 }`.
  Previously the anonymous tuple was filled as `(rows, columns)` on Unix but
  `(columns, rows)` on Windows. Both platforms now use the same order.
- Windows resize events query `GetConsoleScreenBufferInfo` and report the
  visible window (`srWindow`) rather than the screen buffer size. If the query
  fails, the event dimensions are used as a fallback.

## Cursor and window size

- `Cursor.moveTo(x, y)` now emits `CSI {y};{x} H` on VT terminals. It previously
  emitted `{x};{y}`, transposing the axes relative to the WinAPI path.
- `Cursor.restorePosition()` now emits `CSI u` (restore) instead of `CSI s`
  (save, the same sequence used by `savePosition`).
- Unix `Terminal.windowSize()` uses the tty handle owned by `Tty` instead of
  the global lazily opened `/dev/tty`.
- Windows `Terminal.windowSize()` reports the visible window size rather than
  the console buffer dimensions.
- Windows `Input.queryCursorPosition()` reports the cursor row relative to the
  visible window (`dwCursorPosition.Y - srWindow.Top`) and keeps `x` as the
  column, matching the Unix convention.
- Parser CPR responses now store the column in `.x` and the row in `.y`.
  Previously the Unix parser stored the row in `.x`, while the Windows query
  used `.x = column`, so the same API had different meanings per platform.

## Tests and build

- `build.zig`'s `test` step now runs unit tests on the module. It previously
  referenced a non-existent `examples/test.zig`, so `zig build test` could not
  run.
- Added parser tests for the paste markers, Kitty-style Ctrl+Enter and
  Ctrl+Shift+X sequences, and CPR axis order.
- Paste assembly and EOF are exercised indirectly by a terminal line editor
  built on this branch; the parser tests cover the wire format.

# Compatibility notes

- `Event.Resize` consumers that used positional fields must switch to `columns`
  and `rows`. This is intentional: the previous field order was inconsistent
  between platforms.
- Adding `Event.Paste` requires exhaustive `switch` statements over `Event` to
  handle the new variant.
- `Input.read()` can now return `error.EndOfInput`. Callers that previously
  relied on it blocking forever at EOF should handle the error.
- Code that compensated for the old Unix CPR behaviour by swapping `x`/`y` must
  remove the swap. `queryCursorPosition` now returns the same meaning on Unix
  and Windows.
- Code that compensated for the transposed VT `Cursor.moveTo` must remove the
  compensation.
- `windowSize()` now returns the visible window, not the console buffer, on
  Windows. This is the useful value for full-screen layouts; callers that need
  the buffer size can query the console API directly.
- Bracketed paste is opt-in: terminals only send paste events after
  `enableBracketedPaste()`. Windows native console input still reports pasted
  text as key events.

# Commits

- `93ade7e` Add paste events, EOF handling and terminal fixes
- `7c2619a` Normalize resize events and report viewport-relative cursor rows
- `7926da6` Handle console EOF and fix Windows cursor row types
- `fb7374f` Fix Windows cursor column saturation type
- `e14c6ab` Use signed math for Windows cursor coordinates
- `fee5bc8` Report the visible console window size on Windows
- `18aab6f` Report visible window size for console resize events
- `cdee1af` Fix VT cursor addressing and CPR axis order
- `ccece10` Test cursor report axis order

# Testing

- `zig build test` runs the new parser tests.
- Cross-compiles for `x86_64-windows` and `aarch64-linux` with Zig 0.17.
- Manual testing on Linux under a pseudo terminal: bracketed paste (including
  chunked large pastes), EOF, resize while editing, CPR queries, and cursor
  positioning.
- Windows changes are covered by cross-compilation and API inspection; a real
  Windows console run would be valuable before merging.

# Open questions for reviewers

- Is the fixed 16 KiB paste buffer and chunking acceptable, or would you prefer
  an allocator-owned paste buffer?
- Should pasted newlines be normalised in `Input` (currently the slice contains
  the raw bytes, including `\r\n`)?
- Should `Event.Paste` carry a `complete: bool` or a begin/end pair so consumers
  can tell the last chunk of a large paste without inspecting the next event?
- The named `Resize` fields and `Paste` variant are the only source-breaking
  API changes; both are deliberate, but they could be staged behind a major
  version bump.
