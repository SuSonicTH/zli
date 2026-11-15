//! Shared conversion from termy key events to the terminal independent
//! `lineedit` key representation.

const std = @import("std");
const termy = @import("termy");
const lineedit = @import("lineedit.zig");

pub fn convertKey(key: termy.event.KeyEvent) lineedit.Key {
    const code: lineedit.KeyCode = switch (key.code) {
        .Char => |cp| .{ .char = cp },
        .Enter => .enter,
        .Backspace => .backspace,
        .Delete => .delete,
        .Left => .left,
        .Right => .right,
        .Up => .up,
        .Down => .down,
        .Home => .home,
        .End => .end,
        .Tab => .tab,
        .PageUp => .page_up,
        .PageDown => .page_down,
        .Esc => .esc,
        .Insert => .insert,
        .F => |number| .{ .f = number },
        else => .null_key,
    };

    // The Windows console reports Ctrl+A..Ctrl+Z as the raw control bytes
    // 0x01..0x1A.  Normalise them to the same keys the Unix parser produces.
    return lineedit.applyControlCode(.{
        .code = code,
        .shift = key.modifier.Shift,
        .control = key.modifier.Control,
        .alt = key.modifier.Alt,
    });
}
