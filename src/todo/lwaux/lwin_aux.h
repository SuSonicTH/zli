#ifndef LW_AUX_INCLUDED
#define LW_AUX_INCLUDED

#include <lauxlib.h>
#include <lx_value.h>

#ifndef LWAUX_API
	#ifdef LWAUX_EXPORTS
		#define LWAUX_API __declspec(dllexport)
	#else
		#define LWAUX_API
	#endif
#endif

#ifndef LUA_AUXLIBNAME
	#define LUA_AUXLIBNAME "lwaux"
#endif

LWAUX_API int luaopen_lwaux (lua_State *L);

int lw_aux_extend_libs(lua_State* L);
int lw_aux_split(lua_State* L);
int lw_aux_trim(lua_State* L);
int lw_aux_ltrim(lua_State* L);
int lw_aux_rtrim(lua_State* L);

int lw_aux_mergesort_ext(lua_State* L);
int lw_aux_mergesort_int(lua_State* L,int idx,int func,int copy);
int *lw_aux_mergesort_arr(lua_State* L,int idx,int func,unsigned int *tlen);
int *lw_aux_mergesort_impl(lua_State* L,int *in,int *tmp,int len,int idx,int func);
int *lw_aux_mergesort_sublist(lua_State* L,int *in,int *tmp,int len,int idx,int func);
int lw_aux_chek_lte(lua_State* L,int *al,int *bl,int a,int b,int idx,int func);

int lw_aux_kpairs(lua_State* L);
int lw_aux_kpairs_iter(lua_State* L);
int lw_aux_copy_table(lua_State* L);
int lw_aux_concats(lua_State* L);
int lw_aux_tabletostring(lua_State* L);
void lw_aux_tabletostring_traverse(lua_State* L,luaL_Buffer *buffer,int lvl,const char *le, const char *ind);
void lw_aux_tabletostring_additem(lua_State* L,luaL_Buffer *buffer,int lvl,const char *le,const char *ind,int seq);

int lw_aux_readlines(lua_State* L);
int lw_aux_readfile(lua_State* L);
int lw_aux_writelines(lua_State* L);
int lw_aux_writefile(lua_State* L);

static const luaL_Reg lw_auxlib[] = {
	{"split",lw_aux_split},
	{"trim",lw_aux_trim},
	{"ltrim",lw_aux_ltrim},
	{"rtrim",lw_aux_rtrim},

	{"mergesort",lw_aux_mergesort_ext},
	{"kpairs",lw_aux_kpairs},
	{"copytable",lw_aux_copy_table},
	{"concats",lw_aux_concats},
	{"tabletostring",lw_aux_tabletostring},

	{"readfile",lw_aux_readfile},
	{"readlines",lw_aux_readlines},
	{"writefile",lw_aux_writefile},
	{"writelines",lw_aux_writelines},

	{"extendlibs",lw_aux_extend_libs},
	{NULL,NULL}
};


#endif//LW_AUX_INCLUDED