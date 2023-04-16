/*
** $Id: linit.c $
** Initialization of libraries for lua.c and other clients
** See Copyright Notice in lua.h
*/

#define linit_c
#define LUA_LIB

/*
** If you embed Lua in your program and need to open the standard
** libraries, call luaL_openlibs in your program. If you need a
** different set of libraries, copy this file to your project and edit
** it to suit your needs.
**
** You can also *preload* libraries, so that a later 'require' can
** open the library, which is already linked to the application.
** For that, do the following code:
**
**  luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
**  lua_pushcfunction(L, luaopen_modname);
**  lua_setfield(L, -2, modname);
**  lua_pop(L, 1);  // remove PRELOAD table
*/

#include <stddef.h>
#include <string.h>
#include "lauxlib.h"
#include "lprefix.h"
#include "lua.h"
#include "lualib.h"

#include "luaunit.h"
#include "re.h"

/*
** these libs are loaded by lua.c and are readily available to any Lua
** program
*/
static const luaL_Reg loadedlibs[] = {
    {LUA_GNAME, luaopen_base},
    {LUA_LOADLIBNAME, luaopen_package},
    {LUA_COLIBNAME, luaopen_coroutine},
    {LUA_TABLIBNAME, luaopen_table},
    {LUA_IOLIBNAME, luaopen_io},
    {LUA_OSLIBNAME, luaopen_os},
    {LUA_STRLIBNAME, luaopen_string},
    {LUA_MATHLIBNAME, luaopen_math},
    {LUA_UTF8LIBNAME, luaopen_utf8},
    {LUA_DBLIBNAME, luaopen_debug},
    {NULL, NULL}};

static int luaopen_luascript(lua_State *L);

// fullmoon libraries preloaded ready to require
static const luaL_Reg fullmoon_preload[] = {
    {LUA_SQLIT3LIBNAME, luaopen_lsqlite3},
    {LUA_LPEGLIBNAME, luaopen_lpeg},
    {LUA_LFSLIBNAME, luaopen_lfs},
    {LUA_ZLIBLIBNAME, luaopen_zlib},
    {LUA_FMAUXLIBNAME, luaopen_lwaux},
    {"luaunit", luaopen_luascript},
    {"re", luaopen_luascript},
    {NULL, NULL}};

LUALIB_API void luaL_openlibs(lua_State *L) {
    const luaL_Reg *lib;
    /* "require" functions from 'loadedlibs' and set results to global table */
    for (lib = loadedlibs; lib->func; lib++) {
        luaL_requiref(L, lib->name, lib->func, 1);
        lua_pop(L, 1); /* remove lib */
    }

    /* register all fullmoon modules in preload table*/
    luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
    for (lib = fullmoon_preload; lib->func; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);  // remove PRELOAD table
}

static int luaopen_luascript(lua_State *L) {
    char const *const modname = lua_tostring(L, 1);
    int result = 1;

    if (strcmp(modname, "luaunit") == 0) {
        result = luaL_loadbufferx(L, (char*)luaunit_lua, luaunit_lua_len, "luaunit", "t");
    } else if (strcmp(modname, "re") == 0) {
        result = luaL_loadbufferx(L, (char*)re_lua, re_lua_len, "re", "t");
    } else {
        return luaL_error(L, "unknown module \"%s\"", modname);
    }

    if (result != LUA_OK) {
        return lua_error(L);
    }

    lua_call(L, 0, 1);
    return 1;
}
