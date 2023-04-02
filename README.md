# fullmoon

fullmoon is a portable lua interpreter statically compiled with musl with additional libraries

## included libraries
* LuaSQLite3 - http://lua.sqlite.org/
* luafilesystem - https://github.com/lunarmodules/luafilesystem
* lua-zlib - https://github.com/brimworks/lua-zlib
* lpeg - https://www.inf.puc-rio.br/~roberto/lpeg/

## compilation
The compilation is done trough a simple shell script `fullmoon.sh` that downloads musl, lua and all the required libraries and compiles them into a singe portable application.
Just execute ```./fullmoon.sh``` in the main directory and wait.

## cleanup 
To remove all the downloaded libraries and musl execute ```./fullmoon clean```
