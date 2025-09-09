const zlua = @import("zlua");
const Lua = zlua.Lua;

const crossline = @import("crossline.zig");
const auxiliary = @import("auxiliary.zig");
const filesystem = @import("filesystem.zig");
const unzip = @import("unzip.zig");
const zip = @import("zip.zig");
const httpclient = @import("httpclient.zig");
const httpserver = @import("httpserver.zig");

pub extern fn luaopen_lsqlite3(state: ?*zlua.LuaState) callconv(.c) c_int;
pub extern fn luaopen_lpeg(state: ?*zlua.LuaState) callconv(.c) c_int;
pub extern fn luaopen_zlib(state: ?*zlua.LuaState) callconv(.c) c_int;
pub extern fn luaopen_cjson(state: ?*zlua.LuaState) callconv(.c) c_int;

const std = @import("std");
const strcmp = std.zig.c_builtins.__builtin_strcmp;
const strlen = std.zig.c_builtins.__builtin_strlen;

const preload: []const zlua.FnReg = &.{
    .{
        .name = "sqlite3",
        .func = &luaopen_lsqlite3,
    },
    .{
        .name = "lpeg",
        .func = &luaopen_lpeg,
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
        .func = zlua.wrap(luaopen_luascript),
    },
    .{
        .name = "re",
        .func = zlua.wrap(luaopen_luascript),
    },
    .{
        .name = "crossline",
        .func = zlua.wrap(crossline.luaopen_crossline),
    },
    .{
        .name = "filesystem",
        .func = zlua.wrap(filesystem.luaopen_filesystem),
    },
    .{
        .name = "unzip",
        .func = zlua.wrap(unzip.luaopen_unzip),
    },
    .{
        .name = "zip",
        .func = zlua.wrap(zip.luaopen_zip),
    },
    .{
        .name = "httpclient",
        .func = zlua.wrap(httpclient.luaopen_httpclient),
    },
    .{
        .name = "httpserver",
        .func = zlua.wrap(httpserver.luaopen_httpserver),
    },
};

const luascript = struct {
    name: [:0]const u8,
    source: [:0]const u8,
};

const luascripts: []const luascript = &.{
    .{ .name = "argparse", .source = @embedFile("stripped/argparse.lua") },
    .{ .name = "collection", .source = @embedFile("stripped/collection.init.lua") },
    .{ .name = "collection.set", .source = @embedFile("stripped/collection.set.lua") },
    .{ .name = "collection.list", .source = @embedFile("stripped/collection.list.lua") },
    .{ .name = "collection.map", .source = @embedFile("stripped/collection.map.lua") },
    .{ .name = "compile", .source = @embedFile("stripped/compile.lua") },
    .{ .name = "csv", .source = @embedFile("stripped/ftcsv.lua") },
    .{ .name = "F", .source = @embedFile("stripped/F.lua") },
    .{ .name = "log", .source = @embedFile("stripped/logger.lua") },
    .{ .name = "luaunit", .source = @embedFile("stripped/luaunit.lua") },
    .{ .name = "re", .source = @embedFile("stripped/re.lua") },
    .{ .name = "repl", .source = @embedFile("stripped/repl.lua") },
    .{ .name = "serpent", .source = @embedFile("stripped/serpent.lua") },
    .{ .name = "sqlite_cli", .source = @embedFile("stripped/sqlite_cli.lua") },
    .{ .name = "stream", .source = @embedFile("stripped/stream.lua") },
    .{ .name = "timer", .source = @embedFile("stripped/timer.lua") },
    .{ .name = "benchmark", .source = @embedFile("stripped/benchmark.lua") },
    .{ .name = "grid", .source = @embedFile("stripped/grid.lua") },
    .{ .name = "memoize", .source = @embedFile("stripped/memoize.lua") },
};

pub fn openlibs(lua: *Lua) i32 {
    lua.openLibs();

    _ = lua.getSubtable(zlua.registry_index, "_PRELOAD");
    for (preload) |lib| {
        if (lib.func) |func| {
            lua.pushClosure(func, 0);
            lua.setField(-2, lib.name);
        }
    }

    for (luascripts) |script| {
        lua.pushClosure(zlua.wrap(luaopen_luascript), 0);
        lua.setField(-2, script.name);
    }
    lua.setTop(0);

    auxiliary.register(lua);
    return 0;
}

fn luaopen_luascript(lua: *Lua) i32 {
    const modname = lua.toString(1) catch unreachable;
    for (luascripts) |script| {
        if (strcmp(modname, script.name) == 0) {
            lua.loadBuffer(script.source, modname, zlua.Mode.text) catch lua.raiseError();
            lua.call(.{ .args = 0, .results = 1 });
            return 1;
        }
    }
    return lua.raiseErrorStr("unknown module \"%s\"", .{&modname});
}
