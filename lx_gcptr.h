#ifndef LX_GCPTG_INCLUDED
#define LX_GCPTG_INCLUDED

#include <lauxlib.h>

// forward definitions
void lx_register_mt(lua_State *L, const luaL_Reg *list);
void lx_createudata(lua_State *L, void *udata, const char *mtname);
int lx_createudata_table(lua_State *L, void *udata, const char *mtname);
void lx_createudata_set_table(lua_State *L, void *udata, const char *mtname, int pos);

// The boxed pointer type
typedef struct {
    void *ptr;
} lx_udbox;

// Saves a boxed userdata from index idx as type ctype in cvar
#define lx_to_cgudata(L, idx, ctype, cvar) \
    cvar = (ctype)((lx_udbox *)lua_touserdata(L, idx))->ptr

// Sets a boxed udata pointer at index idx to cvar
#define lx_set_cgudata(L, idx, cvar) \
    (void *)((lx_udbox *)lua_touserdata(L, idx))->ptr = (void *)cvar;

/*
        Gets a userdata of type utype from table at index tblidx
        and saves the boxed pointer in cvar of type ctype
*/
#define lx_gettable_gcudata(L, tblidx, utype, ctype, cvar) \
    cvar = NULL;                                           \
    lua_pushstring(L, utype);                              \
    lua_gettable(L, tblidx);                               \
    if (!lua_isnil(L, -1) && lua_getmetatable(L, -1)) {    \
        lua_getfield(L, LUA_REGISTRYINDEX, utype);         \
        if (lua_rawequal(L, -1, -2))                       \
            lx_to_cgudata(L, -3, ctype, cvar);              \
        lua_pop(L, 2);                                     \
    }                                                      \
    lua_pop(L, 1);

/*
        Checks if the argument idx is a table that has a userdata at index name of type utype
        and sets the boxed pointer in cvar of type ctype or raises the error err
*/
#define lx_getarg_objh(L, idx, utype, ctype, cvar, err) \
    lx_gettable_gcudata(L, idx, utype, ctype, cvar);    \
    luaL_argcheck(L, cvar != NULL, idx, err);

#endif  // LX_GCPTG_INCLUDED
