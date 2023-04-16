#include "lx_gcptr.h"

#include <lauxlib.h>

LUAX_API void luax_register_mt(lua_State *L, const luaL_Reg *list) {
    while (list->name) {
        if (luaL_newmetatable(L, list->name)) {
            lua_pushstring(L, "__gc");
            lua_pushcfunction(L, list->func);
            lua_settable(L, -3);
        }
        lua_pop(L, 1);
        list++;
    }
}

LUAX_API void luax_createudata(lua_State *L, void *udata, const char *mtname) {
    struct luax_udbox *ud;
    ud = lua_newuserdata(L, sizeof(struct luax_udbox));
    ud->ptr = udata;
    luaL_getmetatable(L, mtname);
    lua_setmetatable(L, -2);
}

LUAX_API void luax_delete_table_values(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushnil(L);
    while (lua_next(L, 1)) {
        lua_pop(L, 1);
        lua_pushvalue(L, -1);
        lua_pushnil(L);
        lua_settable(L, 1);
    }
}