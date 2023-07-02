# FullMoon todo

# refactorings
* convert fullmoon.c to zig

# fixes

# possible improvements of compilation
* automatic UPX download and build option
* add goals for release build (for all platforms)

# additional functionality
* add functionality to add payload (scripts, modules and resources) to end of exe
    * builtin tool to "compile" exe
    * DONE module can load payload files
    * io.open io.read,... can load payload files
    * DONE fullmoon checks paylod on startup and executes init.lua or main.lua or <exename>.lua
    * DONE add commandline option to execute payload scripts (@script.lua ??)

# additional libraries
* https://github.com/daurnimator/lpeg_patterns ?
* Luasocket https://github.com/lunarmodules/luasocket
* http server/client (based on luasocket)
* xml library
* tar library
* terminal ui library, either some existing lua binding
    * https://github.com/hoelzro/lua-term <-- simple (almost) pure lua
    * or own based on https://github.com/dankamongmen/notcurses
    * or own based an already included Crossline lib
* luacheck. Static analyser and linter https://github.com/lunarmodules/luacheck
* Penlight pure lua libraries https://lunarmodules.github.io/Penlight/
* a markdown library. either https://github.com/mpeterv/markdown or https://github.com/asb/lua-discount/
* gui library https://github.com/Immediate-Mode-UI/Nuklear with wraper or https://www.raylib.com/ 
* xls reader/writer own or https://xlsxwriterlua.readthedocs.io/ https://github.com/jjensen/lua-xlsx/blob/master/xlsx.lua
* maybe add some of these with a lua wraper
    * https://github.com/nothings/single_file_libs
    * https://github.com/nothings/stb
    * https://en.cppreference.com/w/c/links/libs
