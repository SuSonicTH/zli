#include "fm_zip.h"

int luaopen_fmzip(lua_State *L) {
    luaL_newlib(L, fm_ziplib);
    luax_register_mt(L, fm_zip_udatamt);
    return 1;
}

#ifdef _WIN32
#define VC_EXTRALEAN
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#define create_directory(dir) CreateDirectory(dir, NULL)

int directory_exists(const char *directory) {
    WIN32_FIND_DATA ffd;
    HANDLE ffh = NULL;
    if ((ffh = FindFirstFile(directory, &ffd)) == INVALID_HANDLE_VALUE) {
        FindClose(ffh);
        return 0;
    }
    FindClose(ffh);
    return 1;
}

int filetime_to_ziptime(const char *filename, tm_zip *tmz) {
    WIN32_FIND_DATA ffd;
    HANDLE ffh = NULL;
    SYSTEMTIME st;

    if ((ffh = FindFirstFile(filename, &ffd)) == INVALID_HANDLE_VALUE) {
        FindClose(ffh);
        return 0;
    }
    FileTimeToSystemTime(&ffd.ftLastWriteTime, &st);
    FindClose(ffh);

    tmz->tm_year = st.wYear;
    tmz->tm_mon = st.wMonth;
    tmz->tm_mon--;
    tmz->tm_mday = st.wDay;
    tmz->tm_hour = st.wHour;
    tmz->tm_min = st.wMinute;
    tmz->tm_sec = st.wSecond;
    return 1;
}

#else  // not _WIN32
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define create_directory(dir) mkdir(dir, 0775)

char *directory_wo_slash(const char *file) {
    static char name[_MAX_PATH + 1];
    size_t len = strlen(directory);
    if (len > _MAX_PATH) {
        len = _MAX_PATH;
    }

    strncpy(name, file, _MAX_PATH - 1);
    name[MAXFILENAME] = 0;

    if (name[len - 1] == '/') {
        name[len - 1] = 0;
    }

    return name;
}

int directory_exists(char *directory) {
    struct stat st = {0};
    if (stat(directory_wo_slash(directory), &st) == -1) {
        return 0;
    }
    return 1;
}

void filetime_to_ziptime(const char *filename, tm_zip *tmz) {
    struct stat s;
    struct tm *filedate;
    time_t tm_t = 0;
    char *name = directory_wo_slash(filename);

    if (stat(name, &s) != 0) {
        return 0;
    }

    tm_t = s.st_mtime;
    filedate = localtime(&tm_t);

    tmz->tm_sec = filedate->tm_sec;
    tmz->tm_min = filedate->tm_min;
    tmz->tm_hour = filedate->tm_hour;
    tmz->tm_mday = filedate->tm_mday;
    tmz->tm_mon = filedate->tm_mon;
    tmz->tm_year = filedate->tm_year;
    return 1;
}

#endif  //_WIN32

void systemTimeToZipTime(tm_zip *tmz) {
    time_t tm_t = 0;
    struct tm *systemTime;
    time(&tm_t);
    systemTime = localtime(&tm_t);
    tmz->tm_sec = systemTime->tm_sec;
    tmz->tm_min = systemTime->tm_min;
    tmz->tm_hour = systemTime->tm_hour;
    tmz->tm_mday = systemTime->tm_mday;
    tmz->tm_mon = systemTime->tm_mon;
    tmz->tm_year = systemTime->tm_year;
}

