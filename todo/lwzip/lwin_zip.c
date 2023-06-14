#include <lauxlib.h>
#include <lx_gcptr.h>
#include <lx_error.h>
#include <luax_value.h>

#include "lwin_zip.h"
//#include "resource.h"

LWZIP_API int luaopen_lwzip (lua_State *L)
{
	luaL_register(L, LW_ZIPLIBNAME, lw_ziplib);
	luax_register_mt(L,lw_zip_udatamt);
	return 1;
}

void SystemTimeToZipTime(tm_zip *sts)
{
	SYSTEMTIME st;
	GetSystemTime(&st);
	sts->tm_year=st.wYear;
	sts->tm_mon=st.wMonth;
	sts->tm_mon--;
	sts->tm_mday=st.wDay;
	sts->tm_hour=st.wHour;
	sts->tm_min=st.wMinute;
	sts->tm_sec=st.wSecond;
}

int FileTimeToZipTime(const char *filename,tm_zip *sts)
{
	WIN32_FIND_DATA ffd;
	HANDLE ffh=NULL;
	SYSTEMTIME st;

	if ((ffh=FindFirstFile(filename,&ffd))==INVALID_HANDLE_VALUE){
		return 0;
	}
	FileTimeToSystemTime(&ffd.ftLastWriteTime,&st);
	FindClose(ffh);

	sts->tm_year=st.wYear;
	sts->tm_mon=st.wMonth;
	sts->tm_mon--;
	sts->tm_mday=st.wDay;
	sts->tm_hour=st.wHour;
	sts->tm_min=st.wMinute;
	sts->tm_sec=st.wSecond;
	return 1;
}

/* Functions for reading a ZIP from an EXE resource */
//TODO: resource read: move to extra module?
/*
typedef struct res_read{
	char *data;
	char *cpos;
	char *epos;
}res_read;

voidpf fopen_res_file_fun (voidpf opaque, const char* filename, int mode)
{
    res_read *fp=NULL;
    long size;

	if ((mode & ZLIB_FILEFUNC_MODE_READWRITEFILTER)!=ZLIB_FILEFUNC_MODE_READ)
        return NULL;
	
	
	fp=malloc(sizeof(res_read));

	if ((fp->data=resource_read(NULL,filename,0,0,&size))==NULL){
		free(fp);
		return NULL;
	}

	fp->cpos=fp->data;
	fp->epos=fp->data+size;

    return fp;
}

uLong fread_res_file_fun (voidpf opaque, voidpf stream, void* buf, uLong size)
{
    uLong ret;
	res_read *fp=stream;

	if (fp->cpos+size<=fp->epos){
		memcpy(buf,fp->cpos,size);
		fp->cpos+=size;
		return size;
	}else{
		ret=fp->epos-fp->cpos;
		if (ret>0)
			memcpy(buf,fp->cpos,ret);
		fp->cpos=fp->epos;
		return ret;
	}
}


long ftell_res_file_fun (voidpf opaque,voidpf stream)
{
    res_read *fp=stream;
    return fp->cpos-fp->data;
}

long fseek_res_file_fun (voidpf opaque,voidpf stream,uLong offset,int origin)
{
	res_read *fp=stream;

    switch (origin)
    {
    case ZLIB_FILEFUNC_SEEK_CUR :
        fp->cpos+=offset;
        break;
    case ZLIB_FILEFUNC_SEEK_END :
        fp->cpos=fp->epos+offset;
        break;
    case ZLIB_FILEFUNC_SEEK_SET :
        fp->cpos=fp->data+offset;
        break;
    default: return -1;
    }
    return 0;
}

int fclose_res_file_fun (voidpf opaque,voidpf stream)
{
	free(stream);
    return 0;
}

int ferror_res_file_fun (voidpf opaque,voidpf stream)
{
    return 0;
}

void fill_fopen_filefunc_res (zlib_filefunc_def* pzlib_filefunc_def)
{
    pzlib_filefunc_def->zopen_file = fopen_res_file_fun;
    pzlib_filefunc_def->zread_file = fread_res_file_fun;
    pzlib_filefunc_def->zwrite_file = NULL;
    pzlib_filefunc_def->ztell_file = ftell_res_file_fun;
    pzlib_filefunc_def->zseek_file = fseek_res_file_fun;
    pzlib_filefunc_def->zclose_file = fclose_res_file_fun;
    pzlib_filefunc_def->zerror_file = ferror_res_file_fun;
    pzlib_filefunc_def->opaque = NULL;
}
/* End of resource reading functions */

