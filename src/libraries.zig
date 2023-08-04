const ziglua = @import("ziglua");
const Lua = ziglua.Lua;

const crossline = @import("crossline.zig");
const auxiliary = @import("auxiliary.zig");

pub extern fn luaopen_lsqlite3(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_lpeg(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_lfs(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_zlib(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_cjson(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_sbuilder(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_zip(state: ?*ziglua.LuaState) callconv(.C) c_int;

const std = @import("std");
const strcmp = std.zig.c_builtins.__builtin_strcmp;
const strlen = std.zig.c_builtins.__builtin_strlen;

const preload = [_]ziglua.FnReg{
    .{
        .name = "sqlite3",
        .func = &luaopen_lsqlite3,
    },
    .{
        .name = "lpeg",
        .func = &luaopen_lpeg,
    },
    .{
        .name = "lfs",
        .func = &luaopen_lfs,
    },
    .{
        .name = "zlib",
        .func = &luaopen_zlib,
    },
    .{
        .name = "cjson",
        .func = &luaopen_cjson,
    },
    .{
        .name = "luaunit",
        .func = ziglua.wrap(luaopen_luascript),
    },
    .{
        .name = "re",
        .func = ziglua.wrap(luaopen_luascript),
    },
    .{
        .name = "string_builder",
        .func = &luaopen_sbuilder,
    },
    .{
        .name = "zip",
        .func = &luaopen_zip,
    },
    .{
        .name = "crossline",
        .func = crossline.luaopen_crossline,
    },
};

const luascript = struct {
    name: [:0]const u8,
    source: [:0]const u8,
};

const luascripts = [_]luascript{
    .{ .name = "luaunit", .source = @embedFile("stripped/luaunit.lua") },
    .{ .name = "re", .source = @embedFile("stripped/re.lua") },
    .{ .name = "argparse", .source = @embedFile("stripped/argparse.lua") },
    .{ .name = "log", .source = @embedFile("stripped/logger.lua") },
    .{ .name = "repl", .source = @embedFile("stripped/repl.lua") },
    .{ .name = "sqlite_cli", .source = @embedFile("stripped/sqlite_cli.lua") },
    .{ .name = "stream", .source = @embedFile("stripped/stream.lua") },
    .{ .name = "serpent", .source = @embedFile("stripped/serpent.lua") },
    .{ .name = "csv", .source = @embedFile("stripped/ftcsv.lua") },
};

pub fn openlibs(lua: *Lua) i32 {
    lua.openLibs();

    lua.getSubtable(ziglua.registry_index, "_PRELOAD") catch unreachable; //todo: fix: no LUA_PRELOAD_TABLE in ziglua
    for (preload) |lib| {
        if (lib.func) |func| {
            lua.pushClosure(func, 0);
            lua.setField(-2, lib.name);
        }
    }

    for (luascripts) |script| {
        lua.pushClosure(ziglua.wrap(luaopen_luascript), 0);
        lua.setField(-2, script.name);
    }
    lua.setTop(0);

    auxiliary.register(lua);
    return 0;
}

fn luaopen_luascript(lua: *Lua) i32 {
    const modname = lua.toBytes(1) catch unreachable;
    for (luascripts) |script| {
        if (strcmp(modname, script.name) == 0) {
            lua.loadBuffer(script.source, modname, ziglua.Mode.text) catch lua.raiseError();
            lua.callCont(0, 1, 0, null);
            return 1;
        }
    }

    const modname1 = lua.toString(1) catch unreachable; //todo: fix: is there a way to not get the string twice, once with toBytes and once with toString
    return lua.raiseErrorStr("unknown module \"%s\"", .{modname1});
}