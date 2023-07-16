const std = @import("std");
//const ziglua = @import("ziglua");
const ziglua = @import("lib/ziglua/src/ziglua-5.4/lib.zig");
const Lua = ziglua.Lua;

const c = @cImport({
    @cInclude("crossline.h");
});

const crossline = [_]ziglua.FnReg{
    .{ .name = "readline", .func = ziglua.wrap(crossline_readline) },
    .{ .name = "set_prompt_color", .func = ziglua.wrap(crossline_prompt_color_set) },
    .{ .name = "set_color", .func = ziglua.wrap(crossline_color_set) },
};

const crossline_screen = [_]ziglua.FnReg{
    .{ .name = "dimentions", .func = ziglua.wrap(crossline_screen_get) },
    .{ .name = "clear", .func = ziglua.wrap(crossline_screen_clear) },
};

const crossline_cursor = [_]ziglua.FnReg{
    .{ .name = "get", .func = ziglua.wrap(crossline_cursor_get) },
    .{ .name = "set", .func = ziglua.wrap(crossline_cursor_set) },
    .{ .name = "move", .func = ziglua.wrap(crossline_cursor_move) },
    .{ .name = "hide", .func = ziglua.wrap(crossline_cursor_hide) },
    .{ .name = "show", .func = ziglua.wrap(crossline_cursor_show) },
};

const crossline_history = [_]ziglua.FnReg{
    .{ .name = "save", .func = ziglua.wrap(crossline_history_save) },
    .{ .name = "load", .func = ziglua.wrap(crossline_history_load) },
    .{ .name = "show", .func = ziglua.wrap(crossline_history_show) },
    .{ .name = "clear", .func = ziglua.wrap(crossline_history_clear) },
};

const crossline_paging = [_]ziglua.FnReg{
    .{ .name = "start", .func = ziglua.wrap(crossline_paging_start) },
    .{ .name = "stop", .func = ziglua.wrap(crossline_paging_stop) },
    .{ .name = "check", .func = ziglua.wrap(crossline_paging_check) },
    .{ .name = "print", .func = ziglua.wrap(crossline_paging_print) },
};

const NamedConstantInteger = struct {
    name: [:0]const u8,
    number: ziglua.Integer,
};

const fg_colors = [_]NamedConstantInteger{
    .{ .name = "default", .number = c.CROSSLINE_FGCOLOR_DEFAULT },
    .{ .name = "black", .number = c.CROSSLINE_FGCOLOR_BLACK },
    .{ .name = "red", .number = c.CROSSLINE_FGCOLOR_RED },
    .{ .name = "green", .number = c.CROSSLINE_FGCOLOR_GREEN },
    .{ .name = "yellow", .number = c.CROSSLINE_FGCOLOR_YELLOW },
    .{ .name = "blue", .number = c.CROSSLINE_FGCOLOR_BLUE },
    .{ .name = "magenta", .number = c.CROSSLINE_FGCOLOR_MAGENTA },
    .{ .name = "cyan", .number = c.CROSSLINE_FGCOLOR_CYAN },
    .{ .name = "white", .number = c.CROSSLINE_FGCOLOR_WHITE },

    .{ .name = "bright_black", .number = c.CROSSLINE_FGCOLOR_BLACK | c.CROSSLINE_FGCOLOR_BRIGHT },
    .{ .name = "bright_red", .number = c.CROSSLINE_FGCOLOR_RED | c.CROSSLINE_FGCOLOR_BRIGHT },
    .{ .name = "bright_green", .number = c.CROSSLINE_FGCOLOR_GREEN | c.CROSSLINE_FGCOLOR_BRIGHT },
    .{ .name = "bright_yellow", .number = c.CROSSLINE_FGCOLOR_YELLOW | c.CROSSLINE_FGCOLOR_BRIGHT },
    .{ .name = "bright_blue", .number = c.CROSSLINE_FGCOLOR_BLUE | c.CROSSLINE_FGCOLOR_BRIGHT },
    .{ .name = "bright_magenta", .number = c.CROSSLINE_FGCOLOR_MAGENTA | c.CROSSLINE_FGCOLOR_BRIGHT },
    .{ .name = "bright_cyan", .number = c.CROSSLINE_FGCOLOR_CYAN | c.CROSSLINE_FGCOLOR_BRIGHT },
    .{ .name = "bright_white", .number = c.CROSSLINE_FGCOLOR_WHITE | c.CROSSLINE_FGCOLOR_BRIGHT },
};