int lw_zip_open_impl(lua_State* L,int resource)
{
	const char *fname;
	char *comment=NULL;
	unz_global_info uzgi;
	unz_file_info uzfi;
	char zfname[LW_ZIP_BUFFERSIZE];
	long fpos=1;
	int udpos=0;
	unsigned long long compressed=0,uncompressed=0;
	char time[30];
	char sizehr[12];
	zlib_filefunc_def zlff;
	unzFile uzfh;

	luaL_checkstring(L,1);
	fname=lua_tostring(L,1);
	
	if (resource){
		//fill_fopen_filefunc_res(&zlff);
		luax_ReturnWithErrorIF((uzfh=unzOpen2(fname,&zlff))==NULL,"Could not open file");
	}else{
		luax_ReturnWithErrorIF((uzfh=unzOpen(fname))==NULL,"Could not open file");
	}
	unzGetGlobalInfo(uzfh,&uzgi);

	luax_createudata(L,uzfh,"lw_zip_uzfile");
	udpos=lua_gettop(L);
	lua_newtable(L);
	lua_pushstring(L,"uzfh");
	lua_pushvalue(L,udpos);
	lua_settable(L,-3);
	luax_settable_number(L,-3,"entries",uzgi.number_entry);
	lua_pushstring(L,"comment");
	if (uzgi.size_comment) {
		comment=(char*)malloc(sizeof(char)*(uzgi.size_comment+1));
		unzGetGlobalComment(uzfh,comment,uzgi.size_comment+1);
		lua_pushlstring(L,comment,uzgi.size_comment);
		free(comment);
	}else{
		lua_pushstring(L,"");
	}
	lua_settable(L,-3);
	luax_settable_cfunction(L,-3,"extract",lw_zip_extract_file);
	luax_settable_cfunction(L,-3,"get",lw_zip_extract_file_tostring);
	luax_settable_cfunction(L,-3,"extract_all",lw_zip_extract_all);
	luax_settable_cfunction(L,-3,"open",lw_zip_open_uzfile);
	luax_settable_cfunction(L,-3,"lines",lw_zip_lines);
	lua_pushstring(L,"files");
	lua_newtable(L);
	unzGoToFirstFile(uzfh);
	do{ 
		unzGetCurrentFileInfo(uzfh,&uzfi,zfname,sizeof(zfname),NULL,0,NULL,0);
		compressed+=uzfi.compressed_size;
		uncompressed+=uzfi.uncompressed_size;
		lua_pushstring(L,zfname);
		lua_newtable(L);
		lua_pushnumber(L,fpos);
		lua_pushvalue(L,-2);
		lua_pushstring(L,"uzfh");
		lua_pushvalue(L,udpos);
		lua_settable(L,-3);
		luax_settable_string(L,-3,"name",zfname);
		luax_settable_boolean(L,-3,"directory",zfname[strlen(zfname)-1]=='/'?1:0);
		luax_settable_number(L,-3,"uncompressed_size",uzfi.uncompressed_size);
		lw_zip_filesize_hr(uzfi.uncompressed_size,sizehr);
		luax_settable_string(L,-3,"uncompressed_size_hr",sizehr);
		luax_settable_number(L,-3,"compressed_size",uzfi.compressed_size);
		lw_zip_filesize_hr(uzfi.compressed_size,sizehr);
		luax_settable_string(L,-3,"compressed_size_hr",sizehr);
		luax_settable_number(L,-3,"compression_ratio",(double)uzfi.compressed_size/uzfi.uncompressed_size);
		luax_settable_number(L,-3,"crc",uzfi.crc);
		luax_settable_number(L,-3,"pos",fpos++);
		//push filetime
		lua_pushstring(L,"time");
		lua_newtable(L);
		luax_settable_number(L,-3,"year",uzfi.tmu_date.tm_year);
		luax_settable_number(L,-3,"month",uzfi.tmu_date.tm_mon);
		luax_settable_number(L,-3,"day",uzfi.tmu_date.tm_mday);
		luax_settable_number(L,-3,"hour",uzfi.tmu_date.tm_hour);
		luax_settable_number(L,-3,"minute",uzfi.tmu_date.tm_min);
		luax_settable_number(L,-3,"second",uzfi.tmu_date.tm_sec);
		lua_settable(L,-3);
		//push timestamp
		sprintf(time,"%d/%02d/%02d %02d:%02d:%02d",uzfi.tmu_date.tm_year,uzfi.tmu_date.tm_mon,uzfi.tmu_date.tm_mday,uzfi.tmu_date.tm_hour,uzfi.tmu_date.tm_min,uzfi.tmu_date.tm_sec);
		luax_settable_string(L,-3,"timestamp",time);
		//push functions
		luax_settable_cfunction(L,-3,"extract",lw_zip_extract_to);
		luax_settable_cfunction(L,-3,"open",lw_zip_open_uzfile_mt);
		luax_settable_cfunction(L,-3,"lines",lw_zip_lines_mt);
		luax_settable_cfunction(L,-3,"get",lw_zip_extract_tostring);
		lua_settable(L,-5);
		lua_settable(L,-3);
	}while (unzGoToNextFile(uzfh)==UNZ_OK);
	lua_settable(L,-3);
	luax_settable_number(L,-3,"compressed_size",compressed);
	luax_settable_number(L,-3,"uncompressed_size",uncompressed);
	luax_settable_number(L,-3,"compression_ratio",(double)compressed/uncompressed);
	lw_zip_filesize_hr(uncompressed,sizehr);
	luax_settable_string(L,-3,"uncompressed_size_hr",sizehr);
	lw_zip_filesize_hr(compressed,sizehr);
	luax_settable_string(L,-3,"compressed_size_hr",sizehr);
	return 1;
}

