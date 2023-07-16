# ZLI - Zig Lua Interpreter

ZLI is a portable lua interpreter statically compiled (on non windows with with musl) with additional libraries

## Included 3rd Libraries
* [LuaSQLite3](http://lua.sqlite.org/)
* [luafilesystem](https://github.com/lunarmodules/luafilesystem)
* [lua-zlib](https://github.com/brimworks/lua-zlib)
* [LPeg](https://www.inf.puc-rio.br/~roberto/lpeg/) includes re module
* [luaunit](https://github.com/bluebird75/luaunit)
* [lua-cjson](https://github.com/openresty/lua-cjson)
* [argparse](https://github.com/luarocks/argparse)

## Included ZLI libraries
* crossline lua binding to [crossline](https://github.com/jcwangxp/Crossline
* zip - a zip file library
*
## Compilation
The build requires you to have git and zig installed
Zig can be installed trough your package manager or just download from [ziglang.org](https://ziglang.org/download/) extract and add the directory to your path.

## Clone & Build Process:
```bash
git clone --recurse-submodules https://github.com/SuSonicTH/zli.git
cd zli
zig build test
```
binaries are saved in zig-out/bin/

### Release Build
```bash
zig build -Doptimize=ReleaseFast
upx --ultra-brute --lzma zig-out/bin/zli*
```
