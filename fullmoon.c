#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lauxlib.h"
#include "lprefix.h"
#include "lua.h"
#include "lualib.h"

#define PROGRAMM_NAME "FullMoon"

static lua_State *globalL = NULL;

static const char *progname = PROGRAMM_NAME;

#if defined(LUA_USE_POSIX)

static void setsignal(int sig, void (*handler)(int)) {
    struct sigaction sa;
    sa.sa_handler = handler;
    sa.sa_flags = 0;
    sigemptyset(&sa.sa_mask); /* do not mask any signal */
    sigaction(sig, &sa, NULL);
}

#else

#define setsignal signal

#endif

static void lstop(lua_State *L, lua_Debug *ar) {
    (void)ar;                   /* unused arg. */
    lua_sethook(L, NULL, 0, 0); /* reset hook */
    luaL_error(L, "interrupted!");
}

static void laction(int i) {
    int flag = LUA_MASKCALL | LUA_MASKRET | LUA_MASKLINE | LUA_MASKCOUNT;
    setsignal(i, SIG_DFL); /* if another SIGINT happens, terminate process */
    lua_sethook(globalL, lstop, flag, 1);
}

static void l_message(const char *pname, const char *msg) {
    if (pname) lua_writestringerror("%s: ", pname);
    lua_writestringerror("%s\n", msg);
}

static int report(lua_State *L, int status) {
    if (status != LUA_OK) {
        const char *msg = lua_tostring(L, -1);
        l_message(progname, msg);
        lua_pop(L, 1); /* remove message */
    }
    return status;
}

static int msghandler(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL) {                           /* is error object not a string? */
        if (luaL_callmeta(L, 1, "__tostring") && /* does it have a metamethod */
            lua_type(L, -1) == LUA_TSTRING)      /* that produces a string? */
            return 1;                            /* that is the message */
        else
            msg = lua_pushfstring(L, "(error object is a %s value)",
                                  luaL_typename(L, 1));
    }
    luaL_traceback(L, L, msg, 1); /* append a standard traceback */
    return 1;                     /* return the traceback */
}

static int docall(lua_State *L) {
    int status;
    int base = lua_gettop(L);  /* function index */
    lua_pushcfunction(L, msghandler); /* push message handler */
    lua_insert(L, base);              /* put it under function and args */
    globalL = L;                      /* to be available to 'laction' */
    setsignal(SIGINT, laction);       /* set C-signal handler */
    status = lua_pcall(L, 0, 0, base);
    setsignal(SIGINT, SIG_DFL); /* reset C-signal handler */
    lua_remove(L, base);        /* remove message handler from the stack */
    return status;
}

static void createargtable(lua_State *L, char **argv, int argc) {
    lua_createtable(L, argc, argc);
    for (int i = 0; i < argc; i++) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");
}

static int dochunk(lua_State *L, int status) {
    if (status == LUA_OK) status = docall(L);
    return report(L, status);
}

static int dofile(lua_State *L, const char *name) {
    return dochunk(L, luaL_loadfile(L, name));
}

static int dostring(lua_State *L, const char *s, const char *name) {
    return dochunk(L, luaL_loadbuffer(L, s, strlen(s), name));
}

static int pushargs(lua_State *L) {
    int i, n;
    if (lua_getglobal(L, "arg") != LUA_TTABLE)
        luaL_error(L, "'arg' is not a table");
    n = (int)luaL_len(L, -1);
    luaL_checkstack(L, n + 3, "too many arguments to script");
    for (i = 1; i <= n; i++)
        lua_rawgeti(L, -i, i);
    lua_remove(L, -i); /* remove table from the stack */
    return n;
}

extern const char *fullmoon_main;

static int pmain(lua_State *L) {
    int argc = (int)lua_tointeger(L, 1);
    char **argv = (char **)lua_touserdata(L, 2);

    if (argv[0] && argv[0][0]) progname = argv[0];

    luaL_openlibs(L);                      /* open standard libraries */
    createargtable(L, argv, argc); /* create table 'arg' */
    lua_gc(L, LUA_GCGEN, 0, 0);            /* GC in generational mode */

    if (argc >= 2 && argv[1][0] == '-' && argv[1][1] == 0) {
        return dochunk(L, luaL_loadfile(L, NULL));
    } else {
        return dostring(L, fullmoon_main, PROGRAMM_NAME);
    }
    lua_pushboolean(L, 1); /* signal no errors */
    return 1;
}

int main(int argc, char **argv) {
    int status, result;
    lua_State *L = luaL_newstate(); /* create state */
    if (L == NULL) {
        l_message(argv[0], "cannot create state: not enough memory");
        return EXIT_FAILURE;
    }
    lua_pushcfunction(L, &pmain);   /* to call 'pmain' in protected mode */
    lua_pushinteger(L, argc);       /* 1st argument */
    lua_pushlightuserdata(L, argv); /* 2nd argument */
    status = lua_pcall(L, 2, 1, 0); /* do the call */
    result = lua_toboolean(L, -1);  /* get result */
    report(L, status);
    lua_close(L);
    return (result && status == LUA_OK) ? EXIT_SUCCESS : EXIT_FAILURE;
}
