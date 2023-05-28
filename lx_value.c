#include "lx_value.h"

void luax_settable_constant_list(lua_State *L, int n, const luax_const *list) {
    while (list->name != NULL) {
        luax_settable_number(L, n, list->name, list->value);
        list++;
    }
}

void luax_create_subtable_constant_list(lua_State *L, int n, const char *name, const luax_const *list) {
    lua_pushstring(L, name);
    lua_newtable(L);
    luax_settable_constant_list(L, lua_gettop(L), list);
    lua_settable(L, n);
}

void luax_settable_function_list(lua_State *L, int n, const luaL_Reg *list) {
    while (list->name != NULL) {
        luax_settable_cfunction(L, n, list->name, list->func);
        list++;
    }
}

void luax_create_subtable_function_list(lua_State *L, int n, const char *name, const luaL_Reg *list) {
    lua_pushstring(L, name);
    lua_newtable(L);
    luax_settable_function_list(L, lua_gettop(L), list);
    lua_settable(L, n);
}

void luax_regtable_create_list(lua_State *L, const char **name) {
    while (*name != NULL) {
        luax_regtable_create(*name);
        name++;
    }
}

void luax_tableinsert(lua_State *L, int tblidx, int pos) {
    int i;
    if (tblidx < 1) {
        tblidx = lua_gettop(L) + tblidx + 1;
    }
    for (i = lua_rawlen(L, tblidx); i >= pos; i--) {
        lua_rawgeti(L, tblidx, i);
        lua_rawseti(L, tblidx, i + 1);
    }
    lua_rawseti(L, tblidx, pos);
}

void luax_tableremove(lua_State *L, int tblidx, int pos) {
    int i, len;
    if (tblidx < 1) {
        tblidx = lua_gettop(L) + tblidx + 1;
    }
    len = lua_rawlen(L, tblidx);
    for (i = pos; i <= len; i++) {
        lua_rawgeti(L, tblidx, i + 1);
        lua_rawseti(L, tblidx, i);
    }
}

// TODO: luax_call: Test function
void luax_call(lua_State *L, char *name, int nargs, int nresults, int pop) {
    int i;
    int n = lua_gettop(L);

    lua_getglobal(L, name);

    for (i = 1; i <= nargs; i++) {
        lua_pushvalue(L, n - nargs + i);
    }

    lua_call(L, nargs, nresults);
    if (pop) {
        for (i = 1; i <= nargs; i++) {
            lua_remove(L, n - nargs + i);
        }
    }
}

void luax_call_lib(lua_State *L, char *package, char *function, int nargs, int nresults, int pop) {
    int i;
    int n = lua_gettop(L);

    lua_checkstack(L, n + (nresults > nargs ? nresults : nargs) + 2);

    lua_getglobal(L, package);
    lua_pushstring(L, function);
    lua_gettable(L, -2);
    lua_remove(L, n + 1);  // remove package table

    for (i = 1; i <= nargs; i++) {
        lua_pushvalue(L, n - nargs + i);
    }

    lua_call(L, nargs, nresults);
    if (pop) {
        for (i = 1; i <= pop; i++) {
            lua_remove(L, n - nargs + i);
        }
    }
}
