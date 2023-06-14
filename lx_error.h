#ifndef LUAX_ERROR_INCLUDED
#define LUAX_ERROR_INCLUDED

#include <lauxlib.h>

#define luax_exit_with_error_if(condition, message) \
    if (condition) {                                \
        lua_pushstring(L, message);                 \
        lua_error(L);                               \
    }

#define luax_return_with_error_if(condition, message) \
    if (condition) {                                  \
        lua_pushnil(L);                               \
        lua_pushstring(L, message);                   \
        return 2;                                     \
    }

#define luax_return_with_error_if_clean(condition, message, clean) \
    if (condition) {                                               \
        clean                                                      \
            lua_pushnil(L);                                        \
        lua_pushstring(L, message);                                \
        return 2;                                                  \
    }

#define lua_exit_error(s)     \
    {                         \
        lua_pushstring(L, s); \
        lua_error(L);         \
    }

#endif  // LUAX_ERROR_INCLUDED
