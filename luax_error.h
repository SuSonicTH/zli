#ifndef LUAX_ERROR_INCLUDED
#define LUAX_ERROR_INCLUDED

#include <lauxlib.h>

#define luax_return_with_error(L, fmt, ...) \
    lua_pushnil(L);                         \
    lua_pushfstring(L, fmt, __VA_ARGS__);   \
    return 2;

#define lua_exit_error(L, fmt, ...)       \
    lua_pushfstring(L, fmt, __VA_ARGS__); \
    lua_error(L);

#define luax_exit_with_error_if(L, condition, fmt, ...) \
    if (condition) {                                    \
        lua_pushfstring(L, fmt, __VA_ARGS__);           \
        lua_error(L);                                   \
    }

#define luax_return_with_error_if(L, condition, fmt, ...) \
    if (condition) {                                      \
        lua_pushnil(L);                                   \
        lua_pushfstring(L, fmt, __VA_ARGS__);             \
        return 2;                                         \
    }

#define luax_return_with_error_if_clean(L, condition, clean, fmt, ...) \
    if (condition) {                                                   \
        clean;                                                         \
        lua_pushnil(L);                                                \
        lua_pushfstring(L, fmt, __VA_ARGS__);                          \
        return 2;                                                      \
    }

#endif  // LUAX_ERROR_INCLUDED