int lw_zip_open(lua_State* L)
{
	return lw_zip_open_impl(L,0);
}

int lw_zip_open_resource(lua_State* L)
{
	return lw_zip_open_impl(L,1);
}

int lw_zip_lines_mt(lua_State* L)
{
	lua_pushstring(L,"name");
	lua_gettable(L,-2);
	return lw_zip_lines(L);
}

int lw_zip_lines(lua_State* L)
{
	unzFile uzfh;
	const char *fname;
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	luaL_checkstring(L,2);
	fname=lua_tostring(L,2);

	luax_ReturnWithErrorIF(unzLocateFile(uzfh,fname,0)!=UNZ_OK,"File not found");
	luax_ReturnWithErrorIF(unzOpenCurrentFile(uzfh)!=UNZ_OK,"Could not open file");

	lua_pushcfunction(L,lw_zip_file_uzread);
	lua_newtable(L);
	lua_pushstring(L,"uzfh");
	lua_pushstring(L,"uzfh");
	lua_gettable(L,1);
	lua_settable(L,-3);
	luax_settable_boolean(L,-3,"iterator",1);
	return 2;
}

int lw_zip_open_uzfile_mt(lua_State* L)
{
	lua_pushstring(L,"name");
	lua_gettable(L,-2);
	return lw_zip_open_uzfile(L);
}

int lw_zip_open_uzfile(lua_State* L)
{
	unzFile uzfh;
	const char *fname;
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	luaL_checkstring(L,2);
	fname=lua_tostring(L,2);

	unzCloseCurrentFile(uzfh);
	luax_ReturnWithErrorIF(unzLocateFile(uzfh,fname,0)!=UNZ_OK,"File not found");
	luax_ReturnWithErrorIF(unzOpenCurrentFile(uzfh)!=UNZ_OK,"Could not open file");

	lua_newtable(L);
	lua_pushstring(L,"uzfh");
	lua_pushstring(L,"uzfh");
	lua_gettable(L,1);
	lua_settable(L,-3);
	luax_settable_cfunction(L,-3,"read",lw_zip_file_uzread);
	luax_settable_cfunction(L,-3,"close",lw_zip_file_uzclose);
	luax_settable_cfunction(L,-3,"eof",lw_zip_file_uzeof);
	luax_settable_cfunction(L,-3,"tell",lw_zip_file_uztell);
	return 1;
}