int fm_zip_open(lua_State *L) {
    const char *fname;
    char *comment = NULL;
    unz_global_info uzgi;
    unz_file_info uzfi;
    char zfname[LW_ZIP_BUFFERSIZE];
    long fpos = 1;
    int udpos = 0;
    unsigned long long compressed = 0, uncompressed = 0;
    char time[30];
    char sizehr[12];
    zlib_filefunc_def zlff;
    unzFile uzfh;

    luaL_checkstring(L, 1);
    fname = lua_tostring(L, 1);

    luax_return_with_error_if(L, (uzfh = unzOpen(fname)) == NULL, "Could not open file '%s'", fname);
    unzGetGlobalInfo(uzfh, &uzgi);

    luax_createudata(L, uzfh, FM_ZIP_UZ_FILE);
    udpos = lua_gettop(L);
    lua_newtable(L);
    lua_pushstring(L, FM_ZIP_UZ_FILE);
    lua_pushvalue(L, udpos);
    lua_settable(L, -3);
    luax_settable_number(L, -3, "entries", uzgi.number_entry);
    lua_pushstring(L, "comment");
    if (uzgi.size_comment) {
        comment = (char *)malloc(sizeof(char) * (uzgi.size_comment + 1));
        unzGetGlobalComment(uzfh, comment, uzgi.size_comment + 1);
        lua_pushlstring(L, comment, uzgi.size_comment);
        free(comment);
    } else {
        lua_pushstring(L, "");
    }
    lua_settable(L, -3);
    luax_settable_function_list(L, -3, fm_zip_open_reg);
    lua_pushstring(L, "files");
    lua_newtable(L);
    unzGoToFirstFile(uzfh);
    do {
        unzGetCurrentFileInfo(uzfh, &uzfi, zfname, sizeof(zfname), NULL, 0, NULL, 0);
        compressed += uzfi.compressed_size;
        uncompressed += uzfi.uncompressed_size;
        lua_pushstring(L, zfname);
        lua_newtable(L);
        lua_pushnumber(L, fpos);
        lua_pushvalue(L, -2);
        lua_pushstring(L, FM_ZIP_UZ_FILE);
        lua_pushvalue(L, udpos);
        lua_settable(L, -3);
        luax_settable_string(L, -3, "name", zfname);
        luax_settable_boolean(L, -3, "directory", zfname[strlen(zfname) - 1] == '/' ? 1 : 0);
        luax_settable_number(L, -3, "uncompressed_size", uzfi.uncompressed_size);
        fm_zip_filesize_hr(uzfi.uncompressed_size, sizehr);
        luax_settable_string(L, -3, "uncompressed_size_hr", sizehr);
        luax_settable_number(L, -3, "compressed_size", uzfi.compressed_size);
        fm_zip_filesize_hr(uzfi.compressed_size, sizehr);
        luax_settable_string(L, -3, "compressed_size_hr", sizehr);
        luax_settable_number(L, -3, "compression_ratio", (double)uzfi.compressed_size / uzfi.uncompressed_size);
        luax_settable_number(L, -3, "crc", uzfi.crc);
        luax_settable_number(L, -3, "pos", fpos++);
        // push filetime
        lua_pushstring(L, "time");
        lua_newtable(L);
        luax_settable_number(L, -3, "year", uzfi.tmu_date.tm_year);
        luax_settable_number(L, -3, "month", uzfi.tmu_date.tm_mon);
        luax_settable_number(L, -3, "day", uzfi.tmu_date.tm_mday);
        luax_settable_number(L, -3, "hour", uzfi.tmu_date.tm_hour);
        luax_settable_number(L, -3, "minute", uzfi.tmu_date.tm_min);
        luax_settable_number(L, -3, "second", uzfi.tmu_date.tm_sec);
        lua_settable(L, -3);
        // push timestamp
        sprintf(time, "%d/%02d/%02d %02d:%02d:%02d", uzfi.tmu_date.tm_year, uzfi.tmu_date.tm_mon, uzfi.tmu_date.tm_mday, uzfi.tmu_date.tm_hour, uzfi.tmu_date.tm_min, uzfi.tmu_date.tm_sec);
        luax_settable_string(L, -3, "timestamp", time);
        // push functions
        luax_settable_function_list(L, -3, fm_zip_open_file_reg);
        lua_settable(L, -5);
        lua_settable(L, -3);
    } while (unzGoToNextFile(uzfh) == UNZ_OK);
    lua_settable(L, -3);
    luax_settable_number(L, -3, "compressed_size", compressed);
    luax_settable_number(L, -3, "uncompressed_size", uncompressed);
    luax_settable_number(L, -3, "compression_ratio", (double)compressed / uncompressed);
    fm_zip_filesize_hr(uncompressed, sizehr);
    luax_settable_string(L, -3, "uncompressed_size_hr", sizehr);
    fm_zip_filesize_hr(compressed, sizehr);
    luax_settable_string(L, -3, "compressed_size_hr", sizehr);
    return 1;
}

