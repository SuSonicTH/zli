//! Low level terminal binding built on the bundled termy library.
//!
//! The module owns the single `Tty`/`Input` pair used by the interpreter. The
//! `readline` and `pager` modules reach into the same state through the
//! internal accessors at the bottom of this file.

const std = @import("std");
const builtin = @import("builtin");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");
const termy = @import("termy");
const width = @import("term_width.zig");

const allocator = std.heap.c_allocator;

var io: std.Io = undefined;
var io_ready = false;

var out_buffer: [8192]u8 = undefined;
var tty_value: termy.Tty = undefined;
var terminal_value: termy.Terminal = undefined;
var cursor_value: termy.Cursor = undefined;
var style_value: termy.Style = undefined;
var input_value: termy.Input = undefined;
var ready = false;
var raw_active = false;
var paste_active = false;
var enhancements_mask: ?u8 = null;
var mouse_active = false;
var focus_active = false;

pub fn setIo(value: std.Io) void {
    io = value;
    io_ready = true;
}

fn ensure() void {
    if (ready) return;
    std.debug.assert(io_ready);
    tty_value = termy.Tty.init(io, std.Io.File.stdout(), &out_buffer, std.Io.File.stdin());
    terminal_value = .init(&tty_value);
    cursor_value = .init(&tty_value);
    style_value = .init(&tty_value);
    input_value = .init(&tty_value);
    ready = true;
}

pub fn ioValue() std.Io {
    return io;
}

pub fn ttyPtr() *termy.Tty {
    ensure();
    return &tty_value;
}

pub fn terminalPtr() *termy.Terminal {
    ensure();
    return &terminal_value;
}

pub fn cursorPtr() *termy.Cursor {
    ensure();
    return &cursor_value;
}

pub fn stylePtr() *termy.Style {
    ensure();
    return &style_value;
}

pub fn inputPtr() *termy.Input {
    ensure();
    return &input_value;
}

pub fn writerPtr() *std.Io.Writer {
    ensure();
    return tty_value.writer();
}

pub fn flushOutput() !void {
    try writerPtr().flush();
}

pub fn enableRawMode() !void {
    if (raw_active) return;
    try terminalPtr().enableRawMode();
    raw_active = true;
}

pub fn disableRawMode() void {
    if (!raw_active) return;
    terminalPtr().disableRawMode() catch {};
    raw_active = false;
}

pub fn isRawActive() bool {
    return raw_active;
}

pub fn enableBracketedPaste() !void {
    if (paste_active) return;
    try terminalPtr().enableBracketedPaste();
    paste_active = true;
}

pub fn disableBracketedPaste() void {
    if (!paste_active) return;
    terminalPtr().disableBracketedPaste() catch {};
    paste_active = false;
}

pub fn bracketedPasteActive() bool {
    return paste_active;
}

pub fn enableEnhancements(mask: u8) !void {
    if (enhancements_mask == mask) return;
    try terminalPtr().enableEnhancements(mask);
    enhancements_mask = mask;
}

pub fn disableEnhancements() void {
    if (enhancements_mask == null) return;
    terminalPtr().disableEnhancements() catch {};
    enhancements_mask = null;
}

pub fn enhancementsMask() ?u8 {
    return enhancements_mask;
}

pub fn enableMouseCapture() !void {
    if (mouse_active) return;
    try terminalPtr().enableMouseCapture();
    mouse_active = true;
}

pub fn disableMouseCapture() void {
    if (!mouse_active) return;
    terminalPtr().disablesMouseCapture() catch {};
    mouse_active = false;
}

pub fn enableFocusEvents() !void {
    if (focus_active) return;
    try terminalPtr().enableFocusChange();
    focus_active = true;
}

pub fn disableFocusEvents() void {
    if (!focus_active) return;
    terminalPtr().disablesFocusChange() catch {};
    focus_active = false;
}

pub fn isTtyValue() bool {
    if (!io_ready) return false;
    const stdin_tty = std.Io.File.stdin().isTty(io) catch false;
    const stdout_tty = std.Io.File.stdout().isTty(io) catch false;
    if (!stdin_tty or !stdout_tty) return false;

    if (std.c.getenv("TERM")) |term| {
        if (std.ascii.eqlIgnoreCase(std.mem.span(term), "dumb")) return false;
    }
    return true;
}

