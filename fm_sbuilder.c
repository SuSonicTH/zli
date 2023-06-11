#include "fm_sbuilder.h"

// #define FM_SBUILDER_LUA
void fm_sb_reset(fm_sb *sb) {
    sb->pos = sb->buffer;
}

void fm_sb_init(fm_sb *sb, size_t size) {
    sb->reserved = size;
    sb->buffer = malloc(sb->reserved);
    sb->pos = sb->buffer;
}

fm_sb *fm_sb_alloc() {
    fm_sb *sb = malloc(sizeof(fm_sb));
    fm_sb_init(sb, SBUFFER_MINIMAL_SIZE);
    return sb;
}

void fm_sb_reserve(fm_sb *sb, size_t len) {
    if (sb->pos + len > sb->buffer + sb->reserved) {
        int old_len = sb->pos - sb->buffer;
        do {
            sb->reserved *= 2;
        } while (sb->reserved - old_len < len);
        sb->buffer = realloc(sb->buffer, sb->reserved);
        sb->pos = sb->buffer + old_len;
    }
}

void fm_sb_add(fm_sb *sb, const char *str, size_t len) {
    if (len > 0 && str != NULL) {
        fm_sb_reserve(sb, len);
        memcpy(sb->pos, str, len);
        sb->pos += len;
    }
}

void fm_sb_add_string(fm_sb *sb, const char *str) {
    fm_sb_add(sb, str, strlen(str));
}

size_t fm_sb_size(fm_sb *sb) {
    return sb->pos - sb->buffer;
}

char *fm_sb_get(fm_sb *sb, size_t *len) {
    fm_sb_reserve(sb, 1);
    *(sb->pos) = 0;
    if (len != NULL) {
        *len = sb->pos - sb->buffer;
    }
    return sb->buffer;
}

char *fm_sb_get_string(fm_sb *sb) {
    return fm_sb_get(sb, NULL);
}

void fm_sb_free(fm_sb *sb) {
    if (sb != NULL) {
        if (sb->buffer != NULL) {
            free(sb->buffer);
        }
        free(sb);
    }
}

#ifdef FM_SBUILDER_LUA
int luaopen_fmsbuilder(lua_State *L) {
    luaL_newlib(L, fm_sbuilder_reg);
    return 1;
}

#define FM_SB "_fm_sb"

int fm_sbuilder_gc(lua_State *L) {
    fm_sb *sb = (fm_sb *)lua_touserdata(L, 1);
    fflush(stdout);
    if (sb->buffer != NULL) {
        free(sb->buffer);
    }
    return 0;
}

int fm_sbuilder_new(lua_State *L) {
    int size = luaL_optinteger(L, 2, SBUFFER_MINIMAL_SIZE);

    // table to be returned
    lua_newtable(L);
    int n = lua_gettop(L);
    lua_pushstring(L, FM_SB);
    void *sb = lua_newuserdatauv(L, sizeof(fm_sb), 0);
    fm_sb_init(sb, size);

    // metatable
    lua_newtable(L);
    lua_pushstring(L, "__gc");
    lua_pushcfunction(L, fm_sbuilder_gc);
    lua_settable(L, -3);
    lua_setmetatable(L, n + 2);

    lua_settable(L, n);  // set _fm_sb

    // set functions
    luaL_Reg *function = (luaL_Reg *)fm_sbuilder_functions;
    while (function->name != NULL) {
        lua_pushstring(L, function->name);
        lua_pushcfunction(L, function->func);
        lua_settable(L, n);
        function++;
    }

    return 1;
}

fm_sb *get_fm_sb(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushstring(L, FM_SB);
    lua_gettable(L, 1);
    return (fm_sb *)lua_touserdata(L, -1);
}

int fm_sbuilder_add(lua_State *L) {
    int top = lua_gettop(L);
    fm_sb *sb = get_fm_sb(L);
    size_t len;
    const char *str;

    for (int i = 2; i <= top; i++) {
        int type = lua_type(L, i);
        if (type == LUA_TTABLE) {
            lua_pushstring(L, FM_SB);
            lua_gettable(L, i);
            if (!lua_isnil(L, -1)) {
                fm_sb *sbarg = lua_touserdata(L, -1);
                str = fm_sb_get(sbarg, &len);
                fm_sb_add(sb, str, len);
            } else {
                luaL_argerror(L, i, "expected number, string or string_builder");
            }
        } else if (type == LUA_TSTRING || type == LUA_TNUMBER) {
            str = lua_tolstring(L, i, &len);
            fm_sb_add(sb, str, len);
        } else if (type == LUA_TBOOLEAN) {
            if (lua_toboolean(L, i)) {
                fm_sb_add_constant(sb, "true");
            } else {
                fm_sb_add_constant(sb, "false");
            }
        } else {
            luaL_argerror(L, i, "expected number, string or string_builder");
        }
    }
    lua_settop(L, 1);
    return 1;
}

int fm_sbuilder_len(lua_State *L) {
    fm_sb *sb = get_fm_sb(L);
    lua_pushinteger(L, fm_sb_size(sb));
    return 1;
}

int fm_sbuilder_tostring(lua_State *L) {
    fm_sb *sb = get_fm_sb(L);
    size_t len;
    char *str = fm_sb_get(sb, &len);
    lua_pushlstring(L, str, len);
    return 1;
}

int fm_sbuilder_reset(lua_State *L) {
    fm_sb *sb = get_fm_sb(L);
    fm_sb_reset(sb);
    lua_settop(L, 1);
    return 1;
}

int fm_sbuilder_reserve(lua_State *L) {
    fm_sb *sb = get_fm_sb(L);
    int len = luaL_checkinteger(L, 2);
    fm_sb_reserve(sb, len);
    lua_settop(L, 1);
    return 1;
}

#endif  // FM_SBUILDER_LUA