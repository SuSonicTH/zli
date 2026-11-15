//! Lua binding for the line editor, including history userdata and the termy
//! backend implementation.

const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");
const lineedit = @import("lineedit.zig");
const history_mod = @import("history.zig");
const term = @import("term.zig");
const termy = @import("termy");

const allocator = std.heap.c_allocator;

const history_name = "readline.history";
const history_udata_key = "readline.history";

const HistoryData = struct {
    value: history_mod.History,
};

const functions = [_]zlua.FnReg{
    .{ .name = "read", .func = luaerror.wrap(lua_read) },
    .{ .name = "new_history", .func = luaerror.wrap(lua_new_history) },
};

const history_functions = [_]zlua.FnReg{
    .{ .name = "add", .func = luaerror.wrap(history_add) },
    .{ .name = "load", .func = luaerror.wrap(history_load) },
    .{ .name = "save", .func = luaerror.wrap(history_save) },
    .{ .name = "clear", .func = luaerror.wrap(history_clear) },
    .{ .name = "show", .func = luaerror.wrap(history_show) },
    .{ .name = "entries", .func = luaerror.wrap(history_entries) },
    .{ .name = "size", .func = luaerror.wrap(history_size) },
    .{ .name = "set_max", .func = luaerror.wrap(history_set_max) },
};

pub fn register(lua: *Lua) i32 {
    if (lua.getMetatableRegistry(history_name) == .nil) {
        lua.pop(1);
        luax.registerUserData(lua, history_name, zlua.wrap(gc_history));
    } else {
        lua.pop(1);
    }

    lua.newLib(&functions);
    luax.registerExtended(lua, @embedFile("readline.lua"), "readline", "zli_readline");
    return 1;
}

fn gc_history(lua: *Lua) i32 {
    const data: *HistoryData = luax.getGcUserData(lua, HistoryData);
    data.value.deinit();
    return 0;
}

fn history(lua: *Lua) *HistoryData {
    return luax.getUserData(lua, history_udata_key, HistoryData);
}

fn lua_new_history(lua: *Lua) !i32 {
    const data = luax.createUserDataTableSetFunctions(lua, history_udata_key, HistoryData, &history_functions, 0);
    data.value = .init(allocator);

    if (lua.typeOf(1) == .table) {
        if (lua.getField(1, "max") == .number) {
            const max = lua.toInteger(-1) catch 1000;
            if (max > 0) data.value.setMax(@intCast(max));
        }
        lua.pop(1);
    }
    return 1;
}

fn history_add(lua: *Lua) !i32 {
    const data = history(lua);
    const text = lua.checkString(2);
    data.value.add(std.mem.sliceTo(text, 0)) catch |err|
        return luaerror.ret(lua, "could not add a history entry: {s}", .{@errorName(err)});
    return 0;
}

fn history_load(lua: *Lua) !i32 {
    const data = history(lua);
    const path = std.mem.sliceTo(lua.checkString(2), 0);
    data.value.load(term.ioValue(), std.Io.Dir.cwd(), path) catch |err|
        return luaerror.ret(lua, "could not load history '{s}': {s}", .{ path, @errorName(err) });
    lua.pushBoolean(true);
    return 1;
}

fn history_save(lua: *Lua) !i32 {
    const data = history(lua);
    const path = std.mem.sliceTo(lua.checkString(2), 0);
    data.value.save(term.ioValue(), std.Io.Dir.cwd(), path) catch |err|
        return luaerror.ret(lua, "could not save history '{s}': {s}", .{ path, @errorName(err) });
    lua.pushBoolean(true);
    return 1;
}

fn history_clear(lua: *Lua) !i32 {
    const data = history(lua);
    data.value.clear();
    return 0;
}

fn history_show(lua: *Lua) !i32 {
    const data = history(lua);

    _ = fflush(null);
    const writer = term.writerPtr();
    var index: usize = 0;
    while (index < data.value.count()) : (index += 1) {
        const entry = data.value.get(index).?;
        writer.print("{d:>4}  {s}\n", .{ index + 1, entry }) catch |err|
            return luaerror.ret(lua, "could not print the history: {s}", .{@errorName(err)});
    }
    term.flushOutput() catch {};
    return 0;
}

fn history_entries(lua: *Lua) !i32 {
    const data = history(lua);
    lua.newTable();
    var index: usize = 0;
    while (index < data.value.count()) : (index += 1) {
        _ = lua.pushString(data.value.get(index).?);
        lua.setIndexRaw(-2, @intCast(index + 1));
    }
    return 1;
}

fn history_size(lua: *Lua) !i32 {
    lua.pushInteger(@intCast(history(lua).value.count()));
    return 1;
}

