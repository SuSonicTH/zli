# ZLI todo

# refactorings
* rewrite lua_zip.c in zig (and get rid of luax/)
* create a test directory with all tests including binaries for testing for .gz, ,zip,...
* split tests into libraries
* increase test coverage for all libraries (where it makes sense)

# fixes

# possible improvements of compilation
* automatic UPX download and build option
* add goals for release build (for all platforms, and types) in build.zig (get rid of build.sh)
* change/check getzli.sh

# additional functionality
    * in filesystem add size_tree to get the size of whole directory
    * io.open io.read,... can read payload files
    * strings with variable/expression substitution simmilar to groovy g-strings
    * create a set object simmilar to java hashset
    * create a treeset simmilar to java and/or a sorted set (based on auxiliarys table.insert_sorted)
  
# additional libraries brainstorming
* https://github.com/daurnimator/lpeg_patterns ?
* Luasocket https://github.com/lunarmodules/luasocket
* http server/client (based on luasocket?) or write own based on zig http server/client (easier to port, probably much small exe)
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
