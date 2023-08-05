const std = @import("std");

const ziglua = @import("ziglua");
const luax = @import("luax.zig");
const Lua = ziglua.Lua;

const zigStringUtil = @import("zigStringUtil");
const Builder = zigStringUtil.Builder;
const Joiner = zigStringUtil.Joiner;

const string_functions = [_]ziglua.FnReg{
    .{ .name = "split", .func = ziglua.wrap(split) },
    .{ .name = "trim", .func = ziglua.wrap(trim) },
    .{ .name = "ltrim", .func = ziglua.wrap(ltrim_lib) },
    .{ .name = "rtrim", .func = ziglua.wrap(rtrim_lib) },
};

const table_functions = [_]ziglua.FnReg{
    .{ .name = "next", .func = ziglua.wrap(next) },
    .{ .name = "insert_sorted", .func = ziglua.wrap(insert_sorted) },
    .{ .name = "concats", .func = ziglua.wrap(concats) },
    .{ .name = "spairs", .func = ziglua.wrap(spairs) },
    .{ .name = "comparator", .func = ziglua.wrap(comparator) },
};

pub fn register(lua: *Lua) void {
    register_module(lua, "string", &string_functions);
    register_module(lua, "table", &table_functions);
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

fn split(lua: *Lua) i32 {
    const str = luax.slice(lua.checkString(1));
    const delim = luax.slice(lua.optString(2, ","));

    var count: i32 = 0;
    var it = std.mem.splitSequence(u8, str, delim);
    while (it.next()) |item| {
        _ = lua.pushBytes(item);
        count += 1;
    }
    return count;
}

const char_to_strip = " \t\r\n\x00";

fn trim(lua: *Lua) i32 {
    const str = luax.slice(lua.checkString(1));
    const ltrimmed = std.mem.trimLeft(u8, str, char_to_strip);
    _ = lua.pushBytes(std.mem.trimRight(u8, ltrimmed, char_to_strip));
    return 1;
}

fn ltrim_lib(lua: *Lua) i32 {
    const str = luax.slice(lua.checkString(1));
    _ = lua.pushBytes(std.mem.trimLeft(u8, str, char_to_strip));
    return 1;
}

fn rtrim_lib(lua: *Lua) i32 {
    const str = luax.slice(lua.checkString(1));
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

fn comparator(lua: *Lua) i32 {
    lua.pushBoolean(lua.compare(1, 2, .lt));
    return 1;
}

fn insert_sorted(lua: *Lua) i32 {
    lua.checkType(1, .table);
    lua.argCheck(!lua.isNil(2), 2, "item to insert may not be nil");
    if (lua.typeOf(3) == .none) {
        lua.pushFunction(ziglua.wrap(comparator));
    } else {
        lua.checkType(3, .function);
    }
    var start: i32 = 1;
    var len: i32 = @intCast(lua.rawLen(1));
    var mid: i32 = 1;
    var state: u8 = 0;

    while (start <= len) {
        mid = start + (@divTrunc((len - start), 2));
        lua.pushValue(3); // comparator
        lua.pushValue(2); // value
        _ = lua.rawGetIndex(1, mid); // table[mid]
        lua.call(2, 1);
        if (lua.toBoolean(-1)) {
            len = mid - 1;
            state = 0;
        } else {
            start = mid + 1;
            state = 1;
        }
        lua.pop(1);
    }

    luax.pushLibraryFunction(lua, "table", "insert");
    lua.pushValue(1);
    lua.pushInteger(mid + state);
    lua.pushValue(2);
    lua.call(3, 0);

    return 0;
}

fn concats(lua: *Lua) i32 {
    lua.checkType(1, .table);
    const allocator = std.heap.c_allocator;
    var builder: Builder = Builder.init(allocator, 0) catch luax.raiseError(lua, "could not allocate memory");
    defer builder.deinit();

    const len: u64 = lua.rawLen(1);

    if (lua.isNoneOrNil(2)) {
        concats_simple(lua, &builder, len);
    } else {
        concats_separator(lua, &builder, len);
    }

    const str = builder.get();
    _ = lua.pushBytes(str);
    return 1;
}

fn concats_simple(lua: *Lua, builder: *Builder, len: u64) void {
    var i: i64 = 1;
    while (i <= len) : (i += 1) {
        _ = lua.getIndex(1, i);
        var string = lua.toBytesFmt(-1);
        builder.add(string) catch luax.raiseError(lua, "could not allocate memory");
        lua.pop(1);
    }
}

fn concats_separator(lua: *Lua, builder: *Builder, len: u64) void {
    const separator = lua.toBytesFmt(2);
    var i: i64 = 1;
    while (i <= len) : (i += 1) {
        _ = lua.getIndex(1, i);
        var string = lua.toBytesFmt(-1);
        builder.add(string) catch luax.raiseError(lua, "could not allocate memory");
        if (i < len) {
            builder.add(separator) catch luax.raiseError(lua, "could not allocate memory");
        }
        lua.pop(1);
    }
}

fn spairs(lua: *Lua) i32 {
    var i: ziglua.Integer = 1;
    lua.newTable();
    lua.pushNil();
    while (lua.next(1)) : (i += 1) {
        lua.pop(1);
        lua.pushValue(-1);
        lua.rawSetIndex(-3, i);
    }

    luax.pushLibraryFunction(lua, "table", "sort");
    if (lua.isFunction(2)) {
        lua.pushValue(-2);
        lua.pushValue(2);
        lua.call(2, 0);
    } else {
        lua.pushValue(-2);
        lua.call(1, 0);
    }

    lua.pushValue(1);
    lua.pushInteger(1);
    lua.pushClosure(ziglua.wrap(spairs_iter), 3);

    return 1;
}

fn spairs_iter(lua: *Lua) i32 {
    const i = lua.toInteger(Lua.upvalueIndex(3)) catch undefined;
    _ = lua.getIndex(Lua.upvalueIndex(1), i);
    lua.pushValue(-1);
    _ = lua.getTable(Lua.upvalueIndex(2));
    lua.pushInteger(i + 1);
    lua.replace(Lua.upvalueIndex(3));
    return 2;
}
