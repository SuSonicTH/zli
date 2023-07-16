# ZLI - Zig Lua Interpreter

ZLI is a portable lua interpreter statically compiled (on non windows with musl) with additional libraries.
The binary can be moved from system to system without any dependencies on installed ibraries.

## Batteries included
There are many libraries included in the ZIL binary. Some 3rd party lua libraries and some developed for ZIL.

* [3rd party libraries](https://github.com/SuSonicTH/zli/blob/master/src/lib/README.md)
* [ZIL libraries](https://github.com/SuSonicTH/zli/blob/master/src/README.md)

## Compilation
The build requires you to have git and zig installed
Zig can be installed trough your package manager or just download from [ziglang.org](https://ziglang.org/download/) extract and add the directory to your path.
For wihdows users I recomend [git for windows](https://gitforwindows.org/) aka **gitbash** or running under [Windows subsystem for Windows](https://learn.microsoft.com/en-us/windows/wsl/install]) aka **WSL**

I'm using the master branch of zig which is under heavy development and breaking changes are happening often. 
Curently I'm on version **0.11.0-dev.3777**.
You can use the `./getzig.sh` script to get that specific version as described below (works for linux, gitbash and WSL)

## Clone & Build Process:
This works under linux and windows (under gitbash)
```bash
git clone --recurse-submodules https://github.com/SuSonicTH/zli.git
cd zli
sh ./getzig.sh
./zig/zig build test
```
binaries are saved in zig-out/bin/

### Release Build
```bash
./zig/zig build -Doptimize=ReleaseFast
upx --ultra-brute --lzma zig-out/bin/zli*
```
