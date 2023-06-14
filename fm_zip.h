#ifndef FM_ZIP_INCLUDED
#define FM_ZIP_INCLUDED

#include <stdlib.h>
#include <string.h>
#include <lauxlib.h>
#include <lx_value.h>

int luaopen_fmzip(lua_State *L);

int fm_zip_new(lua_State *L);
int fm_zip_open(lua_State *L);

static const luaL_Reg fm_zip_reg[] = {
    {"new", fm_zip_new},
    {"open", fm_zip_open},
    {NULL, NULL}};


#endif  // FM_ZIP_INCLUDED