#ifndef LW_ZIP_INCLUDED
#define LW_ZIP_INCLUDED

#include <lauxlib.h>
#include <lx_error.h>
#include <lx_gcptr.h>

#include "unzip.h"
#include "zip.h"

#ifndef LWZIP_API
#ifdef LWZIP_EXPORTS
#define LWZIP_API __declspec(dllexport)
#else
#define LWZIP_API
#endif
#endif

#ifndef LW_ZIPLIBNAME
#define LW_ZIPLIBNAME "lwzip"
#endif

#define LW_ZIP_BUFFERSIZE 1024

#ifndef _MAX_PATH
#define _MAX_PATH 260
#endif

LWZIP_API int luaopen_lwzip(lua_State* L);

// non portable functions
int FileTimeToZipTime(const char* fileanme, tm_zip* sts);
void SystemTimeToZipTime(tm_zip* sts);

// unzip functions
int lw_zip_open(lua_State* L);
int lw_zip_open_resource(lua_State* L);
int lw_zip_uzfile_gc(lua_State* L);
int lw_zip_uzfile_close(lua_State* L);
int lw_zip_extract_file(lua_State* L);
int lw_zip_extract_to(lua_State* L);
int lw_zip_extract_all(lua_State* L);
int lw_zip_createtree(const char* path);
int lw_zip_open_uzfile(lua_State* L);
int lw_zip_open_uzfile_mt(lua_State* L);
int lw_zip_file_uzread(lua_State* L);
int lw_zip_file_uzclose(lua_State* L);
int lw_zip_file_uzeof(lua_State* L);
int lw_zip_file_uztell(lua_State* L);
int lw_zip_lines_mt(lua_State* L);
int lw_zip_lines(lua_State* L);
int lw_zip_extract_file_tostring(lua_State* L);
int lw_zip_extract_tostring(lua_State* L);

// zip functions
int lw_zip_create(lua_State* L);
int lw_zip_zipfile_gc(lua_State* L);
int lw_zip_zipfile_close(lua_State* L);
int lw_zip_addfile(lua_State* L);
int lw_zip_open_zipfile(lua_State* L);
int lw_zip_file_zipwrite(lua_State* L);
int lw_zip_file_zipclose(lua_State* L);

static const luaL_Reg lw_ziplib[] = {
    {"open", lw_zip_open},
    {"create", lw_zip_create},
    {"open_resource", lw_zip_open_resource},
    {NULL, NULL}};

static const luaL_Reg lw_zip_udatamt[] = {
    {"lw_zip_uzfile", lw_zip_uzfile_gc},
    {"lw_zip_zipfile", lw_zip_zipfile_gc},
    {NULL, NULL}};

#define lw_zip_filesize_hr(size, sizehr)                            \
    if (size > 1099511627776) {                                     \
        sprintf(sizehr, "%0.02f TB", (double)size / 1099511627776); \
    } else if (size > 1073741824) {                                 \
        sprintf(sizehr, "%0.02f GB", (double)size / 1073741824);    \
    } else if (size > 1048576) {                                    \
        sprintf(sizehr, "%0.02f MB", (double)size / 1048576);       \
    } else if (size > 1024) {                                       \
        sprintf(sizehr, "%0.02f KB", (double)size / 1024);          \
    } else {                                                        \
        sprintf(sizehr, "%01.0f B ", (double)size);                 \
    }

#endif  // LW_ZIP_INCLUDED