const functions = [_]zlua.FnReg{
    .{ .name = "is_tty", .func = zlua.wrap(lua_is_tty) },
    .{ .name = "size", .func = zlua.wrap(lua_size) },
    .{ .name = "width", .func = zlua.wrap(lua_width) },
    .{ .name = "truncate", .func = zlua.wrap(lua_truncate) },
    .{ .name = "wrap", .func = zlua.wrap(lua_wrap) },
    .{ .name = "clear", .func = zlua.wrap(lua_clear) },
    .{ .name = "write", .func = zlua.wrap(lua_write) },
    .{ .name = "flush", .func = zlua.wrap(lua_flush) },
    .{ .name = "move_to", .func = zlua.wrap(lua_move_to) },
    .{ .name = "move_by", .func = zlua.wrap(lua_move_by) },
    .{ .name = "move_to_column", .func = zlua.wrap(lua_move_to_column) },
    .{ .name = "move_to_row", .func = zlua.wrap(lua_move_to_row) },
    .{ .name = "save_cursor", .func = zlua.wrap(lua_save_cursor) },
    .{ .name = "restore_cursor", .func = zlua.wrap(lua_restore_cursor) },
    .{ .name = "hide_cursor", .func = zlua.wrap(lua_hide_cursor) },
    .{ .name = "show_cursor", .func = zlua.wrap(lua_show_cursor) },
    .{ .name = "cursor_shape", .func = zlua.wrap(lua_cursor_shape) },
    .{ .name = "style", .func = zlua.wrap(lua_style) },
    .{ .name = "reset_style", .func = zlua.wrap(lua_reset_style) },
    .{ .name = "raw", .func = zlua.wrap(lua_raw) },
    .{ .name = "alternate_screen", .func = zlua.wrap(lua_alternate_screen) },
    .{ .name = "mouse_capture", .func = zlua.wrap(lua_mouse_capture) },
    .{ .name = "focus_events", .func = zlua.wrap(lua_focus_events) },
    .{ .name = "keyboard_enhancements", .func = zlua.wrap(lua_keyboard_enhancements) },
    .{ .name = "bracketed_paste", .func = zlua.wrap(lua_bracketed_paste) },
    .{ .name = "title", .func = zlua.wrap(lua_title) },
    .{ .name = "line_wrap", .func = zlua.wrap(lua_line_wrap) },
    .{ .name = "poll", .func = zlua.wrap(lua_poll) },
    .{ .name = "read_event", .func = zlua.wrap(lua_read_event) },
    .{ .name = "query_cursor", .func = zlua.wrap(lua_query_cursor) },
    .{ .name = "restore", .func = zlua.wrap(lua_restore) },
};

pub fn register(lua: *Lua) i32 {
    lua.newLib(&functions);
    luax.registerExtended(lua, @embedFile("term.lua"), "term", "zli_term");
    return 1;
}

fn lua_is_tty(lua: *Lua) i32 {
    lua.pushBoolean(isTtyValue());
    return 1;
}

fn lua_size(lua: *Lua) i32 {
    const size = terminalPtr().windowSize() catch |err|
        return luaerror.ret(lua, "could not read the terminal size: {s}", .{@errorName(err)});
    if (size.columns == 0 or size.rows == 0) {
        return luaerror.ret(lua, "the terminal does not report a usable size", .{});
    }

    lua.newTable();
    _ = lua.pushString("columns");
    lua.pushInteger(size.columns);
    lua.setTable(-3);
    _ = lua.pushString("rows");
    lua.pushInteger(size.rows);
    lua.setTable(-3);
    return 1;
}

fn lua_width(lua: *Lua) i32 {
    const text = lua.checkString(1);
    lua.pushInteger(@intCast(width.visibleWidth(std.mem.sliceTo(text, 0))));
    return 1;
}

fn columnArgument(lua: *Lua, index: i32) usize {
    const value = lua.checkInteger(index);
    if (value < 0 or value > std.math.maxInt(i32)) lua.argError(index, "expecting a column count between 0 and 2147483647");
    return @intCast(value);
}

