#ifndef LW_CSV_INCLUDED
#define LW_CSV_INCLUDED

#include <lauxlib.h>
#include <lx_value.h>

#ifndef LWCSV_API
	#ifdef LWCSV_EXPORTS
		#define LWCSV_API __declspec(dllexport)
	#else
		#define LWCSV_API
	#endif
#endif

#ifndef LW_CSVLIBNAME 
	#define LW_CSVLIBNAME "lwcsv"
#endif

#define LW_CSV_MAXCOL	512
#define LW_CSV_MAXLINELEN	LW_CSV_MAXCOL*512

LWCSV_API int luaopen_csvlib (lua_State *L);

int lw_csv_splitstr(char *string,char sep,char quout,char *list[]);
int lw_csv_readcsv(lua_State* L);
int lw_csv_writecsv(lua_State* L);
int lw_csv_columnhash(lua_State* L);
int lw_csv_insertcolumn(lua_State* L);
int lw_csv_removecolumn(lua_State* L);
void lw_csv_set_header2idx(lua_State* L,int n);
void lw_csv_new_impl(lua_State* L,int n,int header);
int lw_csv_new(lua_State* L);
int lw_csv_setheader(lua_State* L,int n);
int lw_csv_set_column(lua_State* L);
int lw_csv_get_column(lua_State* L);
int lw_csv_sort(lua_State* L);

static const luaL_Reg lw_csv[] = {
	{"new",lw_csv_new},
	{"read",lw_csv_readcsv},
	{"write",lw_csv_writecsv},
	{"columnhash",lw_csv_columnhash},
	{"insertcolumn",lw_csv_insertcolumn},
	{"removecolumn",lw_csv_removecolumn},
	{"setheader",lw_csv_setheader},
	{"setcolumn",lw_csv_set_column},
	{"getcolumn",lw_csv_get_column},
	{"sort",lw_csv_sort},
	{NULL,NULL}
};

static const luaL_Reg lw_csv_functions[] = {
	{"write",lw_csv_writecsv},
	{"columnhash",lw_csv_columnhash},
	{"insertcolumn",lw_csv_insertcolumn},
	{"removecolumn",lw_csv_removecolumn},
	{"setheader",lw_csv_setheader},
	{"setcolumn",lw_csv_set_column},
	{"getcolumn",lw_csv_get_column},
	{"sort",lw_csv_sort},
	{NULL,NULL}
};

#endif//LW_CSV_INCLUDED
