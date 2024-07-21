#!/bin/bash
function print_help() {
    echo "ZLI build"
    echo ""
    echo "usage ./build.sh [OPTIONs]"
    echo ""
    echo "options:"
    echo "        --help   print this help"
    echo "        --all    build for all platforms (output in bin with platform suffix)"
    echo "        --upx    compress binary with upx"
    echo "        --test   run tests"
    echo "        --clean  delete zig-cache and zig-out"
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

ALL="false"
UPX="false"
TEST="false"
CLEAN="false"

while (( "$#" )); do
    case "$1" in
        -h | --help )   print_help; exit 0;;
        --all )         ALL="true"; shift;;
        --upx )         UPX="true"; shift;;
        --test )        TEST="true"; shift;;
        --clean )       CLEAN="true"; shift;;
        * ) print_help; exit_argument_error "unknown command $1";;
    esac
done

if [ "$CLEAN" == "true" ]; then
    echo cleaning
    rm -fr zig-out .zig-cache
fi

# check if zig is available
ZIG_BIN="zig/zig"
if ! [ -x "$(command -v $ZIG_BIN)" ]; then 
    ZIG_BIN="zig"
    if ! [ -x "$(command -v $ZIG_BIN)" ]; then 
        exit_argument_error "zig not found in ./zig or on path"
    fi
fi

# check if upx is available if to be used
UPX_BIN="upx/upx"
if [ "$UPX" = "true" ] && ! [ -x "$(command -v $UPX_BIN)" ]; then
    UPX_BIN="upx"
    if ! [ -x "$(command -v $UPX_BIN)" ]; then 
        exit_argument_error "upx not found in ./upx or on path"
    fi
fi

NATIVE_SUFFIX=""
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    NATIVE_SUFFIX=".exe"
fi

function build_platform() {
    PLAT=$1
    SUFFIX=$2
    COMPILED_BIN=zig-out/bin/zli${SUFFIX}

    EXE_NAME=bin/zli-${PLAT}${SUFFIX}
    if [ "$PLAT" == "native" ]; then
        EXE_NAME=bin/zli${SUFFIX}
    fi
    
    #compile
    echo building $PLAT
    rm -f $EXE_NAME
    $ZIG_BIN build -Doptimize=ReleaseFast -Dtarget=${PLAT}

    #run tests
    if [ "$PLAT" == "native" ] && [ "$TEST" == "true" ]; then
        echo testing $PLAT
        $COMPILED_BIN ./test/test.lua
    fi

    #compress with UPX if requested, else copy
    if [ "$UPX" = "true" ]; then
        echo compressing $PLAT
        $UPX_BIN -qq --ultra-brute --lzma -o $EXE_NAME $COMPILED_BIN
    else
        cp $COMPILED_BIN $EXE_NAME
    fi
}

# build native
build_platform "native" $NATIVE_SUFFIX

# build all
if [ "$ALL" = "true" ]; then
    build_platform "x86_64-windows" ".exe"
    build_platform "x86_64-linux-musl"
    build_platform "aarch64-linux-musl"
fi
