const std = @import("std");
const zlua = @import("zlua");
const strip = @import("strip.zig");
const luax = @import("luax.zig");
const Lua = zlua.Lua;
const luaerror = @import("luaerror.zig");
const filesystem = @import("filesystem.zig");

const exported_functions = [_]zlua.FnReg{
    .{ .name = "file", .func = luaerror.wrap(file) },
    .{ .name = "string", .func = luaerror.wrap(string) },
    .{ .name = "config", .func = luaerror.wrap(setConfig) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

const Config = struct {
    errorHandling: luaerror.Handling = undefined,
};

pub fn register(lua: *Lua) !i32 {
    var config = setup(lua);
    config.errorHandling = luaerror.getGlobalHanding(lua);
    return 1;
}

fn setup(lua: *Lua) *Config {
    lua.newLibTable(&exported_functions);
    const udata = lua.newUserdata(Config, 0);
    lua.setFuncs(&exported_functions, 1);
    return udata;
}

pub fn setConfig(lua: *Lua) !i32 {
    lua.checkType(1, .table);
    var config = setup(lua);

    if (luax.getOptionalString(lua, "error_handling", 1)) |error_handling| {
        config.errorHandling = try luaerror.getHandling(error_handling);
    }
    return 1;
}

fn get_error_handling(lua: *Lua) !luaerror.Handling {
    const config = try lua.toUserdata(Config, Lua.upvalueIndex(1));
    return config.errorHandling;
}

fn file(lua: *Lua) !i32 {
    const source = try filesystem.get_path_index(lua, 1);
    const output = try filesystem.get_path_index(lua, 2);

    strip.file(io, source, output, lua.allocator()) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not strip '{s}' to '{s}': {any}", .{ source, output, err }, try get_error_handling(lua));

    lua.pushBoolean(true);
    return 1;
}

fn string(lua: *Lua) !i32 {
    const source = luax.getArgStringOrError(lua, 1, "expecting lua source string as 1st argument");
    const output = strip.strip(source, lua.allocator()) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not strip lua source: {any}", .{err}, try get_error_handling(lua));

    _ = lua.pushString(output);
    return 1;
}
