//! Embeddable line editor used by the `prompt` library.
//!
//! The line editor normally paints directly to the terminal.  This module
//! implements its `Backend` over an in-memory row/segment grid and exposes a
//! small step API to Lua, so `prompt` can compose text fields into its own
//! frames without duplicating editing behaviour.

const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");
const lineedit = @import("lineedit.zig");
const termkey = @import("termkey.zig");
const termy = @import("termy");
const width = @import("term_width.zig");

const allocator = std.heap.c_allocator;
const mt_name = "prompt.editor";

const Style = enum(u8) {
    none,
    normal,
    multiline,

    fn name(self: Style) []const u8 {
        return switch (self) {
            .none => "none",
            .normal => "normal",
            .multiline => "multiline",
        };
    }
};

const Segment = struct {
    style: Style,
    text: std.ArrayList(u8) = .empty,
};

const Row = struct {
    segments: std.ArrayList(Segment) = .empty,
    columns: usize = 0,

    fn clear(self: *Row, alloc: std.mem.Allocator) void {
        for (self.segments.items) |*segment| segment.text.deinit(alloc);
        self.segments.clearRetainingCapacity();
        self.columns = 0;
    }

    fn deinit(self: *Row, alloc: std.mem.Allocator) void {
        self.clear(alloc);
        self.segments.deinit(alloc);
    }
};

const Grid = struct {
    alloc: std.mem.Allocator,
    columns: usize,
    height: usize,
    rows: std.ArrayList(Row) = .empty,
    cursor_row: usize = 0,
    cursor_column: usize = 0,
    style: Style = .none,
    mask: ?u21 = null,

    fn init(alloc: std.mem.Allocator, columns: usize, height: usize) !Grid {
        var grid = Grid{
            .alloc = alloc,
            .columns = @max(@as(usize, 1), columns),
            .height = @max(@as(usize, 1), height),
        };
        errdefer grid.deinit();
        try grid.fill();
        return grid;
    }

    fn deinit(self: *Grid) void {
        for (self.rows.items) |*row| row.deinit(self.alloc);
        self.rows.deinit(self.alloc);
    }

    fn fill(self: *Grid) !void {
        self.rows.clearRetainingCapacity();
        var index: usize = 0;
        while (index < self.height) : (index += 1) {
            try self.rows.append(self.alloc, .{});
        }
        self.cursor_row = 0;
        self.cursor_column = 0;
        self.style = .none;
    }

    fn resize(self: *Grid, columns: usize, height: usize) !void {
        const new_columns = @max(@as(usize, 1), columns);
        const new_height = @max(@as(usize, 1), height);
        if (new_columns == self.columns and new_height == self.height) return;
        for (self.rows.items) |*row| row.deinit(self.alloc);
        self.rows.clearRetainingCapacity();
        self.columns = new_columns;
        self.height = new_height;
        try self.fill();
    }

    fn rowAt(self: *Grid, index: usize) *Row {
        return &self.rows.items[index];
    }

    fn clearLine(self: *Grid) void {
        if (self.cursor_row >= self.rows.items.len) self.cursor_row = self.rows.items.len - 1;
        self.rowAt(self.cursor_row).clear(self.alloc);
        self.cursor_column = 0;
    }

    fn clearScreen(self: *Grid) void {
        for (self.rows.items) |*row| row.clear(self.alloc);
        self.cursor_row = 0;
        self.cursor_column = 0;
    }

    fn scrollUp(self: *Grid, rows: usize, count: usize) void {
        const height = @min(rows, self.height);
        const shift = @min(count, height);
        if (shift == 0) return;
        var index: usize = 0;
        while (index + shift < height) : (index += 1) {
            const moved = self.rows.items[index + shift];
            self.rows.items[index + shift] = .{};
            self.rows.items[index].deinit(self.alloc);
            self.rows.items[index] = moved;
        }
        while (index < height) : (index += 1) {
            self.rows.items[index].deinit(self.alloc);
            self.rows.items[index] = .{};
        }
    }

    fn write(self: *Grid, bytes: []const u8) !void {
        if (self.cursor_row >= self.rows.items.len) return;
        const row = self.rowAt(self.cursor_row);

        var segment: *Segment = undefined;
        if (row.segments.items.len != 0 and row.segments.items[row.segments.items.len - 1].style == self.style) {
            segment = &row.segments.items[row.segments.items.len - 1];
        } else {
            try row.segments.append(self.alloc, .{ .style = self.style });
            segment = &row.segments.items[row.segments.items.len - 1];
        }

        if (self.mask) |mask| {
            if (self.style == .none) {
                var index: usize = 0;
                var encoded: [4]u8 = undefined;
                const mask_len = std.unicode.utf8Encode(mask, &encoded) catch 1;
                while (index < bytes.len) {
                    const decoded = width.decode(bytes, index);
                    if (decoded.len == 0) break;
                    try segment.text.appendSlice(self.alloc, encoded[0..mask_len]);
                    row.columns += width.codepointWidth(mask);
                    index += decoded.len;
                }
                return;
            }
        }

        try segment.text.appendSlice(self.alloc, bytes);
        var index: usize = 0;
        while (index < bytes.len) {
            const skip = width.ansiSequenceLength(bytes, index);
            if (skip != 0) {
                index += skip;
                continue;
            }
            const decoded = width.decode(bytes, index);
            if (decoded.len == 0) break;
            row.columns += width.codepointWidth(decoded.codepoint);
            index += decoded.len;
        }
    }
};

