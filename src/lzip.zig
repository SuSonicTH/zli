const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const luax = @import("luax.zig");

const allocator = std.heap.c_allocator;

const lzip = [_]ziglua.FnReg{
    .{ .name = "open", .func = ziglua.wrap(open) },
};

pub export fn luaopen_lzip(state: ?*ziglua.LuaState) callconv(.C) c_int {
    var lua: Lua = .{ .state = state.? };
    lua.newLib(&lzip);
    return 1;
}

fn open(lua: *Lua) i32 {
    _ = lua.pushString("Hello form lzip");
    return 1;
}
