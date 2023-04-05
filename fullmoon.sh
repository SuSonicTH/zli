#!/bin/sh
set -e

FM_HOME=`pwd`

MUSL_VERSION=musl-1.2.3
LUA_VERSION=lua-5.4.4
SQLITE_VERSION=sqlite-amalgamation-3390100
LUASQLITE_VERSION=lsqlite3_fsl09y
LPEG_VERSION=lpeg-1.0.2
ZLIB_VERSION=zlib-1.2.13

if [ "$1" = "clean" ]; then
    echo "cleaning..."
    rm -fr musl
    rm -fr $MUSL_VERSION
    rm -fr $LUA_VERSION
    rm -fr $SQLITE_VERSION
    rm -fr $LUASQLITE_VERSION
    rm -fr $LPEG_VERSION
    rm -fr $ZLIB_VERSION
    rm -fr luafilesystem
    rm -fr lua-zlib
    exit 1
fi

if [ ! -d "musl" ]; then
    echo "getting musl"
    wget -q --show-progress http://musl.libc.org/releases/$MUSL_VERSION.tar.gz 
    tar -xzf $MUSL_VERSION.tar.gz
	rm $MUSL_VERSION.tar.gz
    
    
    echo "installing musl" 
    cd $MUSL_VERSION
    ./configure --prefix=$FM_HOME/musl --exec-prefix=$FM_HOME/musl --disable-shared > /dev/null
    make > /dev/null && make install > /dev/null
    cd $FM_HOME
	rm -fr $MUSL_VERSION
fi 

if [ ! -d "$SQLITE_VERSION" ]; then
    echo "downloading SQLite $SQLITE_VERSION"
    wget https://www.sqlite.org/2022/$SQLITE_VERSION.zip
    unzip $SQLITE_VERSION.zip
    rm $SQLITE_VERSION.zip
fi

if [ ! -d "$LUASQLITE_VERSION" ]; then
    echo "downloading LuaSQLite3 $LUASQLITE_VERSION"
    wget http://lua.sqlite.org/index.cgi/zip/$LUASQLITE_VERSION.zip
    unzip $LUASQLITE_VERSION.zip
    rm $LUASQLITE_VERSION.zip
fi

if [ ! -d "$LPEG_VERSION" ]; then
    echo "downloading lpeg $LPEG_VERSION"
    wget http://www.inf.puc-rio.br/~roberto/lpeg/$LPEG_VERSION.tar.gz
    tar -xzf $LPEG_VERSION.tar.gz
    rm $LPEG_VERSION.tar.gz
fi

if [ ! -d "luafilesystem" ]; then
    echo "downloading luafilesystem"
    git clone https://github.com/keplerproject/luafilesystem.git
fi

if [ ! -d "lua-zlib" ]; then
    echo "downloading lua-zlib"
    git clone https://github.com/brimworks/lua-zlib.git
fi

if [ ! -d "$ZLIB_VERSION" ]; then
    echo "downloading zlib $ZLIB_VERSION"
    wget https://zlib.net/$ZLIB_VERSION.tar.gz
    tar -xzf $ZLIB_VERSION.tar.gz
    rm $ZLIB_VERSION.tar.gz
fi

if [ ! -d "$LUA_VERSION" ]; then
    echo "downloading lua $LUA_VERSION"
    wget https://www.lua.org/ftp/$LUA_VERSION.tar.gz 
    tar -xzf $LUA_VERSION.tar.gz 
    rm $LUA_VERSION.tar.gz 
    cp src/* $LUA_VERSION/src/
fi

## FullMonn compilation
echo compiling fullmoon

LPEG_SRC=$FM_HOME/$LPEG_VERSION
LFS_SRC=$FM_HOME/luafilesystem/src
ZLIB_SRC=$FM_HOME/$ZLIB_VERSION

cp src/* $LUA_VERSION/src

cd $LUA_VERSION/src

$FM_HOME/musl/bin/musl-gcc -O2 -DLUA_COMPAT_5_3 -DLUA_USE_LINUX \
-Wno-implicit-function-declaration \
lapi.c lcode.c lctype.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c lmem.c lobject.c lopcodes.c lparser.c lstate.c lstring.c ltable.c ltm.c lundump.c lvm.c lzio.c \
lauxlib.c lbaselib.c lcorolib.c ldblib.c liolib.c lmathlib.c loadlib.c loslib.c lstrlib.c ltablib.c lutf8lib.c linit.c \
-I $FM_HOME/$SQLITE_VERSION $FM_HOME/$SQLITE_VERSION/sqlite3.c $FM_HOME/$LUASQLITE_VERSION/lsqlite3.c \
-I $LPEG_SRC $LPEG_SRC/lpcap.c $LPEG_SRC/lpcode.c $LPEG_SRC/lpprint.c $LPEG_SRC/lptree.c $LPEG_SRC/lpvm.c \
-I $LFS_SRC $LFS_SRC/lfs.c \
-DLZLIB_COMPAT -I $ZLIB_SRC $FM_HOME/lua-zlib/lua_zlib.c \
$ZLIB_SRC/adler32.c $ZLIB_SRC/crc32.c $ZLIB_SRC/gzclose.c $ZLIB_SRC/gzread.c $ZLIB_SRC/infback.c $ZLIB_SRC/inflate.c $ZLIB_SRC/trees.c $ZLIB_SRC/zutil.c $ZLIB_SRC/compress.c $ZLIB_SRC/deflate.c $ZLIB_SRC/gzlib.c $ZLIB_SRC/gzwrite.c $ZLIB_SRC/inffast.c $ZLIB_SRC/inftrees.c $ZLIB_SRC/uncompr.c \
lua.c -Wl,-E,-strip-all -ldl -lm --static \
-I $FM_HOME/$LUA_VERSION/src -o $FM_HOME/fullmoon 
cd $FM_HOME

if  command -v upx &> /dev/null
then
    echo "compressing with UPX"
    upx --best --lzma fullmoon
fi

