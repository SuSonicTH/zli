#!/bin/bash
function print_help() {
    echo "get-zli"
    echo ""
    echo "usage ./build.sh [OPTIONs]"
    echo ""
    echo "options:"
    echo "        --help   print this help"
    echo "        --force  force downloading of zig and upx"
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

FORCE="false"

while (( "$#" )); do
    case "$1" in
        -h | --help )   print_help; exit 0;;
        --force )       FORCE="true"; shift;;
        * ) print_help; exit_argument_error "unknown command $1";;
    esac
done

#clone repository if curretn directory is not a clone
if ! [ -f "./build.sh" ]; then
    echo downloading zli repository from https://github.com/SuSonicTH/zli.git
    git clone --quiet --recurse-submodules https://github.com/SuSonicTH/zli.git > /dev/null || exit_on_error
    cd zli || exit_on_error
    chmod +x build.sh
fi

if [ "$FORCE" == "true" ]; then
    echo deleting local zig and upx
    rm -fr upx zig
fi

# check if zig needs to be downloaded
GET_ZIG=$FORCE
if ! [ -x "$(command -v zig)" ] && ! [ -d "zig" ]; then 
    GET_ZIG="true"
fi

# check if upx needs to be downloaded
GET_UPX=$FORCE
if ! [ -x "$(command -v upx)" ] && ! [ -d "upx" ]; then
    GET_UPX="true"
fi

# download dependencies if needed
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    if [ "$GET_ZIG" == "true" ]; then
        ZIG_NAME="zig-windows-x86-0.13.0"
        echo downloading $ZIG_NAME
        curl -s https://ziglang.org/download/0.13.0/${ZIG_NAME}.zip --output zig.zip || exit_on_error
        echo "unzipping..."
        unzip -q zig.zip || exit_on_error
        rm zig.zip
        mv $ZIG_NAME zig || exit_on_error
    fi

    if [ "$GET_UPX" == "true" ]; then
        UPX_NAME="upx-4.0.2-win64"
        echo downloading $UPX_NAME                                     
        curl -s -L https://github.com/upx/upx/releases/download/v4.0.2/${UPX_NAME}.zip --output upx.zip || exit_on_error
        unzip -q upx.zip || exit_on_error
        rm upx.zip
        mv $UPX_NAME upx || exit_on_error
    fi
else
    if [ "$GET_ZIG" == "true" ]; then
        ZIG_NAME="zig-linux-x86_64-0.13.0"
        echo downloading $ZIG_NAME
        curl -s https://ziglang.org/download/0.13.0/${ZIG_NAME}.tar.xz | tar -xJ || exit_on_error
        mv $ZIG_NAME zig || exit_on_error
    fi

    if [ "$GET_UPX" == "true" ]; then
        UPX_NAME="upx-4.0.2-amd64_linux"
        echo downloading $UPX_NAME
        curl -s -L https://github.com/upx/upx/releases/download/v4.0.2/${UPX_NAME}.tar.xz | tar -xJ || exit_on_error
        rm ${UPX_NAME}.tar.xz
        mv $UPX_NAME upx || exit_on_error
    fi
fi

./build.sh --test --upx
