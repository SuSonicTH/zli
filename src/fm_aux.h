#ifndef FM_AUX_INCLUDED
#define FM_AUX_INCLUDED

#include <lauxlib.h>
#include <lx_value.h>

typedef struct fm_sb_node {
    char *str;
    char copy;
    int len;
    struct fm_sb_node *next;
} fm_sb_node;

typedef struct fm_sb {
    fm_sb_node *root;
    fm_sb_node *last;
    unsigned int len;
} fm_sb;

int luaopen_fwaux(lua_State *L);

int fw_aux_extend_libs(lua_State *L);
int fw_aux_split(lua_State *L);
int fw_aux_trim(lua_State *L);
int fw_aux_ltrim(lua_State *L);
int fw_aux_rtrim(lua_State *L);

int fw_aux_mergesort_ext(lua_State *L);
int fw_aux_mergesort_int(lua_State *L, int idx, int func, int copy);
int *fw_aux_mergesort_arr(lua_State *L, int idx, int func, unsigned int *tlen);
int *fw_aux_mergesort_impl(lua_State *L, int *in, int *tmp, int len, int idx, int func);
int *fw_aux_mergesort_sublist(lua_State *L, int *in, int *tmp, int len, int idx, int func);
int fw_aux_chek_lte(lua_State *L, int *al, int *bl, int a, int b, int idx, int func);

int fw_aux_kpairs(lua_State *L);
int fw_aux_kpairs_iter(lua_State *L);
int fw_aux_copy_table(lua_State *L);
int fw_aux_concats(lua_State *L);
int fw_aux_tabletostring(lua_State *L);
void fw_aux_tabletostring_traverse(lua_State *L, fm_sb *buffer, int lvl, const char *le, const char *ind);
void fw_aux_tabletostring_additem(lua_State *L, fm_sb *buffer, int lvl, const char *le, const char *ind, int seq);

int fw_aux_readlines(lua_State *L);
int fw_aux_readfile(lua_State *L);
int fw_aux_writelines(lua_State *L);
int fw_aux_writefile(lua_State *L);

static const luaL_Reg fw_auxlib[] = {
    {"split", fw_aux_split},
    {"trim", fw_aux_trim},
    {"ltrim", fw_aux_ltrim},
    {"rtrim", fw_aux_rtrim},

    {"mergesort", fw_aux_mergesort_ext},
    {"kpairs", fw_aux_kpairs},
    {"copytable", fw_aux_copy_table},
    {"concats", fw_aux_concats},
    {"tabletostring", fw_aux_tabletostring},

    {"readfile", fw_aux_readfile},
    {"readlines", fw_aux_readlines},
    {"writefile", fw_aux_writefile},
    {"writelines", fw_aux_writelines},

    {"extendlibs", fw_aux_extend_libs},
    {NULL, NULL}};

#endif  // FM_AUX_INCLUDED