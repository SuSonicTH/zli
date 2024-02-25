const std = @import("std");

const ziglua = @import("ziglua");
const luax = @import("luax.zig");
const Lua = ziglua.Lua;

const builtin = @import("builtin");

const timer = @cImport({
    @cInclude("timer.h");
});

const string_functions = [_]ziglua.FnReg{
    .{ .name = "split", .func = ziglua.wrap(split) },
    .{ .name = "to_table", .func = ziglua.wrap(to_table) },
    .{ .name = "trim", .func = ziglua.wrap(trim) },
    .{ .name = "ltrim", .func = ziglua.wrap(ltrim) },
    .{ .name = "rtrim", .func = ziglua.wrap(rtrim) },
};

const table_functions = [_]ziglua.FnReg{
    .{ .name = "next", .func = ziglua.wrap(next) },
    .{ .name = "create", .func = ziglua.wrap(table_create) },
};

const os_functions = [_]ziglua.FnReg{
    .{ .name = "get_name", .func = ziglua.wrap(os_get_name) },
    .{ .name = "nanotime", .func = ziglua.wrap(nanotime) },
};

pub fn register(lua: *Lua) void {
    register_module(lua, "string", &string_functions);
    register_module(lua, "table", &table_functions);
    register_module(lua, "os", &os_functions);

    lua.loadBuffer(@embedFile("auxiliary.lua"), "auxiliary", ziglua.Mode.text) catch lua.raiseError();
    lua.callCont(0, 0, 0, null);
}

fn register_module(lua: *Lua, module: [:0]const u8, functions: []const ziglua.FnReg) void {
    _ = lua.getGlobal(module) catch unreachable;
    for (functions) |function| {
        _ = lua.pushString(function.name);
        lua.pushFunction(function.func.?);
        lua.setTable(-3);
    }
    lua.pop(1);
}

fn os_get_name(lua: *Lua) i32 {
    if (builtin.os.tag == .windows) {
        _ = lua.pushString("windows");
    } else if (builtin.os.tag == .linux) {
        _ = lua.pushString("linux");
    } else if (builtin.os.tag == .macos) {
        _ = lua.pushString("macos");
    } else {
        _ = lua.pushString("unknown");
    }
    return 1;
}

fn nanotime(lua: *Lua) i32 {
    lua.pushNumber(timer.nanotime());
    return 1;
}

fn split(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    const delim = std.mem.sliceTo(lua.optString(2, ","), 0);

    var count: i32 = 0;
    var it = std.mem.splitSequence(u8, str, delim);
    while (it.next()) |item| {
        _ = lua.pushBytes(item);
        count += 1;
    }
    return count;
}

fn to_table(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    const delim = std.mem.sliceTo(lua.optString(2, ","), 0);

    lua.newTable();
    const table = lua.getTop();

    var index: i32 = 1;
    var it = std.mem.splitSequence(u8, str, delim);
    while (it.next()) |item| {
        _ = lua.pushBytes(item);
        lua.rawSetIndex(table, index);
        index += 1;
    }
    return 1;
}

const char_to_strip = " \t\r\n\x00";

fn trim(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    const ltrimmed = std.mem.trimLeft(u8, str, char_to_strip);
    _ = lua.pushBytes(std.mem.trimRight(u8, ltrimmed, char_to_strip));
    return 1;
}

fn ltrim(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    _ = lua.pushBytes(std.mem.trimLeft(u8, str, char_to_strip));
    return 1;
}

fn rtrim(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    _ = lua.pushBytes(std.mem.trimRight(u8, str, char_to_strip));
    return 1;
}

fn next(lua: *Lua) i32 {
    lua.checkType(1, .table);
    lua.pushValue(1);
    lua.pushInteger(1);
    lua.pushClosure(ziglua.wrap(next_function), 2);
    return 1;
}

fn next_function(lua: *Lua) i32 {
    const index = lua.toInteger(Lua.upvalueIndex(2)) catch unreachable;
    _ = lua.getIndex(Lua.upvalueIndex(1), @intCast(index));
    lua.pushInteger(index + 1);
    lua.replace(Lua.upvalueIndex(2));
    return 1;
}

fn table_create(lua: *Lua) i32 {
    const num_arr: i32 = @intCast(luax.getArgIntegerOrError(lua, 1, "expecting number of array items"));
    const num_rec: i32 = @intCast(luax.getArgIntegerOrError(lua, 2, "expecting number of record items"));
    lua.createTable(num_arr, num_rec);
    return 1;
}

fn memoryError(lua: *Lua) noreturn {
    luax.raiseError(lua, "internal error: could not allocate memory");
}
