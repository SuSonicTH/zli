#ifndef FM_CSV_INCLUDED
#define FM_CSV_INCLUDED

#include <lauxlib.h>
#include <lx_value.h>
#include <string.h>

#define FM_CSV_MAXCOL 512
#define FM_CSV_MAXLINELEN FM_CSV_MAXCOL * 512

int luaopen_fmcsv(lua_State* L);

int fm_csv_splitstr(char* string, char sep, char quout, char* list[]);
int fm_csv_readcsv(lua_State* L);
int fm_csv_writecsv(lua_State* L);
int fm_csv_columnhash(lua_State* L);
int fm_csv_insertcolumn(lua_State* L);
int fm_csv_removecolumn(lua_State* L);
void fm_csv_set_header2idx(lua_State* L, int n);
void fm_csv_new_impl(lua_State* L, int n, int header);
int fm_csv_new(lua_State* L);
int fm_csv_setheader(lua_State* L);
int fm_csv_set_column(lua_State* L);
int fm_csv_get_column(lua_State* L);

static const luaL_Reg fm_csv[] = {
    {"new", fm_csv_new},
    {"read", fm_csv_readcsv},
    {"write", fm_csv_writecsv},
    {"columnhash", fm_csv_columnhash},
    {"insertcolumn", fm_csv_insertcolumn},
    {"removecolumn", fm_csv_removecolumn},
    {"setheader", fm_csv_setheader},
    {"setcolumn", fm_csv_set_column},
    {"getcolumn", fm_csv_get_column},
    {NULL, NULL}};

static const luaL_Reg fm_csv_functions[] = {
    {"write", fm_csv_writecsv},
    {"columnhash", fm_csv_columnhash},
    {"insertcolumn", fm_csv_insertcolumn},
    {"removecolumn", fm_csv_removecolumn},
    {"setheader", fm_csv_setheader},
    {"setcolumn", fm_csv_set_column},
    {"getcolumn", fm_csv_get_column},
    {NULL, NULL}};

#endif  // FM_CSV_INCLUDED
