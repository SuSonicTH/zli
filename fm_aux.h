#ifndef FM_AUX_INCLUDED
#define FM_AUX_INCLUDED

#include <lauxlib.h>
#include <luax_value.h>
#include <stdlib.h>
#include <string.h>
#include <fm_sbuilder.h>

int luaopen_fmaux(lua_State *L);

void fm_aux_extend_libs(lua_State *L);
int fm_aux_split(lua_State *L);
int fm_aux_trim(lua_State *L);
int fm_aux_ltrim(lua_State *L);
int fm_aux_rtrim(lua_State *L);

int fm_aux_mergesort_ext(lua_State *L);
int fm_aux_mergesort_int(lua_State *L, int idx, int func, int copy);
int *fm_aux_mergesort_arr(lua_State *L, int idx, int func, unsigned int *tlen);
int *fm_aux_mergesort_impl(lua_State *L, int *in, int *tmp, int len, int idx, int func);
int *fm_aux_mergesort_sublist(lua_State *L, int *in, int *tmp, int len, int idx, int func);
int fm_aux_chek_lte(lua_State *L, int *al, int *bl, int a, int b, int idx, int func);

int fm_aux_kpairs(lua_State *L);
int fm_aux_kpairs_iter(lua_State *L);
int fm_aux_copy_table(lua_State *L);
int fm_aux_concats(lua_State *L);
int fm_aux_tabletostring(lua_State *L);
void fm_aux_tabletostring_traverse(lua_State *L, fm_sb *buffer, int lvl, const char *le, const char *ind);
void fm_aux_tabletostring_additem(lua_State *L, fm_sb *buffer, int lvl, const char *le, const char *ind, int seq);
int fm_aux_iter(lua_State *L);
int fm_aux_next(lua_State *L);

int fm_aux_readlines(lua_State *L);
int fm_aux_readfile(lua_State *L);
int fm_aux_writelines(lua_State *L);
int fm_aux_writefile(lua_State *L);

static const luaL_Reg fm_auxlib[] = {
    {"split", fm_aux_split},
    {"trim", fm_aux_trim},
    {"ltrim", fm_aux_ltrim},
    {"rtrim", fm_aux_rtrim},

    {"mergesort", fm_aux_mergesort_ext},
    {"kpairs", fm_aux_kpairs},
    {"copytable", fm_aux_copy_table},
    {"concats", fm_aux_concats},
    {"tabletostring", fm_aux_tabletostring},
    {"tableiter", fm_aux_iter},
    {"tablenext", fm_aux_next},

    {"readfile", fm_aux_readfile},
    {"readlines", fm_aux_readlines},
    {"writefile", fm_aux_writefile},
    {"writelines", fm_aux_writelines},

    {NULL, NULL}};

#endif  // FM_AUX_INCLUDED