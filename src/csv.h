#ifndef CSV_INCLUDED
#define CSV_INCLUDED

#include <lauxlib.h>
#include <luax_value.h>
#include <string.h>

#define CSV_MAXCOL 512
#define CSV_MAXLINELEN CSV_MAXCOL * 512

int luaopen_csv(lua_State* L);

int csv_splitstr(char* string, char sep, char quout, char* list[]);
int csv_readcsv(lua_State* L);
int csv_writecsv(lua_State* L);
int csv_columnhash(lua_State* L);
int csv_insertcolumn(lua_State* L);
int csv_removecolumn(lua_State* L);
void csv_set_header2idx(lua_State* L, int n);
void csv_new_impl(lua_State* L, int n, int header);
int csv_new(lua_State* L);
int csv_setheader(lua_State* L);
int csv_set_column(lua_State* L);
int csv_get_column(lua_State* L);

static const luaL_Reg csv[] = {
    {"new", csv_new},
    {"read", csv_readcsv},
    {"write", csv_writecsv},
    {"columnhash", csv_columnhash},
    {"insertcolumn", csv_insertcolumn},
    {"removecolumn", csv_removecolumn},
    {"setheader", csv_setheader},
    {"setcolumn", csv_set_column},
    {"getcolumn", csv_get_column},
    {NULL, NULL}};

static const luaL_Reg csv_functions[] = {
    {"write", csv_writecsv},
    {"columnhash", csv_columnhash},
    {"insertcolumn", csv_insertcolumn},
    {"removecolumn", csv_removecolumn},
    {"setheader", csv_setheader},
    {"setcolumn", csv_set_column},
    {"getcolumn", csv_get_column},
    {NULL, NULL}};

#endif  // CSV_INCLUDED
