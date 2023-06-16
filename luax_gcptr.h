#ifndef LUAX_GCPTG_INCLUDED
#define LUAX_GCPTG_INCLUDED

#include <lauxlib.h>

// forward definitions
void luax_register_mt(lua_State *L, const luaL_Reg *list);
void luax_createudata(lua_State *L, void *udata, const char *mtname);
int luax_createudata_table(lua_State *L, void *udata, const char *mtname);
void luax_createudata_set_table(lua_State *L, void *udata, const char *mtname, int pos);

// The boxed pointer type
typedef struct {
    void *ptr;
} luax_udbox;

// Saves a boxed userdata from index idx as type ctype in cvar
#define luax_to_cgudata(L, idx, ctype, cvar) \
    cvar = (ctype)((luax_udbox *)lua_touserdata(L, idx))->ptr

// Sets a boxed udata pointer at index idx to cvar
#define luax_set_cgudata(L, idx, cvar) \
    (void *)((luax_udbox *)lua_touserdata(L, idx))->ptr = (void *)cvar;

/*
        Gets a userdata of type utype from table at index tblidx
        and saves the boxed pointer in cvar of type ctype
*/
#define luax_gettable_gcudata(L, tblidx, utype, ctype, cvar) \
    cvar = NULL;                                             \
    lua_pushstring(L, utype);                                \
    lua_gettable(L, tblidx);                                 \
    if (!lua_isnil(L, -1) && lua_getmetatable(L, -1)) {      \
        lua_getfield(L, LUA_REGISTRYINDEX, utype);           \
        if (lua_rawequal(L, -1, -2))                         \
            luax_to_cgudata(L, -3, ctype, cvar);             \
        lua_pop(L, 2);                                       \
    }                                                        \
    lua_pop(L, 1);

/*
        Checks if the argument idx is a table that has a userdata at index name of type utype
        and sets the boxed pointer in cvar of type ctype or raises the error err
*/
#define luax_getarg_gcudata(L, idx, utype, ctype, cvar, err) \
    luax_gettable_gcudata(L, idx, utype, ctype, cvar);       \
    luaL_argcheck(L, cvar != NULL, idx, err);

#define luax_set_gcudata(L, tblidx, utype, newptr)                        \
    lua_pushstring(L, utype);                                             \
    lua_gettable(L, tblidx);                                              \
    if (!lua_isnil(L, -1) && lua_getmetatable(L, -1)) {                   \
        lua_getfield(L, LUA_REGISTRYINDEX, utype);                        \
        if (lua_rawequal(L, -1, -2))                                      \
            ((luax_udbox *)lua_touserdata(L, -3))->ptr = (void *)newptr; \
        lua_pop(L, 2);                                                    \
    }                                                                     \
    lua_pop(L, 1);

#endif  // LUAX_GCPTG_INCLUDED
