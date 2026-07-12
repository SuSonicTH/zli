const std = @import("std");
const zlua = @import("zlua");
const strip = @import("strip.zig");
const luax = @import("luax.zig");
const Lua = zlua.Lua;
const luaerror = @import("luaerror.zig");
const filesystem = @import("filesystem.zig");

const luaStrip = [_]zlua.FnReg{
    .{ .name = "file", .func = luaerror.wrap(file) },
    .{ .name = "string", .func = luaerror.wrap(string) },
    .{ .name = "error_handling", .func = luaerror.wrap(error_handling) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

var errorHandling: luaerror.Handling = undefined;

pub fn luaopen_luaStrip(lua: *Lua) i32 {
    lua.newLib(&luaStrip);
    return 1;
}

pub fn error_handling(lua: *Lua) !i32 {
    errorHandling = try luaerror.getErrorHandling(lua);
    return 0;
}

fn file(lua: *Lua) !i32 {
    const source = filesystem.get_path_index(lua, 1);
    const output = filesystem.get_path_index(lua, 2);

    strip.file(io, source, output, lua.allocator()) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not strip '{s}' to '{s}': {any}", .{ source, output, err }, errorHandling);

    lua.pushBoolean(true);
    return 1;
}

fn string(lua: *Lua) !i32 {
    const source = luax.getArgStringOrError(lua, 1, "expecting lua source string as 1st argument");
    const output = strip.strip(source, lua.allocator()) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not strip lua source: {any}", .{err}, errorHandling);

    _ = lua.pushString(output);
    return 1;
}
