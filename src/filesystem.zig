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
    .{ .name = "create_path", .func = ziglua.wrap(create_path) },
};

const filesystem_path = [_]ziglua.FnReg{
    .{ .name = "dir", .func = ziglua.wrap(dir) },
    .{ .name = "list", .func = ziglua.wrap(list) },
    //.{ .name = "iterate", .func = ziglua.wrap(iterate) },
    .{ .name = "stat", .func = ziglua.wrap(stat) },
    .{ .name = "is_file", .func = ziglua.wrap(is_file) },
    .{ .name = "is_directory", .func = ziglua.wrap(is_directory) },
    .{ .name = "size", .func = ziglua.wrap(size) },
    .{ .name = "size_hr", .func = ziglua.wrap(size_hr) },
    .{ .name = "access_time", .func = ziglua.wrap(access_time) },
    .{ .name = "create_time", .func = ziglua.wrap(create_time) },
    .{ .name = "modify_time", .func = ziglua.wrap(modify_time) },
    .{ .name = "access_time_ms", .func = ziglua.wrap(access_time_ms) },
    .{ .name = "create_time_ms", .func = ziglua.wrap(create_time_ms) },
    .{ .name = "modify_time_ms", .func = ziglua.wrap(modify_time_ms) },
    .{ .name = "access_time_stamp", .func = ziglua.wrap(access_time_stamp) },
    .{ .name = "create_time_stamp", .func = ziglua.wrap(create_time_stamp) },
    .{ .name = "modify_time_stamp", .func = ziglua.wrap(modify_time_stamp) },
    .{ .name = "mode", .func = ziglua.wrap(mode) },
    .{ .name = "mode_flags", .func = ziglua.wrap(mode_flags) },
    .{ .name = "rename", .func = ziglua.wrap(rename) },
    .{ .name = "delete", .func = ziglua.wrap(delete) },
    //.{ .name = "delete_tree", .func = ziglua.wrap(delete_tree) },
    //.{ .name = "lines", .func = ziglua.wrap(lines) },
    //.{ .name = "read_all", .func = ziglua.wrap(read_all) },
    //.{ .name = "read_lines", .func = ziglua.wrap(read_lines) },
    .{ .name = "open", .func = ziglua.wrap(open) },
    .{ .name = "exists", .func = ziglua.wrap(exists) },
    .{ .name = "absolute", .func = ziglua.wrap(absolute) },
    //.{ .name = "parent", .func = ziglua.wrap(parent) },
    //.{ .name = "child", .func = ziglua.wrap(child) },
    //.{ .name = "sibling", .func = ziglua.wrap(sibling) },
};

