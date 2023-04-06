#include <string.h>
#include "lwin_csv.h"

LWCSV_API int luaopen_lwcsv (lua_State *L)
{
	luaL_register(L, LW_CSVLIBNAME, lw_csv);
	return 1;
}

//TODO: Implement some more of the mtx.lua functions like sort,...?
//TODO: Implement saving/reading to/from string?
//TODO: Implement streaming with csvpairs over file/string?

int lw_csv_splitstr(char *string,char sep,char quout,char *list[])
{
	int cnt=0;
	list[0]=string;
	if (quout!=0){
		//TODO: Reimplement splitting with quouts
		while (1){
			if (*string==sep){
				if (*(string-1)==quout){
					*(string-1)=0;
				}else{
					*string=0;
				}
				if (*(string+1)==quout){
					list[++cnt]=string+2;
				}else{
					list[++cnt]=string+1;
				}
				if (cnt+1==LW_CSV_MAXCOL) 
					break;
			}else if(*string=='\r' || *string=='\n' || *string==0){
				cnt++;
				if (*(string-1)==quout){
					*(string-1)=0;
				}else{
					*string=0;
				}
				break;
			}
			string++;
		}
	}else{
		while (1){
			if (*string==sep){
				list[++cnt]=string+1;
				if (cnt+1==LW_CSV_MAXCOL) 
					break;
				*string=0;
			}else if(*string=='\r' || *string=='\n' || *string==0){
				cnt++;
				*string=0;
				break;
			}
			string++;
		}
	}
	return cnt;
}

int lw_csv_rowmt_index(lua_State* L)
{
	int k=lua_tonumber(L,2);
	int i;

	for (i=lua_objlen(L,1)+1;i<=k;i++){
		lua_newtable(L);
		lua_pushstring(L,"_rowmt");
		lua_gettable(L,1);
		lua_setmetatable(L,-2);
		lua_rawseti(L,1,i);
	}

	lua_rawgeti(L,1,k);

	return 1;
}

int lw_csv_rowmt_newindex(lua_State* L)
{
	int k=lua_tonumber(L,2);

	if (lua_type(L,3)==LUA_TTABLE){
		lua_pushstring(L,"_rowmt");
		lua_gettable(L,1);
		lua_setmetatable(L,3);
	}

	lua_rawseti(L,1,k);
	lua_rawgeti(L,1,k);

	return 1;
}

int lw_csv_colmt_index(lua_State* L)
{
	int i;
	lua_pushstring(L,"header2idx");
	lua_rawget(L,lua_upvalueindex(1));
	if (lua_isnil(L,-1)){
		lua_pushnil(L);
		return 1;
	}

	lua_pushvalue(L,2);
	lua_gettable(L,-2);
	if (!lua_isnil(L,-1)){
		lua_rawgeti(L,1,lua_tonumber(L,-1));
	}else{
		lua_pushnil(L);
	}

	return 1;
}

int lw_csv_colmt_newindex(lua_State* L)
{
	if (lua_type(L,2)==LUA_TNUMBER){
		lua_rawset(L,1);
	}else{
		lua_pushstring(L,"header2idx");
		lua_rawget(L,lua_upvalueindex(1));
		lua_pushvalue(L,2);
		lua_gettable(L,-2);
		if (!lua_isnil(L,-1)){
			lua_pushvalue(L,3);
			lua_settable(L,1);
		}
	}

	return 0;
}

void lw_csv_set_header2idx(lua_State* L,int n)
{
	int i;

	lua_pushstring(L,"header2idx");
	lua_newtable(L);
	lua_pushstring(L,"header");
	lua_gettable(L,n);
	for (i=1;i<=lua_objlen(L,-1);i++){
		lua_rawgeti(L,-1,i);
		lua_pushnumber(L,i);
		lua_settable(L,-4);
	}
	lua_pop(L,1);
	lua_settable(L,n);
}

int lw_csv_setheader(lua_State* L,int n)
{
	if (lua_type(L,2)!=LUA_TTABLE){
		luaL_argerror(L,2,"A header table must be given");
	}
	lua_pushstring(L,"header");
	lua_pushvalue(L,2);
	lua_settable(L,1);
	lw_csv_set_header2idx(L,1);
	return 0;
}