int fm_zip_lines_mt(lua_State *L) {
    lua_pushstring(L, "name");
    lua_gettable(L, -2);
    return fm_zip_lines(L);
}

int fm_zip_lines(lua_State *L) {
    unzFile uzfh;
    const char *fname;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    luaL_checkstring(L, 2);
    fname = lua_tostring(L, 2);

    luax_return_with_error_if(L, unzLocateFile(uzfh, fname, 0) != UNZ_OK, "File '%s' not found", fname);
    luax_return_with_error_if(L, unzOpenCurrentFile(uzfh) != UNZ_OK, "Could not open file '%s'", fname);

    lua_pushcfunction(L, fm_zip_file_uzread);
    lua_newtable(L);
    lua_pushstring(L, FM_ZIP_UZ_FILE);
    lua_pushstring(L, FM_ZIP_UZ_FILE);
    lua_gettable(L, 1);
    lua_settable(L, -3);
    luax_settable_boolean(L, -3, "iterator", 1);
    return 2;
}

int fm_zip_open_uzfile_mt(lua_State *L) {
    lua_pushstring(L, "name");
    lua_gettable(L, -2);
    return fm_zip_open_uzfile(L);
}

int fm_zip_open_uzfile(lua_State *L) {
    unzFile uzfh;
    const char *fname;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    luaL_checkstring(L, 2);
    fname = lua_tostring(L, 2);

    unzCloseCurrentFile(uzfh);
    luax_return_with_error_if(L, unzLocateFile(uzfh, fname, 0) != UNZ_OK, "File '%s' not found", fname);
    luax_return_with_error_if(L, unzOpenCurrentFile(uzfh) != UNZ_OK, "Could not open file '%s'", fname);

    lua_newtable(L);
    lua_pushstring(L, FM_ZIP_UZ_FILE);
    lua_pushstring(L, FM_ZIP_UZ_FILE);
    lua_gettable(L, 1);
    lua_settable(L, -3);
    luax_settable_cfunction(L, -3, "read", fm_zip_file_uzread);
    luax_settable_cfunction(L, -3, "close", fm_zip_file_uzclose_current);
    luax_settable_cfunction(L, -3, "eof", fm_zip_file_uzeof);
    luax_settable_cfunction(L, -3, "tell", fm_zip_file_uztell);
    return 1;
}