int lw_zip_file_uzread(lua_State* L)
{
	unzFile uzfh;
	const char *readmode;
	int chartoread;
	int n;
	luaL_Buffer lb;
	char rb[LW_ZIP_BUFFERSIZE];
	int cr;
	int maxarg=lua_gettop(L);
	int read;
	int iterator=0;

	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	luax_gettable_bool(L,1,"iterator",iterator,0);
	if (lua_isnil(L,2) || iterator){
		lua_pushstring(L,"*l");
		lua_replace(L,2);
	}

	for (n=2;n<=maxarg;n++){
		if (lua_type(L,n)==LUA_TNUMBER){
			readmode="*c";
			chartoread=luax_toint(L,n);
		}else if(lua_type(L,n)==LUA_TSTRING){
			readmode=lua_tostring(L,n);
			luaL_argcheck(L,readmode[0]=='*' && strlen(readmode)==2,n,"Wrong argument to zip:read()");
		}else{
			lua_pushfstring(L,"Unknown format for argument #%d to zip:read. String or number expected",n);
			lua_error(L);
		}
		//TODO: lw_zip_file_uzread: Implement buffered file reading and missing read modes
		switch (readmode[1]){
			case 'n':
				break;
			case 'a':
				luaL_buffinit(L,&lb);
				while ((cr=unzReadCurrentFile(uzfh,&rb,LW_ZIP_BUFFERSIZE))>0){
					luaL_addlstring(&lb,rb,cr);
				}
				luaL_pushresult(&lb);
				break;
			case 'l':
				read=0;
				luaL_buffinit(L,&lb);
				while (unzReadCurrentFile(uzfh,&rb,1)==1){
					read=1;
					if (*rb=='\n')
						break;
					luaL_addchar(&lb,*rb);
				}
				luaL_pushresult(&lb);
				if (!read){
					lua_pop(L,1);
					lua_pushnil(L);
					if (iterator) 
						unzCloseCurrentFile(uzfh);
				}
				break;
			case 'c':
				luaL_buffinit(L,&lb);
				while ((cr=unzReadCurrentFile(uzfh,&rb,chartoread>LW_ZIP_BUFFERSIZE?LW_ZIP_BUFFERSIZE:chartoread))>0){
					chartoread-=cr;
					luaL_addlstring(&lb,rb,cr);
				}
				luaL_pushresult(&lb);
				break;
			default:
				lua_pushfstring(L,"Format '%s' is unknown",readmode);
				readmode=lua_tostring(L,-1);
				luaL_argerror(L,n,readmode);
				return 1;
		}
	}
	return maxarg-1;
}

int lw_zip_file_uzclose(lua_State* L)
{
	unzFile uzfh;
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	unzCloseCurrentFile(uzfh);
	return 0;
}

int lw_zip_file_uzeof(lua_State* L)
{
	unzFile uzfh;
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	lua_pushboolean(L,unzeof(uzfh));
	return 1;
}

int lw_zip_file_uztell(lua_State* L)
{
	unzFile uzfh;
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	lua_pushnumber(L,unztell(uzfh));
	return 1;
}

