const std = @import("std");
const zlua = @import("zlua");
const strip = @import("zigLuaStrip");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const luaStrip = [_]zlua.FnReg{
    .{ .name = "file", .func = zlua.wrap(file) },
    .{ .name = "string", .func = zlua.wrap(string) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

pub fn luaopen_luaStrip(lua: *Lua) i32 {
    lua.newLib(&luaStrip);
    return 1;
}

fn file(lua: *Lua) i32 {
    const source = luax.getArgStringOrError(lua, 1, "expecting source file as 1st argument");
    const output = luax.getArgStringOrError(lua, 2, "expecting output file as 2nd argument");

    strip.file(io, source, output, lua.allocator()) catch return luax.raiseError(lua, "could not strip output");

    lua.pushBoolean(true);
    return 1;
}

fn string(lua: *Lua) i32 {
    const source = luax.getArgStringOrError(lua, 1, "expecting lua source string as 1st argument");
    const output = strip.strip(source, lua.allocator()) catch return luax.raiseError(lua, "could not strip output");
    _ = lua.pushString(output);
    return 1;
}
