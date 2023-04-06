#ifndef LUAX_GCPTG
#define LUAX_GCPTG

#ifndef LUAX_API
	#ifdef LUAX_EXPORTS
		#define LUAX_API __declspec(dllexport)
	#else
		#define LUAX_API
	#endif
#endif

//forward definitions
LUAX_API void luax_register_mt(lua_State *L,const luaL_Reg  *list);
LUAX_API void luax_createudata(lua_State *L,void *udata,const char *mtname);
LUAX_API void luax_delete_table_values(lua_State *L);

//The boxed pointer type
struct luax_udbox {
  void *ptr;
};

//Saves a boxed userdata from index idx as type ctype in cvar
#define luax_tocgudata(L,idx,ctype,cvar)\
	cvar=(ctype)((struct luax_udbox*)lua_touserdata(L,idx))->ptr

//Sets a boxed udata pointer at index idx to cvar
#define luax_setcgudata(L,idx,cvar)\
	(void*)((struct luax_udbox*)lua_touserdata(L,idx))->ptr=(void*)cvar;\

/*
	Gets a userdata of type utype from table at index tblidx with key name
	and saves the boxed pointer in cvar of type ctype or the default value
*/
#define luax_gettable_gcudata(L,tblidx,name,utype,ctype,cvar,def)\
	cvar=def;\
	lua_pushstring(L,name);\
	lua_gettable(L,tblidx);\
	if (!lua_isnil(L,-1) && lua_getmetatable(L, -1)){\
			lua_getfield(L, LUA_REGISTRYINDEX, utype);\
			if (lua_rawequal(L, -1, -2))\
				luax_tocgudata(L,-3,ctype,cvar);\
			lua_pop(L,2);\
	}\
	lua_pop(L,1);

/*
	Sets a userdata with key name in table at position tblidx to value cvar
*/
#define luax_settable_gcudata(L,tblidx,name,cvar)\
	lua_pushstring(L,name);\
	lua_gettable(L,tblidx);\
	if (!lua_isnil(L,-1)){\
			luax_setcgudata(L,-1,cvar);\
	}\
	lua_pop(L,1);

#define luax_inserttable_gcudata(L,tblidx,name,cvar,utype)\
	lua_pushstring(L,name);\
	luax_createudata(L,cvar,utype);\
	lua_settable(L,tblidx);

/*
	Checks if the argument idx is a table that has a userdata at index name of type utype 
	and sets the boxed pointer in cvar of type ctype or raises the error err
*/
#define luax_getarg_objh(L,idx,name,utype,ctype,cvar,err)\
	luax_gettable_gcudata(L,idx,name,utype,ctype,cvar,NULL)\
	luaL_argcheck(L,cvar!=NULL,idx,err);

#endif//LUAX_GCPTG