//writes the column position of argument n (if given) to pos
//if argument n is a string it gets resolved by header2idx
//if no argument n is given pos gets set to number of entries in header +p
#define lw_csv_getops(L,n,pos,p) \
	if (!lua_isnoneornil(L,n)){ \
		if (lua_type(L,n)==LUA_TSTRING){ \
			lua_pushstring(L,"header2idx"); \
			lua_gettable(L,1); \
			if (lua_isnil(L,-1)){ \
				luaL_argerror(L,n,"Position argument must be an number or a header must be defined"); \
			} \
			lua_pushvalue(L,n); \
			lua_gettable(L,-2); \
			pos=lua_tointeger(L,-1); \
			lua_pop(L,2); \
		}else{ \
			pos=lua_tointeger(L,n); \
		} \
	} \
	if (pos==0){ \
		lua_pushstring(L,"header"); \
		lua_gettable(L,1); \
		if (lua_isnil(L,-1)){ \
			lua_rawgeti(L,1,1); \
			pos=lua_objlen(L,-1); \
			lua_pop(L,2); \
		}else{ \
			pos=lua_objlen(L,-1)+p; \
			lua_pop(L,1); \
		} \
	}

int lw_csv_set_column(lua_State* L)
{
	int pos=0;
	int rcnt,r;

	//get position if given as argument or #header
	lw_csv_getops(L,3,pos,0);

	//go trough all rows and insert value
	if (lua_isfunction(L,2)){
		//value is a function call it for every row
		rcnt=lua_objlen(L,1);
		for (r=1;r<=rcnt;r++){
			lua_rawgeti(L,1,r);		//row
			lua_pushvalue(L,2);		//function
			lua_pushvalue(L,1);		//csv object
			lua_pushnumber(L,r);	//row index
			lua_rawgeti(L,1,r);		//row
			lua_pushnumber(L,pos);	//new column index
			lua_call(L,4,1);
			if (!lua_isnoneornil(L,-1)){
				lua_rawseti(L,-2,pos);
				lua_pop(L,1);
			}else{
				lua_pop(L,2);
			}
		}
	}else if (lua_istable(L,2)){
		//value is a table insert the value from it for each row with coresponding index
		rcnt=lua_objlen(L,1);
		for (r=1;r<=rcnt;r++){
			lua_rawgeti(L,1,r);
			lua_rawgeti(L,2,r);
			lua_rawseti(L,-2,pos);
			lua_pop(L,1);
		}
	}else{
		//value is an ordinary value insert it in every row
		rcnt=lua_objlen(L,1);
		for (r=1;r<=rcnt;r++){
			lua_rawgeti(L,1,r);
			lua_pushvalue(L,2);
			lua_rawseti(L,-2,pos);
			lua_pop(L,1);
		}
	}
	return 0;
}

int lw_csv_get_column(lua_State* L)
{
	int pos=0;
	int n;
	int rcnt,r;

	//get position if given as argument or #header
	lw_csv_getops(L,2,pos,0);

	//Create return table
	lua_newtable(L);
	n=lua_gettop(L);

	//go trough all rows and insert column value into return table
	rcnt=lua_objlen(L,1);
	for (r=1;r<=rcnt;r++){
		lua_rawgeti(L,1,r);
		lua_rawgeti(L,-1,pos);
		lua_rawseti(L,n,r);
		lua_pop(L,1);
	}

	return 1;
}

int lw_csv_insertcolumn(lua_State* L)
{
	int pos=0;
	int rcnt,r;
	
	//get position if given as argument or #header+1
	lw_csv_getops(L,3,pos,1);

	//insert column name into header table if table has a header
	lua_pushstring(L,"header");
	lua_gettable(L,1);
	if (!lua_isnil(L,-1)){
		if (!lua_isstring(L,3)){
			luaL_argerror(L,3,"csv has a hader but no name for the new column was given");
		}
		lua_pushvalue(L,3);
		luax_tableinsert(L,-2,pos);
		lw_csv_set_header2idx(L,1);
	}

	//go trough all rows and insert value
	if (lua_isfunction(L,2)){
		//value is a function call it for every row
		rcnt=lua_objlen(L,1);
		for (r=1;r<=rcnt;r++){
			lua_rawgeti(L,1,r);		//row
			lua_pushvalue(L,2);		//function
			lua_pushvalue(L,1);		//csv object
			lua_pushnumber(L,r);	//row index
			lua_rawgeti(L,1,r);		//row
			lua_pushnumber(L,pos);	//new column index
			lua_call(L,4,1);
			luax_tableinsert(L,-2,pos);
			lua_pop(L,1);
		}
	}else if (lua_istable(L,2)){
		//value is a table insert the value from it for each row with coresponding index
		rcnt=lua_objlen(L,1);
		for (r=1;r<=rcnt;r++){
			lua_rawgeti(L,1,r);
			lua_rawgeti(L,2,r);
			luax_tableinsert(L,-2,pos);
			lua_pop(L,1);
		}
	}else{
		//value is an ordinary value insert it in every row
		rcnt=lua_objlen(L,1);
		for (r=1;r<=rcnt;r++){
			lua_rawgeti(L,1,r);
			lua_pushvalue(L,2);
			luax_tableinsert(L,-2,pos);
			lua_pop(L,1);
		}
	}
	return 0;
}