const bg_colors = [_]NamedConstantInteger{
    .{ .name = "default", .number = c.CROSSLINE_BGCOLOR_DEFAULT },
    .{ .name = "black", .number = c.CROSSLINE_BGCOLOR_BLACK },
    .{ .name = "red", .number = c.CROSSLINE_BGCOLOR_RED },
    .{ .name = "green", .number = c.CROSSLINE_BGCOLOR_GREEN },
    .{ .name = "yellow", .number = c.CROSSLINE_BGCOLOR_YELLOW },
    .{ .name = "blue", .number = c.CROSSLINE_BGCOLOR_BLUE },
    .{ .name = "magenta", .number = c.CROSSLINE_BGCOLOR_MAGENTA },
    .{ .name = "cyan", .number = c.CROSSLINE_BGCOLOR_CYAN },
    .{ .name = "white", .number = c.CROSSLINE_BGCOLOR_WHITE },

    .{ .name = "bright_black", .number = c.CROSSLINE_BGCOLOR_BLACK | c.CROSSLINE_BGCOLOR_BRIGHT },
    .{ .name = "bright_red", .number = c.CROSSLINE_BGCOLOR_RED | c.CROSSLINE_BGCOLOR_BRIGHT },
    .{ .name = "bright_green", .number = c.CROSSLINE_BGCOLOR_GREEN | c.CROSSLINE_BGCOLOR_BRIGHT },
    .{ .name = "bright_yellow", .number = c.CROSSLINE_BGCOLOR_YELLOW | c.CROSSLINE_BGCOLOR_BRIGHT },
    .{ .name = "bright_blue", .number = c.CROSSLINE_BGCOLOR_BLUE | c.CROSSLINE_BGCOLOR_BRIGHT },
    .{ .name = "bright_magenta", .number = c.CROSSLINE_BGCOLOR_MAGENTA | c.CROSSLINE_BGCOLOR_BRIGHT },
    .{ .name = "bright_cyan", .number = c.CROSSLINE_BGCOLOR_CYAN | c.CROSSLINE_BGCOLOR_BRIGHT },
    .{ .name = "bright_white", .number = c.CROSSLINE_BGCOLOR_WHITE | c.CROSSLINE_BGCOLOR_BRIGHT },
};

var stdout: std.fs.File.Writer = undefined;

pub export fn luaopen_crossline(state: ?*ziglua.LuaState) callconv(.C) c_int {
    var lua: Lua = .{ .state = state.? };
    stdout = std.io.getStdOut().writer();
    lua.newLib(&crossline);
    registerColors(&lua);
    createFunctionSubTable(&lua, &crossline_screen, "screen");
    createFunctionSubTable(&lua, &crossline_cursor, "cursor");
    createFunctionSubTable(&lua, &crossline_history, "history");
    createFunctionSubTable(&lua, &crossline_paging, "paging");
    registerExtended(&lua);
    return 1;
}

fn registerColors(lua: *Lua) void {
    const module = lua.getTop();
    _ = lua.pushString("color");
    lua.newTable();
    createConstantSubTable(lua, &fg_colors, lua.getTop(), "fg");
    createConstantSubTable(lua, &bg_colors, lua.getTop(), "bg");
    lua.setTable(module);
}

fn createFunctionSubTable(lua: *Lua, functions: []const ziglua.FnReg, table_name: [:0]const u8) void {
    _ = lua.pushString(table_name);
    lua.newTable();
    lua.setFuncs(functions, 0);
    lua.setTable(-3);
}

fn createConstantSubTable(lua: *Lua, constants: []const NamedConstantInteger, table_index: i32, table_name: [:0]const u8) void {
    _ = lua.pushString(table_name);
    createConstantTable(lua, constants);
    lua.setTable(table_index);
}

fn createConstantTable(lua: *Lua, constants: []const NamedConstantInteger) void {
    lua.newTable();
    const table = lua.getTop();
    for (constants) |constant| {
        _ = lua.pushString(constant.name);
        lua.pushInteger(constant.number);
        lua.setTable(table);
    }
}

fn registerExtended(lua: *Lua) void {
    const exteded = @embedFile("crossline.lua");
    lua.loadBuffer(exteded, "crossline", ziglua.Mode.text) catch lua.raiseError();
    lua.callCont(0, 1, 0, null);
    lua.checkType(-1, ziglua.LuaType.function);
    lua.pushValue(-2);
    lua.callCont(1, 0, 0, null);
}

const bufferSize: i32 = 4096;

fn crossline_readline(lua: *Lua) i32 {
    const prompt = lua.optString(1, "> ");
    const init = lua.optString(2, "");
    var buffer: [bufferSize]u8 = undefined;

    @memcpy(buffer[0..], init);
    if (c.crossline_readline2(prompt, &buffer, bufferSize)) |line| {
        _ = lua.pushString(line[0..std.mem.len(line) :0]);
    } else {
        lua.pushNil();
    }

    return 1;
}

