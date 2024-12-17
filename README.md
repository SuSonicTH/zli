# ZLI - Zig Lua Interpreter

ZLI is a portable lua interpreter statically compiled (on non windows with musl) with additional libraries.
The binary can be moved from system to system without any dependencies on installed ibraries.

Currently supported platforms
* Windows on x86_64
* linux on x86_64
* linux on aarch64

Other platforms that are supported by zig could work but are untested
* Windows on x86 and aarch64
* linux on x86, armv7a, riscv64 and powerpc64le
* macOS on aarch64 and x86_64

## Batteries included
There are many libraries included in the ZIL binary, some 3rd party lua libraries and some developed specifically for ZIL.

### included lua libraries
3rd party lua libraries included in zli

| library    | link                                        | licence | description                                                                                                                            |
| ---------- | ------------------------------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| argparse   | https://github.com/mpeterv/argparse         | MIT     | Argparse is a feature-rich command line parser for Lua inspired by argparse for Python                                                 |
| LuaSQLite3 | http://lua.sqlite.org/                      | MIT     | LuaSQLite 3 is a thin wrapper around the public domain [SQLite3](https://www.sqlite.org/) database engine.                             |
| LPeg       | https://www.inf.puc-rio.br/~roberto/lpeg/   | MIT     | LPeg is a new pattern-matching library for Lua, based on Parsing Expression Grammars (PEGs)                                            |
| lua-zlib   | https://github.com/brimworks/lua-zlib       | MIT     | lua binding to the [zlib](https://zlib.net/) to compress/decompress                                                                    |
| luaunit    | https://github.com/bluebird75/luaunit       | BSD     | LuaUnit is a popular unit-testing framework for Lua, with an interface typical of xUnit libraries (Python unittest, Junit, NUnit, ...) |
| lua-cjson  | https://github.com/openresty/lua-cjson      | MIT     | Fast JSON encoding/parsing                                                                                                             |
| Serpent    | https://github.com/pkulchenko/serpent       | MIT     | Lua serializer and pretty printer.                                                                                                     |
| ftcsv      | https://github.com/FourierTransformer/ftcsv | MIT     | ftcsv is a fast csv library written in pure Lua                                                                                        |
| f-string   | https://github.com/hishamhm/f-strings       | MIT     | String interpolation for Lua, inspired by f-strings, a form of string interpolation coming in Python 3.6.                              |

### Custom ZLI bindings to 3rd party libraries
there are some custom lua bindings for 3rd party libraries

| library     | link                                  | licence | description                                                                                                        |
| ----------- | ------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------ |
| Crossline   | https://github.com/jcwangxp/Crossline | MIT     | Crossline is a small, self-contained, zero-config, MIT licensed, cross-platform, readline and libedit replacement. |
| unzip / zip | https://zlib.net/                     | MIT     | binding to the minizip library included in zlib for zip file handling                                              |

### Inhouse ZLI libraries
libraries developed specifically for ZLI that don't use any external libraries

| library    | description                                                                                                              |
| ---------- | ------------------------------------------------------------------------------------------------------------------------ |
| auxiliary  | some auxiliary functions to improve the string, table and file handling                                                  |
| collection | a collection library simmilar to java's collection. (Hash)Set, (Hash)map and (Array)list are implemented                 |
| filesystem | providing filesystem functions like listing/creating/changing directories, deleting/renaming/moving files & directories. |
| logger     | a very simple logging library                                                                                            |
| stream     | a stream library enspired by the java stream library that brings the functional style programming to lua.                |
| timer      | a nanosecond timer for high precision timings available as os.nanotime                                                   |

### Included tools
In the main binary there are also some commandline tools included. More information can be found in [Tools](https://github.com/SuSonicTH/zli/blob/master/src/tools/)

## Clone & Build
This works under linux and windows(under gitbash) for x86_64 platforms and on linux arm all it needs git and zig version 0.14.0-dev on the path
```bash
git clone https://github.com/SuSonicTH/zli.git
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
Paste the following into your bash terminal. No sudo, no installation, everything happens in the zli directory created in the current directory.
```bash
curl -s https://raw.githubusercontent.com/SuSonicTH/zli/master/getzli.sh | bash && cd zli
```

`get-zig.sh` can also be used in a cloned repository to download the zig compiler and upx binary if they are not on the path, or with option --force it doloads zig and upx anyway.
