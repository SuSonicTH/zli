//! Terminal pager used by the REPL and the SQLite tool.
//!
//! Long output is printed line by line. When a page is full the pager shows a
//! prompt, switches the terminal to raw mode for a single key press and
//! continues when the user presses space, enter or page down.

const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");
const term = @import("term.zig");
const width = @import("term_width.zig");

const functions = [_]zlua.FnReg{
    .{ .name = "print", .func = luaerror.wrap(lua_print) },
};

pub fn register(lua: *Lua) i32 {
    lua.newLib(&functions);
    luax.registerExtended(lua, @embedFile("pager.lua"), "pager", "zli_pager");
    return 1;
}

fn lua_print(lua: *Lua) !i32 {
    const text = std.mem.sliceTo(lua.checkString(1), 0);
    const requested_height = if (lua.typeOf(2) == .number) lua.toInteger(2) catch 0 else 0;
    const prompt = if (lua.typeOf(3) == .string) std.mem.sliceTo(lua.toString(3) catch "more", 0) else "-- more --";

    if (!term.isTtyValue()) {
        const writer = term.writerPtr();
        writer.writeAll(text) catch |err|
            return luaerror.ret(lua, "could not write the output: {s}", .{@errorName(err)});
        if (text.len == 0 or text[text.len - 1] != '\n') writer.writeByte('\n') catch {};
        term.flushOutput() catch {};
        lua.pushBoolean(true);
        return 1;
    }

    const complete = printPaged(text, requested_height, prompt) catch |err|
        return luaerror.ret(lua, "could not page the output: {s}", .{@errorName(err)});

    lua.pushBoolean(complete);
    return 1;
}

const View = struct {
    width: usize,
    height: usize,
    requested_height: i64,
};

fn printPaged(text: []const u8, requested_height: i64, prompt: []const u8) !bool {
    var view = currentView(requested_height);
    var used: usize = 0;
    var iterator = std.mem.splitScalar(u8, text, '\n');

    if (text.len == 0) {
        try term.writerPtr().writeByte('\n');
        try term.flushOutput();
        return true;
    }

    while (iterator.next()) |line| {
        // A trailing newline produces a final empty segment; do not turn it
        // into an extra blank line.
        if (line.len == 0 and iterator.peek() == null) break;

        const rows = @max(@as(usize, 1), width.displayRows(line, view.width));
        if (used > 0 and used + rows > view.height) {
            if (!try waitForPage(&view, prompt)) {
                try term.writerPtr().writeByte('\n');
                try term.flushOutput();
                return false;
            }
            used = 0;
        }

        const writer = term.writerPtr();
        try writer.writeAll(line);
        try writer.writeByte('\n');
        try term.flushOutput();
        used += rows;
    }

    return true;
}

fn currentView(requested_height: i64) View {
    var rows: usize = 24;
    var columns: usize = 80;
    if (term.terminalPtr().windowSize()) |size| {
        if (size.rows != 0 and size.columns != 0) {
            rows = size.rows;
            columns = size.columns;
        }
    } else |_| {}

    const height: usize = if (requested_height > 0)
        @intCast(@min(requested_height, std.math.maxInt(u32)))
    else
        @max(@as(usize, 1), rows -| 1);

    return .{ .width = @max(@as(usize, 1), columns), .height = height, .requested_height = requested_height };
}

fn waitForPage(view: *View, prompt: []const u8) !bool {
    const terminal = term.terminalPtr();
    const writer = term.writerPtr();

    try writer.writeAll(prompt);
    try term.flushOutput();

    const raw_was_active = term.isRawActive();
    if (!raw_was_active) try term.enableRawMode();
    defer if (!raw_was_active) term.disableRawMode();

    var advance = false;
    while (true) {
        const event = term.inputPtr().read() catch |err| switch (err) {
            error.EndOfInput => return false,
            error.InvalidEventFound => continue,
            else => return err,
        };

        switch (event) {
            .Key => |key| {
                if (key.kind == .Release) continue;
                switch (key.code) {
                    .Char => |cp| {
                        // Windows delivers Ctrl+C as the raw ETX byte.
                        if (cp == 3) return false;
                        if (key.modifier.Control and (cp == 'c' or cp == 'C')) return false;
                        if (cp == ' ') {
                            advance = true;
                        } else if (cp == 'q' or cp == 'Q') {
                            return false;
                        }
                    },
                    .Enter, .PageDown => advance = true,
                    .Esc => return false,
                    else => {},
                }
                if (advance) break;
            },
            .Resize => |size| {
                const rows = @max(@as(usize, 1), size.rows);
                view.width = @max(@as(usize, 1), size.columns);
                view.height = if (view.requested_height > 0)
                    @max(@as(usize, 1), @min(@as(usize, @intCast(@min(view.requested_height, std.math.maxInt(u32)))), rows -| 1))
                else
                    @max(@as(usize, 1), rows -| 1);
            },
            else => {},
        }
    }

    try writer.writeByte('\r');
    try terminal.clear(.CurrentRow);
    try term.flushOutput();
    return true;
}
