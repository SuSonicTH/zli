# ZLI - Zig Lua Interpreter

ZLI is a portable lua interpreter statically compiled (on non windows with musl) with additional libraries.
The binary can be moved from system to system without any dependencies on installed ibraries.

## Batteries included
There are many libraries included in the ZIL binary. Some 3rd party lua libraries and some developed for ZIL.

* [3rd party libraries](https://github.com/SuSonicTH/zli/blob/master/src/lib/)
* [ZIL libraries](https://github.com/SuSonicTH/zli/blob/master/src/)

In the main binary there are also some commandline tools included. More information can be found in [Tools](https://github.com/SuSonicTH/zli/blob/master/src/tools/)

## Clone & Build
This works under linux and windows(under gitbash) for x86_64 platforms 
```bash
git clone --recurse-submodules https://github.com/SuSonicTH/zli.git
cd zli
./build.sh --build
```
The build script will download the zig compiler and upx executable if they are not found on the system.
If you want to compile for all the supported platforms call `./build.sh --build-all` the binaries are saved to the bin directory.

## Easymode
You can also use the fully automated `get-zig.sh` script to do everything above. All you need is **git**, **bash** and **curl**.
Paste the following into your bash terminal:
`curl -s https://raw.githubusercontent.com/SuSonicTH/zli/master/getzli.sh | bash && cd zli`

## Manual Compilation
The build requires you to have git and zig installed
Zig can be installed trough your package manager or just download from [ziglang.org](https://ziglang.org/download/) extract and add the directory to your path.
For windows users I recomend [git for windows](https://gitforwindows.org/) aka **gitbash** or running under [Windows subsystem for Windows](https://learn.microsoft.com/en-us/windows/wsl/install) aka **WSL**

I'm currently using zig version 0.11.0. As zig is under heavy development and breaking changes are happening often it might not compile with the newest zig (master) version. 

To compile execute `zig build` (or `./zig/zig build` if you are using the local zig installation)
The executable will be in ./zig-out/bin/. or use the `./build.sh` tool to compile release versions or fopr other platforms.
The `./build.sh` also uses a trick to reduce the binary size by compressing it with upx. To do the compression call `upx --ultra-brute --lzma ./zig-out/bin/zig*' (upx is automatically downloaded by the script)
