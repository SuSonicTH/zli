#ifndef LUAX_ERROR
#define LUAX_ERROR

#ifndef LUAX_API
	#ifdef LUAX_EXPORTS
		#define LUAX_API __declspec(dllexport)
	#else
		#define LUAX_API
	#endif
#endif

#include <lauxlib.h>

#ifdef WIN32
	#define VC_EXTRALEAN
	#define WIN32_LEAN_AND_MEAN
	#include <windows.h>
	LUAX_API char luax_PushSystemError(lua_State* L,const char *message);
	LUAX_API void luax_PushSystemErrorCode(lua_State* L,const char *message,DWORD code);
#endif

#define luax_ExitWithErrorIF(condition,message)\
	if (condition){\
		lua_pushstring(L,message);\
		lua_error(L);\
	}

#define luax_ReturnWithErrorIF(condition,message)\
	if (condition){\
		lua_pushnil(L);\
		lua_pushstring(L,message);\
		return 2;\
	}

#define luax_ReturnWithErrorIF_Clean(condition,message,clean)\
	if (condition){\
		clean\
		lua_pushnil(L);\
		lua_pushstring(L,message);\
		return 2;\
	}

#define luax_ReturnWithSystemErrorIF(condition,message)\
	if (condition){\
		lua_pushnil(L);\
		if (luax_PushSystemError(L,message)){\
			return 2;\
		}else{\
			lua_pop(L,1);\
		}\
	}

#define lua_exit_error(s) {lua_pushstring(L, s); lua_error(L);}

#endif//LUAX_ERROR