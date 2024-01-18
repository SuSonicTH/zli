const std = @import("std");

const ziglua = @import("ziglua");
const luax = @import("luax.zig");
const Lua = ziglua.Lua;

const zigStringUtil = @import("zigStringUtil");
const Builder = zigStringUtil.Builder;
const Joiner = zigStringUtil.Joiner;
const JoinerOptions = zigStringUtil.JoinerOptions;
const builtin = @import("builtin");

const timer = @cImport({
    @cInclude("timer.h");
});

const string_functions = [_]ziglua.FnReg{
    .{ .name = "split", .func = ziglua.wrap(split) },
    .{ .name = "to_table", .func = ziglua.wrap(to_table) },
    .{ .name = "trim", .func = ziglua.wrap(trim) },
    .{ .name = "ltrim", .func = ziglua.wrap(ltrim_lib) },
    .{ .name = "rtrim", .func = ziglua.wrap(rtrim_lib) },
    .{ .name = "builder", .func = ziglua.wrap(BuilderUdata.new) },
    .{ .name = "joiner", .func = ziglua.wrap(JoinerUdata.new) },
};

const table_functions = [_]ziglua.FnReg{
    .{ .name = "next", .func = ziglua.wrap(next) },
    .{ .name = "insert_sorted", .func = ziglua.wrap(insert_sorted) },
    .{ .name = "concats", .func = ziglua.wrap(concats) },
    .{ .name = "spairs", .func = ziglua.wrap(spairs) },
    .{ .name = "comparator", .func = ziglua.wrap(comparator) },
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
    BuilderUdata.register(lua);
    JoinerUdata.register(lua);

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

fn ltrim_lib(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    _ = lua.pushBytes(std.mem.trimLeft(u8, str, char_to_strip));
    return 1;
}

fn rtrim_lib(lua: *Lua) i32 {
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
    var builder: Builder = Builder.init(allocator, 0) catch memoryError(lua);
    defer builder.deinit();

    const len: u64 = lua.rawLen(1);

    if (lua.isNoneOrNil(2)) {
        concats_simple(lua, &builder, len);
    } else {
        concats_separator(lua, &builder, len);
    }

    const str = builder.get() catch memoryError(lua);
    _ = lua.pushBytes(str);
    return 1;
}

fn concats_simple(lua: *Lua, builder: *Builder, len: u64) void {
    var i: i64 = 1;
    while (i <= len) : (i += 1) {
        _ = lua.getIndex(1, i);
        var string = lua.toBytesFmt(-1);
        builder.add(string) catch memoryError(lua);
        lua.pop(1);
    }
}

fn concats_separator(lua: *Lua, builder: *Builder, len: u64) void {
    const separator = lua.toBytesFmt(2);
    var i: i64 = 1;
    while (i <= len) : (i += 1) {
        _ = lua.getIndex(1, i);
        var string = lua.toBytesFmt(-1);
        builder.add(string) catch memoryError(lua);
        if (i < len) {
            builder.add(separator) catch memoryError(lua);
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

fn table_create(lua: *Lua) i32 {
    const num_arr: i32 = @intCast(luax.getArgIntegerOrError(lua, 1, "expecting number of array items"));
    const num_rec: i32 = @intCast(luax.getArgIntegerOrError(lua, 1, "expecting number of record items"));
    lua.createTable(num_arr, num_rec);
    return 1;
}

const BuilderUdata = struct {
    builder: Builder,
    const name = "_BuilderUdata";
    const functions = [_]ziglua.FnReg{
        .{ .name = "add", .func = ziglua.wrap(add) },
        .{ .name = "tostring", .func = ziglua.wrap(toString) },
        .{ .name = "clear", .func = ziglua.wrap(clear) },
        .{ .name = "len", .func = ziglua.wrap(len) },
        .{ .name = "isempty", .func = ziglua.wrap(isEmpty) },
    };

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, ziglua.wrap(garbageCollect));
    }

    fn new(lua: *Lua) i32 {
        const allocator = std.heap.c_allocator;
        const size = lua.optInteger(1, 0);

        const ud: *BuilderUdata = luax.createUserDataTableSetFunctions(lua, name, BuilderUdata, &functions);
        ud.builder = Builder.init(allocator, @intCast(size)) catch memoryError(lua);
        return 1;
    }

    fn garbageCollect(lua: *Lua) i32 {
        const ud: *BuilderUdata = luax.getGcUserData(lua, BuilderUdata);
        ud.builder.deinit();
        return 0;
    }

    fn add(lua: *Lua) i32 {
        const ud: *BuilderUdata = luax.getUserData(lua, name, BuilderUdata);
        const top = lua.getTop();
        var index: i32 = 2;
        while (index <= top) : (index += 1) {
            switch (lua.typeOf(index)) {
                .string, .number => {
                    const string = lua.toString(index) catch unreachable;
                    ud.builder.add(string[0..std.mem.len(string)]) catch memoryError(lua);
                },
                .boolean => {
                    if (lua.toBoolean(index)) {
                        ud.builder.add("true") catch memoryError(lua);
                    } else {
                        ud.builder.add("false") catch memoryError(lua);
                    }
                },
                .table => {
                    const udArg: *BuilderUdata = luax.getUserDataIndex(lua, name, BuilderUdata, index);
                    const string = udArg.builder.get() catch memoryError(lua);
                    ud.builder.add(string) catch memoryError(lua);
                },
                else => {
                    lua.argError(index, "expected string, number, boolean or string.builder");
                },
            }
        }
        lua.setTop(1);
        return 1;
    }

    fn toString(lua: *Lua) i32 {
        const ud: *BuilderUdata = luax.getUserData(lua, name, BuilderUdata);
        const string = ud.builder.get() catch memoryError(lua);
        _ = lua.pushString(string);
        return 1;
    }

    fn clear(lua: *Lua) i32 {
        const ud: *BuilderUdata = luax.getUserData(lua, name, BuilderUdata);
        ud.builder.clear();
        lua.setTop(1);
        return 1;
    }

    fn len(lua: *Lua) i32 {
        const ud: *BuilderUdata = luax.getUserData(lua, name, BuilderUdata);
        lua.pushInteger(@intCast(ud.builder.len));
        return 1;
    }

    fn isEmpty(lua: *Lua) i32 {
        const ud: *BuilderUdata = luax.getUserData(lua, name, BuilderUdata);
        lua.pushBoolean(ud.builder.isEmpty());
        return 1;
    }
};

const JoinerUdata = struct {
    joiner: Joiner,
    const name = "_JoinerUdata";
    const functions = [_]ziglua.FnReg{
        .{ .name = "add", .func = ziglua.wrap(add) },
        .{ .name = "tostring", .func = ziglua.wrap(toString) },
        .{ .name = "clear", .func = ziglua.wrap(clear) },
        .{ .name = "len", .func = ziglua.wrap(len) },
        .{ .name = "isempty", .func = ziglua.wrap(isEmpty) },
    };

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, ziglua.wrap(garbageCollect));
    }

    fn new(lua: *Lua) i32 {
        const allocator = std.heap.c_allocator;
        lua.argCheck(lua.isTable(1), 1, "expecting option table {prefix='',suffix='',delimiter='',size=0}");
        const options: JoinerOptions = .{
            .prefix = luax.getOptionString(lua, "prefix", 1, ""),
            .suffix = luax.getOptionString(lua, "suffix", 1, ""),
            .delimiter = luax.getOptionString(lua, "delimiter", 1, ""),
            .size = @intCast(luax.getOptionInteger(lua, "size", 1, 0)),
        };
        const ud: *JoinerUdata = luax.createUserDataTableSetFunctions(lua, name, JoinerUdata, &functions);
        ud.joiner = Joiner.init(allocator, options) catch memoryError(lua);
        return 1;
    }

    fn garbageCollect(lua: *Lua) i32 {
        const ud: *JoinerUdata = luax.getGcUserData(lua, JoinerUdata);
        ud.joiner.deinit();
        return 0;
    }

    fn add(lua: *Lua) i32 {
        const ud: *JoinerUdata = luax.getUserData(lua, name, JoinerUdata);
        const top = lua.getTop();
        var index: i32 = 2;
        while (index <= top) : (index += 1) {
            switch (lua.typeOf(index)) {
                .string, .number => {
                    const string = lua.toString(index) catch unreachable;
                    ud.joiner.add(string[0..std.mem.len(string)]) catch memoryError(lua);
                },
                .boolean => {
                    if (lua.toBoolean(index)) {
                        ud.joiner.add("true") catch memoryError(lua);
                    } else {
                        ud.joiner.add("false") catch memoryError(lua);
                    }
                },
                .table => {
                    const udArg: *JoinerUdata = luax.getUserDataIndex(lua, name, JoinerUdata, index);
                    const string = udArg.joiner.get() catch memoryError(lua);
                    ud.joiner.add(string) catch memoryError(lua);
                },
                else => {
                    lua.argError(index, "expected string, number, boolean or string.joiner");
                },
            }
        }
        lua.setTop(1);
        return 1;
    }

    fn toString(lua: *Lua) i32 {
        const ud: *JoinerUdata = luax.getUserData(lua, name, JoinerUdata);
        const string = ud.joiner.get() catch memoryError(lua);
        _ = lua.pushString(string);
        return 1;
    }

    fn clear(lua: *Lua) i32 {
        const ud: *JoinerUdata = luax.getUserData(lua, name, JoinerUdata);
        ud.joiner.clear();
        lua.setTop(1);
        return 1;
    }

    fn len(lua: *Lua) i32 {
        const ud: *JoinerUdata = luax.getUserData(lua, name, JoinerUdata);
        lua.pushInteger(@intCast(ud.joiner.len()));
        return 1;
    }

    fn isEmpty(lua: *Lua) i32 {
        const ud: *JoinerUdata = luax.getUserData(lua, name, JoinerUdata);
        lua.pushBoolean(ud.joiner.isEmpty());
        return 1;
    }
};

fn memoryError(lua: *Lua) noreturn {
    luax.raiseError(lua, "internal error: could not allocate memory");
}
