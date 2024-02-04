#!/bin/bash
function print_help() {
    echo "ZLI build"
    echo ""
    echo "usage ./build.sh [OPTIONs]"
    echo ""
    echo "options:"
    echo "        --help        print this help"
    echo "        --clean       clean directories zig-out zigcache and bin"
    echo "        --clean-all   additionally delete downloaded dependencies"
    echo "        --build       build for current platform (output in bin without suffix)"
    echo "        --build-all   build for all platforms (output in bin with platform suffix)"
    echo "        --no-compress do not compress binary with upx"
    echo "        --get-zig     download local zig even though it is installed"
    echo "        --get-upx     download local upx even though it is installed"
    echo "        --get-all     download build binaries regardless if they are installed"
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

CLEAN="false"
CLEAN_ALL="false"
BUILD_NATIVE="false"
BUILD_ALL="false"
GET_ZIG="false"
COMPRESS="true"

if [ "$#" -eq 0 ]; then
    exit_argument_error "no argument given"
fi

while (( "$#" )); do
    case "$1" in
        -h | --help )   print_help; exit 0;;
        --clean )       CLEAN="true"; shift;;
        --clean-all )   CLEAN="true"; CLEAN_ALL="true"; shift;;
        --build )       BUILD_NATIVE="true"; shift;;
        --no-compress ) COMPRESS="false"; shift;;
        --build-all )   BUILD_ALL="true"; shift;;
        --get-zig )     GET_ZIG="true"; shift;;
        --get-upx )     GET_UPX="true"; shift;;
        --get-all )     GET_ZIG="true";GET_UPX="true"; shift;;
        * ) print_help; exit_argument_error "unknown command $1";;
    esac
done

if [ "$CLEAN" == "true" ]; then
    echo cleaning zig-out, zig-cache and bin
    rm -fr zig-out zig-cache
    rm -f bin/*
fi

if [ "$CLEAN_ALL" == "true" ]; then
    echo removing local zig and upx
    rm -fr zig upx
fi

# check if zig is available
if [ -d "zig" ] && [ "$GET_ZIG" == "true" ]; then
    rm -fr zig
fi
if [ ! -d "zig" ] && ! [ -x "$(command -v zig)" ]; then 
    GET_ZIG="true"
fi

# check if upx is available
if [ ! -f "upx" ] && ! [ -x "$(command -v upx)" ]; then
    GET_UPX="true"
fi

NATIVE_SUFFIX=""
# download dependencies if needed
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    NATIVE_SUFFIX=".exe"
    if [ "$GET_ZIG" == "true" ]; then
        echo downloading $ZIG_NAME
        curl -s https://ziglang.org/download/0.11.0/zig-windows-x86-0.11.0.zip --output zig.zip || exit_on_error
        echo "unzipping..."
        unzip -q zig.zip || exit_on_error
        rm zig.zip
        mv $ZIG_NAME zig || exit_on_error
    fi

    if [ "$GET_UPX" == "true" ]; then
        echo downloading $UPX_NAME
        curl -s -L https://github.com/upx/upx/releases/download/v4.0.2/upx-4.0.2-win64.zip --output upx.zip || exit_on_error
        unzip -q upx.zip || exit_on_error
        rm upx.zip
        mv $UPX_NAME/upx ./ || exit_on_error
        rm -r $UPX_NAME
    fi
else
    if [ "$GET_ZIG" == "true" ]; then
        echo downloading $ZIG_NAME
        curl -s https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz | tar -xJ || exit_on_error
        mv $ZIG_NAME zig || exit_on_error
    fi

    if [ "$GET_UPX" == "true" ]; then
        echo downloading $UPX_NAME
        curl -s -L https://github.com/upx/upx/releases/download/v4.0.2/upx-4.0.2-amd64_linux.tar.xz | tar -xJ || exit_on_error
        mv $UPX_NAME/upx ./ || exit_on_error
        rm -r $UPX_NAME
    fi
fi

# set binaries to use
ZIG_BIN="zig"
if [ -d "zig" ]; then
    ZIG_BIN="./zig/zig"
fi

UPX_BIN="upx"
if [ -f "upx" ]; then
    UPX_BIN="./upx"
fi

# native build
if [ "$BUILD_NATIVE" = "true" ]; then
    echo building zli native
    rm -f bin/zli${NATIVE_SUFFIX}

    $ZIG_BIN build -Doptimize=ReleaseFast || exit_on_error

    if [ "$COMPRESS" = "true" ]; then
        echo compressing binary with upx
        $UPX_BIN -qq --ultra-brute --lzma -o bin/zli${NATIVE_SUFFIX} zig-out/bin/zli${NATIVE_SUFFIX}
    else
        cp zig-out/bin/zli${NATIVE_SUFFIX} bin/zli_no_upx${NATIVE_SUFFIX}
    fi
fi

function build_platform() {
    PLAT=$1
    SUFFIX=$2
    echo building ${PLAT}
    rm -f bin/zli-${PLAT}${SUFFIX}

    zig build -Doptimize=ReleaseFast -Dtarget=${PLAT}

    if [ "$COMPRESS" = "true" ]; then
        echo compressing ${PLAT}
        $UPX_BIN -qq --ultra-brute --lzma -o bin/zli-${PLAT}${SUFFIX} zig-out/bin/zli${SUFFIX}
    else
        cp zig-out/bin/zli${SUFFIX} bin/zli-${PLAT}_no_upx${SUFFIX}
    fi
}

# build all
if [ "$BUILD_ALL" = "true" ]; then
    build_platform "x86_64-windows" ".exe"
    build_platform "x86_64-linux-musl"
    build_platform "aarch64-linux-musl"
fi

