const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const luax = @import("luax.zig");

const zigStringUtil = @import("zigStringUtil");
const Builder = zigStringUtil.Builder;

const allocator = std.heap.c_allocator;

const filesystem = [_]ziglua.FnReg{
    .{ .name = "cwd", .func = ziglua.wrap(cwd) },
    .{ .name = "dir", .func = ziglua.wrap(dir) },
    .{ .name = "create_path", .func = ziglua.wrap(create_path) },
};

const filesystem_lazy_init = [_]ziglua.FnReg{
    .{ .name = "full_path", .func = ziglua.wrap(full_path) },
    .{ .name = "stat", .func = ziglua.wrap(stat) },
    .{ .name = "is_file", .func = ziglua.wrap(is_file) },
    .{ .name = "is_directory", .func = ziglua.wrap(is_directory) },
    .{ .name = "size", .func = ziglua.wrap(size) },
    .{ .name = "size_hr", .func = ziglua.wrap(size_hr) },
};

const separator = switch (builtin.os.tag) {
    .windows => '\\',
    else => '/',
};

const separator_string = switch (builtin.os.tag) {
    .windows => "\\",
    else => "/",
};

const zli_filesystem = "zli_filesystem";

pub export fn luaopen_filesystem(state: ?*ziglua.LuaState) callconv(.C) c_int {
    var lua: Lua = .{ .state = state.? };
    lua.newLib(&filesystem);
    _ = lua.pushString("separator");
    _ = lua.pushString(separator_string);
    lua.setTable(-3);

    const exteded = @embedFile("filesystem.lua");
    luax.registerExtended(&lua, exteded, "filesytem", zli_filesystem);
    return 1;
}

var path_buffer: [fs.MAX_PATH_BYTES]u8 = undefined;

fn pathToString(path: []const u8) [:0]u8 {
    path_buffer[path.len] = 0;
    @memcpy(path_buffer[0..path.len], path);
    return path_buffer[0..path.len :0];
}

fn pathToStringAlloc(path: []const u8) ![:0]u8 {
    var ret = try allocator.alloc(u8, path.len + 1);
    ret[path.len] = 0;
    @memcpy(ret[0..path.len], path);
    return ret[0..path.len :0];
}

fn getRealPath(lua: *Lua, path: []const u8) [:0]u8 {
    const realPath = fs.cwd().realpathAlloc(allocator, path) catch luax.raiseError(lua, "could not get realPath");
    defer allocator.free(realPath);
    return pathToString(realPath);
}

fn getRealPathAlloc(lua: *Lua, path: []const u8) [:0]u8 {
    const realPath = fs.cwd().realpathAlloc(allocator, path) catch luax.raiseError(lua, "could not get realPath");
    defer allocator.free(realPath);
    return pathToStringAlloc(realPath) catch luax.raiseError(lua, "could not get realPath");
}

fn dir(lua: *Lua) i32 {
    var path = lua.optString(1, ".");
    var directory = std.fs.cwd().openIterableDir(path[0..std.mem.len(path)], .{}) catch luax.raiseError(lua, "could not open directory");
    defer directory.close();

    const fullPath = getRealPathAlloc(lua, std.mem.sliceTo(path, 0));
    defer allocator.free(fullPath);

    lua.newTable();
    const table = lua.getTop();
    var iterator = directory.iterate();
    while (iterator.next() catch luax.raiseError(lua, "could not traverse directory")) |entry| {
        const name = lua.pushString(pathToString(entry.name));
        create_path_sub(lua, fullPath, name);
        lua.setTable(table);
    }
    return 1;
}

fn create_path(lua: *Lua) i32 {
    var path = std.mem.sliceTo(lua.checkString(1), 0);
    var name = std.mem.sliceTo(lua.checkString(2), 0);
    create_path_sub(lua, path, name);
    return 1;
}

fn create_path_sub(lua: *Lua, path: [:0]const u8, name: [:0]const u8) void {
    lua.newTable();

    _ = lua.pushString("__lazy_init");
    lua.newTable();
    lua.setFuncs(&filesystem_lazy_init, 0);
    lua.setTable(-3);

    lua.newTable();
    _ = lua.pushString("__index");
    lua.pushClosure(ziglua.wrap(lazy_init), 0);
    lua.setTable(-3);
    lua.setMetatable(-2);

    _ = lua.pushString("path");
    _ = lua.pushString(path);
    lua.setTable(-3);

    _ = lua.pushString("name");
    _ = lua.pushString(name);
    lua.setTable(-3);
}

