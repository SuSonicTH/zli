const std = @import("std");
//const ziglua = @import("ziglua");
const ziglua = @import("lib/ziglua/src/ziglua-5.4/lib.zig");

pub const NamedConstantInteger = struct {
    name: [:0]const u8,
    number: ziglua.Integer,
};

pub fn createFunctionSubTable(lua: *ziglua.Lua, functions: []const ziglua.FnReg, table_name: [:0]const u8) void {
    _ = lua.pushString(table_name);
    lua.newTable();
    lua.setFuncs(functions, 0);
    lua.setTable(-3);
}

pub fn createConstantSubTable(lua: *ziglua.Lua, constants: []const NamedConstantInteger, table_index: i32, table_name: [:0]const u8) void {
    _ = lua.pushString(table_name);
    createConstantTable(lua, constants);
    lua.setTable(table_index);
}

pub fn createConstantTable(lua: *ziglua.Lua, constants: []const NamedConstantInteger) void {
    lua.newTable();
    const table = lua.getTop();
    for (constants) |constant| {
        _ = lua.pushString(constant.name);
        lua.pushInteger(constant.number);
        lua.setTable(table);
    }
}

pub fn slice(str: [*:0]const u8) []const u8 {
    return std.mem.sliceTo(str, 0);
}

pub fn push_library_function(lua: *ziglua.Lua, module: [:0]const u8, function: [:0]const u8) void {
    _ = lua.getGlobal(module) catch undefined;
    _ = lua.pushString(function);
    _ = lua.getTable(-2);
    lua.remove(-2);
}
