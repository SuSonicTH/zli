#include "lwin_xml.h"
#include "lx_value.h"

//TODO: implement reading of CDATA
//TODO: implement Open Function to read from filestream
//TODO: implement a writer? (which does the intention and single tags automatically)
LWXML_API int luaopen_lwxml (lua_State *L)
{
	luaL_register(L, LUA_XMLLIBNAME, lw_xml);
	return 1;
}

int lw_xml_open(lua_State* L)
{
	return 1;
}

#define LW_XML_CALLBACK_FUNCTION 2
#define LW_XML_IS_TABLE 3
#define LW_XML_EMPTY_TABLE 4
#define LW_XML_STACK_TABLE 5
#define LW_XML_CALLBACK_TABLE 6

int lw_xml_parse_arg(lua_State* L,char *spos,char *epos)
{
	char *cpos=spos;

	while (cpos!=epos && *cpos!=' ' && *cpos!='\t' && *cpos!='\r' && *cpos!='\n' && *cpos!='/'){
		cpos++;
	}
	lua_pushlstring(L,spos,cpos-spos);
	lua_pushvalue(L,-1);
	lua_rawseti(L,LW_XML_STACK_TABLE,lua_objlen(L,LW_XML_STACK_TABLE)+1);

	if (*cpos=='/' || (*cpos==' ' && *(cpos+1)=='/')){
		lua_pushvalue(L,LW_XML_EMPTY_TABLE);
		return 1;
	}

	//Create arg table
	lua_newtable(L);

	while (cpos<epos && !(*cpos==' ' && *(cpos+1)=='/') && *cpos!='/'){
		//skip whitespaces
		while (cpos<epos && (*cpos=='\r' || *cpos=='\n' || *cpos==' ' || *cpos=='\t')){
			cpos++;
		}
		if (cpos==epos) break;

		//search for end of attribute name
		spos=cpos;
		while (cpos<epos && !(*cpos==' ' && *(cpos+1)=='/') && *cpos!='/' && *cpos!='='){
			cpos++;
		}
		if (cpos==epos) break;
		lua_pushlstring(L,spos,cpos-spos);

		//skip whitespaces
		while (cpos<epos && (*cpos=='\r' || *cpos=='\n' || *cpos==' ' || *cpos=='\t' || *cpos=='=')){
			cpos++;
		}
		if (cpos==epos || *cpos!='"') break;
		
		//Search for end of attribute value
		cpos++;
		spos=cpos;
		while (cpos<epos && !(*cpos==' ' && *(cpos+1)=='/') && *cpos!='"'){
			cpos++;
		}
		if (cpos==epos || *cpos!='"') break;

		//insert attribute into table
		lua_pushlstring(L,spos,cpos-spos);
		lua_settable(L,-3);
		cpos++;
	}

	if (*cpos=='/')
		return 1;

	return 0;
}

int lw_xml_check_callback_return(lua_State* L)
{
	int i,top,back;

	if (!lua_isnil(L,-1)){
		if (lua_type(L,-1)==LUA_TFUNCTION){
			lua_rawseti(L,LW_XML_CALLBACK_TABLE,lua_objlen(L,LW_XML_CALLBACK_TABLE)+1); //callback function
		}else if(lua_type(L,-1)==LUA_TBOOLEAN && lua_toboolean(L,1)==0){
				return 0;
		}else{
			top=lua_objlen(L,LW_XML_CALLBACK_TABLE);
			back=lua_tonumber(L,-1);
			for (i=top;i>top-back;i--){
				lua_pushnil(L);
				lua_rawseti(L,LW_XML_CALLBACK_TABLE,i); //callback function
			}
			lua_pop(L,1);
		}
	}else{
		lua_pop(L,1);
	}
	return 1;
}