int fm_zip_file_uzread(lua_State *L) {
    unzFile uzfh;
    const char *readmode;
    int chartoread;
    int n;
    luaL_Buffer lb;
    char rb[LW_ZIP_BUFFERSIZE];
    int cr;
    int maxarg = lua_gettop(L);
    int read;
    int iterator = 0;

    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    luax_gettable_bool(L, 1, "iterator", iterator, 0);
    if (lua_isnil(L, 2) || iterator) {
        lua_pushstring(L, "*l");
        lua_replace(L, 2);
    }

    for (n = 2; n <= maxarg; n++) {
        if (lua_type(L, n) == LUA_TNUMBER) {
            readmode = "*c";
            chartoread = luax_toint(L, n);
        } else if (lua_type(L, n) == LUA_TSTRING) {
            readmode = lua_tostring(L, n);
            luaL_argcheck(L, readmode[0] == '*' && strlen(readmode) == 2, n, "Wrong argument to zip:read()");
        } else {
            lua_pushfstring(L, "Unknown format for argument #%d to zip:read. String or number expected", n);
            lua_error(L);
        }
        // TODO: fm_zip_file_uzread: Implement buffered file reading and missing read modes
        switch (readmode[1]) {
            case 'n':
                break;
            case 'a':
                luaL_buffinit(L, &lb);
                while ((cr = unzReadCurrentFile(uzfh, &rb, LW_ZIP_BUFFERSIZE)) > 0) {
                    luaL_addlstring(&lb, rb, cr);
                }
                luaL_pushresult(&lb);
                break;
            case 'l':
                read = 0;
                luaL_buffinit(L, &lb);
                while (unzReadCurrentFile(uzfh, &rb, 1) == 1) {
                    read = 1;
                    if (*rb == '\n')
                        break;
                    luaL_addchar(&lb, *rb);
                }
                luaL_pushresult(&lb);
                if (!read) {
                    lua_pop(L, 1);
                    lua_pushnil(L);
                    if (iterator)
                        unzCloseCurrentFile(uzfh);
                }
                break;
            case 'c':
                luaL_buffinit(L, &lb);
                while ((cr = unzReadCurrentFile(uzfh, &rb, chartoread > LW_ZIP_BUFFERSIZE ? LW_ZIP_BUFFERSIZE : chartoread)) > 0) {
                    chartoread -= cr;
                    luaL_addlstring(&lb, rb, cr);
                }
                luaL_pushresult(&lb);
                break;
            default:
                lua_pushfstring(L, "Format '%s' is unknown", readmode);
                readmode = lua_tostring(L, -1);
                luaL_argerror(L, n, readmode);
                return 1;
        }
    }
    return maxarg - 1;
}

int fm_zip_file_uzclose(lua_State *L) {
    unzFile uzfh;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    unzCloseCurrentFile(uzfh);
    unzClose(uzfh);
    luax_set_gcudata(L, 1, FM_ZIP_UZ_FILE, NULL);
    return 0;
}

int fm_zip_file_uzclose_current(lua_State *L) {
    unzFile uzfh;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    unzCloseCurrentFile(uzfh);
    return 0;
}

int fm_zip_file_uzeof(lua_State *L) {
    unzFile uzfh;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    lua_pushboolean(L, unzeof(uzfh));
    return 1;
}

int fm_zip_file_uztell(lua_State *L) {
    unzFile uzfh;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    lua_pushnumber(L, unztell(uzfh));
    return 1;
}

int fm_zip_extract_file(lua_State *L) {
    unzFile uzfh;
    const char *fnamein;
    const char *fnameout;
    char *buff[LW_ZIP_BUFFERSIZE];
    int cr;
    FILE *fp;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    luaL_checkstring(L, 2);
    luaL_checkstring(L, 3);

    fnamein = lua_tostring(L, 2);
    fnameout = lua_tostring(L, 3);

    luax_return_with_error_if(L, unzLocateFile(uzfh, fnamein, 0) != UNZ_OK, "File '%s' not found", fnamein);
    luax_return_with_error_if(L, unzOpenCurrentFile(uzfh) != UNZ_OK, "Could not read file '%s'", fnamein);
    luax_return_with_error_if(L, (fp = fopen(fnameout, "wb")) == NULL, "Could not open output file '%s'", fnameout);

    while ((cr = unzReadCurrentFile(uzfh, &buff, LW_ZIP_BUFFERSIZE)) > 0) {
        fwrite(buff, sizeof(char), cr, fp);
    }

    fclose(fp);
    unzCloseCurrentFile(uzfh);
    lua_pushboolean(L, 1);
    return 1;
}