const filesystem_path_lua = [_][:0]const u8{
    "read_all",
    "read_lines",
    "lines",
    "iterate",
    "delete_tree",
    "walk",
    "parent",
    "child",
    "sibling",
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
const zli_mt_path = "zli_mt_path";

pub export fn luaopen_filesystem(state: ?*ziglua.LuaState) callconv(.C) c_int {
    var lua: Lua = .{ .state = state.? };
    lua.newLib(&filesystem);
    lua.setFuncs(&filesystem_path, 0);
    _ = lua.pushString("separator");
    _ = lua.pushString(separator_string);
    lua.setTable(-3);

    register_path_mt(&lua);
    const exteded = @embedFile("filesystem.lua");
    luax.registerExtended(&lua, exteded, "filesytem", zli_filesystem);
    return 1;
}

fn register_path_mt(lua: *Lua) void {
    lua.newMetatable(zli_mt_path) catch luax.raiseError(lua, "register_path_mt internal error: could not crete metatable");
    _ = lua.pushString("__tostring");
    lua.pushFunction(ziglua.wrap(path__tostring));
    lua.setTable(-3);
    lua.pop(1);
}

var path_buffer: [fs.MAX_PATH_BYTES]u8 = undefined;

fn path__tostring(lua: *Lua) i32 {
    const path = get_path(lua);
    _ = lua.pushString(path);
    return 1;
}

fn pathToString(path: []const u8) [:0]u8 {
    path_buffer[path.len] = 0;
    @memcpy(path_buffer[0..path.len], path);
    return path_buffer[0..path.len :0];
}

fn getRealPath(lua: *Lua, path: []const u8) [:0]u8 {
    const realPath = fs.cwd().realpathAlloc(allocator, path) catch luax.raiseError(lua, "path does not exist");
    defer allocator.free(realPath);
    return pathToString(realPath);
}

fn list(lua: *Lua) i32 {
    return list_dir(lua, false);
}

fn dir(lua: *Lua) i32 {
    return list_dir(lua, true);
}

fn iterate(lua: *Lua) i32 {
    const args = lua.getTop();

    luax.pushRegistryFunction(lua, zli_filesystem, "iterate");
    lua.pushValue(1);
    if (args == 2) {
        lua.pushValue(2);
    }

    lua.call(args, 4);
    return 4;
}

fn list_dir(lua: *Lua, keyValue: bool) i32 {
    var path = get_path(lua);
    var directory = std.fs.cwd().openIterableDir(path, .{}) catch luax.raiseError(lua, "could not open directory");
    defer directory.close();

    const fullPath = lua.pushString(getRealPath(lua, std.mem.sliceTo(path, 0)));

    lua.newTable();
    const table = lua.getTop();
    var iterator = directory.iterate();
    if (keyValue) {
        while (iterator.next() catch luax.raiseError(lua, "could not traverse directory")) |entry| {
            const name = lua.pushString(pathToString(entry.name));
            create_path_sub(lua, fullPath, name);
            lua.setTable(table);
        }
    } else {
        var index: i32 = 1;
        while (iterator.next() catch luax.raiseError(lua, "could not traverse directory")) |entry| {
            const name = pathToString(entry.name);
            create_path_sub(lua, fullPath, name);
            lua.rawSetIndex(table, index);
            index += 1;
        }
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
    lua.setFuncs(&filesystem_path, 0);

    inline for (filesystem_path_lua) |function_name| {
        _ = lua.pushString(function_name);
        luax.pushRegistryFunction(lua, zli_filesystem, function_name);
        lua.setTable(-3);
    }

    _ = lua.getMetatableRegistry(zli_mt_path);
    lua.setMetatable(-2);

    _ = lua.pushString("path");
    _ = lua.pushString(path);
    lua.setTable(-3);

    _ = lua.pushString("name");
    _ = lua.pushString(name);
    lua.setTable(-3);

    var builder: Builder = full_path(path, name) catch memoryError(lua);
    defer builder.deinit();
    const fullpath = builder.get() catch memoryError(lua);

    _ = lua.pushString("full_path");
    _ = lua.pushString(fullpath);
    lua.setTable(-3);
}

fn full_path(path: [:0]const u8, name: [:0]const u8) !Builder {
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

fn get_stat(lua: *Lua, fullpath: [:0]const u8) std.fs.File.Stat {
    const file = open_file_or_directory(std.fs.cwd(), fullpath) catch luax.raiseError(lua, "Could not open file");
    defer file.close();
    return file.stat() catch luax.raiseError(lua, "Could not get file stats");
}

const SECONDS_DENOMINATOR = 1000000000;
const MILLISECONDS_DENOMINATOR = 1000000;
const TIMESTAMP_FORMAT = "%Y/%m/%d %H:%M:%S";

fn stat(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));

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

    _ = lua.pushString("access_time");
    lua.pushInteger(@intCast(@divTrunc(stats.atime, SECONDS_DENOMINATOR)));
    lua.setTable(-3);

    _ = lua.pushString("create_time");
    lua.pushInteger(@intCast(@divTrunc(stats.ctime, SECONDS_DENOMINATOR)));
    lua.setTable(-3);

    _ = lua.pushString("modify_time");
    lua.pushInteger(@intCast(@divTrunc(stats.mtime, SECONDS_DENOMINATOR)));
    lua.setTable(-3);

    _ = lua.pushString("access_time_ms");
    lua.pushInteger(@intCast(@divTrunc(stats.atime, MILLISECONDS_DENOMINATOR)));
    lua.setTable(-3);

    _ = lua.pushString("create_time_ms");
    lua.pushInteger(@intCast(@divTrunc(stats.ctime, MILLISECONDS_DENOMINATOR)));
    lua.setTable(-3);

    _ = lua.pushString("modify_time_ms");
    lua.pushInteger(@intCast(@divTrunc(stats.mtime, MILLISECONDS_DENOMINATOR)));
    lua.setTable(-3);

    _ = lua.pushString("access_time_stamp");
    push_time_stamp(lua, stats.atime);
    lua.setTable(-3);

    _ = lua.pushString("create_time_stamp");
    push_time_stamp(lua, stats.ctime);
    lua.setTable(-3);

    _ = lua.pushString("modify_time_stamp");
    push_time_stamp(lua, stats.mtime);
    lua.setTable(-3);

    _ = lua.pushString("mode");
    lua.pushInteger(@intCast(stats.mode));
    lua.setTable(-3);

    _ = lua.pushString("mode_flags");
    push_mode_flags(lua, stats);
    lua.setTable(-3);

    return 1;
}

fn get_path(lua: *Lua) [:0]const u8 {
    const luaType = lua.typeOf(1);
    if (luaType == .table) {
        return luax.getTableString(lua, "full_path", 1);
    } else if (luaType == .string) {
        const path = lua.toString(1) catch luax.raiseError(lua, "get_path: internal error");
        return std.mem.sliceTo(path, 0);
    }
    lua.argError(1, "expected string representing a path or a path object");
}

fn is_directory(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushBoolean(stats.kind == std.fs.File.Kind.directory);
    return 1;
}

fn is_file(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushBoolean(stats.kind == std.fs.File.Kind.file);
    return 1;
}

fn size(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushInteger(@intCast(stats.size));
    return 1;
}

fn access_time(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushInteger(@intCast(@divTrunc(stats.atime, SECONDS_DENOMINATOR)));
    return 1;
}

fn create_time(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushInteger(@intCast(@divTrunc(stats.ctime, SECONDS_DENOMINATOR)));
    return 1;
}

fn modify_time(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushInteger(@intCast(@divTrunc(stats.mtime, SECONDS_DENOMINATOR)));
    return 1;
}

fn access_time_ms(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushInteger(@intCast(@divTrunc(stats.atime, MILLISECONDS_DENOMINATOR)));
    return 1;
}

fn create_time_ms(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushInteger(@intCast(@divTrunc(stats.ctime, MILLISECONDS_DENOMINATOR)));
    return 1;
}

fn modify_time_ms(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushInteger(@intCast(@divTrunc(stats.mtime, MILLISECONDS_DENOMINATOR)));
    return 1;
}

fn access_time_stamp(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    push_time_stamp(lua, stats.atime);
    return 1;
}

fn push_time_stamp(lua: *Lua, time: i128) void {
    luax.pushLibraryFunction(lua, "os", "date");
    _ = lua.pushString(TIMESTAMP_FORMAT);
    lua.pushInteger(@intCast(@divTrunc(time, SECONDS_DENOMINATOR)));
    lua.call(2, 1);
}

fn create_time_stamp(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    push_time_stamp(lua, stats.ctime);
    return 1;
}

fn modify_time_stamp(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    push_time_stamp(lua, stats.mtime);
    return 1;
}

fn mode(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    lua.pushInteger(@intCast(stats.mode));
    return 1;
}

fn mode_flags(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    push_mode_flags(lua, stats);
    return 1;
}

fn push_mode_flags(lua: *Lua, stats: std.fs.File.Stat) void {
    if (builtin.os.tag == .windows) {
        var modeString = [10:0]u8{ '-', 'r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x' };

        if (stats.kind == std.fs.File.Kind.directory) {
            modeString[0] = 'd';
        }

        _ = lua.pushString(&modeString);
    } else {
        var modeString = [10:0]u8{ '-', '-', '-', '-', '-', '-', '-', '-', '-', '-' };
        const modeFlags = "drwxrwxrwx";

        if (stats.kind == std.fs.File.Kind.directory) {
            modeString[0] = 'd';
        }

        var current_flag: u32 = 0b100000000;
        inline for (1..10) |i| {
            if (stats.mode & current_flag == current_flag) {
                modeString[i] = modeFlags[i];
            }
            current_flag = current_flag >> 1;
        }

        _ = lua.pushString(&modeString);
    }
}

fn size_hr(lua: *Lua) i32 {
    luax.pushRegistryFunction(lua, zli_filesystem, "size_hr");
    _ = size(lua);
    lua.call(1, 1);
    return 1;
}

fn rename(lua: *Lua) i32 {
    const old = get_path_arg(lua, 1);
    const new = get_path_arg(lua, 2);
    std.fs.cwd().rename(old, new) catch luax.raiseError(lua, "could not rename");
    return 0;
}

fn get_path_arg(lua: *Lua, idx: i32) [:0]const u8 {
    const luaType = lua.typeOf(idx);
    if (luaType == .table) {
        return luax.getTableString(lua, "full_path", idx);
    } else if (luaType == .string) {
        const value = lua.toString(idx) catch luax.raiseError(lua, "get_path: internal error");
        return std.mem.sliceTo(value, 0);
    }
    lua.argError(idx, "expected string representing a path or a path object");
}

fn delete(lua: *Lua) i32 {
    const path = get_path(lua);
    const stats = get_stat(lua, path);
    if (stats.kind == std.fs.File.Kind.file) {
        std.fs.cwd().deleteFile(path) catch luax.raiseError(lua, "Could not delete file");
    } else {
        std.fs.cwd().deleteDir(path) catch luax.raiseError(lua, "Could not delete direcory");
    }
    return 0;
}

fn delete_tree(lua: *Lua) i32 {
    luax.pushRegistryFunction(lua, zli_filesystem, "delete_tree");
    lua.pushValue(1);
    lua.call(1, 0);
    return 0;
}

fn read_all(lua: *Lua) i32 {
    luax.pushRegistryFunction(lua, zli_filesystem, "read_all");
    lua.pushValue(1);
    lua.call(1, 2);
    return 2;
}

fn lines(lua: *Lua) i32 {
    const args = lua.getTop();
    luax.pushRegistryFunction(lua, zli_filesystem, "lines");
    lua.pushValue(1);
    if (args == 2) {
        lua.pushValue(2);
    }
    lua.call(args, 4);
    return 4;
}

fn read_lines(lua: *Lua) i32 {
    const args = lua.getTop();
    luax.pushRegistryFunction(lua, zli_filesystem, "read_lines");
    lua.pushValue(1);
    if (args == 2) {
        lua.pushValue(2);
    }
    lua.call(args, 2);
    return 2;
}

fn open(lua: *Lua) i32 {
    const args = lua.getTop();
    const path = get_path(lua);

    luax.pushLibraryFunction(lua, "io", "open");
    _ = lua.pushString(path);
    if (args == 2) {
        lua.pushValue(2);
    }

    lua.call(args, 2);
    return 2;
}

fn exists(lua: *Lua) i32 {
    const path = get_path(lua);
    const file = open_file_or_directory(fs.cwd(), path) catch {
        lua.pushBoolean(false);
        return 1;
    };
    file.close();
    lua.pushBoolean(true);
    return 1;
}

fn absolute(lua: *Lua) i32 {
    const path = get_path(lua);
    const realPath = fs.cwd().realpathAlloc(allocator, std.mem.sliceTo(path, 0)) catch {
        lua.pushNil();
        return 1;
    };
    defer allocator.free(realPath);
    _ = lua.pushString(pathToString(realPath));
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
        .handle = try std.os.openat(dire.fd, path, std.os.O.RDONLY, 0),
        .capable_io_mode = std.io.default_mode,
        .intended_io_mode = .blocking,
    };
}
