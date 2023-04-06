#ifndef LUAX_VALUE
#define LUAX_VALUE

#include <lauxlib.h>

typedef struct luax_const{
	char *name;
	LUA_NUMBER value;
}luax_const;

void luax_settable_function_list(lua_State* L,int n,const luaL_Reg *lf);
void luax_settable_constant_list(lua_State *L,int n,const luax_const *lc);
void luax_tableinsert(lua_State* L,int tblidx,int pos);
void luax_tableremove(lua_State* L,int tblidx,int pos);
void luax_call(lua_State* L,char *name,int nargs,int nresults,int pop);
void luax_call_lib(lua_State* L,char *package,char *function,int nargs,int nresults,int pop);
void luax_regtable_create_list(lua_State* L,const char **name);

#define luax_tolong(L,n)\
	(long)lua_tonumber(L,n)
	
#define luax_toint(L,n)\
	(int)lua_tonumber(L,n)
	
#define luax_tofloat(L,n)\
	(float)lua_tonumber(L,n)
	
#define luax_todouble(L,n)\
	(double)lua_tonumber(L,n)

#define luax_gettable_table(L,tblidx,name,succ)\
	succ=0;\
	lua_pushstring(L,name);\
	lua_gettable(L,tblidx);\
	if (!lua_isnil(L,-1)){\
		if (lua_type(L,-1)!=LUA_TTABLE)\
			lua_pop(L,1);\
		else\
			succ=1;\
	}else\
		lua_pop(L,1);

#define luax_gettablei_table(L,tblidx,getidx,succ)\
	succ=0;\
	lua_pushnumber(L,getidx);\
	lua_gettable(L,tblidx);\
	if (!lua_isnil(L,-1)){\
		if (lua_type(L,-1)!=LUA_TTABLE)\
			lua_pop(L,1);\
		else\
			succ=1;\
	}else\
		lua_pop(L,1);

#define luax_gettable_lstring(L,tblidx,name,cvar,slen,def)\
	lua_pushstring(L,name);\
	lua_gettable(L,tblidx);\
	if (lua_isnil(L,-1))\
		cvar=def;\
	else\
		cvar=(char*)lua_tolstring(L,-1,slen);\
	lua_pop(L,1);

#define luax_gettable_type(L,tblidx,name,func,ctype,cvar,def) \
	lua_pushstring(L,name);\
	lua_gettable(L,tblidx);\
	if (lua_isnil(L,-1))\
		cvar=def;\
	else\
		cvar=(ctype)func(L,-1);\
	lua_pop(L,1);

#define luax_gettable_long(L,tblidx,name,cvar,def) \
	luax_gettable_type (L,tblidx,name,lua_tonumber,long,cvar,def);

#define luax_gettable_long_long(L,tblidx,name,cvar,def) \
	luax_gettable_type (L,tblidx,name,lua_tonumber,long long,cvar,def);

#define luax_gettable_int(L,tblidx,name,cvar,def) \
	luax_gettable_type (L,tblidx,name,lua_tonumber,int,cvar,def);

#define luax_gettable_double(L,tblidx,name,cvar,def) \
	luax_gettable_type (L,tblidx,name,lua_tonumber,double,cvar,def);

#define luax_gettable_float(L,tblidx,name,cvar,def) \
	luax_gettable_type (L,tblidx,name,lua_tonumber,float,cvar,def);

#define luax_gettable_bool(L,tblidx,name,cvar,def) \
	luax_gettable_type (L,tblidx,name,lua_toboolean,int,cvar,def);

#define luax_gettable_string(L,tblidx,name,cvar,def) \
	luax_gettable_type (L,tblidx,name,lua_tostring,char*,cvar,def);

#define luax_gettable_udata_type(L,tblidx,name,ctype,cvar,def) \
	luax_gettable_type (L,tblidx,name,lua_touserdata,ctype,cvar,def);