int lw_csv_removecolumn(lua_State* L)
{
	int pos=0;
	int rcnt,r;
	int getcopy=0;

	//get position if given as argument or #header
	lw_csv_getops(L,3,pos,0);
	
	//remove column name from header table if table has a header
	lua_pushstring(L,"header");
	lua_gettable(L,1);
	if (!lua_isnil(L,-1)){
		luax_tableremove(L,-1,pos);
		lw_csv_set_header2idx(L,1);
	}
	
	if (getcopy){
		//create return table
		lua_newtable(L);

		//remove column from every row, set column value in return table
		rcnt=lua_objlen(L,1);
		for (r=1;r<=rcnt;r++){
			lua_rawgeti(L,1,r);		//row
			lua_rawgeti(L,-1,pos);	//column
			lua_rawseti(L,-3,r);	//set in return table
			luax_tableremove(L,-1,pos);
			lua_pop(L,1);
		}
		return 1;
	}else{
		//remove column from every row
		rcnt=lua_objlen(L,1);
		for (r=1;r<=rcnt;r++){
			lua_rawgeti(L,1,r);
			luax_tableremove(L,-1,pos);
			lua_pop(L,1);
		}
	}
	return 0;
}

int lw_csv_readcsv(lua_State* L)
{
	char str[LW_CSV_MAXLINELEN];
	char *col[LW_CSV_MAXCOL];
	int cnt=0;
	int row=1;
	char *filename;
	FILE *fh;
	int i;
	int firstrowheader=0;
	int headergiven=0;
	char sep=',';
	char quout=0;
	char *buffer;
	int n;

	filename=lua_tostring(L,1);
	
	if (lua_gettop(L)>1){
		if (lua_type(L,2)==LUA_TBOOLEAN){
			firstrowheader=lua_toboolean(L,2);
		}else if(lua_type(L,2)==LUA_TTABLE){
			headergiven=1;
		}
		if (lua_gettop(L)>2){
			buffer=lua_tostring(L,3);
			sep=buffer[0];
			if (lua_gettop(L)>3){
				buffer=lua_tostring(L,4);
				quout=buffer[0];
			}
		}
	}

	if ((fh=fopen(filename,"rb"))==NULL){
		lua_pushnil(L);
		lua_pushstring(L,"Could not open File!");
		return 2;
	}
	
	//create return table
	lua_newtable(L);
	n=lua_gettop(L);

	if (firstrowheader){
		fgets(str,LW_CSV_MAXLINELEN,fh);
		cnt=lw_csv_splitstr(str,sep,quout,col);
		lua_newtable(L);
		for (i=0;i<cnt;i++){
			lua_pushstring(L,col[i]);
			lua_rawseti(L,-2,i+1);
		}
		lw_csv_new_impl(L,n,n+1);
	}else if (headergiven){
		lw_csv_new_impl(L,n,2);
	}else{
		lw_csv_new_impl(L,n,0);
	}

	lua_pushstring(L,"_rowmt");
	lua_gettable(L,n);

	while (!feof(fh)){
		fgets(str,LW_CSV_MAXLINELEN,fh);
		if (strlen(str)==LW_CSV_MAXLINELEN && str[strlen(str)]!='\r' && str[strlen(str)]!='\n' && !feof(fh)){
			lua_pushnil(L);
			lua_pushstring(L,"Line longer then maximum allowed length!");
			return 2;
		}

		cnt=lw_csv_splitstr(str,sep,quout,col);
		if (cnt>0 && !(cnt==1 && col[0][0]==0)){
			lua_newtable(L);
			for (i=0;i<cnt;i++){
				lua_pushstring(L,col[i]);
				lua_rawseti(L,-2,i+1);
			}
			lua_pushvalue(L,-2);
			lua_setmetatable(L,-2);
			lua_rawseti(L,n,row);
			row++;
		}
	}
	lua_pop(L,1);
	if (firstrowheader){
		lua_pop(L,1);
	}
	fclose(fh);
	return 1;
}

