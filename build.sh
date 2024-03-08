#!/bin/bash
function print_help() {
    echo "ZLI build"
    echo ""
    echo "usage ./build.sh [OPTIONs]"
    echo ""
    echo "options:"
    echo "        --help  print this help"
    echo "        --all   build for all platforms (output in bin with platform suffix)"
    echo "        --upx   compress binary with upx"
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

while (( "$#" )); do
    case "$1" in
        -h | --help )   print_help; exit 0;;
        --all )         ALL="true"; shift;;
        --upx )         UPX="true"; shift;;
        * ) print_help; exit_argument_error "unknown command $1";;
    esac
done

# check if zig is available
if ! [ -x "$(command -v zig)" ]; then 
    exit_argument_error "zig not found on path"
fi

# check if upx is available if to be used
if [ "$UPX" = "true" ] && ! [ -x "$(command -v upx)" ]; then
    exit_argument_error "upx not found on path"
fi

NATIVE_SUFFIX=""
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    NATIVE_SUFFIX=".exe"
fi

# native build
echo building zli native
rm -f bin/zli${NATIVE_SUFFIX}

zig build -Doptimize=ReleaseFast || exit_on_error

if [ "$UPX" = "true" ]; then
    echo compressing binary with upx
    upx -qq --ultra-brute --lzma -o bin/zli${NATIVE_SUFFIX} zig-out/bin/zli${NATIVE_SUFFIX}
else
    cp zig-out/bin/zli${NATIVE_SUFFIX} bin/zli_no_upx${NATIVE_SUFFIX}
fi

function build_platform() {
    PLAT=$1
    SUFFIX=$2
    echo building ${PLAT}
    rm -f bin/zli-${PLAT}${SUFFIX}

    zig build -Doptimize=ReleaseFast -Dtarget=${PLAT}

    if [ "$UPX" = "true" ]; then
        echo compressing ${PLAT}
        upx -qq --ultra-brute --lzma -o bin/zli-${PLAT}${SUFFIX} zig-out/bin/zli${SUFFIX}
    else
        cp zig-out/bin/zli${SUFFIX} bin/zli-${PLAT}_no_upx${SUFFIX}
    fi
}

# build all
if [ "$ALL" = "true" ]; then
    build_platform "x86_64-windows" ".exe"
    build_platform "x86_64-linux-musl"
    build_platform "aarch64-linux-musl"
fi
