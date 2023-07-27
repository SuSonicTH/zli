# ZLI


## ZLI bindings to 3rd party libraries
there are some custom lua bindings for 3rd party libraries

| library   | link                                  | licence                                                               | description                                                                                                        |
| --------- | ------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Crossline | https://github.com/jcwangxp/Crossline | MIT                                                                   | Crossline is a small, self-contained, zero-config, MIT licensed, cross-platform, readline and libedit replacement. |
| lua_zip   | https://zlib.net/                     | binding to the minizip library included in zlib for zip file handling |

## Inhouse ZIL libraries
libraries developed specifically for ZLI that don't use any external libraries

| library   | description                                                                                                                                                                         |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| auxiliary | some auxiliary functions to improve the string, table and file handling                                                                                                             |
| csv       | a simple csv (character/comma separated values) reading/writing library                                                                                                             |
| logger    | a very simple logging library                                                                                                                                                       |
| sbuilder  | a string builder that is faster then the lua way of adding to a table and calling table.concat                                                                                      |
| stream    | a stream library enspired by the java stream library that brings the functional style programming to lua. Stream any table (list) or iterator and execute operations on the stream |