int lw_csv_new(lua_State* L)
{
	int headergiven=0;

	if(lua_type(L,1)==LUA_TTABLE){
		headergiven=1;
	}
	
	//create return table
	lua_newtable(L);
	lw_csv_new_impl(L,lua_gettop(L),headergiven);

	return 1;
}

void lw_csv_new_impl(lua_State* L,int n,int header)
{

	//set object Methods
	luax_settable_function_list(L,n,lw_csv_functions);
	
	//set header if given
	if (header){
		lua_pushstring(L,"header");
		lua_pushvalue(L,header);
		lua_settable(L,n);
		lw_csv_set_header2idx(L,n);
	}

	//set metatables
	lua_pushstring(L,"_rowmt");
	lua_newtable(L);
	lua_pushstring(L,"__index");
	lua_pushvalue(L,n);
	lua_pushcclosure(L,lw_csv_colmt_index,1);
	lua_settable(L,-3);

	lua_pushstring(L,"__newindex");
	lua_pushvalue(L,n);
	lua_pushcclosure(L,lw_csv_colmt_newindex,1);
	lua_settable(L,-3);

	lua_settable(L,n);

	lua_newtable(L);
	lua_pushstring(L,"__index");
	lua_pushcfunction(L,lw_csv_rowmt_index);
	lua_settable(L,-3);

	lua_pushstring(L,"__newindex");
	lua_pushcfunction(L,lw_csv_rowmt_newindex);
	lua_settable(L,-3);

	lua_setmetatable(L,n);
}

int lw_csv_writecsv(lua_State* L)
{
	char sep=',';
	char quout=0;
	char *filename;
	FILE *fh;
	int useheader=0;
	int headergiven=0;
	char *cfield;
	int clen;
	int maxfield;
	char *buffer;
	int r,i;
	int filter=0;

	filename=lua_tostring(L,2);
	
	if (lua_gettop(L)>2){
		if (lua_type(L,3)==LUA_TBOOLEAN){
			useheader=lua_toboolean(L,3);
		}else if(lua_type(L,3)==LUA_TTABLE){
			headergiven=1;
		}
		if (lua_gettop(L)>3){
			buffer=lua_tostring(L,4);
			sep=buffer[0];
			if (lua_gettop(L)>4){
				buffer=lua_tostring(L,5);
				if (buffer!=NULL)
					quout=buffer[0];
				if (lua_gettop(L)>5)
					filter=1;
			}
		}
	}

	if ((fh=fopen(filename,"wb"))==NULL){
		lua_pushnil(L);
		lua_pushstring(L,"Could not open File!");
		return 2;
	}

	if (useheader){
		lua_pushstring(L,"header");
		lua_gettable(L,1);
		maxfield=lua_objlen(L,-1);
		for (i=1;i<=maxfield;i++){
			lua_rawgeti(L,-1,i);
			cfield=lua_tolstring(L,-1,&clen);
			fwrite(cfield,clen,1,fh);
			if (i<maxfield)
				fwrite(&sep,1,1,fh);
			else
				fwrite("\n",1,1,fh);
			lua_pop(L,1);
		}
		lua_pop(L,1);
	}else if (headergiven){
		maxfield=lua_objlen(L,3);
		for (i=1;i<=maxfield;i++){
			lua_rawgeti(L,3,i);
			cfield=lua_tolstring(L,-1,&clen);
			fwrite(cfield,clen,1,fh);
			if (i<maxfield)
				fwrite(&sep,1,1,fh);
			else
				fwrite("\n",1,1,fh);
			lua_pop(L,1);
		}
		lua_pop(L,1);
	}

	if (!filter){
		for (r=1;r<=lua_objlen(L,1);r++){
			lua_rawgeti(L,1,r);
			maxfield=lua_objlen(L,-1);
			for (i=1;i<=maxfield;i++){
				lua_rawgeti(L,-1,i);
				cfield=lua_tolstring(L,-1,&clen);
				fwrite(cfield,clen,1,fh);
				if (i<maxfield)
					fwrite(&sep,1,1,fh);
				else
					fwrite("\n",1,1,fh);
				lua_pop(L,1);
			}
			lua_pop(L,1);
		}
	}else{
		for (r=1;r<=lua_objlen(L,1);r++){
			lua_pushvalue(L,6);
			lua_rawgeti(L,1,r);
			lua_call(L,1,1);
			if (!lua_isnil(L,-1)){
				maxfield=lua_objlen(L,-1);
				for (i=1;i<=maxfield;i++){
					lua_rawgeti(L,-1,i);
					cfield=lua_tolstring(L,-1,&clen);
					fwrite(cfield,clen,1,fh);
					if (i<maxfield)
						fwrite(&sep,1,1,fh);
					else
						fwrite("\n",1,1,fh);
					lua_pop(L,1);
				}
			}
			lua_pop(L,1);
		}
	}
	fclose(fh);

	return 0;
}

