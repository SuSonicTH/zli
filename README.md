# ZLI - Zig Lua Interpreter

ZLI is a portable lua interpreter statically compiled (on non windows with musl) with additional libraries.
The binary can be moved from system to system without any dependencies on installed ibraries.

## Batteries included
There are many libraries included in the ZIL binary. Some 3rd party lua libraries and some developed for ZIL.

* [3rd party libraries](https://github.com/SuSonicTH/zli/blob/master/src/lib/)
* [ZIL libraries](https://github.com/SuSonicTH/zli/blob/master/src/)

In the main binary there are also some commandline tools included. More information can be found in [Tools](https://github.com/SuSonicTH/zli/blob/master/src/tools/)

## Clone & Build
This works under linux and windows (under gitbash)
```bash
git clone --recurse-submodules https://github.com/SuSonicTH/zli.git
cd zli
chmod +x build.sh
./build.sh
```
The build script will download the zig compiler and upx executable if they are not found on the system.

## Easymode
You can alos use the fully automated `get-zig.sh` script to do everything above. All you need is **git**, **bash** and **curl**.
Paste the following into your bash terminal:
`curl -s https://raw.githubusercontent.com/SuSonicTH/zli/master/getzli.sh | bash && cd zli`

## Manual Compilation
The build requires you to have git and zig installed
Zig can be installed trough your package manager or just download from [ziglang.org](https://ziglang.org/download/) extract and add the directory to your path.
For windows users I recomend [git for windows](https://gitforwindows.org/) aka **gitbash** or running under [Windows subsystem for Windows](https://learn.microsoft.com/en-us/windows/wsl/install) aka **WSL**

I'm using the master branch of zig which is under heavy development and breaking changes are happening often. 
Curently I'm on version **0.11.0-dev.3777**.
You can use `./build.sh --get-zig` to get that specific version as described below (works for linux, gitbash and WSL) which will donwload zig into the subdirectory zig.

To compile execute `zig build` (or `./zig/zig build` if you are using the local zig installation)
The executable will be in ./zig-out/bin/.
The `./build.sh` also uses a trick to reduce the binary size by compressing it with upx. To do the compression call `upx --ultra-brute --lzma ./zig-out/bin/zig*' 