const Binding = struct {
    grid: Grid = undefined,
    editor: lineedit.Editor = undefined,
    ready: bool = false,
};

const vtable = lineedit.Backend.VTable{
    .size = backendSize,
    .cursorPosition = backendCursor,
    .write = backendWrite,
    .moveTo = backendMoveTo,
    .clearLine = backendClearLine,
    .clearScreen = backendClearScreen,
    .hideCursor = backendNoop,
    .showCursor = backendNoop,
    .promptStyle = backendPromptStyle,
    .flush = backendNoop,
    .readEvent = backendReadEvent,
    .scrollUp = backendScrollUp,
};

fn gridFrom(ctx: *anyopaque) *Grid {
    return @ptrCast(@alignCast(ctx));
}

fn backendSize(ctx: *anyopaque) lineedit.Size {
    const grid = gridFrom(ctx);
    return .{ .rows = grid.height, .columns = grid.columns };
}

fn backendCursor(ctx: *anyopaque) anyerror!lineedit.Cursor {
    const grid = gridFrom(ctx);
    return .{ .row = @min(grid.cursor_row, grid.height - 1), .column = grid.cursor_column };
}

fn backendWrite(ctx: *anyopaque, bytes: []const u8) anyerror!void {
    try gridFrom(ctx).write(bytes);
}

fn backendMoveTo(ctx: *anyopaque, row: usize, column: usize) anyerror!void {
    const grid = gridFrom(ctx);
    grid.cursor_row = @min(row, grid.height - 1);
    grid.cursor_column = column;
}

fn backendClearLine(ctx: *anyopaque) anyerror!void {
    gridFrom(ctx).clearLine();
}

fn backendClearScreen(ctx: *anyopaque) anyerror!void {
    gridFrom(ctx).clearScreen();
}

fn backendNoop(_: *anyopaque) anyerror!void {}

fn backendPromptStyle(ctx: *anyopaque, style: lineedit.PromptStyle) anyerror!void {
    const grid = gridFrom(ctx);
    grid.style = switch (style) {
        .none => .none,
        .normal => .normal,
        .multiline => .multiline,
    };
}

fn backendReadEvent(_: *anyopaque) anyerror!?lineedit.Event {
    return null;
}

fn backendScrollUp(ctx: *anyopaque, rows: usize, count: usize) anyerror!void {
    gridFrom(ctx).scrollUp(rows, count);
}

fn getBinding(lua: *Lua) *Binding {
    return lua.toUserdata(Binding, 1) catch lua.raiseErrorStr("expected a prompt editor", .{});
}

fn luaGc(lua: *Lua) i32 {
    const binding = getBinding(lua);
    if (binding.ready) binding.editor.deinit();
    binding.grid.deinit();
    binding.ready = false;
    return 0;
}

