#include "fm_zip.h"

#include <lx_value.h>
#include <string.h>
#include <unzip.h>
#include <zip.h>

int luaopen_fmzip(lua_State *L) {
    luaL_newlib(L, fm_zip_reg);
    return 1;
}

int fm_zip_new(lua_State *L) {
    return 0;
}

char *fm_zip_get_compression_method_name(unz_file_info64 file_info) {
    if (file_info.compression_method == 0) {
        return "Stored";
    } else if (file_info.compression_method == Z_DEFLATED) {
        return "Deflated";
    } else if (file_info.compression_method == Z_BZIP2ED) {
        return "BZip2";
    }
    return "Unknown";
}

char *fm_zip_get_time_string(unz_file_info64 file_info) {
    static char buffer[17];
    sprintf(buffer, "%d/%02d/%02d  %02d:%02d",
            file_info.tmu_date.tm_year,
            file_info.tmu_date.tm_mon + 1,
            file_info.tmu_date.tm_mday,
            file_info.tmu_date.tm_hour,
            file_info.tmu_date.tm_min);
    return buffer;
}

int fm_zip_open(lua_State *L) {
    const char *filename = luaL_checkstring(L, 1);
    unzFile uf;
    unz_global_info64 gi;
    unz_file_info64 file_info;
    int error;
    char filename_inzip[512];

    if ((uf = unzOpen64(filename)) == NULL) {
        lua_pushnil(L);
        lua_pushfstring(L, "could not open file %s", filename);
        return 2;
    }
    if ((error = unzGetGlobalInfo64(uf, &gi)) != UNZ_OK) {
        unzClose(uf);
        lua_pushnil(L);
        lua_pushfstring(L, "could not get fileinfo for %s error# %d", filename, error);
        return 2;
    }

    lua_settop(L, 1);
    lua_createtable(L, gi.number_entry, 1);
    for (int i = 0; i < gi.number_entry; i++) {
        if ((error = unzGetCurrentFileInfo64(uf, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0)) != UNZ_OK) {
            unzClose(uf);
            lua_pushnil(L);
            lua_pushfstring(L, "could not get fileinfo for file in %s error# %d", filename, error);
            return 2;
        }

        lua_newtable(L);
        luax_settable_string(L, 3, "name", filename_inzip);
        luax_settable_integer(L, 3, "size", file_info.uncompressed_size);
        luax_settable_integer(L, 3, "compressed", file_info.compressed_size);
        luax_settable_number(L, 3, "ratio", ((file_info.compressed_size * 100.0) / file_info.uncompressed_size));
        luax_settable_boolean(L, 3, "crypted", (file_info.flag & 1));
        luax_settable_string(L, 3, "method", fm_zip_get_compression_method_name(file_info));
        luax_settable_string(L, 3, "time", fm_zip_get_time_string(file_info));

        lua_rawseti(L, 2, i + 1);
        if ((i + 1) < gi.number_entry) {
            if ((error = unzGoToNextFile(uf)) != UNZ_OK) {
                unzClose(uf);
                lua_pushnil(L);
                lua_pushfstring(L, "could not get next fileinfo for %s error# %d", filename, error);
                return 2;
            }
        }
    }
    unzClose(uf);
    return 1;
}
