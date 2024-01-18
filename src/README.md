# ZLI


## ZLI bindings to 3rd party libraries
there are some custom lua bindings for 3rd party libraries

| library     | link                                  | licence | description                                                                                                        |
| ----------- | ------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------ |
| Crossline   | https://github.com/jcwangxp/Crossline | MIT     | Crossline is a small, self-contained, zero-config, MIT licensed, cross-platform, readline and libedit replacement. |
| unzip / zip | https://zlib.net/                     | MIT     | binding to the minizip library included in zlib for zip file handling                                              |

## Inhouse ZLI libraries
libraries developed specifically for ZLI that don't use any external libraries

| library    | description                                                                                                              |
| ---------- | ------------------------------------------------------------------------------------------------------------------------ |
| auxiliary  | some auxiliary functions to improve the string, table and file handling                                                  |
| collection | a collection library simmilar to javas collection. Currently only (Hash)Set is implemented, more to come                 |
| filesystem | providing filesystem functions like listing/creating/changing directories, deleting/renaming/moving files & directories. |
| logger     | a very simple logging library                                                                                            |
| stream     | a stream library enspired by the java stream library that brings the functional style programming to lua.                |
| timer      | a nanosecont timer for high precision timings available as os.nanotime                                                   |