fn crossline_prompt_color_set(lua: *Lua) i32 {
    const fg = lua.optInteger(1, 0);
    const bg = lua.optInteger(2, 0);
    c.crossline_prompt_color_set(@intCast(u32, fg | bg));
    return 0;
}

fn crossline_color_set(lua: *Lua) i32 {
    const fg = lua.optInteger(1, 0);
    const bg = lua.optInteger(2, 0);
    c.crossline_color_set(@intCast(u32, fg | bg));
    return 0;
}

fn create_pos_table(lua: *Lua, x: c_int, y: c_int) void {
    lua.newTable();

    _ = lua.pushString("x");
    lua.pushInteger(x);
    lua.setTable(-3);

    _ = lua.pushString("y");
    lua.pushInteger(y);
    lua.setTable(-3);
}

fn crossline_screen_get(lua: *Lua) i32 {
    var x: c_int = undefined;
    var y: c_int = undefined;
    c.crossline_screen_get(&y, &x);
    create_pos_table(lua, x, y);
    return 1;
}

fn crossline_screen_clear(lua: *Lua) i32 {
    _ = lua;
    c.crossline_screen_clear();
    return 0;
}

fn crossline_cursor_get(lua: *Lua) i32 {
    var x: c_int = undefined;
    var y: c_int = undefined;
    _ = c.crossline_cursor_get(&y, &x);
    create_pos_table(lua, x, y);
    return 1;
}

const Position = struct {
    x: c_int = 0,
    y: c_int = 0,
};

fn getPosition(lua: *Lua) Position {
    var position = Position{};
    if (lua.typeOf(1) == .table) {
        _ = lua.pushString("x");
        _ = lua.getTable(1);
        position.x = @truncate(i32, lua.toInteger(-1) catch 0);
        _ = lua.pushString("y");
        _ = lua.getTable(1);
        position.y = @truncate(i32, lua.toInteger(-1) catch 0);
    } else {
        position.x = @truncate(i32, lua.checkInteger(1));
        position.y = @truncate(i32, lua.checkInteger(2));
    }
    return position;
}

fn crossline_cursor_set(lua: *Lua) i32 {
    const position = getPosition(lua);
    _ = c.crossline_cursor_set(position.y, position.x);
    return 0;
}

fn crossline_cursor_move(lua: *Lua) i32 {
    const position = getPosition(lua);
    _ = c.crossline_cursor_move(position.y, position.x);
    return 0;
}

fn crossline_cursor_hide(lua: *Lua) i32 {
    _ = lua;
    c.crossline_cursor_hide(1);
    return 0;
}

fn crossline_cursor_show(lua: *Lua) i32 {
    _ = lua;
    c.crossline_cursor_hide(0);
    return 0;
}

fn crossline_history_save(lua: *Lua) i32 {
    _ = c.crossline_history_save(lua.checkString(1));
    return 0;
}

fn crossline_history_load(lua: *Lua) i32 {
    _ = c.crossline_history_load(lua.checkString(1));
    return 0;
}

fn crossline_history_show(lua: *Lua) i32 {
    _ = lua;
    _ = c.crossline_history_show();
    return 0;
}

fn crossline_history_clear(lua: *Lua) i32 {
    _ = lua;
    _ = c.crossline_history_clear();
    return 0;
}

fn crossline_paging_start(lua: *Lua) i32 {
    _ = lua;
    _ = c.crossline_paging_set(1);
    return 0;
}

fn crossline_paging_stop(lua: *Lua) i32 {
    _ = lua;
    _ = c.crossline_paging_set(0);
    return 0;
}

fn crossline_paging_check(lua: *Lua) i32 {
    const length = lua.checkInteger(1);
    const stop = c.crossline_paging_check(@truncate(i32, length));
    lua.pushBoolean(stop >= 0);
    return 1;
}

fn crossline_paging_print_output(lua: *Lua) c_int {
    const str = lua.toString(-1) catch "";
    const string = str[0..std.mem.len(str)];
    stdout.writeAll(string) catch unreachable;
    if (string.len == 0 or string[string.len - 1] != '\n') {
        stdout.writeByte('\n') catch unreachable;
    }
    return c.crossline_paging_check(@intCast(c_int, string.len));
}

fn crossline_paging_print(lua: *Lua) i32 {
    var stop: c_int = undefined;
    if (lua.typeOf(1) == .table) {
        const len = lua.rawLen(1);
        for (1..len) |i| {
            _ = lua.rawGetIndex(1, @intCast(ziglua.Integer, i));
            stop = crossline_paging_print_output(lua);
            lua.pop(1);
        }
    } else {
        stop = crossline_paging_print_output(lua);
    }
    lua.pushBoolean(stop >= 1);
    return 1;
}
