const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;

pub const NamedConstantInteger = struct {
    name: [:0]const u8,
    number: zlua.Integer,
};

pub fn createFunctionSubTable(lua: *Lua, functions: []const zlua.FnReg, table_name: [:0]const u8) void {
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

pub fn registerExtended(lua: *Lua, source: [:0]const u8, name: [:0]const u8, module: [:0]const u8) void {
    lua.loadBuffer(source, name, zlua.Mode.text) catch lua.raiseError();
    lua.call(.{ .args = 0, .results = 1 });
    lua.checkType(-1, zlua.LuaType.function);
    lua.pushValue(-2);
    lua.call(.{ .args = 1, .results = 1 });
    if (lua.typeOf(-1) == .table) {
        _ = lua.pushString(module);
        lua.pushValue(-2);
        lua.setTable(zlua.registry_index);
    }
    lua.pop(1);
}

pub fn pushLibraryFunction(lua: *Lua, module: [:0]const u8, function: [:0]const u8) void {
    _ = lua.getGlobal(module) catch undefined;
    _ = lua.pushString(function);
    _ = lua.getTable(-2);
    lua.remove(-2);
}

pub fn pushRegistryFunction(lua: *Lua, module: [:0]const u8, function: [:0]const u8) void {
    _ = lua.pushString(module);
    _ = lua.getTable(zlua.registry_index);
    if (lua.isNil(-1)) {
        raiseFormattedError(lua, "internal error: could not get module '%s' from registry", .{module.ptr});
    }
    _ = lua.pushString(function);
    _ = lua.getTable(-2);
    if (lua.isNil(-1)) {
        raiseFormattedError(lua, "internal error: could not get function '%s' from module '%s'", .{ function.ptr, module.ptr });
    }
    lua.remove(-2);
}

pub fn raiseFormattedError(lua: *Lua, message: [:0]const u8, args: anytype) noreturn {
    _ = lua.pushFString(message, args);
    lua.raiseError();
}

pub fn raiseError(lua: *Lua, message: [:0]const u8) noreturn {
    _ = lua.pushString(message);
    lua.raiseError();
}

pub fn returnError(lua: *Lua, message: [:0]const u8) i32 {
    lua.pushNil();
    _ = lua.pushString(message);
    return 2;
}

pub fn returnFormattedError(lua: *Lua, message: [:0]const u8, args: anytype) i32 {
    lua.pushNil();
    _ = lua.pushFString(message, args);
    return 2;
}

pub fn returnOrRaiseForamttedError(lua: *Lua, doRaiseError: bool, message: [:0]const u8, args: anytype) i32 {
    if (doRaiseError) {
        raiseFormattedError(lua, message, args);
    }
    return returnFormattedError(lua, message, args);
}

pub fn registerUserData(lua: *Lua, name: [:0]const u8, function: zlua.CFn) void {
    lua.newMetatable(name) catch raiseError(lua, "could not register userData");
    _ = lua.pushString("__gc");
    lua.pushFunction(function);
    lua.setTable(-3);
    lua.pop(1);
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

pub fn createUserDataTableSetFunctions(lua: *Lua, name: [:0]const u8, comptime T: type, functions: []const zlua.FnReg) *T {
    const userData: *T = createUserDataTable(lua, name, T);
    lua.setFuncs(functions, 0);
    return userData;
}

pub fn getUserData(lua: *Lua, name: [:0]const u8, comptime T: type) *T {
    return getUserDataIndex(lua, name, T, 1);
}

pub fn getUserDataIndex(lua: *Lua, name: [:0]const u8, comptime T: type, index: i32) *T {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(name);
    _ = lua.getTable(table_index);
    if (lua.isNil(-1)) {
        raiseError(lua, "expected userdata got nil");
    }
    const udata: *T = lua.toUserdata(T, -1) catch raiseError(lua, "could not get UserData");
    lua.pop(1);
    return udata;
}

pub fn getGcUserData(lua: *Lua, comptime T: type) *T {
    return lua.toUserdata(T, -1) catch raiseError(lua, "could not get UserData");
}

pub fn getTable(lua: *Lua, key: [:0]const u8, index: i32) void {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(key);
    _ = lua.getTable(table_index);
}

pub fn getOptionalTable(lua: *Lua, key: [:0]const u8, index: i32) bool {
    getTable(lua, key, index);
    return lua.isTable(-1);
}

pub fn getTableStringOrError(lua: *Lua, key: [:0]const u8, index: i32) ![:0]const u8 {
    getTable(lua, key, index);
    if (lua.isNil(-1)) {
        lua.pop(1);
        return error.KeyNotFound;
    }
    const value = lua.toString(-1) catch return error.KeyNotaString;
    lua.pop(1);
    return std.mem.sliceTo(value, 0);
}

pub fn getTableString(lua: *Lua, key: [:0]const u8, index: i32) [:0]const u8 {
    return getTableStringOrError(lua, key, index) catch raiseError(lua, "illegal option, expecting String");
}

pub fn getOptionString(lua: *Lua, key: [:0]const u8, index: i32, default: [:0]const u8) [:0]const u8 {
    getTable(lua, key, index);
    if (lua.isNil(-1)) {
        lua.pop(1);
        return default;
    }
    const value = lua.toString(-1) catch raiseFormattedError(lua, "illegal option '%s', expecting String", .{key.ptr});
    lua.pop(1);
    return std.mem.sliceTo(value, 0);
}

pub fn getOptionalString(lua: *Lua, key: [:0]const u8, index: i32) ?[:0]const u8 {
    getTable(lua, key, index);
    if (lua.isNil(-1)) {
        lua.pop(1);
        return null;
    }
    const value = lua.toString(-1) catch raiseFormattedError(lua, "illegal option '%s', expecting String", .{key.ptr});
    lua.pop(1);
    return std.mem.sliceTo(value, 0);
}

pub fn getOptionInteger(lua: *Lua, key: [:0]const u8, index: i32, default: zlua.Integer) zlua.Integer {
    getTable(lua, key, index);
    if (lua.isNil(-1)) {
        lua.pop(1);
        return default;
    }
    const value = lua.toInteger(-1) catch raiseFormattedError(lua, "illegal option '%s', expecting Integer", .{key.ptr});
    lua.pop(1);
    return value;
}

pub fn getOptionBool(lua: *Lua, key: [:0]const u8, index: i32, default: bool) bool {
    getTable(lua, key, index);
    if (lua.isNil(-1)) {
        lua.pop(1);
        return default;
    }
    const value = lua.toBoolean(-1);
    lua.pop(1);
    return value;
}

pub inline fn getAbsoluteIndex(lua: *Lua, index: i32) i32 {
    if (index >= 0) {
        return index;
    } else {
        return lua.getTop() + index + 1;
    }
}

pub fn setTableString(lua: *Lua, index: i32, key: [:0]const u8, value: [:0]const u8) void {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(key);
    _ = lua.pushString(value);
    lua.setTable(table_index);
}

pub fn setTableNumber(lua: *Lua, index: i32, key: [:0]const u8, value: zlua.Number) void {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(key);
    lua.pushNumber(value);
    lua.setTable(table_index);
}

pub fn setTableInteger(lua: *Lua, index: i32, key: [:0]const u8, value: zlua.Integer) void {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(key);
    lua.pushInteger(value);
    lua.setTable(table_index);
}

pub fn setTableBoolean(lua: *Lua, index: i32, key: [:0]const u8, value: bool) void {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(key);
    lua.pushBoolean(value);
    lua.setTable(table_index);
}

pub fn setTableUserData(lua: *Lua, index: i32, key: [:0]const u8, value: *anyopaque) void {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(key);
    lua.pushLightUserdata(value);
    lua.setTable(table_index);
}

pub fn setTableFunction(lua: *Lua, index: i32, key: [:0]const u8, value: zlua.CFn) void {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(key);
    lua.pushFunction(value);
    lua.setTable(table_index);
}

pub fn setTableValue(lua: *Lua, index: i32, key: [:0]const u8, value: i32, remove: bool) void {
    const table_index = getAbsoluteIndex(lua, index);
    const value_index = getAbsoluteIndex(lua, value);
    _ = lua.pushString(key);
    lua.pushValue(value_index);
    lua.setTable(table_index);
    if (remove) {
        lua.remove(value_index);
    }
}

pub fn setTableRegistryFunction(lua: *Lua, index: i32, key: [:0]const u8, module: [:0]const u8, function: [:0]const u8) void {
    const table_index = getAbsoluteIndex(lua, index);
    _ = lua.pushString(key);
    pushRegistryFunction(lua, module, function);
    lua.setTable(table_index);
}

pub fn getArgStringOrError(lua: *Lua, index: i32, message: [:0]const u8) [:0]const u8 {
    lua.argCheck(lua.typeOf(index) == .string, index, message);
    return lua.toString(index) catch unreachable;
}

pub fn getArgIntegerOrError(lua: *Lua, index: i32, message: [:0]const u8) zlua.Integer {
    lua.argCheck(lua.typeOf(index) == .number, index, message);
    return lua.toInteger(index) catch unreachable;
}

pub fn getArgNumberOrError(lua: *Lua, index: i32, message: [:0]const u8) zlua.Number {
    lua.argCheck(lua.typeOf(index) == .number, index, message);
    return lua.toNumber(index) catch unreachable;
}

pub fn getArgBooleanOrError(lua: *Lua, index: i32, message: [:0]const u8) bool {
    lua.argCheck(lua.typeOf(index) == .boolean, index, message);
    return lua.toBoolean(index) catch unreachable;
}
