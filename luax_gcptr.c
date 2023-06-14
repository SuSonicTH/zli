#include "luax_gcptr.h"

void luax_register_mt(lua_State *L, const luaL_Reg *list) {
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

void luax_createudata(lua_State *L, void *udata, const char *mtname) {
    luax_udbox *ud;
    ud = lua_newuserdatauv(L, sizeof(luax_udbox), 0);
    ud->ptr = udata;
    luaL_getmetatable(L, mtname);
    lua_setmetatable(L, -2);
}

void luax_createudata_set_table(lua_State *L, void *udata, const char *mtname, int pos) {
    lua_pushstring(L, mtname);
    luax_createudata(L, udata, mtname);
    lua_settable(L, pos);
}

int luax_createudata_table(lua_State *L, void *udata, const char *mtname) {
    lua_newtable(L);
    int n = lua_gettop(L);
    lua_pushstring(L, mtname);
    luax_createudata(L, udata, mtname);
    lua_settable(L, n);
    return n;
}