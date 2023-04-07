#!/bin/bash
function print_help() {
    echo "fullmoon compilation"
    echo ""
    echo "usage ./make.sh [--zig|--gcc] [--windows|--linux] [--clean]"
    echo ""
    echo "options:"
    echo "        -h | --help      print this help"
    echo "        -c | --clean     clean directory"
    echo "        -z | --zig       compile using zig cc"
    echo "        -g | --gcc       compile using gcc and musl"
    echo "        -w | --windows   compile for windows only valid for --zig"
    echo ""
}

function exit_on_error() {
    if [ $? -ne 0 ]; then
        >&2 echo ""
        >&2 echo "an error occured, stopping."
        >&2 echo ""
        exit 1
    fi
}

function exit_argument_error() {
    error=$1
    print_help
    >&2 echo "error: $error"
    >&2 echo ""
    exit 1
}

function assert_tool_installed() {
    tool=$1
    if ! command -v $tool &> /dev/null
    then
        >&2 echo "required command '$tool' could not be found"
        exit 1
    fi
}

FM_HOME=`pwd`

CLEAN="false"
TARGET=""
USE_ZIG=""
USE_GCC=""
COMPILE_COMMAND=""

while (( "$#" )); do
    case "$1" in
        -h | --help ) print_help; exit 1;;
        -c | --clean ) CLEAN="true"; shift;;
        --zig ) USE_ZIG="true"; shift;;
        --gcc ) USE_GCC="true"; shift;;
        --windows ) TARGET="WINDOWS"; shift;;
        * ) print_help; exit_argument_error "unknown command $1";;
    esac
done

if [ "$USE_GCC" = "true" ]; then
    COMPILE_COMMAND="$FM_HOME/musl/bin/musl-gcc -Wl,-E,-strip-all -ldl -lm --static -DLUA_USE_LINUX "
    elif [ "$USE_ZIG" = "true" ]; then
    if [ "$TARGET" = "WINDOWS" ]; then
        COMPILE_COMMAND="zig cc -lm --static -target x86_64-windows-gnu -Wdeprecated-non-prototype -LFS_EXPORT "
    else
        COMPILE_COMMAND="zig cc -ldl -lm --static -target x86_64-linux-musl -Wdeprecated-non-prototype -DLUA_USE_LINUX "
    fi
else
    exit_argument_error "set either --zig or --gcc"
fi

MUSL_VERSION=musl-1.2.3
LUA_VERSION=lua-5.4.4
SQLITE_VERSION=sqlite-amalgamation-3390100
LUASQLITE_VERSION=lsqlite3_fsl09y
LPEG_VERSION=lpeg-1.0.2
ZLIB_VERSION=zlib-1.2.13
ZIG_VERSION="zig-linux-x86_64-0.10.1"

if [ "$CLEAN" = "true" ]; then
    echo "[ cleaning... ]"
    rm -fr musl
    rm -fr $MUSL_VERSION
    rm -fr $LUA_VERSION
    rm -fr $SQLITE_VERSION
    rm -fr $LUASQLITE_VERSION
    rm -fr $LPEG_VERSION
    rm -fr $ZLIB_VERSION
    rm -fr luafilesystem
    rm -fr lua-zlib
    rm -fr luaunit
    rm -fr fullmoon.pdb
    rm -fr lua.lib
    echo ""
    exit 1
fi

echo "[ checking dependencies ]"
assert_tool_installed "wget"
assert_tool_installed "tar"
assert_tool_installed "git"
assert_tool_installed "unzip"
assert_tool_installed "xxd"
echo "OK"
echo ""

## Downloading dependencies if needed

if [ ! -d "$LUA_VERSION" ]; then
    echo "[ downloading lua ($LUA_VERSION) ]"
    wget -q --show-progress https://www.lua.org/ftp/$LUA_VERSION.tar.gz || exit_on_error
    tar -xzf $LUA_VERSION.tar.gz || exit_on_error
    rm $LUA_VERSION.tar.gz
    echo ""
fi

if [ ! -d "$SQLITE_VERSION" ]; then
    echo "[ downloading SQLite ($SQLITE_VERSION) ]"
    wget -q --show-progress https://www.sqlite.org/2022/$SQLITE_VERSION.zip || exit_on_error
    unzip -q $SQLITE_VERSION.zip || exit_on_error
    rm $SQLITE_VERSION.zip
    echo ""
fi

if [ ! -d "$LUASQLITE_VERSION" ]; then
    echo "[ downloading LuaSQLite3 ($LUASQLITE_VERSION) ]"
    wget -q --show-progress http://lua.sqlite.org/index.cgi/zip/$LUASQLITE_VERSION.zip || exit_on_error
    unzip -q $LUASQLITE_VERSION.zip || exit_on_error
    rm $LUASQLITE_VERSION.zip
    echo ""
fi

if [ ! -d "luafilesystem" ]; then
    echo "[ downloading luafilesystem (git)]"
    git clone --quiet https://github.com/keplerproject/luafilesystem.git || exit_on_error
    echo ""
fi

if [ ! -d "$LPEG_VERSION" ]; then
    echo "[ downloading lpeg ($LPEG_VERSION) ]"
    wget -q --show-progress http://www.inf.puc-rio.br/~roberto/lpeg/$LPEG_VERSION.tar.gz || exit_on_error
    tar -xzf $LPEG_VERSION.tar.gz || exit_on_error
    rm $LPEG_VERSION.tar.gz
    
    cd $LPEG_VERSION
    xxd -i re.lua > $FM_HOME/$LUA_VERSION/src/re.h || exit_on_error
    cd $FM_HOME
    echo ""