int lw_zip_extract_file(lua_State* L)
{
	unzFile uzfh;
	const char *fnamein;
	const char *fnameout;
	char *buff[LW_ZIP_BUFFERSIZE];
	int cr;
	FILE *fp;
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	luaL_checkstring(L,2);
	luaL_checkstring(L,3);

	fnamein=lua_tostring(L,2);
	fnameout=lua_tostring(L,3);

	luax_ReturnWithErrorIF(unzLocateFile(uzfh,fnamein,0)!=UNZ_OK,"File not found");
	luax_ReturnWithErrorIF(unzOpenCurrentFile(uzfh)!=UNZ_OK,"Could not read file");
	luax_ReturnWithErrorIF((fp=fopen(fnameout,"wb"))==NULL,"Could not open output file");

	while ((cr=unzReadCurrentFile(uzfh,&buff,LW_ZIP_BUFFERSIZE))>0){
		fwrite(buff,sizeof(char),cr,fp);
	}

	fclose(fp);
	unzCloseCurrentFile(uzfh);
	lua_pushboolean(L,1);
	return 1;
}

int lw_zip_extract_file_tostring(lua_State* L)
{
	unzFile uzfh;
	const char *fnamein;
	const char *fnameout;
	char *buff[LW_ZIP_BUFFERSIZE];
	luaL_Buffer lbuff;
	int cr;

	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	luaL_checkstring(L,2);

	fnamein=lua_tostring(L,2);

	luax_ReturnWithErrorIF(unzLocateFile(uzfh,fnamein,0)!=UNZ_OK,"File not found");
	luax_ReturnWithErrorIF(unzOpenCurrentFile(uzfh)!=UNZ_OK,"Could not read file");

	luaL_buffinit(L,&lbuff);
	while ((cr=unzReadCurrentFile(uzfh,&buff,LW_ZIP_BUFFERSIZE))>0){
		lua_pushlstring(L,buff,cr);
		luaL_addvalue(&lbuff);
	}

	luaL_pushresult(&lbuff);
	unzCloseCurrentFile(uzfh);

	return 1;
}

int lw_zip_extract_tostring(lua_State* L)
{
	unzFile uzfh;
	const char *fnamein;
	const char *fnameout;
	char *buff[LW_ZIP_BUFFERSIZE];
	luaL_Buffer lbuff;
	int cr;
	
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	luax_gettable_string(L,1,"name",fnamein,NULL);

	luax_ReturnWithErrorIF(unzLocateFile(uzfh,fnamein,0)!=UNZ_OK,"File not found");
	luax_ReturnWithErrorIF(unzOpenCurrentFile(uzfh)!=UNZ_OK,"Could not read file");

	luaL_buffinit(L,&lbuff);
	while ((cr=unzReadCurrentFile(uzfh,&buff,LW_ZIP_BUFFERSIZE))>0){
		lua_pushlstring(L,buff,cr);
		luaL_addvalue(&lbuff);
	}
	luaL_pushresult(&lbuff);
	unzCloseCurrentFile(uzfh);
	
	return 1;
}

int lw_zip_extract_to(lua_State* L)
{
	unzFile uzfh;
	const char *fnamein;
	const char *fnameout;
	char *buff[LW_ZIP_BUFFERSIZE];
	int cr;
	FILE *fp;
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	fnameout=lua_tostring(L,2);
	luax_gettable_string(L,1,"name",fnamein,NULL);
	if (fnameout==NULL)
		fnameout=fnamein;

	luax_ReturnWithErrorIF(unzLocateFile(uzfh,fnamein,0)!=UNZ_OK,"File not found");
	luax_ReturnWithErrorIF(unzOpenCurrentFile(uzfh)!=UNZ_OK,"Could not read file");
	luax_ReturnWithErrorIF((fp=fopen(fnameout,"wb"))==NULL,"Could not open output file");
	
	while ((cr=unzReadCurrentFile(uzfh,&buff,LW_ZIP_BUFFERSIZE))>0){
		fwrite(buff,sizeof(char),cr,fp);
	}

	fclose(fp);
	unzCloseCurrentFile(uzfh);
	lua_pushboolean(L,1);
	return 1;
}

