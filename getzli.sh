#!/bin/bash

function exit_on_error() {
    if [ $? -ne 0 ]; then
        >&2 echo ""
        >&2 echo "an error occured, stopping."
        >&2 echo ""
        exit 1
    fi
}

echo downloading zli repository from https://github.com/SuSonicTH/zli.git
git clone --quiet --recurse-submodules https://github.com/SuSonicTH/zli.git > /dev/null || exit_on_error
cd zli || exit_on_error
chmod +x build.sh

# check if zig needs to be downloaded
GET_ZIG=false
if ! [ -x "$(command -v zig)" ]; then 
    GET_ZIG="true"
fi

# check if upx needs to be downloaded
GET_UPX=false
if ! [ -x "$(command -v upx)" ]; then
    GET_UPX="true"
fi

# download dependencies if needed
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    if [ "$GET_ZIG" == "true" ]; then
        ZIG_NAME="zig-windows-x86_64-0.11.0"
        echo downloading $ZIG_NAME
        curl -s https://ziglang.org/download/0.11.0/${ZIG_NAME}.zip --output zig.zip || exit_on_error
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
        ZIG_NAME="zig-linux-x86_64-0.11.0"
        echo downloading $ZIG_NAME
        curl -s https://ziglang.org/download/0.11.0/${ZIG_NAME}.tar.xz | tar -xJ || exit_on_error
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