#define luax_gettablei_type(L,tblidx,getidx,func,ctype,cvar,def) \
	lua_pushnumber(L,getidx);\
	lua_gettable(L,tblidx);\
	if (lua_isnil(L,-1))\
		cvar=def;\
	else\
		cvar=(ctype)func(L,-1);\
	lua_pop(L,1);

#define luax_gettablei_long(L,tblidx,getidx,cvar,def) \
	luax_gettablei_type (L,tblidx,getidx,lua_tonumber,long,cvar,def);

#define luax_gettablei_long_long(L,tblidx,getidx,cvar,def) \
	luax_gettablei_type (L,tblidx,getidx,lua_tonumber,long long,cvar,def);

#define luax_gettablei_int(L,tblidx,getidx,cvar,def) \
	luax_gettablei_type (L,tblidx,getidx,lua_tonumber,int,cvar,def);

#define luax_gettablei_double(L,tblidx,getidx,cvar,def) \
	luax_gettablei_type (L,tblidx,getidx,lua_tonumber,double,cvar,def);

#define luax_gettablei_float(L,tblidx,getidx,cvar,def) \
	luax_gettablei_type (L,tblidx,getidx,lua_tonumber,float,cvar,def);

#define luax_gettablei_bool(L,tblidx,getidx,cvar,def) \
	luax_gettablei_type (L,tblidx,getidx,lua_toboolean,int,cvar,def);

#define luax_gettablei_string(L,tblidx,getidx,cvar,def) \
	luax_gettablei_type (L,tblidx,getidx,lua_tostring,char*,cvar,def);

#define luax_gettablei_udata_type(L,tblidx,getidx,t,v,d) \
	luax_gettablei_type (L,tblidx,getidx,lua_touserdata,t,cvar,def);

#define luax_gettable_udata(L,tblidx,name,cvar,def) luax_gettable_type(L,tblidx,name,lua_touserdata,void*,cvar,def);

#define luax_settable_type(L,tblidx,name,func,cvar) \
		lua_pushstring(L,name);\
		func(L,cvar);\
		lua_settable(L,tblidx);

#define luax_settable_udata(L,tblidx,name,cvar) \
	luax_settable_type (L,tblidx,name,lua_pushlightuserdata,cvar);
	
#define luax_settable_string(L,tblidx,name,cvar) \
	luax_settable_type (L,tblidx,name,lua_pushstring,cvar);
	
#define luax_settable_boolean(L,tblidx,name,cvar) \
	luax_settable_type (L,tblidx,name,lua_pushboolean,cvar);
	
#define luax_settable_cfunction(L,tblidx,name,cvar) \
	luax_settable_type (L,tblidx,name,lua_pushcfunction,cvar);
	
#define luax_settable_number(L,tblidx,name,cvar)\
	luax_settable_type (L,tblidx,name,lua_pushnumber,(lua_Number)cvar);

#define luax_settable_lstring(L,tblidx,name,cvar,slen)\
		lua_pushstring(L,name);\
		lua_pushlstring(L,cvar,slen);\
		lua_settable(L,tblidx);

#define luax_tostring_copy(L,idx,cvar)\
	cvar=(char*)malloc(sizeof(char)*(lua_strlen(L,idx)+1));\
	strcpy(cvar,lua_tostring(L,idx));

#define luax_tolstring_copy(L,idx,cvar,slen)\
	slen=lua_strlen(L,idx);\
	cvar=(char*)malloc(sizeof(char)*slen);\
	strcpy(cvar,lua_tolstring(L,idx,NULL);

#define luax_regtable_create(name)	\
	lua_pushstring(L,name);	\
	lua_newtable(L);	\
	lua_settable(L,LUA_REGISTRYINDEX);	

#define luax_regtable_get(name) \
	lua_pushstring(L,name);	\
	lua_gettable(L,LUA_REGISTRYINDEX);	

#endif//LUAX_VALUE