fn lazy_init(lua: *Lua) i32 {
    _ = lua.pushString("__lazy_init");
    _ = lua.getTable(1);

    lua.pushValue(2);
    _ = lua.getTable(-2);
    lua.pushValue(1);
    lua.call(1, 1);

    lua.pushValue(2);
    lua.pushValue(-2);
    lua.setTable(1);

    return 1;
}

fn full_path(lua: *Lua) i32 {
    lua.argCheck(lua.typeOf(1) == .table, 1, "expected path object");
    const path = luax.getTableString(lua, "path", 1);
    const name = luax.getTableString(lua, "name", 1);

    var builder: Builder = full_path_sub(path, name) catch memoryError(lua);
    defer builder.deinit();

    const fullpath = builder.get() catch memoryError(lua);
    _ = lua.pushBytes(fullpath);
    return 1;
}

fn full_path_sub(path: [:0]const u8, name: [:0]const u8) !Builder {
    var builder: Builder = try Builder.init(allocator, 0);
    try builder.add(path);
    try builder.add(separator_string);
    try builder.add(name);
    return builder;
}

fn memoryError(lua: *Lua) noreturn {
    luax.raiseError(lua, "could not allocate memory");
}

fn cwd(lua: *Lua) i32 {
    _ = lua.pushString(getRealPath(lua, "."));
    return 1;
}

fn stat(lua: *Lua) i32 {
    lua.argCheck(lua.typeOf(1) == .table, 1, "expected path object");
    const fullPath = luax.getTableString(lua, "full_path", 1);
    const file = open_file_or_directory(std.fs.cwd(), fullPath) catch luax.raiseError(lua, "Could not open file");
    defer file.close();
    const stats = file.stat() catch luax.raiseError(lua, "Could not get file stats");

    lua.newTable();
    _ = lua.pushString("is_directory");
    lua.pushBoolean(stats.kind == std.fs.File.Kind.directory);
    lua.setTable(-3);

    _ = lua.pushString("is_file");
    lua.pushBoolean(stats.kind == std.fs.File.Kind.file);
    lua.setTable(-3);

    _ = lua.pushString("size");
    lua.pushInteger(@intCast(stats.size));
    lua.setTable(-3);

    return 1;
}

fn get_stat(lua: *Lua, name: [:0]const u8) i32 {
    lua.argCheck(lua.typeOf(1) == .table, 1, "expected path object");
    luax.getTable(lua, "stat", 1);
    luax.getTable(lua, name, 2);
    return 1;
}

fn is_directory(lua: *Lua) i32 {
    return get_stat(lua, "is_directory");
}

fn is_file(lua: *Lua) i32 {
    return get_stat(lua, "is_file");
}

fn size(lua: *Lua) i32 {
    return get_stat(lua, "size");
}

fn size_hr(lua: *Lua) i32 {
    _ = get_stat(lua, "size");
    luax.pushRegistryFunction(lua, zli_filesystem, "size_hr");
    lua.pushValue(-2);
    lua.call(1, 1);
    return 1;
}

fn open_file_or_directory(dire: std.fs.Dir, path: []const u8) !std.fs.File {
    if (builtin.os.tag == .windows) {
        const path_w = try std.os.windows.sliceToPrefixedFileW(path);
        return std.fs.File{
            .handle = try std.os.windows.OpenFile(path_w.span(), .{
                .dir = dire.fd,
                .access_mask = std.os.windows.SYNCHRONIZE | std.os.windows.GENERIC_READ,
                .creation = std.os.windows.FILE_OPEN,
                .io_mode = .blocking,
                .filter = .any,
            }),
            .capable_io_mode = std.io.default_mode,
            .intended_io_mode = .blocking,
        };
    }
    return std.fs.File{
        .handle = try std.os.openat(dir.fd, path, std.os.O.RDONLY, 0),
        .capable_io_mode = std.io.default_mode,
        .intended_io_mode = .blocking,
    };
}