int fm_zip_extract_file_tostring(lua_State *L) {
    unzFile uzfh;
    const char *fnamein;
    char *buff[LW_ZIP_BUFFERSIZE];
    luaL_Buffer lbuff;
    int cr;

    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    luaL_checkstring(L, 2);

    fnamein = lua_tostring(L, 2);

    luax_return_with_error_if(L, unzLocateFile(uzfh, fnamein, 0) != UNZ_OK, "File '%s' not found", fnamein);
    luax_return_with_error_if(L, unzOpenCurrentFile(uzfh) != UNZ_OK, "Could not read file '%s'", fnamein);

    luaL_buffinit(L, &lbuff);
    while ((cr = unzReadCurrentFile(uzfh, &buff, LW_ZIP_BUFFERSIZE)) > 0) {
        lua_pushlstring(L, (const char *)buff, cr);
        luaL_addvalue(&lbuff);
    }

    luaL_pushresult(&lbuff);
    unzCloseCurrentFile(uzfh);

    return 1;
}

int fm_zip_extract_tostring(lua_State *L) {
    unzFile uzfh;
    const char *fnamein;
    char *buff[LW_ZIP_BUFFERSIZE];
    luaL_Buffer lbuff;
    int cr;

    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    luax_gettable_string(L, 1, "name", fnamein, NULL);

    luax_return_with_error_if(L, unzLocateFile(uzfh, fnamein, 0) != UNZ_OK, "File '%s' not found", fnamein);
    luax_return_with_error_if(L, unzOpenCurrentFile(uzfh) != UNZ_OK, "Could not read file '%s'", fnamein);

    luaL_buffinit(L, &lbuff);
    while ((cr = unzReadCurrentFile(uzfh, &buff, LW_ZIP_BUFFERSIZE)) > 0) {
        lua_pushlstring(L, (const char *)buff, cr);
        luaL_addvalue(&lbuff);
    }
    luaL_pushresult(&lbuff);
    unzCloseCurrentFile(uzfh);

    return 1;
}

int fm_zip_extract_to(lua_State *L) {
    unzFile uzfh;
    const char *fnamein;
    const char *fnameout;
    char *buff[LW_ZIP_BUFFERSIZE];
    int cr;
    FILE *fp;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    fnameout = lua_tostring(L, 2);
    luax_gettable_string(L, 1, "name", fnamein, NULL);
    if (fnameout == NULL)
        fnameout = fnamein;

    luax_return_with_error_if(L, unzLocateFile(uzfh, fnamein, 0) != UNZ_OK, "File '%s' not found", fnamein);
    luax_return_with_error_if(L, unzOpenCurrentFile(uzfh) != UNZ_OK, "Could not read file '%s'", fnamein);
    luax_return_with_error_if(L, (fp = fopen(fnameout, "wb")) == NULL, "Could not open output file '%s'", fnameout);

    while ((cr = unzReadCurrentFile(uzfh, &buff, LW_ZIP_BUFFERSIZE)) > 0) {
        fwrite(buff, sizeof(char), cr, fp);
    }

    fclose(fp);
    unzCloseCurrentFile(uzfh);
    lua_pushboolean(L, 1);
    return 1;
}

