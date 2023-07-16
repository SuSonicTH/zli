#ifndef LUA_ZIP_INCLUDED
#define LUA_ZIP_INCLUDED

#include <ctype.h>
#include <lauxlib.h>
#include <luax_error.h>
#include <luax_gcptr.h>
#include <luax_value.h>
#include <string.h>
#include <time.h>
#include <unzip.h>
#include <zip.h>

#define LUA_ZIP_BUFFERSIZE 4096

#ifndef _MAX_PATH
#define _MAX_PATH 260
#endif

int luaopen_zip(lua_State* L);

// non portable functions
int FileTimeToZipTime(const char* fileanme, tm_zip* sts);
void SystemTimeToZipTime(tm_zip* sts);

// unzip functions
int lua_zip_open(lua_State* L);
int lua_zip_uzfile_gc(lua_State* L);
int lua_zip_uzfile_close(lua_State* L);
int lua_zip_extract_file(lua_State* L);
int lua_zip_extract_to(lua_State* L);
int lua_zip_extract_all(lua_State* L);
int lua_zip_createtree(const char* path);
int lua_zip_open_uzfile(lua_State* L);
int lua_zip_open_uzfile_mt(lua_State* L);
int lua_zip_file_uzread(lua_State* L);
int lua_zip_file_uzclose_current(lua_State* L);
int lua_zip_file_uzclose(lua_State* L);
int lua_zip_file_uzeof(lua_State* L);
int lua_zip_file_uztell(lua_State* L);
int lua_zip_lines_mt(lua_State* L);
int lua_zip_lines(lua_State* L);
int lua_zip_extract_file_tostring(lua_State* L);
int lua_zip_extract_tostring(lua_State* L);

// zip functions
int lua_zip_create(lua_State* L);
int lua_zip_zipfile_gc(lua_State* L);
int lua_zip_zipfile_close(lua_State* L);
int lua_zip_addfile(lua_State* L);
int lua_zip_open_zipfile(lua_State* L);
int lua_zip_file_zipwrite(lua_State* L);
int lua_zip_file_zipclose(lua_State* L);

static const luaL_Reg lua_ziplib[] = {
    {"open", lua_zip_open},
    {"create", lua_zip_create},
    {NULL, NULL}};

#define LUA_ZIP_UZ_FILE "_lua_zip_uzfile"
#define LUA_ZIP_ZIP_FILE "_lua_zip_zipfile"

static const luaL_Reg lua_zip_udatamt[] = {
    {LUA_ZIP_UZ_FILE, lua_zip_uzfile_gc},
    {LUA_ZIP_ZIP_FILE, lua_zip_zipfile_gc},
    {NULL, NULL}};

static const luaL_Reg lua_zip_open_reg[] = {
    {"extract", lua_zip_extract_file},
    {"get", lua_zip_extract_file_tostring},
    {"extract_all", lua_zip_extract_all},
    {"open", lua_zip_open_uzfile},
    {"lines", lua_zip_lines},
    {"close", lua_zip_file_uzclose},
    {NULL, NULL}};

static const luaL_Reg lua_zip_open_file_reg[] = {
    {"extract", lua_zip_extract_to},
    {"open", lua_zip_open_uzfile_mt},
    {"lines", lua_zip_lines_mt},
    {"get", lua_zip_extract_tostring},
    {NULL, NULL}};

#define lua_zip_filesize_hr(size, sizehr)                        \
    if (size > 1073741824) {                                     \
        sprintf(sizehr, "%0.02f GB", (double)size / 1073741824); \
    } else if (size > 1048576) {                                 \
        sprintf(sizehr, "%0.02f MB", (double)size / 1048576);    \
    } else if (size > 1024) {                                    \
        sprintf(sizehr, "%0.02f KB", (double)size / 1024);       \
    } else {                                                     \
        sprintf(sizehr, "%01.0f B ", (double)size);              \
    }

#endif  // LUA_ZIP_INCLUDED