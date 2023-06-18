#include "fm_payload.h"

static unzFile uzfh = NULL;
static char *exename = "";

const char *payload_reder(lua_State *L, void *data, size_t *size) {
    static char buffer[FM_PAYLOAD_BUFFER_SIZE];
    *size = unzReadCurrentFile(uzfh, &buffer, FM_PAYLOAD_BUFFER_SIZE);
    return buffer;
}

int payload_loader(lua_State *L) {
    if (lua_load(L, payload_reder, NULL, lua_tostring(L, 2), "rt") != LUA_OK) {
        lua_error(L);
    }
    if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK) {
        lua_error(L);
    }
    return 1;
}

int paylod_searcher(lua_State *L) {
    fflush(stdout);
    const char *module = lua_tostring(L, 1);
    char filename[260] = {0};

    strcpy(filename, module);
    strcat(filename, ".lua");
    if (unzLocateFile(uzfh, filename, 0) != UNZ_OK) {
        strcpy(filename, module);
        strcat(filename, "/init.lua");
        if (unzLocateFile(uzfh, filename, 0) != UNZ_OK) {
            lua_pushfstring(L, "no file '%s.lua' or '%s/init.lua' in %s", module, module, exename);
            return 1;
        }
    }

    if (unzOpenCurrentFile(uzfh) != UNZ_OK) {
        lua_pushnil(L);
        return 1;
    }

    lua_pushcfunction(L, payload_loader);
    lua_pushstring(L, filename);
    return 2;
}

void create_payload_searcher(lua_State *L, char *exe) {
    char zfname[260];
    if ((uzfh = unzOpen(exe)) == NULL) {
        return;
    }
    exename = exe;
    int top = lua_gettop(L);

    lua_getglobal(L, "package");
    int package = lua_gettop(L);

    lua_pushstring(L, "searchers");
    lua_gettable(L, package);
    luax_len(L, int len, -1);
    lua_pushcfunction(L, paylod_searcher);
    lua_rawseti(L, -2, len + 1);

    lua_settop(L, top);
}