int lw_zip_extract_all(lua_State* L)
{
	unzFile uzfh;
	const char *dest;
	const char *path;
	char zfname[_MAX_PATH]={0};
	char buff[LW_ZIP_BUFFERSIZE];
	int cr;
	FILE *fp;

	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	dest=lua_tostring(L,2);
	if (dest){
		luaL_gsub(L,dest,"\\","/");
		dest=lua_tostring(L,-1);
		lua_pop(L,1);
		if (dest[strlen(dest)-1]!='/' && dest[strlen(dest)-1]!='\\'){
			lua_pushfstring(L,"%s/",dest);
			dest=lua_tostring(L,-1);	
			lua_pop(L,1);
		}
		if (!lw_zip_createtree(dest)){
			lua_pushnil(L);
			lua_pushfstring(L,"Could not create output path:'%s'",dest);
			return 2;
		}
	}

	unzGoToFirstFile(uzfh);
	do{
		unzGetCurrentFileInfo(uzfh,NULL,zfname,sizeof(zfname),NULL,0,NULL,0);
		if (zfname[strlen(zfname)-1]=='/'){
			if (dest){
				lua_pushfstring(L,"%s%s",dest,zfname);
				path=lua_tostring(L,-1);
				lua_pop(L,1);
				if (!lw_zip_createtree(path)){
					lua_pushnil(L);
					lua_pushfstring(L,"Could not create output path:'%s'",path);
					return 2;
				}
			}else{
				if (!lw_zip_createtree(zfname)){
					lua_pushnil(L);
					lua_pushfstring(L,"Could not create output path:'%s'",zfname);
					return 2;
				}
			}
		}else{
			luax_ReturnWithErrorIF(unzOpenCurrentFile(uzfh)!=UNZ_OK,"Could not read file");
			if (dest){
				lua_pushfstring(L,"%s%s",dest,zfname);
				path=lua_tostring(L,-1);
				lua_pop(L,1);
			}else{
				path=zfname;
			}
			if ((fp=fopen(path,"wb"))==NULL){
				unzCloseCurrentFile(uzfh);
				lua_pushnil(L);
				lua_pushfstring(L,"Could not open output file '%s'",path);
				return 2;
			}
			while ((cr=unzReadCurrentFile(uzfh,&buff,LW_ZIP_BUFFERSIZE))>0){
				fwrite(buff,sizeof(char),cr,fp);
			}

			fclose(fp);
			unzCloseCurrentFile(uzfh);
		}
	}while (unzGoToNextFile(uzfh)==UNZ_OK);

	lua_pushboolean(L,1);
	return 1;
}

int lw_zip_createtree(const char *path)
{
	WIN32_FIND_DATA ffd;
	HANDLE ffh=NULL;
	char npath[_MAX_PATH];
	char *cpos;
	
	if (path[strlen(path)-1]=='/'){
			strcpy(npath,path);
			cpos=npath+strlen(npath)-1;
			*cpos=0;
			return (lw_zip_createtree(npath));
	}else{
		if ((ffh=FindFirstFile(path,&ffd))==INVALID_HANDLE_VALUE){
			strcpy(npath,path);
			cpos=npath+strlen(npath)-1;
			while (*cpos!='/' && cpos!=npath){
				cpos--;
			}
			*cpos=0;
			if (*npath!=0)
				if (!lw_zip_createtree(npath))
					return 0;
			return CreateDirectory(path,NULL);
		}else{
			FindClose(ffh);
			return 1;
		}
	}
}

int lw_zip_uzfile_gc(lua_State* L)
{
	unzFile uzfh;
	luaL_checkudata(L,1,"lw_zip_uzfile");
	luax_tocgudata(L,1,unzFile,uzfh);
	if (uzfh)
		unzClose(uzfh);
	return 0;
}

int lw_zip_uzfile_close(lua_State* L)
{
	unzFile uzfh;
	luax_getarg_objh(L,1,"uzfh","lw_zip_uzfile",unzFile,uzfh,"Zip object expected");
	unzClose(uzfh);
	luax_settable_gcudata(L,1,"uzfh",NULL);
	return 0;
}

