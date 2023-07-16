# luax utility functions
These are utility function to make the lia-c bindings shorter and more readable.

They might be removed completley after rewriting the c-libraries in zig

## files
| lib        | description                                              |
| ---------- | -------------------------------------------------------- |
| luax_error | some macros to check for errors and retrun or raise them |
| luax_gcptr | easier handling of lua garbage collected pointers        |
| luax_value | some helpers for table handling and value getting        |
