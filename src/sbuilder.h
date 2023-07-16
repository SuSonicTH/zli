#ifndef SBUILDER_INCLUDED
#define SBUILDER_INCLUDED

#include <stdlib.h>
#include <string.h>

#ifndef SBUFFER_MINIMAL_SIZE
#define SBUFFER_MINIMAL_SIZE 64
#endif

typedef struct sbuilder {
    char *buffer;
    char *pos;
    size_t reserved;
} sbuilder;

void sb_reset(sbuilder *sb);
void sb_init(sbuilder *sb, size_t size);
sbuilder *sb_alloc(size_t size);
void sb_reserve(sbuilder *sb, size_t len);
void sb_add(sbuilder *sb, const char *str, size_t len);
void sb_add_string(sbuilder *sb, const char *str);
size_t sb_size(sbuilder *sb);
char *sb_get(sbuilder *sb, size_t *len);
char *sb_get_string(sbuilder *sb);
void sb_free(sbuilder *sb);

#define sb_add_constant(sb, str) sb_add(sb, str, sizeof(str) - 1)

#ifdef SBUILDER_LUA
#include <lauxlib.h>
#include <luax_gcptr.h>
#include <luax_value.h>

int luaopen_sbuilder(lua_State *L);

int sbuilder_new(lua_State *L);
int sbuilder_add(lua_State *L);
int sbuilder_len(lua_State *L);
int sbuilder_tostring(lua_State *L);
int sbuilder_reset(lua_State *L);
int sbuilder_reserve(lua_State *L);

int sbuilder_gc(lua_State *L);

static const luaL_Reg sbuilder_reg[] = {
    {"new", sbuilder_new},
    {NULL, NULL}};

#define SBUILDER_UDATA_NAME "_sbuilder_sb"

static const luaL_Reg sbuilder_udatamt[] = {
    {SBUILDER_UDATA_NAME, sbuilder_gc},
    {NULL, NULL}};

static const luaL_Reg sbuilder_functions[] = {
    {"add", sbuilder_add},
    {"len", sbuilder_len},
    {"tostring", sbuilder_tostring},
    {"reset", sbuilder_reset},
    {"reserve", sbuilder_reserve},
    {NULL, NULL}};

#endif  // SBUILDER_LUA
#endif  // SBUILDER_INCLUDED