const std = @import("std");

const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const builtin = @import("builtin");

const timer = @cImport({
    @cInclude("timer.h");
});

const string_functions = [_]zlua.FnReg{
    .{ .name = "split", .func = zlua.wrap(split) },
    .{ .name = "to_table", .func = zlua.wrap(to_table) },
    .{ .name = "trim", .func = zlua.wrap(trim) },
    .{ .name = "ltrim", .func = zlua.wrap(ltrim) },
    .{ .name = "rtrim", .func = zlua.wrap(rtrim) },
    .{ .name = "base64encode", .func = zlua.wrap(base64encode) },
    .{ .name = "base64decode", .func = zlua.wrap(base64decode) },
    .{ .name = "base64urlEncode", .func = zlua.wrap(base64urlEncode) },
    .{ .name = "base64urlDecode", .func = zlua.wrap(base64urlDecode) },
    .{ .name = "urlEecode", .func = zlua.wrap(urlEecode) },
    .{ .name = "utf8len", .func = zlua.wrap(utf8len) },
};

const table_functions = [_]zlua.FnReg{
    .{ .name = "next", .func = zlua.wrap(next) },
};

const os_functions = [_]zlua.FnReg{
    .{ .name = "get_name", .func = zlua.wrap(os_get_name) },
    .{ .name = "nanotime", .func = zlua.wrap(nanotime) },
};

pub fn register(lua: *Lua) void {
    register_module(lua, "string", &string_functions);
    register_module(lua, "table", &table_functions);
    register_module(lua, "os", &os_functions);

    lua.loadBuffer(@embedFile("auxiliary.lua"), "auxiliary", zlua.Mode.text) catch lua.raiseError();
    lua.call(.{ .args = 0, .results = 0 });
}

fn register_module(lua: *Lua, module: [:0]const u8, functions: []const zlua.FnReg) void {
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
    const delim = std.mem.sliceTo(lua.optString(2) orelse ",", 0);

    var count: i32 = 0;
    var it = std.mem.splitSequence(u8, str, delim);
    while (it.next()) |item| {
        _ = lua.pushString(item);
        count += 1;
    }
    return count;
}

fn to_table(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    const delim = std.mem.sliceTo(lua.optString(2) orelse ",", 0);

    lua.newTable();
    const table = lua.getTop();

    var index: i32 = 1;
    var it = std.mem.splitSequence(u8, str, delim);
    while (it.next()) |item| {
        _ = lua.pushString(item);
        lua.rawSetIndex(table, index);
        index += 1;
    }
    return 1;
}

const char_to_strip = " \t\r\n\x00";

fn trim(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    const ltrimmed = std.mem.trimLeft(u8, str, char_to_strip);
    _ = lua.pushString(std.mem.trimRight(u8, ltrimmed, char_to_strip));
    return 1;
}

fn ltrim(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    _ = lua.pushString(std.mem.trimLeft(u8, str, char_to_strip));
    return 1;
}

fn rtrim(lua: *Lua) i32 {
    const str = std.mem.sliceTo(lua.checkString(1), 0);
    _ = lua.pushString(std.mem.trimRight(u8, str, char_to_strip));
    return 1;
}

fn base64encode(lua: *Lua) i32 {
    return base64enc(lua, std.base64.standard.Encoder);
}

fn base64urlEncode(lua: *Lua) i32 {
    return base64enc(lua, std.base64.url_safe.Encoder);
}

fn base64enc(lua: *Lua, encoder: std.base64.Base64Encoder) i32 {
    const string = lua.toString(1) catch luax.raiseError(lua, "could not get string argument");
    const buffer = lua.allocator().alloc(u8, encoder.calcSize(string.len)) catch luax.raiseError(lua, "could not allocate memory");
    defer lua.allocator().free(buffer);

    const encoded = encoder.encode(buffer, string);
    _ = lua.pushString(encoded);
    return 1;
}

fn base64decode(lua: *Lua) i32 {
    return base64dec(lua, std.base64.standard.Decoder);
}

fn base64urlDecode(lua: *Lua) i32 {
    return base64dec(lua, std.base64.url_safe.Decoder);
}

fn base64dec(lua: *Lua, decoder: std.base64.Base64Decoder) i32 {
    const string = lua.toString(1) catch luax.raiseError(lua, "could not get string argument");
    const bufferSize = decoder.calcSizeForSlice(string) catch luax.raiseError(lua, "could not decode string");
    const buffer = lua.allocator().alloc(u8, bufferSize) catch luax.raiseError(lua, "could not allocate memory");
    defer lua.allocator().free(buffer);

    decoder.decode(buffer, string) catch luax.raiseError(lua, "could not decode string");
    _ = lua.pushString(buffer[0..buffer.len]);
    return 1;
}

fn urlEecode(lua: *Lua) i32 {
    const string = lua.toString(1) catch luax.raiseError(lua, "could not get string argument");
    var lua_buffer: zlua.Buffer = undefined;
    var buffer: [3]u8 = undefined;
    var start: usize = 0;

    for (string, 0..) |char, index| {
        switch (char) {
            'a'...'z', 'A'...'Z', '0'...'9' => continue,
            else => {
                if (start == 0) {
                    _ = lua_buffer.initSize(lua, @intFromFloat(@as(f64, @floatFromInt(string.len)) * 1.2));
                }
                lua_buffer.addString(string[start..index]);
                lua_buffer.addString(std.fmt.bufPrint(&buffer, "%{X:0>2}", .{char}) catch luax.raiseError(lua, "could not urlEncode string"));
                start = index + 1;
            },
        }
    }
    if (start > 0) {
        lua_buffer.addString(string[start..string.len]);
        lua_buffer.pushResult();
    }
    return 1;
}

fn utf8len(lua: *Lua) i32 {
    const string = lua.toString(1) catch luax.raiseError(lua, "could not get string argument");
    const len = std.unicode.utf8CountCodepoints(string) catch luax.raiseError(lua, "could not count codepoints (invalid utf8?)");
    lua.pushInteger(@bitCast(len));
    return 1;
}

fn next(lua: *Lua) i32 {
    lua.checkType(1, .table);
    lua.pushValue(1);
    lua.pushInteger(1);
    lua.pushClosure(zlua.wrap(next_function), 2);
    return 1;
}

fn next_function(lua: *Lua) i32 {
    const index = lua.toInteger(Lua.upvalueIndex(2)) catch unreachable;
    _ = lua.getIndex(Lua.upvalueIndex(1), @intCast(index));
    lua.pushInteger(index + 1);
    lua.replace(Lua.upvalueIndex(2));
    return 1;
}

fn memoryError(lua: *Lua) noreturn {
    luax.raiseError(lua, "internal error: could not allocate memory");
}
