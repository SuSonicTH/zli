#ifdef WIN32
#include <lauxlib.h>
#include "lx_error.h"

LUAX_API char luax_PushSystemError(lua_State* L,const char *message)
{
	LPVOID lpMsgBuf;
	DWORD error=GetLastError();
	
	if (error==NO_ERROR){
		return 0;
	}

	if (FormatMessage(
		FORMAT_MESSAGE_ALLOCATE_BUFFER | 
		FORMAT_MESSAGE_FROM_SYSTEM | 
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		error,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		(LPTSTR) &lpMsgBuf,
		0,
		NULL ))
	{
		lua_pushfstring(L,"Error %s: %s",message,lpMsgBuf);
	}else{
		lua_pushfstring(L,"Error %s",message,lpMsgBuf);
	}
	return 1;
}

LUAX_API void luax_PushSystemErrorCode(lua_State* L,const char *message,DWORD code)
{
	LPVOID lpMsgBuf;

	if (FormatMessage(
		FORMAT_MESSAGE_ALLOCATE_BUFFER | 
		FORMAT_MESSAGE_FROM_SYSTEM | 
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		code,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		(LPTSTR) &lpMsgBuf,
		0,
		NULL ))
	{
		lua_pushfstring(L,"Error %s: %s",message,lpMsgBuf);
	}else{
		lua_pushfstring(L,"Error %s",message,lpMsgBuf);
	}
}

#endif
