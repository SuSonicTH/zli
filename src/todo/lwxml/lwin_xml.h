#ifndef LW_XML_INCLUDED
#define LW_XML_INCLUDED

#include <lauxlib.h>

#ifndef LWXML_API
	#ifdef LWXML_EXPORTS
		#define LWXML_API __declspec(dllexport)
	#else
		#define LWXML_API
	#endif
#endif

#ifndef LUA_XMLLIBNAME 
	#define LUA_XMLLIBNAME "lwxml"
#endif

LWXML_API int luaopen_xml (lua_State *L);

int lw_xml_open(lua_State* L);
int lw_xml_parse(lua_State* L);

static const luaL_Reg lw_xml[] = {
	{"open",lw_xml_open},
	{"parse",lw_xml_parse},
	{NULL,NULL}
};

#endif//LW_XML_INCLUDED