fn history_set_max(lua: *Lua) !i32 {
    const max = lua.checkInteger(2);
    if (max < 1) lua.argError(2, "expecting a positive maximum");
    history(lua).value.setMax(@intCast(max));
    return 0;
}

const CallbackCtx = struct {
    lua: *Lua,
    multiline_index: ?i32 = null,
    complete_index: ?i32 = null,
    error_message: ?[]u8 = null,
};

fn setCallbackError(ctx: *CallbackCtx) void {
    const lua = ctx.lua;
    const text: []const u8 = if (lua.typeOf(-1) == .string)
        std.mem.sliceTo(lua.toString(-1) catch "callback failed", 0)
    else
        "callback failed";

    if (ctx.error_message) |old| allocator.free(old);
    ctx.error_message = allocator.dupe(u8, text) catch null;
    lua.pop(1);
}

fn multilineCallback(context: *anyopaque, buffer: []const u8) anyerror!bool {
    const ctx: *CallbackCtx = @ptrCast(@alignCast(context));
    const index = ctx.multiline_index orelse return true;

    ctx.lua.pushValue(index);
    _ = ctx.lua.pushString(buffer);
    ctx.lua.protectedCall(.{ .args = 1, .results = 1 }) catch {
        setCallbackError(ctx);
        return error.CallbackFailed;
    };

    const result = ctx.lua.toBoolean(-1);
    ctx.lua.pop(1);
    return result;
}

fn completeCallback(context: *anyopaque, buffer: []const u8, cursor: usize, allocation: std.mem.Allocator) anyerror!?lineedit.Completion {
    const ctx: *CallbackCtx = @ptrCast(@alignCast(context));
    const index = ctx.complete_index orelse return null;

    ctx.lua.pushValue(index);
    _ = ctx.lua.pushString(buffer);
    ctx.lua.pushInteger(@intCast(cursor));
    ctx.lua.protectedCall(.{ .args = 2, .results = 3 }) catch {
        setCallbackError(ctx);
        return error.CallbackFailed;
    };

    if (ctx.lua.typeOf(-1) != .table) {
        ctx.lua.pop(3);
        return null;
    }

    const start_value = ctx.lua.toInteger(-3) catch 1;
    const end_value = ctx.lua.toInteger(-2) catch 0;
    const count = ctx.lua.lenRaw(-1);
    if (count == 0) {
        ctx.lua.pop(3);
        return null;
    }

    const candidates = try allocation.alloc([]const u8, count);
    errdefer allocation.free(candidates);

    var filled: usize = 0;
    errdefer {
        for (candidates[0..filled]) |candidate| allocation.free(candidate);
    }

    while (filled < count) : (filled += 1) {
        _ = ctx.lua.getIndexRaw(-1, @intCast(filled + 1));
        const text = std.mem.sliceTo(ctx.lua.toString(-1) catch "", 0);
        candidates[filled] = try allocation.dupe(u8, text);
        ctx.lua.pop(1);
    }

    const buffer_len: i64 = @intCast(buffer.len);
    const start = std.math.clamp(start_value - 1, 0, buffer_len);
    const end = std.math.clamp(end_value, start, buffer_len);

    ctx.lua.pop(3);
    return .{
        .start = @intCast(start),
        .end = @intCast(end),
        .candidates = candidates,
    };
}

const BackendCtx = struct {
    callbacks: *CallbackCtx,
    pending: std.ArrayList(lineedit.Event) = .empty,
    paste_scratch: std.ArrayList(u8) = .empty,
};

extern fn fflush(stream: ?*anyopaque) c_int;