fi

if [ ! -d "lua-zlib" ]; then
    echo "[ downloading lua-zlib (git) ]"
    git clone --quiet https://github.com/brimworks/lua-zlib.git || exit_on_error
    echo ""
fi

if [ ! -d "$ZLIB_VERSION" ]; then
    echo "[ downloading zlib ($ZLIB_VERSION) ]"
    wget -q --show-progress https://zlib.net/$ZLIB_VERSION.tar.gz || exit_on_error
    tar -xzf $ZLIB_VERSION.tar.gz || exit_on_error
    rm $ZLIB_VERSION.tar.gz
    echo ""
fi

if [ ! -d "luaunit" ]; then
    echo "[ downloading luaunit (git) ]"
    git clone --quiet https://github.com/bluebird75/luaunit.git || exit_on_error
    
    cd luaunit
    xxd -i luaunit.lua > $FM_HOME/$LUA_VERSION/src/luaunit.h || exit_on_error
    cd $FM_HOME
    echo ""
fi

if [ "$USE_GCC" = "true" ] && [ ! -d "musl" ]; then
    echo "[ downloading musel ($MUSL_VERSION) ]"
    wget -q --show-progress http://musl.libc.org/releases/$MUSL_VERSION.tar.gz  || exit_on_error
    tar -xzf $MUSL_VERSION.tar.gz || exit_on_error
    rm $MUSL_VERSION.tar.gz
    
    echo ""
    echo "[ build musl ]"
    cd $MUSL_VERSION
    ./configure --prefix=$FM_HOME/musl --exec-prefix=$FM_HOME/musl --disable-shared > /dev/null || exit_on_error
    make CFLAGS='-Wno-return-local-addr' > /dev/null  || exit_on_error
    make install > /dev/null || exit_on_error
    
    cd $FM_HOME
    rm -fr $MUSL_VERSION
    echo ""
fi

if [ "$USE_ZIG" = "true" ];then
    if [ ! -d "$ZIG_VERSION" ]; then
        echo "[ downloading zig ($ZIG_VERSION) ]"
        wget -q --show-progress https://ziglang.org/download/0.10.1/$ZIG_VERSION.tar.xz  || exit_on_error
        tar -xf $ZIG_VERSION.tar.xz  || exit_on_error
        rm $ZIG_VERSION.tar.xz
        echo ""
    fi
    PATH=$FM_HOME/$ZIG_VERSION:$PATH
fi

## FullMonn compilation
echo "[ compiling fullmoon ]"

LPEG_SRC=$FM_HOME/$LPEG_VERSION
LFS_SRC=$FM_HOME/luafilesystem/src
ZLIB_SRC=$FM_HOME/$ZLIB_VERSION
SRC=$FM_HOME/src
OUTPUT=$FM_HOME/fullmoon

if [ "$TARGET" = "WINDOWS" ];then
    OUTPUT=$FM_HOME/fullmoon.exe
fi

cd $LUA_VERSION/src

$COMPILE_COMMAND \
-I $FM_HOME/$LUA_VERSION/src -Wno-implicit-function-declaration -O2 -DLUA_COMPAT_5_3  \
lua.c lapi.c lcode.c lctype.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c lmem.c lobject.c lopcodes.c lparser.c lstate.c lstring.c ltable.c ltm.c lundump.c lvm.c lzio.c \
lauxlib.c lbaselib.c lcorolib.c ldblib.c liolib.c lmathlib.c loadlib.c loslib.c lstrlib.c ltablib.c lutf8lib.c \
-I $SRC $SRC/linit.c $SRC/fm_aux.c $SRC/lx_value.c \
-I $FM_HOME/$SQLITE_VERSION $FM_HOME/$SQLITE_VERSION/sqlite3.c $FM_HOME/$LUASQLITE_VERSION/lsqlite3.c \
-I $LPEG_SRC $LPEG_SRC/lpcap.c $LPEG_SRC/lpcode.c $LPEG_SRC/lpprint.c $LPEG_SRC/lptree.c $LPEG_SRC/lpvm.c \
-I $LFS_SRC $LFS_SRC/lfs.c \
-DLZLIB_COMPAT -I $ZLIB_SRC $FM_HOME/lua-zlib/lua_zlib.c \
$ZLIB_SRC/adler32.c $ZLIB_SRC/crc32.c $ZLIB_SRC/gzclose.c $ZLIB_SRC/gzread.c $ZLIB_SRC/infback.c $ZLIB_SRC/inflate.c $ZLIB_SRC/trees.c $ZLIB_SRC/zutil.c $ZLIB_SRC/compress.c $ZLIB_SRC/deflate.c $ZLIB_SRC/gzlib.c $ZLIB_SRC/gzwrite.c $ZLIB_SRC/inffast.c $ZLIB_SRC/inftrees.c $ZLIB_SRC/uncompr.c \
-o $OUTPUT || exit_on_error

cd $FM_HOME
echo ""

if [ ! "$TARGET" = "WINDOWS" ];then
    echo "[ running unit tests ]"
    ./fullmoon test.lua || exit_on_error
    echo ""
fi

echo "[ stripping binary ]"
if [ ! command -v strip ] &> /dev/null;then
    echo "strip not installed skipping"
else
    strip --strip-all $OUTPUT || exit_on_error
fi
echo ""

echo "[ compressing with UPX ]"
if [! command -v upx] &> /dev/null;then
    echo "upx not installed skipping"
else
    upx --best --lzma -q $OUTPUT > /dev/null
fi
echo ""