fn lua_truncate(lua: *Lua) i32 {
    const text = std.mem.sliceTo(lua.checkString(1), 0);
    const columns = columnArgument(lua, 2);
    const ellipsis = std.mem.sliceTo(lua.optString(3) orelse "...", 0);

    const result = width.truncate(text, columns, ellipsis, allocator) catch |err|
        return luaerror.ret(lua, "could not truncate the text: {s}", .{@errorName(err)});
    defer allocator.free(result);
    _ = lua.pushString(result);
    return 1;
}

fn lua_wrap(lua: *Lua) i32 {
    const text = std.mem.sliceTo(lua.checkString(1), 0);
    const columns = columnArgument(lua, 2);
    if (columns == 0) lua.argError(2, "expecting a positive column count");

    const result = width.wrap(text, columns, allocator) catch |err|
        return luaerror.ret(lua, "could not wrap the text: {s}", .{@errorName(err)});
    defer allocator.free(result);
    _ = lua.pushString(result);
    return 1;
}

fn clearType(name: []const u8) ?termy.Terminal.ClearType {
    if (std.mem.eql(u8, name, "all") or std.mem.eql(u8, name, "screen")) return .All;
    if (std.mem.eql(u8, name, "history") or std.mem.eql(u8, name, "purge")) return .Purge;
    if (std.mem.eql(u8, name, "down")) return .FromCursorDown;
    if (std.mem.eql(u8, name, "up")) return .FromCursorUp;
    if (std.mem.eql(u8, name, "line")) return .CurrentRow;
    if (std.mem.eql(u8, name, "to_end")) return .UntilRowEnd;
    return null;
}