int fm_zip_extract_all(lua_State *L) {
    unzFile uzfh;
    const char *dest;
    const char *path;
    char zfname[_MAX_PATH] = {0};
    char buff[LW_ZIP_BUFFERSIZE];
    int cr;
    FILE *fp;

    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    dest = lua_tostring(L, 2);
    if (dest) {
        luax_gsub(L, dest, dest, "\\", "/");
        luax_gsub(L, dest, dest, "./", "");
        if (strlen(dest)) {
            if (dest[strlen(dest) - 1] != '/') {
                luax_fstring(L, dest, "%s/", dest);
            }
            if (!fm_zip_createtree(dest)) {
                lua_pushnil(L);
                lua_pushfstring(L, "Could not create output path:'%s'", dest);
                return 2;
            }
        }
    }

    unzGoToFirstFile(uzfh);
    do {
        unzGetCurrentFileInfo(uzfh, NULL, zfname, sizeof(zfname), NULL, 0, NULL, 0);
        if (zfname[strlen(zfname) - 1] == '/') {
            if (dest) {
                lua_pushfstring(L, "%s%s", dest, zfname);
                path = lua_tostring(L, -1);
                lua_pop(L, 1);
                if (!fm_zip_createtree(path)) {
                    lua_pushnil(L);
                    lua_pushfstring(L, "Could not create output path:'%s'", path);
                    return 2;
                }
            } else {
                if (!fm_zip_createtree(zfname)) {
                    lua_pushnil(L);
                    lua_pushfstring(L, "Could not create output path:'%s'", zfname);
                    return 2;
                }
            }
        } else {
            luax_return_with_error_if(L, unzOpenCurrentFile(uzfh) != UNZ_OK, "Could not read file '%s'", zfname);
            if (dest) {
                lua_pushfstring(L, "%s%s", dest, zfname);
                path = lua_tostring(L, -1);
                lua_pop(L, 1);
            } else {
                path = zfname;
            }
            if ((fp = fopen(path, "wb")) == NULL) {
                unzCloseCurrentFile(uzfh);
                lua_pushnil(L);
                lua_pushfstring(L, "Could not open output file '%s'", path);
                return 2;
            }
            while ((cr = unzReadCurrentFile(uzfh, &buff, LW_ZIP_BUFFERSIZE)) > 0) {
                fwrite(buff, sizeof(char), cr, fp);
            }

            fclose(fp);
            unzCloseCurrentFile(uzfh);
        }
    } while (unzGoToNextFile(uzfh) == UNZ_OK);

    lua_pushboolean(L, 1);
    return 1;
}

int fm_zip_createtree(const char *path) {
    char npath[_MAX_PATH];
    char *cpos;

    if (path[strlen(path) - 1] == '/') {
        strcpy(npath, path);
        cpos = npath + strlen(npath) - 1;
        *cpos = 0;
        return fm_zip_createtree(npath);
    } else if (directory_exists(path)) {
        return 1;
    } else {
        strcpy(npath, path);
        cpos = npath + strlen(npath) - 1;
        while (*cpos != '/' && cpos != npath) {
            cpos--;
        }
        *cpos = 0;
        if (*npath != 0) {
            if (!fm_zip_createtree(npath)) {
                return 0;
            }
        }
        return create_directory(path);
    }
    return 0;
}

int fm_zip_uzfile_gc(lua_State *L) {
    unzFile uzfh;
    luaL_checkudata(L, 1, FM_ZIP_UZ_FILE);
    luax_to_cgudata(L, 1, unzFile, uzfh);
    if (uzfh)
        unzClose(uzfh);
    return 0;
}

int fm_zip_uzfile_close(lua_State *L) {
    unzFile uzfh;
    luax_getarg_gcudata(L, 1, FM_ZIP_UZ_FILE, unzFile, uzfh, "Zip object expected");
    unzClose(uzfh);
    luax_set_gcudata(L, 1, FM_ZIP_UZ_FILE, NULL);
    return 0;
}

int fm_zip_create(lua_State *L) {
    zipFile zfh;
    char *sappend;
    const char *fname;
    const char *serror;
    int append;
    luaL_checkstring(L, 1);
    fname = lua_tostring(L, 1);

    if (lua_gettop(L) == 1 || lua_isnil(L, 2)) {
        append = APPEND_STATUS_CREATE;
    } else {
        luax_tostring_copy(L, 2, sappend);
        strupr(sappend);
        if (strcmp(sappend, "CREATE") == 0) {
            append = APPEND_STATUS_CREATE;
        } else if (strcmp(sappend, "ADD") == 0) {
            append = APPEND_STATUS_ADDINZIP;
        } else if (strcmp(sappend, "CREATEAFTER") == 0) {
            append = APPEND_STATUS_CREATEAFTER;
        } else {
            free(sappend);
            lua_pushfstring(L, "Creation type '%s' is unknown", sappend);
            serror = lua_tostring(L, -1);
            luaL_argerror(L, 2, serror);
        }
        free(sappend);
    }
    luax_return_with_error_if(L, (zfh = zipOpen(fname, append)) == NULL, "Could not open Zip file '%s'", fname);

    lua_newtable(L);
    lua_pushstring(L, FM_ZIP_ZIP_FILE);
    luax_createudata(L, zfh, FM_ZIP_ZIP_FILE);
    lua_settable(L, -3);
    luax_settable_cfunction(L, -3, "close", fm_zip_zipfile_close);
    luax_settable_cfunction(L, -3, "addfile", fm_zip_addfile);
    luax_settable_cfunction(L, -3, "open", fm_zip_open_zipfile);
    return 1;
}

