const std = @import("std");
const builtin = @import("builtin");

const windows = std.os.windows;

extern "kernel32" fn GetConsoleOutputCP() callconv(.winapi) windows.UINT;
extern "kernel32" fn SetConsoleOutputCP(codepage: windows.UINT) callconv(.winapi) windows.BOOL;

const utf8CodePage: windows.UINT = 65001;
var oldCodePage: windows.UINT = 0;

pub fn init() void {
    if (builtin.os.tag == .windows) {
        oldCodePage = GetConsoleOutputCP();
        if (oldCodePage != utf8CodePage) {
            _ = SetConsoleOutputCP(utf8CodePage);
        }
    }
}

pub fn deinit() void {
    if (builtin.os.tag == .windows) {
        if (oldCodePage > 0 and oldCodePage != utf8CodePage) {
            _ = SetConsoleOutputCP(oldCodePage);
        }
    }
}
