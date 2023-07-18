#include "sbuilder.h"

// #define SBUILDER_LUA
void sb_reset(sbuilder *sb) {
    sb->pos = sb->buffer;
}

void sb_init(sbuilder *sb, size_t size) {
    sb->reserved = size;
    sb->buffer = malloc(sb->reserved);
    sb->pos = sb->buffer;
}

sbuilder *sb_alloc(size_t size) {
    sbuilder *sb = malloc(sizeof(sbuilder));
    if (size < SBUFFER_MINIMAL_SIZE)
        size = SBUFFER_MINIMAL_SIZE;
    sb_init(sb, size);
    return sb;
}

void sb_reserve(sbuilder *sb, size_t len) {
    if (sb->pos + len > sb->buffer + sb->reserved) {
        int old_len = sb->pos - sb->buffer;
        do {
            sb->reserved *= 2;
        } while (sb->reserved - old_len < len);
        sb->buffer = realloc(sb->buffer, sb->reserved);
        sb->pos = sb->buffer + old_len;
    }
}

void sb_add(sbuilder *sb, const char *str, size_t len) {
    if (len > 0 && str != NULL) {
        sb_reserve(sb, len);
        memcpy(sb->pos, str, len);
        sb->pos += len;
    }
}

void sb_add_string(sbuilder *sb, const char *str) {
    sb_add(sb, str, strlen(str));
}

size_t sb_size(sbuilder *sb) {
    return sb->pos - sb->buffer;
}

char *sb_get(sbuilder *sb, size_t *len) {
    sb_reserve(sb, 1);
    *(sb->pos) = 0;
    if (len != NULL) {
        *len = sb->pos - sb->buffer;
    }
    return sb->buffer;
}

char *sb_get_string(sbuilder *sb) {
    return sb_get(sb, NULL);
}

void sb_free(sbuilder *sb) {
    if (sb != NULL) {
        if (sb->buffer != NULL) {
            free(sb->buffer);
        }
        free(sb);
    }
}

#ifdef SBUILDER_LUA
int luaopen_sbuilder(lua_State *L) {
    luaL_newlib(L, sbuilder_reg);
    luax_register_mt(L, sbuilder_udatamt);
    return 1;
}

int sbuilder_gc(lua_State *L) {
    sbuilder *sb;
    luaL_checkudata(L, 1, SBUILDER_UDATA_NAME);
    luax_to_cgudata(L, 1, sbuilder *, sb);
    if (sb)
        sb_free(sb);
    return 0;
}

int sbuilder_new(lua_State *L) {
    int size = luaL_optinteger(L, 2, 0);
    int n = luax_createudata_table(L, sb_alloc(size), SBUILDER_UDATA_NAME);

    // set functions
    luaL_Reg *function = (luaL_Reg *)sbuilder_functions;
    while (function->name != NULL) {
        lua_pushstring(L, function->name);
        lua_pushcfunction(L, function->func);
        lua_settable(L, n);
        function++;
    }

    return 1;
}

int sbuilder_add(lua_State *L) {
    int top = lua_gettop(L);
    sbuilder *sb;
    luax_getarg_gcudata(L, 1, SBUILDER_UDATA_NAME, sbuilder *, sb, "not a valid string_builder object");

    size_t len;
    const char *str;

    for (int i = 2; i <= top; i++) {
        int type = lua_type(L, i);
        if (type == LUA_TTABLE) {
            sbuilder *sbarg;
            luax_getarg_gcudata(L, i, SBUILDER_UDATA_NAME, sbuilder *, sbarg, "not a valid string_builder object");
            str = sb_get(sbarg, &len);
            sb_add(sb, str, len);
        } else if (type == LUA_TSTRING || type == LUA_TNUMBER) {
            str = lua_tolstring(L, i, &len);
            sb_add(sb, str, len);
        } else if (type == LUA_TBOOLEAN) {
            if (lua_toboolean(L, i)) {
                sb_add_constant(sb, "true");
            } else {
                sb_add_constant(sb, "false");
            }
        } else {
            luaL_argerror(L, i, "expected number, string or string_builder");
        }
    }
    lua_settop(L, 1);
    return 1;
}

int sbuilder_len(lua_State *L) {
    sbuilder *sb;
    luax_getarg_gcudata(L, 1, SBUILDER_UDATA_NAME, sbuilder *, sb, "not a valid string_builder object");
    lua_pushinteger(L, sb_size(sb));
    return 1;
}

int sbuilder_tostring(lua_State *L) {
    sbuilder *sb;
    luax_getarg_gcudata(L, 1, SBUILDER_UDATA_NAME, sbuilder *, sb, "not a valid string_builder object");
    size_t len;
    char *str = sb_get(sb, &len);
    lua_pushlstring(L, str, len);
    return 1;
}

int sbuilder_reset(lua_State *L) {
    sbuilder *sb;
    luax_getarg_gcudata(L, 1, SBUILDER_UDATA_NAME, sbuilder *, sb, "not a valid string_builder object");
    sb_reset(sb);
    lua_settop(L, 1);
    return 1;
}

int sbuilder_reserve(lua_State *L) {
    sbuilder *sb;
    luax_getarg_gcudata(L, 1, SBUILDER_UDATA_NAME, sbuilder *, sb, "not a valid string_builder object");
    int len = luaL_checkinteger(L, 2);
    sb_reserve(sb, len);
    lua_settop(L, 1);
    return 1;
}

#endif  // SBUILDER_LUA