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

const std = @import("std");
const strcmp = std.zig.c_builtins.__builtin_strcmp;
const strlen = std.zig.c_builtins.__builtin_strlen;

const loadedlibs: [11]c.luaL_Reg = [11]c.luaL_Reg{
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
    c.luaL_Reg{
        .name = null,
        .func = null,
    },
};

const fullmoon_preload: [10]c.luaL_Reg = [10]c.luaL_Reg{
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
        .name = null,
        .func = null,
    },
};

const luascript = extern struct {
    name: [*c]const u8,
    script: [*c]const u8,
};

const luascripts = [_]luascript{
    luascript{ .name = "luaunit", .script = @embedFile("luaunit/luaunit.lua") },
    luascript{ .name = "re", .script = @embedFile("lpeg/re.lua") },
};

pub export fn luaL_openlibs(arg_L: ?*c.lua_State) callconv(.C) void {
    var L = arg_L;
    var lib: [*c]const c.luaL_Reg = undefined;

    lib = @ptrCast([*c]const c.luaL_Reg, @alignCast(@import("std").meta.alignment([*c]const c.luaL_Reg), &loadedlibs));
    while (lib.*.func != null) : (lib += 1) {
        c.luaL_requiref(L, lib.*.name, lib.*.func, 1);
        c.lua_settop(L, -1 - 1);
    }

    _ = c.luaL_getsubtable(L, c.LUA_REGISTRYINDEX, c.LUA_PRELOAD_TABLE);
    lib = @ptrCast([*c]const c.luaL_Reg, @alignCast(@import("std").meta.alignment([*c]const c.luaL_Reg), &fullmoon_preload));
    while (lib.*.func != null) : (lib += 1) {
        c.lua_pushcclosure(L, lib.*.func, 0);
        c.lua_setfield(L, -2, lib.*.name);
    }
    c.lua_settop(L, -1 - 1);
}

fn luaopen_luascript(L: ?*c.lua_State) callconv(.C) c_int {
    const modname = c.lua_tolstring(L, 1, null);

    for (luascripts) |lua| {
        if (strcmp(modname, lua.name) == 0) {
            var result: c_int = c.luaL_loadbufferx(L, lua.script, strlen(lua.script), modname, "t");
            if (result != 0) {
                return c.lua_error(L);
            }
            c.lua_callk(L, 0, 1, @bitCast(c.lua_KContext, @as(c_longlong, 0)), null);
            return 1;
        }
    }
    return c.luaL_error(L, "unknown module \"%s\"", modname);
}