int fm_zip_zipfile_gc(lua_State *L) {
    zipFile zfh;
    luaL_checkudata(L, 1, FM_ZIP_ZIP_FILE);
    luax_to_cgudata(L, 1, zipFile, zfh);
    if (zfh) {
        zipCloseFileInZip(zfh);
        zipClose(zfh, NULL);
    }
    return 0;
}

int fm_zip_zipfile_close(lua_State *L) {
    zipFile zfh;
    const char *comment;
    luax_getarg_gcudata(L, 1, FM_ZIP_ZIP_FILE, zipFile, zfh, "Zip object expected");
    comment = lua_tostring(L, 2);
    zipCloseFileInZip(zfh);
    zipClose(zfh, comment);
    luax_set_gcudata(L, 1, FM_ZIP_ZIP_FILE, NULL);
    return 0;
}

int fm_zip_zip_fill_filedate(lua_State *L, zip_fileinfo *zfi, const char *filename, int n) {
    char *stime;
    const char *serror;

    zfi->dosDate = 0;
    zfi->external_fa = 0;
    zfi->internal_fa = 0;

    if (lua_type(L, n) == LUA_TNIL || lua_type(L, n) == LUA_TNONE) {
        if (filename == NULL) {
            systemTimeToZipTime(&zfi->tmz_date);
            return 1;
        } else {
            if (filetime_to_ziptime(filename, &zfi->tmz_date)) {
                return 1;
            } else {
                lua_pushfstring(L, "Could not find file '%s'!", filename);
                serror = lua_tostring(L, -1);
                lua_pushnil(L);
                lua_pushstring(L, serror);
                return 0;
            }
        }
    } else if (lua_type(L, n) == LUA_TSTRING) {
        luax_tostring_copy(L, n, stime);
        strupr(stime);
        if (strcmp(stime, "FILETIME") == 0) {
            if (filetime_to_ziptime(filename, &zfi->tmz_date)) {
                return 1;
            } else {
                lua_pushfstring(L, "Could not find file '%s'!", filename);
                serror = lua_tostring(L, -1);
                lua_pushnil(L);
                lua_pushstring(L, serror);
                free(stime);
                return 0;
            }
        } else if (strcmp(stime, "LOCALTIME") == 0 || strcmp(stime, "SYSTEMTIME") == 0) {
            free(stime);
            systemTimeToZipTime(&zfi->tmz_date);
            return 1;
        } else {
            free(stime);
            luaL_argerror(L, n, "Timeformat unknown!");
            return 0;
        }
    } else if (lua_type(L, n) == LUA_TTABLE) {
        luax_gettable_int(L, n, "year", zfi->tmz_date.tm_year, 0);
        luax_gettable_int(L, n, "month", zfi->tmz_date.tm_mon, 0);
        zfi->tmz_date.tm_mon--;
        luax_gettable_int(L, n, "day", zfi->tmz_date.tm_mday, 0);
        luax_gettable_int(L, n, "hour", zfi->tmz_date.tm_hour, 0);
        luax_gettable_int(L, n, "minute", zfi->tmz_date.tm_min, 0);
        luax_gettable_int(L, n, "second", zfi->tmz_date.tm_sec, 0);
        return 1;
    } else {
        luaL_argerror(L, n, "Timeformat unknown!");
        return 0;
    }
}