fn lua_clear(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    const name = std.mem.sliceTo(lua.optString(1) orelse "all", 0);
    const kind = clearType(name) orelse lua.argError(1, "expecting one of all, history, down, up, line or to_end");
    terminalPtr().clear(kind) catch |err|
        return luaerror.ret(lua, "could not clear the terminal: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_write(lua: *Lua) i32 {
    const text = lua.checkString(1);
    writerPtr().writeAll(text) catch |err|
        return luaerror.ret(lua, "could not write to the terminal: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_flush(lua: *Lua) i32 {
    flushOutput() catch |err|
        return luaerror.ret(lua, "could not flush the terminal: {s}", .{@errorName(err)});
    return 0;
}

fn coordinate(lua: *Lua, index: i32) u16 {
    const value = lua.checkInteger(index);
    if (value < 1 or value > std.math.maxInt(u16)) lua.argError(index, "expecting a coordinate between 1 and 65535");
    return @intCast(value);
}

fn lua_move_to(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    const column = coordinate(lua, 1);
    const row = coordinate(lua, 2);
    cursorPtr().moveTo(column, row) catch |err|
        return luaerror.ret(lua, "could not move the cursor: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_move_by(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    const limit: i64 = std.math.maxInt(u16);
    const dx = std.math.clamp(lua.checkInteger(1), -limit, limit);
    const dy = std.math.clamp(lua.checkInteger(2), -limit, limit);
    if (dx < 0) {
        cursorPtr().moveLeft(@intCast(@min(-dx, std.math.maxInt(u16)))) catch |err|
            return luaerror.ret(lua, "could not move the cursor: {s}", .{@errorName(err)});
    } else if (dx > 0) {
        cursorPtr().moveRight(@intCast(@min(dx, std.math.maxInt(u16)))) catch |err|
            return luaerror.ret(lua, "could not move the cursor: {s}", .{@errorName(err)});
    }
    if (dy < 0) {
        cursorPtr().moveUp(@intCast(@min(-dy, std.math.maxInt(u16)))) catch |err|
            return luaerror.ret(lua, "could not move the cursor: {s}", .{@errorName(err)});
    } else if (dy > 0) {
        cursorPtr().moveDown(@intCast(@min(dy, std.math.maxInt(u16)))) catch |err|
            return luaerror.ret(lua, "could not move the cursor: {s}", .{@errorName(err)});
    }
    flushOutput() catch {};
    return 0;
}

fn lua_move_to_column(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    cursorPtr().moveToColumn(coordinate(lua, 1)) catch |err|
        return luaerror.ret(lua, "could not move the cursor: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_move_to_row(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    cursorPtr().moveToRow(coordinate(lua, 1)) catch |err|
        return luaerror.ret(lua, "could not move the cursor: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_save_cursor(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    cursorPtr().savePosition() catch |err|
        return luaerror.ret(lua, "could not save the cursor: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_restore_cursor(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    cursorPtr().restorePosition() catch |err|
        return luaerror.ret(lua, "could not restore the cursor: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_hide_cursor(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    cursorPtr().hide() catch |err|
        return luaerror.ret(lua, "could not hide the cursor: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_show_cursor(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    cursorPtr().show() catch |err|
        return luaerror.ret(lua, "could not show the cursor: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_cursor_shape(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    const name = std.mem.sliceTo(lua.checkString(1), 0);
    const shape: termy.Cursor.CursorStyle = if (std.mem.eql(u8, name, "default"))
        .DefaultUserShape
    else if (std.mem.eql(u8, name, "block"))
        .SteadyBlock
    else if (std.mem.eql(u8, name, "blinking_block"))
        .BlinkingBlock
    else if (std.mem.eql(u8, name, "underline"))
        .SteadyUnderScore
    else if (std.mem.eql(u8, name, "blinking_underline"))
        .BlinkingUnderScore
    else if (std.mem.eql(u8, name, "bar"))
        .SteadyBar
    else if (std.mem.eql(u8, name, "blinking_bar"))
        .BlinkingBar
    else
        lua.argError(1, "unknown cursor shape");

    cursorPtr().setCursorStyle(shape) catch |err|
        return luaerror.ret(lua, "could not set the cursor shape: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn colorFromName(name: []const u8) ?termy.Style.Color {
    inline for (.{
        .{ "default", termy.Style.Color.Reset },
        .{ "reset", termy.Style.Color.Reset },
        .{ "black", termy.Style.Color.Black },
        .{ "bright_black", termy.Style.Color.BrightBlack },
        .{ "red", termy.Style.Color.Red },
        .{ "bright_red", termy.Style.Color.BrightRed },
        .{ "green", termy.Style.Color.Green },
        .{ "bright_green", termy.Style.Color.BrightGreen },
        .{ "yellow", termy.Style.Color.Yellow },
        .{ "bright_yellow", termy.Style.Color.BrightYellow },
        .{ "blue", termy.Style.Color.Blue },
        .{ "bright_blue", termy.Style.Color.BrightBlue },
        .{ "magenta", termy.Style.Color.Magenta },
        .{ "bright_magenta", termy.Style.Color.BrightMagenta },
        .{ "cyan", termy.Style.Color.Cyan },
        .{ "bright_cyan", termy.Style.Color.BrightCyan },
        .{ "white", termy.Style.Color.White },
        .{ "bright_white", termy.Style.Color.BrightWhite },
    }) |item| {
        if (std.mem.eql(u8, name, item[0])) return item[1];
    }
    return null;
}

fn colorAt(lua: *Lua, index: i32) termy.Style.Color {
    switch (lua.typeOf(index)) {
        .string => {
            const name = std.mem.sliceTo(lua.toString(index) catch unreachable, 0);
            return colorFromName(name) orelse lua.argError(index, "unknown colour name");
        },
        .number => {
            const value = lua.toInteger(index) catch lua.argError(index, "expecting a colour number between 0 and 255");
            if (value < 0 or value > 255) lua.argError(index, "expecting a colour number between 0 and 255");
            return .{ .AnsiValue = @intCast(value) };
        },
        .table => {
            const r = tableInteger(lua, index, "r") orelse lua.argError(index, "expecting {r=, g=, b=}");
            const g = tableInteger(lua, index, "g") orelse lua.argError(index, "expecting {r=, g=, b=}");
            const b = tableInteger(lua, index, "b") orelse lua.argError(index, "expecting {r=, g=, b=}");
            return .{ .Rgb = .{ .r = @intCast(std.math.clamp(r, 0, 255)), .g = @intCast(std.math.clamp(g, 0, 255)), .b = @intCast(std.math.clamp(b, 0, 255)) } };
        },
        else => lua.argError(index, "expecting a colour name, an ANSI number or {r=, g=, b=}"),
    }
}

fn tableInteger(lua: *Lua, index: i32, key: [:0]const u8) ?i64 {
    if (lua.getField(index, key) == .nil) {
        lua.pop(1);
        return null;
    }
    const value = lua.toInteger(-1) catch {
        lua.pop(1);
        return null;
    };
    lua.pop(1);
    return value;
}

fn tableBoolean(lua: *Lua, index: i32, key: [:0]const u8) ?bool {
    if (lua.getField(index, key) == .nil) {
        lua.pop(1);
        return null;
    }
    const value = lua.toBoolean(-1);
    lua.pop(1);
    return value;
}

fn setAttribute(attribute: termy.Style.Attribute) !void {
    try stylePtr().setAttribute(attribute);
}

fn lua_style(lua: *Lua) i32 {
    if (lua.typeOf(1) != .table) lua.argError(1, "expecting a table");
    if (!isTtyValue()) return 0;

    if (lua.getField(1, "fg") != .nil) {
        stylePtr().setForegroundColor(colorAt(lua, -1)) catch |err|
            return luaerror.ret(lua, "could not set the foreground colour: {s}", .{@errorName(err)});
        lua.pop(1);
    }
    if (lua.getField(1, "bg") != .nil) {
        stylePtr().setBackgroundColor(colorAt(lua, -1)) catch |err|
            return luaerror.ret(lua, "could not set the background colour: {s}", .{@errorName(err)});
        lua.pop(1);
    }
    if (lua.getField(1, "underline_color") != .nil) {
        stylePtr().setUnderlineColor(colorAt(lua, -1)) catch |err|
            return luaerror.ret(lua, "could not set the underline colour: {s}", .{@errorName(err)});
        lua.pop(1);
    }

    inline for (.{
        .{ "bold", termy.Style.Attribute.Bold, termy.Style.Attribute.NormalIntensity },
        .{ "dim", termy.Style.Attribute.Dim, termy.Style.Attribute.NormalIntensity },
        .{ "italic", termy.Style.Attribute.Italic, termy.Style.Attribute.NoItalic },
        .{ "underline", termy.Style.Attribute.Underlined, termy.Style.Attribute.NoUnderline },
        .{ "reverse", termy.Style.Attribute.Reverse, termy.Style.Attribute.NoReverse },
        .{ "blink", termy.Style.Attribute.SlowBlink, termy.Style.Attribute.NoBlink },
        .{ "strikethrough", termy.Style.Attribute.CrossedOut, termy.Style.Attribute.NotCrossedOut },
    }) |item| {
        if (tableBoolean(lua, 1, item[0])) |enabled| {
            setAttribute(if (enabled) item[1] else item[2]) catch |err|
                return luaerror.ret(lua, "could not set a text attribute: {s}", .{@errorName(err)});
        }
    }

    flushOutput() catch {};
    return 0;
}

fn lua_reset_style(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    resetStyleQuiet();
    flushOutput() catch {};
    _ = lua;
    return 0;
}

fn lua_raw(lua: *Lua) i32 {
    const enable = lua.toBoolean(1);
    if (enable) {
        enableRawMode() catch |err|
            return luaerror.ret(lua, "could not enable raw mode: {s}", .{@errorName(err)});
    } else {
        disableRawMode();
    }
    flushOutput() catch {};
    return 0;
}

fn lua_alternate_screen(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    if (lua.toBoolean(1)) {
        terminalPtr().enterAlternateScreen() catch |err|
            return luaerror.ret(lua, "could not enter the alternate screen: {s}", .{@errorName(err)});
    } else {
        terminalPtr().leaveAlternateScreen() catch |err|
            return luaerror.ret(lua, "could not leave the alternate screen: {s}", .{@errorName(err)});
    }
    flushOutput() catch {};
    return 0;
}

fn lua_mouse_capture(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    if (lua.toBoolean(1)) {
        enableMouseCapture() catch |err|
            return luaerror.ret(lua, "could not enable mouse capture: {s}", .{@errorName(err)});
    } else {
        disableMouseCapture();
    }
    flushOutput() catch {};
    return 0;
}

fn lua_focus_events(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    if (lua.toBoolean(1)) {
        enableFocusEvents() catch |err|
            return luaerror.ret(lua, "could not enable focus events: {s}", .{@errorName(err)});
    } else {
        disableFocusEvents();
    }
    flushOutput() catch {};
    return 0;
}

fn lua_keyboard_enhancements(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    if (lua.typeOf(1) == .nil or lua.toBoolean(1)) {
        const mask = if (lua.typeOf(2) == .number) @as(u8, @intCast(std.math.clamp(lua.toInteger(2) catch 1, 0, 255))) else termy.Terminal.Enhancements.DISAMBIGUATE_ESCAPE_CODES;
        enableEnhancements(mask) catch |err|
            return luaerror.ret(lua, "could not enable keyboard enhancements: {s}", .{@errorName(err)});
    } else {
        disableEnhancements();
    }
    flushOutput() catch {};
    return 0;
}

fn lua_bracketed_paste(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    if (lua.toBoolean(1)) {
        enableBracketedPaste() catch |err|
            return luaerror.ret(lua, "could not enable bracketed paste: {s}", .{@errorName(err)});
    } else {
        disableBracketedPaste();
    }
    flushOutput() catch {};
    return 0;
}

fn lua_title(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    const title = std.mem.sliceTo(lua.checkString(1), 0);
    terminalPtr().setTitle(title) catch |err|
        return luaerror.ret(lua, "could not set the title: {s}", .{@errorName(err)});
    flushOutput() catch {};
    return 0;
}

fn lua_line_wrap(lua: *Lua) i32 {
    if (!isTtyValue()) return 0;
    if (lua.toBoolean(1)) {
        terminalPtr().enableLineWrap() catch |err|
            return luaerror.ret(lua, "could not enable line wrap: {s}", .{@errorName(err)});
    } else {
        terminalPtr().disableLineWrap() catch |err|
            return luaerror.ret(lua, "could not disable line wrap: {s}", .{@errorName(err)});
    }
    flushOutput() catch {};
    return 0;
}

fn lua_poll(lua: *Lua) i32 {
    if (hasBufferedInput(inputPtr())) {
        lua.pushBoolean(true);
        return 1;
    }
    const milliseconds = lua.optInteger(1) orelse 0;
    const ready_now = inputPtr().poll(.fromMilliseconds(@intCast(std.math.clamp(milliseconds, -1, std.math.maxInt(i32))))) catch |err|
        return luaerror.ret(lua, "could not poll the terminal: {s}", .{@errorName(err)});
    lua.pushBoolean(ready_now);
    return 1;
}

const PollResult = enum { ready, timeout, closed };

fn hasBufferedInput(input: *termy.Input) bool {
    return input.start < input.len or input.paste_active;
}

fn pollInput(timeout_ms: i32) !PollResult {
    if (builtin.os.tag == .windows) {
        const ready_now = try inputPtr().poll(.fromMilliseconds(timeout_ms));
        return if (ready_now) .ready else .timeout;
    }

    var fds = [_]std.posix.pollfd{.{
        .fd = std.Io.File.stdin().handle,
        .events = std.posix.POLL.IN,
        .revents = 0,
    }};
    const count = try std.posix.poll(&fds, timeout_ms);
    if (count == 0) return .timeout;
    const hangup = std.posix.POLL.HUP | std.posix.POLL.ERR | std.posix.POLL.NVAL;
    if ((fds[0].revents & hangup) != 0) return .closed;
    return .ready;
}

fn lua_read_event(lua: *Lua) i32 {
    const input = inputPtr();
    if (lua.typeOf(1) == .number) {
        const milliseconds = lua.checkInteger(1);
        if (milliseconds >= 0 and !hasBufferedInput(input)) {
            const result = pollInput(@intCast(std.math.clamp(milliseconds, 0, std.math.maxInt(i32)))) catch |err|
                return luaerror.ret(lua, "could not poll the terminal: {s}", .{@errorName(err)});
            switch (result) {
                .timeout => {
                    lua.pushNil();
                    _ = lua.pushString("timeout");
                    return 2;
                },
                .closed => {
                    lua.pushNil();
                    _ = lua.pushString("eof");
                    return 2;
                },
                .ready => {},
            }
        }
    }

    const event = input.read() catch |err| switch (err) {
        error.EndOfInput => {
            lua.pushNil();
            _ = lua.pushString("eof");
            return 2;
        },
        error.InvalidEventFound => {
            lua.pushNil();
            _ = lua.pushString("invalid");
            return 2;
        },
        else => return luaerror.ret(lua, "could not read a terminal event: {s}", .{@errorName(err)}),
    };

    pushEvent(lua, event);
    return 1;
}

fn lua_query_cursor(lua: *Lua) i32 {
    if (!isTtyValue()) {
        lua.pushNil();
        _ = lua.pushString("not a terminal");
        return 2;
    }
    const milliseconds = lua.optInteger(1) orelse 100;
    var queued: std.ArrayList(termy.event.Event) = .empty;
    defer queued.deinit(allocator);

    const position = inputPtr().queryCursorPosition(.fromMilliseconds(@intCast(milliseconds)), .{ .allocator = allocator, .list = &queued }) catch |err|
        return luaerror.ret(lua, "could not query the cursor position: {s}", .{@errorName(err)});

    if (position) |pos| {
        lua.newTable();
        _ = lua.pushString("x");
        lua.pushInteger(pos.x);
        lua.setTable(-3);
        _ = lua.pushString("y");
        lua.pushInteger(pos.y);
        lua.setTable(-3);
        return 1;
    }

    lua.pushNil();
    _ = lua.pushString("timeout");
    return 2;
}

fn lua_restore(lua: *Lua) i32 {
    _ = lua;
    disableRawMode();
    if (!isTtyValue()) return 0;
    cursorPtr().show() catch {};
    disableEnhancements();
    disableBracketedPaste();
    disableFocusEvents();
    disableMouseCapture();
    disableRawMode();
    resetStyleQuiet();
    flushOutput() catch {};
    return 0;
}

pub fn resetStyleQuiet() void {
    const style = stylePtr();
    style.setForegroundColor(.Reset) catch {};
    style.setBackgroundColor(.Reset) catch {};
    style.setUnderlineColor(.Reset) catch {};
    style.setAttribute(.NormalIntensity) catch {};
    style.setAttribute(.NoItalic) catch {};
    style.setAttribute(.NoUnderline) catch {};
    style.setAttribute(.NoBlink) catch {};
    style.setAttribute(.NoReverse) catch {};
    style.setAttribute(.NotCrossedOut) catch {};
}

fn pushEvent(lua: *Lua, event: termy.event.Event) void {
    lua.newTable();
    switch (event) {
        .Key => |key| {
            setString(lua, "type", "key");
            pushKey(lua, key);
        },
        .Mouse => |mouse| {
            setString(lua, "type", "mouse");
            setString(lua, "action", mouseAction(mouse.kind));
            switch (mouse.kind) {
                .Down => |button| setString(lua, "button", mouseButton(button)),
                .Up => |button| setString(lua, "button", mouseButton(button)),
                .Drag => |button| setString(lua, "button", mouseButton(button)),
                else => {},
            }
            setInteger(lua, "column", mouse.column);
            setInteger(lua, "row", mouse.row);
            pushModifiers(lua, mouse.modifier);
        },
        .Resize => |size| {
            setString(lua, "type", "resize");
            setInteger(lua, "columns", size.columns);
            setInteger(lua, "rows", size.rows);
        },
        .FocusGained => {
            setString(lua, "type", "focus");
            setBoolean(lua, "gained", true);
        },
        .FocusLost => {
            setString(lua, "type", "focus");
            setBoolean(lua, "gained", false);
        },
        .Paste => |text| {
            setString(lua, "type", "paste");
            setString(lua, "text", text);
        },
    }
}

fn pushKey(lua: *Lua, key: termy.event.KeyEvent) void {
    switch (key.code) {
        .Char => |cp| {
            setString(lua, "code", "char");
            var encoded: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(cp, &encoded) catch 0;
            setString(lua, "char", encoded[0..len]);
        },
        .F => |number| {
            var buffer: [8]u8 = undefined;
            const name = std.fmt.bufPrint(&buffer, "f{d}", .{number}) catch "f";
            setString(lua, "code", name);
        },
        else => setString(lua, "code", keyCodeName(key.code)),
    }

    pushModifiers(lua, key.modifier);
    setString(lua, "kind", switch (key.kind) {
        .Press => "press",
        .Release => "release",
        .Repeat => "repeat",
    });
    switch (key.kind) {
        .Repeat => |count| setInteger(lua, "repeat", count),
        else => {},
    }
    setBoolean(lua, "caps_lock", key.state.CapsLock);
    setBoolean(lua, "num_lock", key.state.NumLock);
    setBoolean(lua, "keypad", key.state.KeyPad);
}

fn pushModifiers(lua: *Lua, modifiers: termy.event.KeyModifiers) void {
    setBoolean(lua, "shift", modifiers.Shift);
    setBoolean(lua, "control", modifiers.Control);
    setBoolean(lua, "alt", modifiers.Alt);
    setBoolean(lua, "super", modifiers.Super);
    setBoolean(lua, "hyper", modifiers.Hyper);
    setBoolean(lua, "meta", modifiers.Meta);
}

fn keyCodeName(code: termy.event.KeyCode) []const u8 {
    return switch (code) {
        .Backspace => "backspace",
        .Enter => "enter",
        .Left => "left",
        .Right => "right",
        .Up => "up",
        .Down => "down",
        .Home => "home",
        .End => "end",
        .PageUp => "page_up",
        .PageDown => "page_down",
        .Tab => "tab",
        .Delete => "delete",
        .Insert => "insert",
        .Char => "char",
        .F => "f",
        .Null => "null",
        .Esc => "esc",
        .CapsLock => "caps_lock",
        .ScrollLock => "scroll_lock",
        .NumLock => "num_lock",
        .PrintScreen => "print_screen",
        .Pause => "pause",
        .Menu => "menu",
        .KeypadBegin => "keypad_begin",
        .MediaPlay => "media_play",
        .MediaPause => "media_pause",
        .MediaPlayPause => "media_play_pause",
        .MediaReverse => "media_reverse",
        .MediaStop => "media_stop",
        .MediaFastForward => "media_fast_forward",
        .MediaRewind => "media_rewind",
        .MediaTrackNext => "media_track_next",
        .MediaTrackPrevious => "media_track_previous",
        .MediaRecord => "media_record",
        .MediaLowerVolume => "media_lower_volume",
        .MediaRaiseVolume => "media_raise_volume",
        .MediaMuteVolume => "media_mute_volume",
        .KeyModifier => |modifier| switch (modifier) {
            .LeftShift => "left_shift",
            .LeftControl => "left_control",
            .LeftAlt => "left_alt",
            .LeftSuper => "left_super",
            .LeftHyper => "left_hyper",
            .LeftMeta => "left_meta",
            .RightShift => "right_shift",
            .RightControl => "right_control",
            .RightAlt => "right_alt",
            .RightSuper => "right_super",
            .RightHyper => "right_hyper",
            .RightMeta => "right_meta",
            .IsoLevel3Shift => "iso_level3_shift",
            .IsoLevel5Shift => "iso_level5_shift",
        },
    };
}

fn mouseAction(kind: termy.event.MouseEventKind) []const u8 {
    return switch (kind) {
        .Down => "down",
        .Up => "up",
        .Drag => "drag",
        .Moved => "moved",
        .ScrollDown => "scroll_down",
        .ScrollUp => "scroll_up",
        .ScrollLeft => "scroll_left",
        .ScrollRight => "scroll_right",
    };
}

fn mouseButton(button: termy.event.MouseButton) []const u8 {
    return switch (button) {
        .Left => "left",
        .Right => "right",
        .Middle => "middle",
        .Unknown => "unknown",
    };
}

fn setString(lua: *Lua, key: [:0]const u8, value: []const u8) void {
    _ = lua.pushString(key);
    _ = lua.pushString(value);
    lua.setTable(-3);
}

fn setInteger(lua: *Lua, key: [:0]const u8, value: anytype) void {
    _ = lua.pushString(key);
    lua.pushInteger(@intCast(value));
    lua.setTable(-3);
}

fn setBoolean(lua: *Lua, key: [:0]const u8, value: bool) void {
    _ = lua.pushString(key);
    lua.pushBoolean(value);
    lua.setTable(-3);
}
