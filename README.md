# fullmoon

fullmoon is a portable lua interpreter statically compiled with musl with additional libraries

## included libraries
* [LuaSQLite3](http://lua.sqlite.org/)
* [luafilesystem](https://github.com/lunarmodules/luafilesystem)
* [lua-zlib](https://github.com/brimworks/lua-zlib)
* [lpeg](https://www.inf.puc-rio.br/~roberto/lpeg/) includes re module
* [luaunit](https://github.com/bluebird75/luaunit)

## compilation
The compilation is done trough a simple shell script `fullmoon.sh` that downloads musl, lua and all the required libraries and compiles them into a singe portable application.
Just execute `./fullmoon.sh` in the main directory and wait.
If you have [upx](https://upx.github.io/) installed the binary will be also compressed with upx.

## cleanup 
To remove all the downloaded libraries and musl execute `./fullmoon clean`

