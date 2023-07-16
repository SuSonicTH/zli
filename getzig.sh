#!/bin/sh

if [ -d "/c/windows" ]; then
    curl https://ziglang.org/builds/zig-windows-x86_64-0.11.0-dev.3777+64f0059cd.zip --output zig.zip
    echo "unzipping..."
    unzip -q zig.zip
    rm zig.zip
    mv zig-windows-x86_64* zig
else
    curl https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.3777+64f0059cd.tar.xz --output zig.tar.xz
    echo "unzipping..."
    tar -xf zig.tar.xz
    rm zig.tar.xz
    mv zig-linux-x86_64* zig
fi
