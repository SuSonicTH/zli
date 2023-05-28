#ifndef FM_CROSSLINE_INCLUDED
#define FM_CROSSLINE_INCLUDED

#include <crossline.h>
#include <lauxlib.h>
#include <lx_value.h>
#include <string.h>

#define FM_CROSSLINE_BUFFER_SIZE 4096
static char fm_crossline_buffer[FM_CROSSLINE_BUFFER_SIZE];

int luaopen_fmcrossline(lua_State* L);
void fm_crossline_register_colors(lua_State* L);
void fm_register_screen(lua_State* L);

int fm_crossline_readline(lua_State* L);
int fm_crossline_prompt_color_set(lua_State* L);
int fm_crossline_color_set(lua_State* L);

static const luaL_Reg fm_crossline[] = {
    {"readline", fm_crossline_readline},
    {"set_prompt_color", fm_crossline_prompt_color_set},
    {"set_color", fm_crossline_color_set},
    {NULL, NULL}};

int fm_crossline_screen_get(lua_State* L);
int fm_crossline_screen_clear(lua_State* L);
int fm_crossline_cursor_get(lua_State* L);
int fm_crossline_cursor_set(lua_State* L);
int fm_crossline_cursor_move(lua_State* L);
int fm_crossline_cursor_hide(lua_State* L);
int fm_crossline_cursor_show(lua_State* L);

static const luaL_Reg fm_crossline_screen[] = {
    {"dimentions", fm_crossline_screen_get},
    {"clear", fm_crossline_screen_clear},
    {"get_cursor", fm_crossline_cursor_get},
    {"set_cursor", fm_crossline_cursor_set},
    {"move_cursor", fm_crossline_cursor_move},
    {"hide_cursor", fm_crossline_cursor_hide},
    {"show_cursor", fm_crossline_cursor_show},
    {NULL, NULL}};

typedef struct {
    const char* name;
    crossline_color_e value;
} fm_crossline_color;

static const luax_const fm_crossline_fg_color[] = {
    {"default", CROSSLINE_FGCOLOR_DEFAULT},
    {"black", CROSSLINE_FGCOLOR_BLACK},
    {"red", CROSSLINE_FGCOLOR_RED},
    {"green", CROSSLINE_FGCOLOR_GREEN},
    {"yellow", CROSSLINE_FGCOLOR_YELLOW},
    {"blue", CROSSLINE_FGCOLOR_BLUE},
    {"magenta", CROSSLINE_FGCOLOR_MAGENTA},
    {"cyan", CROSSLINE_FGCOLOR_CYAN},
    {"white", CROSSLINE_FGCOLOR_WHITE},

    {"bright_black", CROSSLINE_FGCOLOR_BLACK | CROSSLINE_FGCOLOR_BRIGHT},
    {"bright_red", CROSSLINE_FGCOLOR_RED | CROSSLINE_FGCOLOR_BRIGHT},
    {"bright_green", CROSSLINE_FGCOLOR_GREEN | CROSSLINE_FGCOLOR_BRIGHT},
    {"bright_yellow", CROSSLINE_FGCOLOR_YELLOW | CROSSLINE_FGCOLOR_BRIGHT},
    {"bright_blue", CROSSLINE_FGCOLOR_BLUE | CROSSLINE_FGCOLOR_BRIGHT},
    {"bright_magenta", CROSSLINE_FGCOLOR_MAGENTA | CROSSLINE_FGCOLOR_BRIGHT},
    {"bright_cyan", CROSSLINE_FGCOLOR_CYAN | CROSSLINE_FGCOLOR_BRIGHT},
    {"bright_white", CROSSLINE_FGCOLOR_WHITE | CROSSLINE_FGCOLOR_BRIGHT},
    {NULL, 0}};

static const luax_const fm_crossline_bg_color[] = {
    {"default", CROSSLINE_BGCOLOR_DEFAULT},
    {"black", CROSSLINE_BGCOLOR_BLACK},
    {"red", CROSSLINE_BGCOLOR_RED},
    {"green", CROSSLINE_BGCOLOR_GREEN},
    {"yellow", CROSSLINE_BGCOLOR_YELLOW},
    {"blue", CROSSLINE_BGCOLOR_BLUE},
    {"magenta", CROSSLINE_BGCOLOR_MAGENTA},
    {"cyan", CROSSLINE_BGCOLOR_CYAN},
    {"white", CROSSLINE_BGCOLOR_WHITE},

    {"bright_black", CROSSLINE_BGCOLOR_BLACK | CROSSLINE_BGCOLOR_BRIGHT},
    {"bright_red", CROSSLINE_BGCOLOR_RED | CROSSLINE_BGCOLOR_BRIGHT},
    {"bright_green", CROSSLINE_BGCOLOR_GREEN | CROSSLINE_BGCOLOR_BRIGHT},
    {"bright_yellow", CROSSLINE_BGCOLOR_YELLOW | CROSSLINE_BGCOLOR_BRIGHT},
    {"bright_blue", CROSSLINE_BGCOLOR_BLUE | CROSSLINE_BGCOLOR_BRIGHT},
    {"bright_magenta", CROSSLINE_BGCOLOR_MAGENTA | CROSSLINE_BGCOLOR_BRIGHT},
    {"bright_cyan", CROSSLINE_BGCOLOR_CYAN | CROSSLINE_BGCOLOR_BRIGHT},
    {"bright_white", CROSSLINE_BGCOLOR_WHITE | CROSSLINE_BGCOLOR_BRIGHT},
    {NULL, 0}};
#endif  // FM_CROSSLINE_INCLUDED