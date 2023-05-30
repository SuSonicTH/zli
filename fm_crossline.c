#include "fm_crossline.h"

int luaopen_fmcrossline(lua_State* L) {
    luaL_newlib(L, fm_crossline);
    fm_crossline_register_colors(L);

    int index = lua_gettop(L);
    luax_create_subtable_function_list(L, index, "paging", fm_crossline_paging);
    luax_create_subtable_function_list(L, index, "screen", fm_crossline_screen);
    luax_create_subtable_function_list(L, index, "cursor", fm_crossline_cursor);
    luax_create_subtable_function_list(L, index, "history", fm_crossline_history);

    return 1;
}

void fm_crossline_register_colors(lua_State* L) {
    int top = lua_gettop(L);

    lua_pushliteral(L, "color");
    lua_newtable(L);

    luax_create_subtable_constant_list(L, lua_gettop(L), "fg", fm_crossline_fg_color);
    luax_create_subtable_constant_list(L, lua_gettop(L), "bg", fm_crossline_bg_color);

    lua_settable(L, top);
}

int fm_crossline_readline(lua_State* L) {
    const char* prompt = lua_tostring(L, 1);
    size_t init_len;
    const char* init = lua_tolstring(L, 2, &init_len);
    char* line;

    if (prompt == NULL) prompt = ">";
    if (init != NULL) {
        memcpy(fm_crossline_buffer, init, init_len);
        fm_crossline_buffer[init_len] = 0;
        line = crossline_readline2(prompt, fm_crossline_buffer, FM_CROSSLINE_BUFFER_SIZE);
    } else {
        line = crossline_readline(prompt, fm_crossline_buffer, FM_CROSSLINE_BUFFER_SIZE);
    }

    lua_pushstring(L, line);
    return 1;
}

int fm_crossline_prompt_color_set(lua_State* L) {
    int fg = lua_tointeger(L, 1);
    int bg = lua_tointeger(L, 2);
    crossline_prompt_color_set(fg | bg);
    return 0;
}

int fm_crossline_color_set(lua_State* L) {
    int fg = lua_tointeger(L, 1);
    int bg = lua_tointeger(L, 2);
    crossline_color_set(fg | bg);
    return 0;
}

int fm_crossline_delimiter_set(lua_State* L) {
    crossline_delimiter_set(luaL_checkstring(L, 1));
    return 0;
}

int fm_crossline_getch(lua_State* L) {
    char character[2] = {0, 0};
    character[0] = (char)crossline_getch();
    lua_pushlstring(L, character, 1);
    return 1;
}

void fm_create_pos_table(lua_State* L, int x, int y) {
    lua_newtable(L);
    int table = lua_gettop(L);
    luax_settable_number(L, table, "x", x);
    luax_settable_number(L, table, "y", y);
}

int fm_crossline_screen_get(lua_State* L) {
    int x, y;
    crossline_screen_get(&y, &x);
    fm_create_pos_table(L, x, y);
    return 1;
}

int fm_crossline_screen_clear(lua_State* L) {
    crossline_screen_clear();
    return 0;
}

int fm_crossline_cursor_get(lua_State* L) {
    int x, y;
    crossline_cursor_get(&y, &x);
    fm_create_pos_table(L, x, y);
    return 0;
}

int fm_crossline_cursor_set(lua_State* L) {
    int x, y;
    if (lua_type(L, 1) == LUA_TTABLE) {
        luax_gettable_int(L, 1, "x", x, 0);
        luax_gettable_int(L, 1, "y", y, 0);
    } else {
        x = luaL_checkinteger(L, 1);
        y = luaL_checkinteger(L, 2);
    }
    crossline_cursor_set(y, x);
    return 0;
}

int fm_crossline_cursor_move(lua_State* L) {
    int x, y;
    if (lua_type(L, 1) == LUA_TTABLE) {
        luax_gettable_int(L, 1, "x", x, 0);
        luax_gettable_int(L, 1, "y", y, 0);
    } else {
        x = luaL_checkinteger(L, 1);
        y = luaL_checkinteger(L, 2);
    }
    crossline_cursor_move(y, x);
    return 0;
}

int fm_crossline_cursor_hide(lua_State* L) {
    crossline_cursor_hide(1);
    return 0;
}

int fm_crossline_cursor_show(lua_State* L) {
    crossline_cursor_hide(0);
    return 0;
}

int fm_crossline_paging_start(lua_State* L) {
    crossline_paging_set(1);
    return 0;
}

int fm_crossline_paging_stop(lua_State* L) {
    crossline_paging_set(0);
    return 0;
}

int fm_crossline_paging_check(lua_State* L) {
    int length = luaL_checkinteger(L, 1);
    int stop = crossline_paging_check(length);
    lua_pushboolean(L, stop);
    return 1;
}

int fm_crossline_paging_print_output(lua_State* L) {
    size_t length;
    char* string = lua_tolstring(L, -1, &length);
    fwrite(string, 1, length, stdout);
    if (string[length - 1] != '\n') {
        putchar('\n');
    }
    return crossline_paging_check(length);
}

int fm_crossline_paging_print(lua_State* L) {
    int stop = 0;
    if (lua_type(L, 1) == LUA_TTABLE) {
        lua_len(L, 1);
        int size = lua_tointeger(L, -1);
        for (int i = 1; i <= size && !stop; i++) {
            lua_geti(L, 1, i);
            stop = fm_crossline_paging_print_output(L);
            lua_pop(L, 1);
        }
    } else {
        stop = fm_crossline_paging_print_output(L);
    }
    lua_pushboolean(L, stop);
    return 1;
}

int fm_crossline_history_save(lua_State* L) {
    crossline_history_save(luaL_checkstring(L, 1));
    return 0;
}

int fm_crossline_history_load(lua_State* L) {
    crossline_history_load(luaL_checkstring(L, 1));
    return 0;
}

int fm_crossline_history_show(lua_State* L) {
    crossline_history_show();
    return 0;
}

int fm_crossline_history_clear(lua_State* L) {
    crossline_history_clear();
    return 0;
}