int fm_zip_addfile(lua_State *L) {
    zipFile zfh;
    zip_fileinfo zfi;
    const char *infname;
    const char *outfname;
    const char *comment;
    char buffer[LW_ZIP_BUFFERSIZE];
    FILE *fh;
    size_t cr;
    int compression;

    luax_getarg_gcudata(L, 1, FM_ZIP_ZIP_FILE, zipFile, zfh, "Zip object expected");
    
    infname = luaL_checkstring(L, 2);
    outfname = luaL_checkstring(L, 3);

    if (!fm_zip_zip_fill_filedate(L, &zfi, infname, 4))
        return 2;

    compression = (int)luaL_optnumber(L, 5, 9);
    comment = luaL_optstring(L, 6, NULL);

    zipCloseFileInZip(zfh);
    luax_return_with_error_if(L, zipOpenNewFileInZip(zfh, outfname, &zfi, NULL, 0, NULL, 0, comment, Z_DEFLATED, compression), "Could not add file '%s' to zip", outfname);
    luax_return_with_error_if(L, (fh = fopen(infname, "rb")) == NULL, "Could not open input file '%s'", infname);

    while ((cr = fread(buffer, 1, LW_ZIP_BUFFERSIZE, fh)) > 0) {
        zipWriteInFileInZip(zfh, buffer, (unsigned int)cr);
    }

    fclose(fh);
    zipCloseFileInZip(zfh);
    lua_pushboolean(L, 1);
    return 1;
}

int fm_zip_open_zipfile(lua_State *L) {
    zipFile zfh;
    zip_fileinfo zfi;
    const char *fname;
    const char *comment;
    int compression;

    luax_getarg_gcudata(L, 1, FM_ZIP_ZIP_FILE, zipFile, zfh, "Zip object expected");
    luaL_checkstring(L, 2);
    fname = lua_tostring(L, 2);
    if (!fm_zip_zip_fill_filedate(L, &zfi, NULL, 3))
        return 2;

    compression = (int)luaL_optnumber(L, 4, 9);
    comment = luaL_optstring(L, 5, NULL);

    zipCloseFileInZip(zfh);
    luax_return_with_error_if(L, zipOpenNewFileInZip(zfh, fname, &zfi, NULL, 0, NULL, 0, comment, Z_DEFLATED, compression), "Could not add file '%s' to zip", fname);

    lua_newtable(L);
    lua_pushstring(L, FM_ZIP_ZIP_FILE);
    lua_pushstring(L, FM_ZIP_ZIP_FILE);
    lua_gettable(L, 1);
    lua_settable(L, -3);
    luax_settable_cfunction(L, -3, "write", fm_zip_file_zipwrite);
    luax_settable_cfunction(L, -3, "close", fm_zip_file_zipclose);

    return 1;
}

int fm_zip_file_zipwrite(lua_State *L) {
    zipFile zfh;
    const char *data;
    size_t datalen;
    int maxarg = lua_gettop(L);
    int n;
    luax_getarg_gcudata(L, 1, FM_ZIP_ZIP_FILE, zipFile, zfh, "Zip object expected");
    for (n = 2; n <= maxarg; n++) {
        luaL_checkstring(L, n);
        data = lua_tolstring(L, n, &datalen);
        if (data && datalen > 0)
            zipWriteInFileInZip(zfh, data, (unsigned int)datalen);
    }
    lua_pushboolean(L, 1);
    return 1;
}

int fm_zip_file_zipclose(lua_State *L) {
    zipFile zfh;
    luax_getarg_gcudata(L, 1, FM_ZIP_ZIP_FILE, zipFile, zfh, "Zip object expected");
    zipCloseFileInZip(zfh);
    return 0;
}