fn convertKey(key: termy.event.KeyEvent) lineedit.Key {
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

fn pushPending(ctx: *BackendCtx, event: termy.event.Event) !void {
    switch (event) {
        .Key => |key| {
            if (key.kind == .Release) return;
            try ctx.pending.append(allocator, .{ .key = convertKey(key) });
        },
        .Paste => |text| {
            ctx.pending.append(allocator, .{ .paste = try allocator.dupe(u8, text) }) catch return error.OutOfMemory;
        },
        .Resize => |size| {
            try ctx.pending.append(allocator, .{ .resize = .{ .rows = size.rows, .columns = size.columns } });
        },
        else => {},
    }
}

fn backendSize(context: *anyopaque) lineedit.Size {
    _ = context;
    const size = term.terminalPtr().windowSize() catch return .{ .rows = 24, .columns = 80 };
    if (size.columns == 0 or size.rows == 0) return .{ .rows = 24, .columns = 80 };
    return .{ .rows = size.rows, .columns = size.columns };
}

fn backendCursor(context: *anyopaque) anyerror!lineedit.Cursor {
    const ctx: *BackendCtx = @ptrCast(@alignCast(context));
    var queued: std.ArrayList(termy.event.Event) = .empty;
    defer queued.deinit(allocator);

    const position = term.inputPtr().queryCursorPosition(
        .fromMilliseconds(150),
        .{ .allocator = allocator, .list = &queued },
    ) catch |err| {
        for (queued.items) |event| pushPending(ctx, event) catch {};
        return err;
    };
    for (queued.items) |event| pushPending(ctx, event) catch {};

    const pos = position orelse return error.CursorQueryTimeout;
    return .{ .row = pos.y -| 1, .column = pos.x -| 1 };
}

fn backendWrite(context: *anyopaque, bytes: []const u8) anyerror!void {
    _ = context;
    try term.writerPtr().writeAll(bytes);
}

fn backendMoveTo(context: *anyopaque, row: usize, column: usize) anyerror!void {
    _ = context;
    const x: u16 = @intCast(@min(column, std.math.maxInt(u16) - 1) + 1);
    const y: u16 = @intCast(@min(row, std.math.maxInt(u16) - 1) + 1);
    try term.cursorPtr().moveTo(x, y);
}

fn backendClearLine(context: *anyopaque) anyerror!void {
    _ = context;
    try term.terminalPtr().clear(.UntilRowEnd);
}

fn backendClearScreen(context: *anyopaque) anyerror!void {
    _ = context;
    try term.terminalPtr().clear(.All);
}

fn backendHideCursor(context: *anyopaque) anyerror!void {
    _ = context;
    try term.cursorPtr().hide();
}

fn backendShowCursor(context: *anyopaque) anyerror!void {
    _ = context;
    try term.cursorPtr().show();
}

fn backendPromptStyle(context: *anyopaque, style: lineedit.PromptStyle) anyerror!void {
    _ = context;
    switch (style) {
        .normal => try term.stylePtr().setForegroundColor(.Blue),
        .multiline => try term.stylePtr().setForegroundColor(.Yellow),
        .none => try term.stylePtr().setForegroundColor(.Reset),
    }
}

fn backendFlush(context: *anyopaque) anyerror!void {
    _ = context;
    try term.flushOutput();
}

fn backendScrollUp(context: *anyopaque, rows: usize, count: usize) anyerror!void {
    _ = context;
    if (count == 0) return;

    const last_row: u16 = @intCast(@min(@max(rows, 1), std.math.maxInt(u16)));
    try term.cursorPtr().moveTo(1, last_row);

    const writer = term.writerPtr();
    var index: usize = 0;
    while (index < count) : (index += 1) {
        try writer.writeByte('\n');
    }
}

fn backendReadEvent(context: *anyopaque) anyerror!?lineedit.Event {
    const ctx: *BackendCtx = @ptrCast(@alignCast(context));

    while (true) {
        if (ctx.pending.items.len > 0) {
            const event = ctx.pending.orderedRemove(0);
            if (event == .paste) {
                ctx.paste_scratch.clearRetainingCapacity();
                ctx.paste_scratch.appendSlice(allocator, event.paste) catch {
                    allocator.free(event.paste);
                    return error.OutOfMemory;
                };
                allocator.free(event.paste);
                return .{ .paste = ctx.paste_scratch.items };
            }
            return event;
        }

        const event = term.inputPtr().read() catch |err| switch (err) {
            error.EndOfInput => return null,
            error.InvalidEventFound => return .other,
            else => return err,
        };

        switch (event) {
            .Key => |key| {
                if (key.kind == .Release) continue;
                return .{ .key = convertKey(key) };
            },
            .Paste => |text| return .{ .paste = text },
            .Resize => |size| return .{ .resize = .{ .rows = size.rows, .columns = size.columns } },
            else => return .other,
        }
    }
}

const backend_vtable: lineedit.Backend.VTable = .{
    .size = backendSize,
    .cursorPosition = backendCursor,
    .write = backendWrite,
    .moveTo = backendMoveTo,
    .clearLine = backendClearLine,
    .clearScreen = backendClearScreen,
    .hideCursor = backendHideCursor,
    .showCursor = backendShowCursor,
    .promptStyle = backendPromptStyle,
    .flush = backendFlush,
    .readEvent = backendReadEvent,
    .scrollUp = backendScrollUp,
};

fn optionalString(lua: *Lua, table_index: i32, field: [:0]const u8) ?[]const u8 {
    if (lua.getField(table_index, field) == .nil) {
        lua.pop(1);
        return null;
    }
    if (lua.typeOf(-1) != .string) {
        lua.pop(1);
        lua.argError(table_index, "readline options must contain strings");
    }
    const text = lua.toString(-1) catch unreachable;
    lua.pop(1);
    return std.mem.sliceTo(text, 0);
}

fn optionalBoolean(lua: *Lua, table_index: i32, field: [:0]const u8) ?bool {
    if (lua.getField(table_index, field) == .nil) {
        lua.pop(1);
        return null;
    }
    if (lua.typeOf(-1) != .boolean) {
        lua.pop(1);
        lua.argError(table_index, "readline options must contain booleans");
    }
    const value = lua.toBoolean(-1);
    lua.pop(1);
    return value;
}

fn lua_read(lua: *Lua) !i32 {
    if (!term.isTtyValue()) {
        return luaerror.ret(lua, "standard input and output must be a terminal", .{});
    }

    var options: lineedit.Options = .{};
    var callback_ctx: CallbackCtx = .{ .lua = lua };

    switch (lua.typeOf(1)) {
        .string => {
            options.prompt = std.mem.sliceTo(lua.toString(1) catch unreachable, 0);
        },
        .table => {
            options.prompt = optionalString(lua, 1, "prompt") orelse options.prompt;
            options.continuation = optionalString(lua, 1, "continuation") orelse options.continuation;
            options.initial = optionalString(lua, 1, "initial") orelse options.initial;
            options.multiline_color = optionalBoolean(lua, 1, "multiline_color") orelse true;

            if (lua.getField(1, "history") != .nil) {
                if (lua.typeOf(-1) == .table) {
                    const data = luax.getUserDataIndex(lua, history_udata_key, HistoryData, -1);
                    options.history = &data.value;
                }
                lua.pop(1);
            }

            if (lua.getField(1, "multiline") != .nil) {
                if (lua.typeOf(-1) != .function) {
                    lua.pop(1);
                    lua.argError(1, "multiline must be a function");
                }
                callback_ctx.multiline_index = lua.getTop();
            }

            if (lua.getField(1, "complete") != .nil) {
                if (lua.typeOf(-1) != .function) {
                    lua.pop(1);
                    lua.argError(1, "complete must be a function");
                }
                callback_ctx.complete_index = lua.getTop();
            }
        },
        .none, .nil => {},
        else => lua.argError(1, "expecting a prompt string or an options table"),
    }

    if (callback_ctx.multiline_index != null) {
        options.multiline = .{ .ctx = &callback_ctx, .call = multilineCallback };
    }
    if (callback_ctx.complete_index != null) {
        options.complete = .{ .ctx = &callback_ctx, .call = completeCallback };
    }

    var backend_ctx: BackendCtx = .{ .callbacks = &callback_ctx };
    defer {
        for (backend_ctx.pending.items) |event| {
            if (event == .paste) allocator.free(event.paste);
        }
        backend_ctx.pending.deinit(allocator);
        backend_ctx.paste_scratch.deinit(allocator);
    }

    var editor = lineedit.Editor.init(allocator, .{ .ctx = &backend_ctx, .vtable = &backend_vtable }, options);
    defer editor.deinit();

    const raw_was_active = term.isRawActive();
    if (!raw_was_active) {
        term.enableRawMode() catch |err|
            return luaerror.ret(lua, "could not enable raw mode: {s}", .{@errorName(err)});
    }
    const paste_was_active = term.bracketedPasteActive();
    if (!paste_was_active) term.enableBracketedPaste() catch {};
    const previous_enhancements = term.enhancementsMask();
    const desired_enhancements = (previous_enhancements orelse 0) | termy.Terminal.Enhancements.DISAMBIGUATE_ESCAPE_CODES;
    if (previous_enhancements != desired_enhancements) {
        term.enableEnhancements(desired_enhancements) catch {};
    }
    term.cursorPtr().hide() catch {};
    term.flushOutput() catch {};

    defer {
        term.cursorPtr().show() catch {};
        if (previous_enhancements) |previous| {
            term.enableEnhancements(previous) catch {};
        } else {
            term.disableEnhancements();
        }
        if (!paste_was_active) term.disableBracketedPaste();
        if (!raw_was_active) term.disableRawMode();
        term.resetStyleQuiet();
        term.flushOutput() catch {};
    }

    const outcome = editor.run() catch |err| {
        defer if (callback_ctx.error_message) |message| allocator.free(message);
        if (callback_ctx.error_message) |message| {
            return luaerror.raise(err, "{s}", .{message});
        }
        return luaerror.raise(err, "readline failed: {s}", .{@errorName(err)});
    };

    switch (outcome) {
        .line => |line| {
            defer allocator.free(line);
            _ = lua.pushString(line);
            return 1;
        },
        .eof => {
            lua.pushNil();
            _ = lua.pushString("eof");
            return 2;
        },
        .abort => {
            lua.pushNil();
            _ = lua.pushString("abort");
            return 2;
        },
    }
}
