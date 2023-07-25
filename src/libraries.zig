//const ziglua = @import("ziglua");
const ziglua = @import("lib/ziglua/src/ziglua-5.4/lib.zig");
const Lua = ziglua.Lua;

const crossline = @import("crossline.zig");
const auxiliary = @import("auxiliary.zig");

pub extern fn luaopen_lsqlite3(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_lpeg(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_lfs(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_zlib(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_cjson(state: ?*ziglua.LuaState) callconv(.C) c_int;
pub extern fn luaopen_csv(state: ?*ziglua.LuaState) callconv(.C) c_int;
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
        .name = "csv",
        .func = &luaopen_csv,
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

//const FnRegExt = struct {
//    name: [:0]const u8,
//    func: ziglua.CFn,
//    extend: [:0]const u8,
//};

//const preload_extended = [_]FnRegExt{
//    .{ .name = "crossline", .func = &luaopen_fmcrossline, .extend = @embedFile("crossline.lua") },
//};

const luascript = struct {
    name: [:0]const u8,
    source: [:0]const u8,
};

const luascripts = [_]luascript{
    .{ .name = "luaunit", .source = @embedFile("lib/luaunit/luaunit.lua") },
    .{ .name = "re", .source = @embedFile("lib/lpeg/re.lua") },
    .{ .name = "argparse", .source = @embedFile("lib/argparse/src/argparse.lua") },
    .{ .name = "log", .source = @embedFile("logger.lua") },
    .{ .name = "repl", .source = @embedFile("tools/repl.lua") },
    .{ .name = "sqlite_cli", .source = @embedFile("tools/sqlite_cli.lua") },
    .{ .name = "stream", .source = @embedFile("stream.lua") },
    .{ .name = "serpent", .source = @embedFile("lib/serpent/src/serpent.lua") },
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

    //for (preload_extended) |lib_ex| {
    //    lua.pushClosure(ziglua.wrap(luaopen_extended), 0);
    //    lua.setField(-2, lib_ex.name);
    //}

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

//fn luaopen_extended(lua: *Lua) i32 {
//    const modname = lua.toBytes(1) catch unreachable;
//
//    for (preload_extended) |lib| {
//        if (strcmp(modname, lib.name) == 0) {
//            lua.pushClosure(lib.func, 0);
//            lua.callCont(0, 1, 0, null);
//            if (lua.isNil(-1)) {
//                return 1;
//            }
//
//            lua.loadBuffer(lib.extend, modname, ziglua.Mode.text) catch lua.raiseError();
//            lua.callCont(0, 1, 0, null);
//            lua.checkType(-1, ziglua.LuaType.function);
//            lua.pushValue(-2);
//            lua.callCont(1, 0, 0, null);
//            return 1;
//        }
//    }
//
//    const modname1 = lua.toString(1) catch unreachable; //todo: fix: is there a way to not get the string twice, once with toBytes and once with toString
//    return lua.raiseErrorStr("unknown module \"%s\"", .{modname1});
//}
