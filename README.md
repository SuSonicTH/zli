# ZLI - Zig Lua Interpreter

ZLI is a portable lua interpreter statically compiled (on non windows with musl) with additional libraries.
The binary can be moved from system to system without any dependencies on installed ibraries.

## Batteries included
There are many libraries included in the ZIL binary. Some 3rd party lua libraries and some developed for ZIL.

* [3rd party libraries](https://github.com/SuSonicTH/zli/blob/master/src/lib/)
* [ZIL libraries](https://github.com/SuSonicTH/zli/blob/master/src/)

In the main binary there are also some commandline tools included. More information can be found in [Tools](https://github.com/SuSonicTH/zli/blob/master/src/tools/)

## Clone & Build
This works under linux and windows(under gitbash) for x86_64 platforms and on linux arm all it needs git and zig on the path
```bash
git clone --recurse-submodules https://github.com/SuSonicTH/zli.git
cd zli
./build.sh
```
If you want to compile for all the supported platforms use the `--all` switch, all binaries are saved to the bin directory with the platform suffix. 
```bash
./build.sh --all
```
If you want to have a substentially smaller binary you also have to have upx on the path and call:
```bash
./build.sh --upx
```
Tests can be executed by calling 
```bash
./build.shj --test
```
## Easymode
You can also use the fully automated `get-zig.sh` script to do everything above and dowload the zig compiler and upx binary for the build if needed. *only on x86_64 on windows or linux*
All you need to have is **git**, **bash** and **curl**. (works on gitbash in windows)
Paste the following into your bash terminal. No sudo, no installation, everything happens in the zli directory created in the current directory
```bash
curl -s https://raw.githubusercontent.com/SuSonicTH/zli/master/getzli.sh | bash && cd zli
```

`get-zig.sh` can also be used in a cloned repository to download the zig compiler and upx binary if they are not on the path, or with option --force it doloads zig and upx anyway.