fn luaNew(lua: *Lua) !i32 {
    const columns: usize = @intCast(@max(lua.checkInteger(1), 1));
    const height: usize = @intCast(@max(lua.checkInteger(2), 1));
    const options_index: i32 = if (lua.typeOf(3) == .table) 3 else 0;

    const binding = luax.createUserData(lua, mt_name, Binding);
    binding.ready = false;
    binding.grid = .{ .alloc = allocator, .columns = 1, .height = 1 };
    binding.grid = Grid.init(allocator, columns, height) catch |err|
        return luaerror.ret(lua, "could not create the editor grid: {s}", .{@errorName(err)});

    var options = lineedit.Options{
        .prompt = "",
        .continuation = "",
        .submit_on_enter = true,
        .single_line = true,
    };

    if (options_index != 0) {
        if (luax.getTableStringOptional(lua, "initial", options_index)) |initial| {
            options.initial = initial;
        }
        options.submit_on_enter = luax.getOptionBool(lua, "submit_on_enter", options_index, true);
        options.alt_enter_newline = luax.getOptionBool(lua, "alt_enter_newline", options_index, false);
        options.single_line = luax.getOptionBool(lua, "single_line", options_index, true);
        const max_length = luax.getOptionInteger(lua, "max_length", options_index, 0);
        if (max_length > 0) options.max_length = @intCast(max_length);
        if (luax.getTableStringOptional(lua, "mask", options_index)) |mask| {
            if (mask.len != 0) {
                const decoded = width.decode(mask, 0);
                if (decoded.len != 0 and decoded.codepoint != 0xfffd) options.mask = decoded.codepoint;
            }
        }
    }

    binding.grid.mask = options.mask;
    binding.editor = lineedit.Editor.init(allocator, .{ .ctx = &binding.grid, .vtable = &vtable }, options);
    binding.ready = true;
    binding.editor.begin(.{ .rows = height, .columns = columns }) catch |err|
        return luaerror.ret(lua, "could not start the editor: {s}", .{@errorName(err)});
    return 1;
}

fn keyCode(lua: *Lua, code: []const u8, char: ?[]const u8) lineedit.KeyCode {
    if (std.mem.eql(u8, code, "char")) {
        const text = char orelse lua.argError(1, "a char key needs a char field");
        const decoded = width.decode(text, 0);
        if (decoded.len == 0) return .null_key;
        return .{ .char = decoded.codepoint };
    }
    if (std.mem.eql(u8, code, "enter")) return .enter;
    if (std.mem.eql(u8, code, "backspace")) return .backspace;
    if (std.mem.eql(u8, code, "delete")) return .delete;
    if (std.mem.eql(u8, code, "left")) return .left;
    if (std.mem.eql(u8, code, "right")) return .right;
    if (std.mem.eql(u8, code, "up")) return .up;
    if (std.mem.eql(u8, code, "down")) return .down;
    if (std.mem.eql(u8, code, "home")) return .home;
    if (std.mem.eql(u8, code, "end")) return .end;
    if (std.mem.eql(u8, code, "tab")) return .tab;
    if (std.mem.eql(u8, code, "page_up")) return .page_up;
    if (std.mem.eql(u8, code, "page_down")) return .page_down;
    if (std.mem.eql(u8, code, "esc")) return .esc;
    if (std.mem.eql(u8, code, "insert")) return .insert;
    if (std.mem.startsWith(u8, code, "f") and code.len > 1) {
        const number = std.fmt.parseInt(u8, code[1..], 10) catch return .null_key;
        return .{ .f = number };
    }
    return .null_key;
}

fn luaFeed(lua: *Lua) !i32 {
    const binding = getBinding(lua);
    if (!binding.ready) return luaerror.ret(lua, "the editor is closed", .{});

    const event_type = luax.getTableStringOptional(lua, "type", 2) orelse "key";
    if (std.mem.eql(u8, event_type, "paste")) {
        const text = luax.getTableStringOptional(lua, "text", 2) orelse "";
        binding.editor.feedPaste(text) catch |err|
            return luaerror.ret(lua, "could not paste text: {s}", .{@errorName(err)});
        _ = lua.pushString("continue");
        return 1;
    }
    if (!std.mem.eql(u8, event_type, "key")) {
        _ = lua.pushString("ignored");
        return 1;
    }

    const code = luax.getTableStringOptional(lua, "code", 2) orelse "null";
    const char = luax.getTableStringOptional(lua, "char", 2);
    var key = lineedit.Key{
        .code = keyCode(lua, code, char),
        .shift = luax.getOptionBool(lua, "shift", 2, false),
        .control = luax.getOptionBool(lua, "control", 2, false),
        .alt = luax.getOptionBool(lua, "alt", 2, false),
    };
    key = lineedit.applyControlCode(key);

    const action = binding.editor.feedKey(key) catch |err|
        return luaerror.ret(lua, "could not edit the text: {s}", .{@errorName(err)});
    _ = lua.pushString(switch (action) {
        .continue_editing => "continue",
        .submit => "submit",
        .abort => "abort",
        .eof => "eof",
    });
    return 1;
}

