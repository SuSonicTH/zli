# ZLI - Tools

These command line tools are shipped in the zip payload attached to the main
executable and are started with `zli @tool`.

## tools

| tool      | description                                                                  |
| --------- | ---------------------------------------------------------------------------- |
| `@repl`   | a Read Print Eval loop                                                       |
| `@sqlite` | a sqlite interface. open, query and manipulate any sqlite database           |
| `@compile`| a tool to package lua scripts and files into a zip attached to an executable |
| `@test`   | run a LuaUnit test file                                                      |
| `@manual` | serve the Lua manual in a browser                                            |
| `@serve`  | serve a directory over http                                                  |

`serve_lib.lua` is an internal helper shared by `@serve` and `@manual`.
