# fullmoon

fullmoon is a portable lua interpreter statically compiled with musl with additional libraries

## included libraries
* [LuaSQLite3](http://lua.sqlite.org/)
* [luafilesystem](https://github.com/lunarmodules/luafilesystem)
* [lua-zlib](https://github.com/brimworks/lua-zlib)
* [lpeg](https://www.inf.puc-rio.br/~roberto/lpeg/) includes re module
* [luaunit](https://github.com/bluebird75/luaunit)

## compilation
To compile fullmoon you need zig on your path.
Either install trough your package manager or just download from [ziglang.org](https://ziglang.org/download/) extract and add the directory to your path.
To build and test just run `zig build test`