fn luaRender(lua: *Lua) !i32 {
    const binding = getBinding(lua);
    if (!binding.ready) return luaerror.ret(lua, "the editor is closed", .{});

    binding.editor.renderFrame() catch |err|
        return luaerror.ret(lua, "could not render the editor: {s}", .{@errorName(err)});

    lua.newTable();
    const rows_table = lua.getTop();
    for (binding.grid.rows.items, 0..) |*row, row_index| {
        lua.newTable();
        const line_table = lua.getTop();
        var span_index: usize = 0;
        for (row.segments.items) |*segment| {
            if (segment.text.items.len == 0) continue;
            span_index += 1;
            lua.newTable();
            const span_table = lua.getTop();
            _ = lua.pushString("text");
            _ = lua.pushString(segment.text.items);
            lua.setTable(span_table);
            _ = lua.pushString("style");
            _ = lua.pushString(segment.style.name());
            lua.setTable(span_table);
            lua.pushInteger(@intCast(span_index));
            lua.insert(-2);
            lua.setTable(line_table);
        }
        lua.pushInteger(@intCast(row_index + 1));
        lua.insert(-2);
        lua.setTable(rows_table);
    }

    lua.newTable();
    const cursor_table = lua.getTop();
    _ = lua.pushString("row");
    lua.pushInteger(@intCast(binding.grid.cursor_row));
    lua.setTable(cursor_table);
    _ = lua.pushString("column");
    lua.pushInteger(@intCast(binding.grid.cursor_column));
    lua.setTable(cursor_table);
    return 2;
}

fn luaValue(lua: *Lua) !i32 {
    const binding = getBinding(lua);
    if (!binding.ready) return luaerror.ret(lua, "the editor is closed", .{});
    _ = lua.pushString(binding.editor.textValue());
    return 1;
}

fn luaLen(lua: *Lua) !i32 {
    const binding = getBinding(lua);
    if (!binding.ready) return luaerror.ret(lua, "the editor is closed", .{});
    lua.pushInteger(@intCast(binding.editor.textLength()));
    return 1;
}

fn luaSetText(lua: *Lua) !i32 {
    const binding = getBinding(lua);
    if (!binding.ready) return luaerror.ret(lua, "the editor is closed", .{});
    const text = lua.checkString(2);
    binding.editor.setText(std.mem.sliceTo(text, 0)) catch |err|
        return luaerror.ret(lua, "could not set the editor text: {s}", .{@errorName(err)});
    return 0;
}

fn luaResize(lua: *Lua) !i32 {
    const binding = getBinding(lua);
    if (!binding.ready) return luaerror.ret(lua, "the editor is closed", .{});
    const columns: usize = @intCast(@max(lua.checkInteger(2), 1));
    const height: usize = @intCast(@max(lua.checkInteger(3), 1));
    binding.grid.resize(columns, height) catch |err|
        return luaerror.ret(lua, "could not resize the editor: {s}", .{@errorName(err)});
    binding.editor.setSize(.{ .rows = height, .columns = columns });
    return 0;
}

fn luaClose(lua: *Lua) !i32 {
    const binding = getBinding(lua);
    if (binding.ready) binding.editor.deinit();
    binding.ready = false;
    return 0;
}

const methods = [_]zlua.FnReg{
    .{ .name = "feed", .func = zlua.wrap(luaFeed) },
    .{ .name = "render", .func = zlua.wrap(luaRender) },
    .{ .name = "value", .func = zlua.wrap(luaValue) },
    .{ .name = "len", .func = zlua.wrap(luaLen) },
    .{ .name = "set_text", .func = zlua.wrap(luaSetText) },
    .{ .name = "resize", .func = zlua.wrap(luaResize) },
    .{ .name = "close", .func = zlua.wrap(luaClose) },
};

const functions = [_]zlua.FnReg{
    .{ .name = "new", .func = zlua.wrap(luaNew) },
};

pub fn register(lua: *Lua) !i32 {
    lua.newLibTable(&functions);
    lua.setFuncs(&functions, 0);

    if (lua.getMetatableRegistry(mt_name) == .nil) {
        lua.pop(1);
        try registerMetatable(lua);
    } else {
        lua.pop(1);
    }
    return 1;
}

fn registerMetatable(lua: *Lua) !void {
    lua.newMetatable(mt_name) catch |err|
        return luaerror.raise(err, "could not register the prompt editor: {s}", .{@errorName(err)});
    _ = lua.pushString("__gc");
    lua.pushFunction(zlua.wrap(luaGc));
    lua.setTable(-3);

    lua.newTable();
    lua.setFuncs(&methods, 0);
    _ = lua.pushString("__index");
    lua.pushValue(-2);
    lua.setTable(-4);
    lua.pop(1);
    lua.pop(1);
}
