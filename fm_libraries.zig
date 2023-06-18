const c = @cImport({
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

pub extern fn luaopen_lsqlite3(L: ?*c.lua_State) c_int;
pub extern fn luaopen_lpeg(L: ?*c.lua_State) c_int;
pub extern fn luaopen_lfs(L: ?*c.lua_State) c_int;
pub extern fn luaopen_zlib(L: ?*c.lua_State) c_int;
pub extern fn luaopen_cjson(L: ?*c.lua_State) c_int;
pub extern fn luaopen_fmaux(L: ?*c.lua_State) c_int;
pub extern fn luaopen_fmcsv(L: ?*c.lua_State) c_int;
pub extern fn luaopen_fmcrossline(L: ?*c.lua_State) c_int;
pub extern fn luaopen_fmsbuilder(L: ?*c.lua_State) c_int;
pub extern fn luaopen_fmzip(L: ?*c.lua_State) c_int;

const std = @import("std");
const strcmp = std.zig.c_builtins.__builtin_strcmp;
const strlen = std.zig.c_builtins.__builtin_strlen;

const loadedlibs = [_]c.luaL_Reg{
    c.luaL_Reg{
        .name = "_G",
        .func = &c.luaopen_base,
    },
    c.luaL_Reg{
        .name = "package",
        .func = &c.luaopen_package,
    },
    c.luaL_Reg{
        .name = "coroutine",
        .func = &c.luaopen_coroutine,
    },
    c.luaL_Reg{
        .name = "table",
        .func = &c.luaopen_table,
    },
    c.luaL_Reg{
        .name = "io",
        .func = &c.luaopen_io,
    },
    c.luaL_Reg{
        .name = "os",
        .func = &c.luaopen_os,
    },
    c.luaL_Reg{
        .name = "string",
        .func = &c.luaopen_string,
    },
    c.luaL_Reg{
        .name = "math",
        .func = &c.luaopen_math,
    },
    c.luaL_Reg{
        .name = "utf8",
        .func = &c.luaopen_utf8,
    },
    c.luaL_Reg{
        .name = "debug",
        .func = &c.luaopen_debug,
    },
};

const fullmoon_preload = [_]c.luaL_Reg{
    c.luaL_Reg{
        .name = "sqlite3",
        .func = &luaopen_lsqlite3,
    },
    c.luaL_Reg{
        .name = "lpeg",
        .func = &luaopen_lpeg,
    },
    c.luaL_Reg{
        .name = "lfs",
        .func = &luaopen_lfs,
    },
    c.luaL_Reg{
        .name = "zlib",
        .func = &luaopen_zlib,
    },
    c.luaL_Reg{
        .name = "aux",
        .func = &luaopen_fmaux,
    },
    c.luaL_Reg{
        .name = "csv",
        .func = &luaopen_fmcsv,
    },
    c.luaL_Reg{
        .name = "cjson",
        .func = &luaopen_cjson,
    },
    c.luaL_Reg{
        .name = "luaunit",
        .func = &luaopen_luascript,
    },
    c.luaL_Reg{
        .name = "re",
        .func = &luaopen_luascript,
    },
    c.luaL_Reg{
        .name = "string_builder",
        .func = &luaopen_fmsbuilder,
    },
    c.luaL_Reg{
        .name = "zip",
        .func = &luaopen_fmzip,
    },
};

const luaL_RegExt = extern struct {
    name: [*c]const u8,
    func: c.lua_CFunction,
    extend: [*c]const u8,
};

const fullmoon_preload_extended = [_]luaL_RegExt{
    luaL_RegExt{ .name = "crossline", .func = &luaopen_fmcrossline, .extend = @embedFile("fm_crossline.lua") },
};

const luascript = struct {
    name: [*c]const u8,
    script: [*c]const u8,
};

const luascripts = [_]luascript{
    luascript{ .name = "luaunit", .script = @embedFile("luaunit/luaunit.lua") },
    luascript{ .name = "re", .script = @embedFile("lpeg/re.lua") },
    luascript{ .name = "argparse", .script = @embedFile("argparse/src/argparse.lua") },
    luascript{ .name = "log", .script = @embedFile("fm_log.lua") },
    luascript{ .name = "repl", .script = @embedFile("fm_repl.lua") },
    luascript{ .name = "sqlite_cli", .script = @embedFile("fm_sqlite_cli.lua") },
};

export const fullmoon_main: [*c]const u8 = @embedFile("fullmoon.lua");

pub export fn luaL_openlibs(arg_L: ?*c.lua_State) callconv(.C) void {
    var L = arg_L;

    for (loadedlibs) |lib| {
        c.luaL_requiref(L, lib.name, lib.func, 1);
        c.lua_pop(L, 1);
    }

    _ = c.luaL_getsubtable(L, c.LUA_REGISTRYINDEX, c.LUA_PRELOAD_TABLE);
    for (fullmoon_preload) |fm_lib| {
        c.lua_pushcfunction(L, fm_lib.func);
        c.lua_setfield(L, -2, fm_lib.name);
    }

    for (fullmoon_preload_extended) |fm_lib_ex| {
        c.lua_pushcclosure(L, luaopen_extended, 0);
        c.lua_setfield(L, -2, fm_lib_ex.name);
    }

    for (luascripts) |lua| {
        c.lua_pushcclosure(L, luaopen_luascript, 0);
        c.lua_setfield(L, -2, lua.name);
    }
}

fn luaopen_luascript(L: ?*c.lua_State) callconv(.C) c_int {
    const modname = c.lua_tolstring(L, 1, null);

    for (luascripts) |lua| {
        if (strcmp(modname, lua.name) == 0) {
            var result: c_int = c.luaL_loadbufferx(L, lua.script, strlen(lua.script), modname, "t");
            if (result != 0) {
                return c.lua_error(L);
            }
            c.lua_callk(L, 0, 1, 0, null);
            return 1;
        }
    }
    return c.luaL_error(L, "unknown module \"%s\"", modname);
}

fn luaopen_extended(L: ?*c.lua_State) callconv(.C) c_int {
    const modname = c.lua_tolstring(L, 1, null);

    for (fullmoon_preload_extended) |lib| {
        if (strcmp(modname, lib.name) == 0) {
            c.lua_pushcfunction(L, lib.func);
            c.lua_callk(L, 0, 1, 0, null);
            if (c.lua_isnil(L, -1)) {
                return 1;
            }

            var result: c_int = c.luaL_loadbufferx(L, lib.extend, strlen(lib.extend), modname, "t");
            if (result != 0) {
                return c.lua_error(L);
            }
            c.lua_callk(L, 0, 1, 0, null);
            c.luaL_checktype(L, -1, c.LUA_TFUNCTION);
            c.lua_pushvalue(L, -2);
            c.lua_callk(L, 1, 0, 0, null);
            return 1;
        }
    }
    return c.luaL_error(L, "unknown module \"%s\"", modname);
}