int lw_zip_create(lua_State* L)
{
	zipFile zfh;
	char *sappend;
	const char *fname;
	const char *serror;
	int append;
	luaL_checkstring(L,1);
	fname=lua_tostring(L,1);

	if (lua_gettop(L)==1 || lua_isnil(L,2)){
		append=APPEND_STATUS_CREATE;
	}else{
		luax_tostring_copy(L,2,sappend);
		CharUpperBuff(sappend,strlen(sappend));//strupr(sappend);
		if (strcmp(sappend,"CREATE")==0){
			append=APPEND_STATUS_CREATE;
		}else if (strcmp(sappend,"ADD")==0){
			append=APPEND_STATUS_ADDINZIP;
		}else if (strcmp(sappend,"CREATEAFTER")==0){
			append=APPEND_STATUS_CREATEAFTER;
		}else{
			free(sappend);
			lua_pushfstring(L,"Creation type '%s' is unknown",sappend);
			serror=lua_tostring(L,-1);
			luaL_argerror(L,2,serror);
		}
		free(sappend);
	}
	luax_ReturnWithErrorIF((zfh=zipOpen(fname,append))==NULL,"Could not open Zip file");
	
	lua_newtable(L);
	lua_pushstring(L,"zfh");
	luax_createudata(L,zfh,"lw_zip_zipfile");
	lua_settable(L,-3);
	luax_settable_cfunction(L,-3,"close",lw_zip_zipfile_close);
	luax_settable_cfunction(L,-3,"addfile",lw_zip_addfile);
	luax_settable_cfunction(L,-3,"open",lw_zip_open_zipfile);
	return 1;
}

int lw_zip_zipfile_gc(lua_State* L)
{
	zipFile zfh;
	luaL_checkudata(L,1,"lw_zip_zipfile");
	luax_tocgudata(L,1,zipFile,zfh);
	if (zfh){
		zipCloseFileInZip(zfh);
		zipClose(zfh,NULL);
	}
	return 0;
}

int lw_zip_zipfile_close(lua_State* L)
{
	zipFile zfh;
	const char *comment;
	luax_getarg_objh(L,1,"zfh","lw_zip_zipfile",zipFile,zfh,"Zip object expected");
	comment=lua_tostring(L,2);
	zipCloseFileInZip(zfh);
	zipClose(zfh,comment);
	luax_settable_gcudata(L,1,"zfh",NULL);
	return 0;
}

int lw_zip_zip_fill_filedate(lua_State* L,zip_fileinfo *zfi,const char *filename, int n)
{
	char *stime;
	const char *serror;

	zfi->dosDate=0;
	zfi->external_fa=0;
	zfi->internal_fa=0;

	if (lua_type(L,n)==LUA_TNIL || lua_type(L,n)==LUA_TNONE){
		if (filename==NULL){
			SystemTimeToZipTime(&zfi->tmz_date);
			return 1;
		}else{
			if (FileTimeToZipTime(filename,&zfi->tmz_date)){
				return 1;
			}else{
				lua_pushfstring(L,"Could not find file '%s'!",filename);
				serror=lua_tostring(L,-1);
				lua_pushnil(L);
				lua_pushstring(L,serror);
				return 0;
			}
		}
	}else if(lua_type(L,n)==LUA_TSTRING){
		luax_tostring_copy(L,n,stime);
		CharUpperBuff(stime,strlen(stime));//strupr(stime);
		if (strcmp(stime,"FILETIME")==0){
			if (FileTimeToZipTime(filename,&zfi->tmz_date)){
				return 1;
			}else{
				lua_pushfstring(L,"Could not find file '%s'!",filename);
				serror=lua_tostring(L,-1);
				lua_pushnil(L);
				lua_pushstring(L,serror);
				free(stime);
				return 0;
			}
		}else if (strcmp(stime,"LOCALTIME")==0 || strcmp(stime,"SYSTEMTIME")==0){
			free(stime);
			SystemTimeToZipTime(&zfi->tmz_date);
			return 1;
		}else{
			free(stime);
			luaL_argerror(L,n,"Timeformat unknown!");
			return 0;
		}
	}else if(lua_type(L,n)==LUA_TTABLE){
		luax_gettable_int(L,n,"year",zfi->tmz_date.tm_year,0)
		luax_gettable_int(L,n,"month",zfi->tmz_date.tm_mon,0)
		zfi->tmz_date.tm_mon--;
		luax_gettable_int(L,n,"day",zfi->tmz_date.tm_mday,0)
		luax_gettable_int(L,n,"hour",zfi->tmz_date.tm_hour,0)
		luax_gettable_int(L,n,"minute",zfi->tmz_date.tm_min,0)
		luax_gettable_int(L,n,"second",zfi->tmz_date.tm_sec,0)
		return 1;
	}else{
		luaL_argerror(L,n,"Timeformat unknown!");
		return 0;
	}
}

