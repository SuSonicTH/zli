# fullmoon

fullmoon is a portable lua interpreter statically compiled with musl with additional libraries

## included libraries
* [LuaSQLite3](http://lua.sqlite.org/)
* [luafilesystem](https://github.com/lunarmodules/luafilesystem)
* [lua-zlib](https://github.com/brimworks/lua-zlib)
* [lpeg](https://www.inf.puc-rio.br/~roberto/lpeg/) includes re module
* [luaunit](https://github.com/bluebird75/luaunit)

## compilation
The build requires you to have git an dzig installed
Zig can be installed trough your package manager or just download from [ziglang.org](https://ziglang.org/download/) extract and add the directory to your path.

## build process:
```bash
git clone --recurse-submodules https://github.com/SuSonicTH/fullmoon.git
cd fullmoon
zig build test
```
binaries are saved in zig-out/bin/

### release buld
```bash
zig build -Doptimize=ReleaseFast
```
