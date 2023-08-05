const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;

pub const NamedConstantInteger = struct {
    name: [:0]const u8,
    number: ziglua.Integer,
};

pub const UserData = struct {
    name: [:0]const u8,
    function: ?ziglua.CFn,
};

pub fn createFunctionSubTable(lua: *Lua, functions: []const ziglua.FnReg, table_name: [:0]const u8) void {
    _ = lua.pushString(table_name);
    lua.newTable();
    lua.setFuncs(functions, 0);
    lua.setTable(-3);
}

pub fn createConstantSubTable(lua: *Lua, constants: []const NamedConstantInteger, table_index: i32, table_name: [:0]const u8) void {
    _ = lua.pushString(table_name);
    createConstantTable(lua, constants);
    lua.setTable(table_index);
}

pub fn createConstantTable(lua: *Lua, constants: []const NamedConstantInteger) void {
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

pub fn pushLibraryFunction(lua: *Lua, module: [:0]const u8, function: [:0]const u8) void {
    _ = lua.getGlobal(module) catch undefined;
    _ = lua.pushString(function);
    _ = lua.getTable(-2);
    lua.remove(-2);
}

pub fn raiseError(lua: *Lua, message: [:0]const u8) noreturn {
    _ = lua.pushString(message);
    lua.raiseError();
}

pub fn registerUserData(lua: *Lua, userData: UserData) void {
    if (userData.function) |function| {
        lua.newMetatable(userData.name) catch raiseError(lua, "could not register userData");
        _ = lua.pushString("__gc");
        lua.pushFunction(function);
        lua.setTable(-3);
        lua.pop(1);
    }
}

pub fn createUserData(lua: *Lua, name: [:0]const u8, comptime T: type) *T {
    const userData: *T = lua.newUserdata(T, 0);
    _ = lua.getMetatableRegistry(name);
    lua.setMetatable(-2);
    return userData;
}

pub fn createUserDataTable(lua: *Lua, name: [:0]const u8, comptime T: type) *T {
    lua.newTable();
    _ = lua.pushString(name);
    const userData: *T = createUserData(lua, name, T);
    lua.setTable(-3);
    return userData;
}

pub fn createUserDataTableSetFunctions(lua: *Lua, name: [:0]const u8, comptime T: type, functions: []const ziglua.FnReg) *T {
    const userData: *T = createUserDataTable(lua, name, T);
    lua.setFuncs(functions, 0);
    return userData;
}

pub fn getUserData(lua: *Lua, name: [:0]const u8, comptime T: type) *T {
    _ = lua.pushString(name);
    _ = lua.getTable(1);
    return lua.toUserdata(T, -1) catch raiseError(lua, "could not get UserData");
}

pub fn getGcUserData(lua: *Lua, comptime T: type) *T {
    return lua.toUserdata(T, -1) catch raiseError(lua, "could not get UserData");
}