int lw_csv_columnhash(lua_State* L)
{
	int unique=0;
	int i;
	int n;
	int j;
	int col[512];
	char *colval[512];
	int colcnt;
	char *column;
	luaL_Buffer buff;

	if (!lua_isnil(L,3))
		unique=lua_toboolean(L,3);

	lua_newtable(L);
	n=lua_gettop(L);

	if (lua_type(L,2)==LUA_TTABLE){
		colcnt=lua_objlen(L,2);
		for (i=1;i<=colcnt;i++){
			lua_gettop(L);
			lua_rawgeti(L,2,i);
			if (lua_type(L,-1)==LUA_TNUMBER){
				col[i]=lua_tonumber(L,-1);
				lua_pop(L,1);
			}else{
				lua_pushstring(L,"header2idx");
				lua_gettable(L,1);
				lua_pushvalue(L,-2);
				lua_gettable(L,-2);
				if (lua_isnil(L,-1)){
					lua_pushnil(L);
					lua_pushstring(L,"Column unknown!");
					return 2;
				}
				col[i]=lua_tonumber(L,-1);
				lua_pop(L,3);
			}
		}
		for (i=1;i<=lua_objlen(L,1);i++){
			lua_gettop(L);
			lua_rawgeti(L,1,i);
			
			for (j=1;j<=colcnt;j++){
				lua_rawgeti(L,-1,col[j]);
				colval[j]=lua_tostring(L,-1);
				lua_pop(L,1);
			}
			luaL_buffinit(L,&buff);
			for (j=1;j<=colcnt;j++){
				if (colval[j]==NULL){
					luaL_addstring(&buff,"#NIL#");
				}else{
					luaL_addstring(&buff,colval[j]);
				}
				if (j<colcnt)
					luaL_addchar(&buff,'|');
			}
			luaL_pushresult(&buff);
			lua_pushvalue(L,-1);
			lua_gettable(L,n);
			if (unique){
				if (!lua_isnil(L,-1)){
					lua_pushnil(L);
					lua_pushstring(L,"Column values are not unique!");
					return 2;
				}else{
					lua_pop(L,1);
					lua_pushvalue(L,-2);
					lua_settable(L,n);
				}
			}else{
				if (!lua_isnil(L,-1)){
					lua_pushvalue(L,-3);
					lua_rawseti(L,-2,lua_objlen(L,-2)+1);
					lua_pop(L,2);
				}else{
					lua_pop(L,1);
					lua_newtable(L);
					lua_pushvalue(L,-3);
					lua_rawseti(L,-2,1);
					lua_settable(L,n);
				}
			}
			lua_pop(L,1);
		}
	}else{
		if (unique){
			for (i=1;i<=lua_objlen(L,1);i++){
				lua_gettop(L);
				lua_rawgeti(L,1,i);
				lua_pushvalue(L,-1);
				lua_pushvalue(L,2);
				lua_gettable(L,-3);
				lua_pushvalue(L,-1);
				lua_gettable(L,n);
				if (!lua_isnil(L,-1)){
					lua_pushnil(L);
					lua_pushstring(L,"Column values are not unique!");
					return 2;
				}else{
					lua_pop(L,1);
					lua_pushvalue(L,-2);
					lua_settable(L,n);
					lua_pop(L,2);
				}
			}
		}else{
			for (i=1;i<=lua_objlen(L,1);i++){
				lua_rawgeti(L,1,i);
				lua_pushvalue(L,-1);
				lua_pushvalue(L,2);
				lua_gettable(L,-3);
				lua_pushvalue(L,-1);
				lua_gettable(L,n);
				if (lua_isnil(L,-1)){
					lua_pushvalue(L,-2);
					lua_newtable(L);
					lua_pushvalue(L,-5);
					lua_rawseti(L,-2,1);
					lua_settable(L,n);
					lua_pop(L,4);
				}else{
					lua_pushvalue(L,-3);
					lua_rawseti(L,-2,lua_objlen(L,-2)+1);
					lua_pop(L,4);
				}
			}
		}
	}

	return 1;
}

int lw_csv_sort(lua_State* L)
{

}