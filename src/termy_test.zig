//! Regression tests for the pinned termy fork's terminal output.

const std = @import("std");
const builtin = @import("builtin");
const termy = @import("termy");

test "VT cursor addressing emits row then column" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile(std.testing.io, "out", .{ .read = true });
    defer file.close(std.testing.io);

    var buffer: [256]u8 = undefined;
    var tty: termy.Tty = .init(std.testing.io, file, &buffer, null);
    var cursor: termy.Cursor = .init(&tty);

    try cursor.moveTo(22, 7);
    try cursor.moveToRow(4);
    try cursor.moveToColumn(9);
    try tty.writer().flush();

    var output: [128]u8 = undefined;
    const count = try file.readPositionalAll(std.testing.io, &output, 0);
    try std.testing.expectEqualStrings("\x1b[7;22H\x1b[4d\x1b[9G", output[0..count]);
}