int lw_zip_addfile(lua_State* L)
{
	zipFile zfh;
	zip_fileinfo zfi;
	const char *infname;
	const char *outfname; 
	const char *comment;
	char buffer[LW_ZIP_BUFFERSIZE];
	FILE *fh;
	size_t cr;
	int compression;

	luax_getarg_objh(L,1,"zfh","lw_zip_zipfile",zipFile,zfh,"Zip object expected");
	luaL_checkstring(L,2);
	infname=lua_tostring(L,2);
	luaL_checkstring(L,3);
	outfname=lua_tostring(L,3);

	if (!lw_zip_zip_fill_filedate(L,&zfi,infname,4))
		return 2;

	compression=(int)luaL_optnumber(L,5,9);
	comment=luaL_optstring(L,6,NULL);
	
	zipCloseFileInZip(zfh);
	luax_ReturnWithErrorIF(zipOpenNewFileInZip(zfh,outfname,&zfi,NULL,0,NULL,0,comment,Z_DEFLATED,compression),"Could not add file to zip");
	luax_ReturnWithErrorIF((fh=fopen(infname,"rb"))==NULL,"Could not open input file!");
	
	while ((cr=fread(buffer,1,LW_ZIP_BUFFERSIZE,fh))>0){
		zipWriteInFileInZip(zfh,buffer,(unsigned int)cr);
	}

	fclose(fh);
	zipCloseFileInZip(zfh);
	lua_pushboolean(L,1);
	return 1;
}

int lw_zip_open_zipfile(lua_State* L)
{
	zipFile zfh;
	zip_fileinfo zfi;
	const char *fname;
	const char *comment;
	int compression;

	luax_getarg_objh(L,1,"zfh","lw_zip_zipfile",zipFile,zfh,"Zip object expected");
	luaL_checkstring(L,2);
	fname=lua_tostring(L,2);
	if (!lw_zip_zip_fill_filedate(L,&zfi,NULL,3))
		return 2;

	compression=(int)luaL_optnumber(L,4,9);
	comment=luaL_optstring(L,5,NULL);
	
	zipCloseFileInZip(zfh);
	luax_ReturnWithErrorIF(zipOpenNewFileInZip(zfh,fname,&zfi,NULL,0,NULL,0,comment,Z_DEFLATED,compression),"Could not add file to zip");
	
	lua_newtable(L);
	lua_pushstring(L,"zfh");
	lua_pushstring(L,"zfh");
	lua_gettable(L,1);
	lua_settable(L,-3);
	luax_settable_cfunction(L,-3,"write",lw_zip_file_zipwrite);
	luax_settable_cfunction(L,-3,"close",lw_zip_file_zipclose);

	return 1;
}

int lw_zip_file_zipwrite(lua_State* L)
{
	zipFile zfh;
	const char *data;
	size_t datalen;
	int maxarg=lua_gettop(L);
	int n;
	luax_getarg_objh(L,1,"zfh","lw_zip_zipfile",zipFile,zfh,"Zip object expected");
	for (n=2;n<=maxarg;n++){
		luaL_checkstring(L,n);
		data=lua_tolstring(L,n,&datalen);
		if (data && datalen>0)
			zipWriteInFileInZip(zfh,data,(unsigned int)datalen);
	}
	lua_pushboolean(L,1);
	return 1;
}

int lw_zip_file_zipclose(lua_State* L)
{
	zipFile zfh;
	luax_getarg_objh(L,1,"zfh","lw_zip_zipfile",zipFile,zfh,"Zip object expected");
	zipCloseFileInZip(zfh);
	return 0;
}