int lw_xml_parse(lua_State* L)
{
	char *xml;
	int func;
	int len;
	int single;
	char *cpos,*epos,*spos;
	char *tag;
	int i;
	int pos;

	//Check arguments
	if (lua_gettop(L)>3){
		lua_settop(L,3);
	}
	if (!lua_isstring(L,1)){
		lua_pushnil(L);
		lua_pushstring(L,"Argument 1 must be a xml string");
		return 2;
	}
	if (!lua_isfunction(L,2)){
		lua_pushnil(L);
		lua_pushstring(L,"Argument 2 must be a function");
		return 2;
	}

	//Create invariant state table if not given in function call
	if (lua_gettop(L)==2){
		lua_newtable(L);
	}
	//empty Table
	lua_newtable(L);

	//stack Table
	lua_newtable(L);

	//callback Table
	lua_newtable(L);
	lua_pushvalue(L,2);
	lua_rawseti(L,-2,1);

	//create copy of xml string
	len=lua_objlen(L,1);
	xml=malloc(len);
	memcpy(xml,lua_tolstring(L,1,NULL),len);
	cpos=xml;
	epos=cpos+len;
	
	//Call the function with the "start" action
	lua_pushvalue(L,2);
	lua_pushstring(L,"start");
	lua_pushstring(L,"");
	lua_pushvalue(L,LW_XML_EMPTY_TABLE);
	lua_pushstring(L,"");
	lua_pushvalue(L,LW_XML_IS_TABLE);
	lua_pushvalue(L,LW_XML_STACK_TABLE);
	lua_call(L,6,1);

	//start parsing
	while(cpos<=epos){
		//skip whitespaces
		while (cpos<=epos && (*cpos=='\r' || *cpos=='\n' || *cpos==' ' || *cpos=='\t')){
			cpos++;
		}
		if (cpos==epos){
			break;
		}

		//check for '<'
		if (*cpos=='<'){
			//search for '>'
			cpos++;
			spos=cpos;
			while(*cpos!='>'){
				cpos++;
			}
			if (*spos=='/'){
				spos++;
				lua_rawgeti(L,LW_XML_CALLBACK_TABLE,lua_objlen(L,LW_XML_CALLBACK_TABLE)); //callback function
				lua_pushstring(L,"close");
				lua_pushlstring(L,spos,cpos-spos);
				lua_pushvalue(L,LW_XML_EMPTY_TABLE);
				lua_pushstring(L,"");
				lua_pushvalue(L,LW_XML_IS_TABLE);
				lua_pushvalue(L,LW_XML_STACK_TABLE);
				lua_call(L,6,1);
				if (!lw_xml_check_callback_return(L))
					break;
				lua_pushnil(L);
				lua_rawseti(L,LW_XML_STACK_TABLE,lua_objlen(L,LW_XML_STACK_TABLE));
			}else if(*spos=='!' && *(spos+1)=='-' && *(spos+2)=='-'){
				lua_rawgeti(L,LW_XML_CALLBACK_TABLE,lua_objlen(L,LW_XML_CALLBACK_TABLE)); //callback function
				lua_pushstring(L,"comment");
				lua_pushstring(L,"!--");
				lua_pushvalue(L,-1);
				lua_rawseti(L,LW_XML_STACK_TABLE,lua_objlen(L,LW_XML_STACK_TABLE)+1);
				lua_pushvalue(L,LW_XML_EMPTY_TABLE);
				lua_pushlstring(L,spos+3,cpos-spos-5);
				lua_pushvalue(L,LW_XML_IS_TABLE);
				lua_pushvalue(L,LW_XML_STACK_TABLE);
				lua_call(L,6,1); 
				if (!lw_xml_check_callback_return(L))
					break;
			}else{
				lua_rawgeti(L,LW_XML_CALLBACK_TABLE,lua_objlen(L,LW_XML_CALLBACK_TABLE)); //callback function
				lua_pushstring(L,"open");
				single=lw_xml_parse_arg(L,spos,cpos);
				tag=lua_tostring(L,-2);
				lua_pushstring(L,"");
				lua_pushvalue(L,LW_XML_IS_TABLE);
				lua_pushvalue(L,LW_XML_STACK_TABLE);
				lua_call(L,6,1);
				if (!lw_xml_check_callback_return(L))
					break;
				if (single){
					lua_rawgeti(L,LW_XML_CALLBACK_TABLE,lua_objlen(L,LW_XML_CALLBACK_TABLE)); //callback function
					lua_pushstring(L,"close");
					lua_pushstring(L,tag);
					lua_pushvalue(L,LW_XML_IS_TABLE);
					lua_pushstring(L,"");
					lua_pushvalue(L,LW_XML_IS_TABLE);
					lua_pushvalue(L,LW_XML_STACK_TABLE);
					lua_call(L,6,1);
					if (!lw_xml_check_callback_return(L))
						break;
					lua_pushnil(L);
					lua_rawseti(L,LW_XML_STACK_TABLE,lua_objlen(L,LW_XML_STACK_TABLE));
				}
			}
			cpos++;
		}else{
			spos=cpos;
			while(*(cpos)!='<'){
				cpos++;
			}
			lua_rawgeti(L,LW_XML_CALLBACK_TABLE,lua_objlen(L,LW_XML_CALLBACK_TABLE)); //callback function
			lua_pushstring(L,"text");
			lua_rawgeti(L,LW_XML_STACK_TABLE,lua_objlen(L,LW_XML_STACK_TABLE));
			lua_pushvalue(L,LW_XML_EMPTY_TABLE);
			lua_pushlstring(L,spos,cpos-spos);
			lua_pushvalue(L,LW_XML_IS_TABLE);
			lua_pushvalue(L,LW_XML_STACK_TABLE);
			lua_call(L,6,1);
			if (!lw_xml_check_callback_return(L))
				break;
		}
	}

	//Call the function with the "end" action
	lua_rawgeti(L,LW_XML_CALLBACK_TABLE,lua_objlen(L,LW_XML_CALLBACK_TABLE)); //callback function
	lua_pushstring(L,"end");
	lua_pushstring(L,"");
	lua_pushvalue(L,LW_XML_EMPTY_TABLE);
	lua_pushstring(L,"");
	lua_pushvalue(L,LW_XML_IS_TABLE);
	lua_pushvalue(L,LW_XML_STACK_TABLE);
	lua_call(L,6,1);

	free(xml);
	return 0;
}
