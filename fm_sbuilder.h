#ifndef FM_SBUILDER_INCLUDED
#define FM_SBUILDER_INCLUDED

#include <stdlib.h>
#include <string.h>

#ifndef SBUFFER_MINIMAL_SIZE
#define SBUFFER_MINIMAL_SIZE 64
#endif

typedef struct fm_sb {
    char *buffer;
    char *pos;
    size_t reserved;
} fm_sb;

void fm_sb_reset(fm_sb *sb);
void fm_sb_init(fm_sb *sb, size_t size);
fm_sb *fm_sb_alloc(size_t size);
void fm_sb_reserve(fm_sb *sb, size_t len);
void fm_sb_add(fm_sb *sb, const char *str, size_t len);
void fm_sb_add_string(fm_sb *sb, const char *str);
size_t fm_sb_size(fm_sb *sb);
char *fm_sb_get(fm_sb *sb, size_t *len);
char *fm_sb_get_string(fm_sb *sb);
void fm_sb_free(fm_sb *sb);

#define fm_sb_add_constant(sb, str) fm_sb_add(sb, str, sizeof(str) - 1)

#ifdef FM_SBUILDER_LUA
#include <lauxlib.h>
#include <luax_value.h>
#include <luax_gcptr.h>

int luaopen_fmsbuilder(lua_State *L);

int fm_sbuilder_new(lua_State *L);
int fm_sbuilder_add(lua_State *L);
int fm_sbuilder_len(lua_State *L);
int fm_sbuilder_tostring(lua_State *L);
int fm_sbuilder_reset(lua_State *L);
int fm_sbuilder_reserve(lua_State *L);

int fm_sbuilder_gc(lua_State *L);

static const luaL_Reg fm_sbuilder_reg[] = {
    {"new", fm_sbuilder_new},
    {NULL, NULL}};

#define FM_SB_UDATA_NAME "_fm_sbuilder_fm_sb"
static const luaL_Reg fm_sbuilder_udatamt[] = {
    {FM_SB_UDATA_NAME, fm_sbuilder_gc},
    {NULL, NULL}};

static const luaL_Reg fm_sbuilder_functions[] = {
    {"add", fm_sbuilder_add},
    {"len", fm_sbuilder_len},
    {"tostring", fm_sbuilder_tostring},
    {"reset", fm_sbuilder_reset},
    {"reserve", fm_sbuilder_reserve},
    {NULL, NULL}};

#endif  // FM_SBUILDER_LUA
#endif  // FM_SBUILDER_INCLUDED