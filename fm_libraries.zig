const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lprefix.h"); //needed?
});

const lua_State = c.lua_State;
const luaL_Reg = c.luaL_Reg;
const lua_pushcclosure = c.lua_pushcclosure;
const lua_setfield = c.lua_setfield;
const lua_settop = c.lua_settop;
const luaL_getsubtable = c.luaL_getsubtable;
const luaL_requiref = c.luaL_requiref;
const lua_KContext = c_longlong;
const lua_KFunction = ?*const fn (?*lua_State, c_int, lua_KContext) callconv(.C) c_int;

pub extern fn luaopen_base(L: ?*lua_State) c_int;
pub extern fn luaopen_coroutine(L: ?*lua_State) c_int;
pub extern fn luaopen_table(L: ?*lua_State) c_int;
pub extern fn luaopen_io(L: ?*lua_State) c_int;
pub extern fn luaopen_os(L: ?*lua_State) c_int;
pub extern fn luaopen_string(L: ?*lua_State) c_int;
pub extern fn luaopen_utf8(L: ?*lua_State) c_int;
pub extern fn luaopen_math(L: ?*lua_State) c_int;
pub extern fn luaopen_debug(L: ?*lua_State) c_int;
pub extern fn luaopen_package(L: ?*lua_State) c_int;
pub extern fn luaopen_lsqlite3(L: ?*lua_State) c_int;
pub extern fn luaopen_lpeg(L: ?*lua_State) c_int;
pub extern fn luaopen_lfs(L: ?*lua_State) c_int;
pub extern fn luaopen_zlib(L: ?*lua_State) c_int;
pub extern fn luaopen_cjson(L: ?*lua_State) c_int;
pub extern fn luaopen_fmaux(L: ?*lua_State) c_int;
pub extern fn luaopen_fmcsv(L: ?*lua_State) c_int;
pub extern fn lua_tolstring(L: ?*lua_State, idx: c_int, len: [*c]usize) [*c]const u8;
pub extern fn luaL_loadbufferx(L: ?*lua_State, buff: [*c]const u8, sz: usize, name: [*c]const u8, mode: [*c]const u8) c_int;
pub extern fn luaL_error(L: ?*lua_State, fmt: [*c]const u8, ...) c_int;
pub extern fn lua_error(L: ?*lua_State) c_int;
pub extern fn lua_callk(L: ?*lua_State, nargs: c_int, nresults: c_int, ctx: lua_KContext, k: lua_KFunction) void;

const std = @import("std");
const strcmp = std.zig.c_builtins.__builtin_strcmp;

const loadedlibs: [11]luaL_Reg = [11]luaL_Reg{
    luaL_Reg{
        .name = "_G",
        .func = &luaopen_base,
    },
    luaL_Reg{
        .name = "package",
        .func = &luaopen_package,
    },
    luaL_Reg{
        .name = "coroutine",
        .func = &luaopen_coroutine,
    },
    luaL_Reg{
        .name = "table",
        .func = &luaopen_table,
    },
    luaL_Reg{
        .name = "io",
        .func = &luaopen_io,
    },
    luaL_Reg{
        .name = "os",
        .func = &luaopen_os,
    },
    luaL_Reg{
        .name = "string",
        .func = &luaopen_string,
    },
    luaL_Reg{
        .name = "math",
        .func = &luaopen_math,
    },
    luaL_Reg{
        .name = "utf8",
        .func = &luaopen_utf8,
    },
    luaL_Reg{
        .name = "debug",
        .func = &luaopen_debug,
    },
    luaL_Reg{
        .name = null,
        .func = null,
    },
};

const fullmoon_preload: [10]luaL_Reg = [10]luaL_Reg{
    luaL_Reg{
        .name = "sqlite3",
        .func = &luaopen_lsqlite3,
    },
    luaL_Reg{
        .name = "lpeg",
        .func = &luaopen_lpeg,
    },
    luaL_Reg{
        .name = "lfs",
        .func = &luaopen_lfs,
    },
    luaL_Reg{
        .name = "zlib",
        .func = &luaopen_zlib,
    },
    luaL_Reg{
        .name = "aux",
        .func = &luaopen_fmaux,
    },
    luaL_Reg{
        .name = "csv",
        .func = &luaopen_fmcsv,
    },
    luaL_Reg{
        .name = "cjson",
        .func = &luaopen_cjson,
    },
    luaL_Reg{
        .name = "luaunit",
        .func = &luaopen_luascript,
    },
    luaL_Reg{
        .name = "re",
        .func = &luaopen_luascript,
    },
    luaL_Reg{
        .name = null,
        .func = null,
    },
};

pub export fn luaL_openlibs(arg_L: ?*lua_State) callconv(.C) void {
    var L = arg_L;
    var lib: [*c]const luaL_Reg = undefined;
    {
        lib = @ptrCast([*c]const luaL_Reg, @alignCast(@import("std").meta.alignment([*c]const luaL_Reg), &loadedlibs));
        while (lib.*.func != null) : (lib += 1) {
            luaL_requiref(L, lib.*.name, lib.*.func, @as(c_int, 1));
            lua_settop(L, -@as(c_int, 1) - @as(c_int, 1));
        }
    }
    _ = luaL_getsubtable(L, -@as(c_int, 1000000) - @as(c_int, 1000), "_PRELOAD");
    {
        lib = @ptrCast([*c]const luaL_Reg, @alignCast(@import("std").meta.alignment([*c]const luaL_Reg), &fullmoon_preload));
        while (lib.*.func != null) : (lib += 1) {
            lua_pushcclosure(L, lib.*.func, @as(c_int, 0));
            lua_setfield(L, -@as(c_int, 2), lib.*.name);
        }
    }
    lua_settop(L, -@as(c_int, 1) - @as(c_int, 1));
}

const luaunit_lua = @embedFile("luaunit/luaunit.lua");
const re_lua = @embedFile("lpeg/re.lua");

fn luaopen_luascript(arg_L: ?*lua_State) callconv(.C) c_int {
    var L = arg_L;
    const modname: [*c]const u8 = lua_tolstring(L, @as(c_int, 1), null);
    var result: c_int = 1;
    if (strcmp(modname, "luaunit") == @as(c_int, 0)) {
        result = luaL_loadbufferx(L, luaunit_lua, luaunit_lua.len, "luaunit", "t");
    } else if (strcmp(modname, "re") == @as(c_int, 0)) {
        result = luaL_loadbufferx(L, re_lua, re_lua.len, "re", "t");
    } else {
        return luaL_error(L, "unknown module \"%s\"", modname);
    }
    if (result != @as(c_int, 0)) {
        return lua_error(L);
    }
    lua_callk(L, @as(c_int, 0), @as(c_int, 1), @bitCast(lua_KContext, @as(c_longlong, @as(c_int, 0))), null);
    return 1;
}
