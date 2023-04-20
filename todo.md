# FullMoon

# fixes

# improvements of compilation
* generate lua source library header in buld (luaunit.lua , re.lua) instead of having it in repo

# possible improvements of compilation
* automatic UPX download and build option

# additional libraries
* argparse https://github.com/luarocks/argparse
* cleanup & include zip/unzip
* Luasocket https://github.com/lunarmodules/luasocket
* http server/client (based on luasocket)
* xml library
* tar library
* terminal ui library, either some existing lua binding
    * or own based on https://github.com/dankamongmen/notcurses
    * https://github.com/hoelzro/lua-term <-- simple (almost) pure lua
* luacheck. Static analyser and linter https://github.com/lunarmodules/luacheck
* Penlight pure lua libraries https://lunarmodules.github.io/Penlight/
* a markdown library. either https://github.com/mpeterv/markdown or https://github.com/asb/lua-discount/
* gui library https://github.com/Immediate-Mode-UI/Nuklear with wraper or https://www.raylib.com/ 
* als reader/writer own or https://xlsxwriterlua.readthedocs.io/ https://github.com/jjensen/lua-xlsx/blob/master/xlsx.lua
* maybe add some of these with a lua wraper
    * https://github.com/nothings/single_file_libs
    * https://github.com/nothings/stb
    * https://en.cppreference.com/w/c/links/libs
