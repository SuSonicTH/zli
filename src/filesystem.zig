const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");

const allocator = std.heap.c_allocator;

const filesystem = [_]zlua.FnReg{
    .{ .name = "cwd", .func = luaerror.wrap(current_directory) },
    .{ .name = "current_directory", .func = luaerror.wrap(current_directory) },

    .{ .name = "create_path", .func = luaerror.wrap(create_path) },
    .{ .name = "absolute", .func = luaerror.wrap(absolute) },
    .{ .name = "size_to_hr", .func = luaerror.wrap(size_to_hr) },
    .{ .name = "config", .func = luaerror.wrap(setConfig) },
};

const filesystem_path = [_]zlua.FnReg{
    .{ .name = "dir", .func = luaerror.wrap(dir) },
    .{ .name = "list", .func = luaerror.wrap(list) },
    .{ .name = "stat", .func = luaerror.wrap(stat) },
    .{ .name = "is_file", .func = luaerror.wrap(is_file) },
    .{ .name = "is_directory", .func = luaerror.wrap(is_directory) },
    .{ .name = "size", .func = luaerror.wrap(size) },
    .{ .name = "size_hr", .func = luaerror.wrap(size_hr) },
    .{ .name = "access_time", .func = luaerror.wrap(access_time) },
    .{ .name = "create_time", .func = luaerror.wrap(create_time) },
    .{ .name = "modify_time", .func = luaerror.wrap(modify_time) },
    .{ .name = "access_time_ms", .func = luaerror.wrap(access_time_ms) },
    .{ .name = "create_time_ms", .func = luaerror.wrap(create_time_ms) },
    .{ .name = "modify_time_ms", .func = luaerror.wrap(modify_time_ms) },
    .{ .name = "access_time_stamp", .func = luaerror.wrap(access_time_stamp) },
    .{ .name = "create_time_stamp", .func = luaerror.wrap(create_time_stamp) },
    .{ .name = "modify_time_stamp", .func = luaerror.wrap(modify_time_stamp) },
    .{ .name = "mode", .func = luaerror.wrap(mode) },
    .{ .name = "mode_flags", .func = luaerror.wrap(mode_flags) },
    .{ .name = "open", .func = luaerror.wrap(open) },
    .{ .name = "exists", .func = luaerror.wrap(exists) },

    .{ .name = "rename", .func = luaerror.wrap(rename) },
    .{ .name = "mv", .func = luaerror.wrap(rename) },

    .{ .name = "delete", .func = luaerror.wrap(delete) },
    .{ .name = "rm", .func = luaerror.wrap(delete) },

    .{ .name = "change_directory", .func = luaerror.wrap(change_directory) },
    .{ .name = "cd", .func = luaerror.wrap(change_directory) },

    .{ .name = "create_directory", .func = luaerror.wrap(create_directory) },
    .{ .name = "mkdir", .func = luaerror.wrap(create_directory) },
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
    "stream",
    "stream_tree",
    "tree",
    "to_relative",
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

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

const Config = struct {
    errorHandling: luaerror.Handling = undefined,
};

pub fn register(lua: *Lua) !i32 {
    var config = setup(lua);
    config.errorHandling = luaerror.getGlobalHanding(lua);
    luax.setTableString(lua, -1, "error_handling", @tagName(config.errorHandling));

    if (lua.getMetatableRegistry(zli_mt_path) == .nil) {
        lua.pop(1);
        try register_path_mt(lua);
    } else {
        lua.pop(1);
    }
    return 1;
}

fn setup(lua: *Lua) *Config {
    const config = luax.setupLibrary(lua, &filesystem, Config, "filesystem");
    lua.pushLightUserdata(config);
    lua.setFuncs(&filesystem_path, 1);
    luax.setTableString(lua, -1, "separator", separator_string);
    return config;
}

fn register_path_mt(lua: *Lua) !void {
    lua.newMetatable(zli_mt_path) catch |err|
        return luaerror.raise(err, "register_path_mt internal error, could not crete metatable: {any}", .{err});
    _ = lua.pushString("__tostring");
    lua.pushFunction(zlua.wrap(path__tostring));
    lua.setTable(-3);
    lua.pop(1);
}

pub fn setConfig(lua: *Lua) !i32 {
    luax.isFirstArgLibTableOrError(lua, "expecting filesystem library as 1st argument use \"require('filesystem'):config{}\" syntax");
    lua.argCheck(lua.typeOf(2) == .table, 2, "expecting config table");

    var config = setup(lua);
    if (luax.getTableStringOptional(lua, "error_handling", 2)) |error_handling| {
        config.errorHandling = try luaerror.getHandling(error_handling);
        luax.setTableString(lua, -1, "error_handling", @tagName(config.errorHandling));
    }
    return 1;
}

fn get_error_handling(lua: *Lua) !luaerror.Handling {
    const config = try lua.toUserdata(Config, Lua.upvalueIndex(1));
    return config.errorHandling;
}

var path_buffer: [fs.max_path_bytes]u8 = undefined;

fn path__tostring(lua: *Lua) !i32 {
    const path = get_path(lua) catch |err|
        return luaerror.raiseOrReturnLast(lua, err, try get_error_handling(lua));
    _ = lua.pushString(path);
    return 1;
}

fn pathToString(path: []const u8) [:0]u8 {
    path_buffer[path.len] = 0;
    @memcpy(path_buffer[0..path.len], path);
    return path_buffer[0..path.len :0];
}

fn getRealPath(path: []const u8) ![:0]u8 {
    const realPath = try std.Io.Dir.cwd().realPathFileAlloc(io, path, allocator);
    defer allocator.free(realPath);
    return pathToString(realPath);
}

fn list(lua: *Lua) !i32 {
    return try list_dir(lua, false);
}

fn dir(lua: *Lua) !i32 {
    return try list_dir(lua, true);
}

fn list_dir(lua: *Lua, keyValue: bool) !i32 {
    var path: [:0]const u8 = undefined;
    if (lua.getTop() >= 1) {
        path = get_path(lua) catch |err|
            return luaerror.raiseOrReturnLast(lua, err, try get_error_handling(lua));
    } else {
        path = "./";
    }
    var directory = std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not open directory '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    defer directory.close(io);

    const realPath = getRealPath(std.mem.sliceTo(path, 0)) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not open get real path '{s}': {any}", .{ path, err }, try get_error_handling(lua));

    const fullPath = lua.pushString(realPath);

    lua.newTable();
    const table = lua.getTop();
    var iterator = directory.iterate();
    if (keyValue) {
        while (iterator.next(io) catch |err| {
            return luaerror.raiseOrReturn(lua, err, "could not traverse directory '{s}': {any}", .{ path, err }, try get_error_handling(lua));
        }) |entry| {
            const name = lua.pushString(pathToString(entry.name));
            try create_path_sub(lua, fullPath, name);
            lua.setTable(table);
        }
    } else {
        var index: i32 = 1;
        while (iterator.next(io) catch |err| {
            return luaerror.raiseOrReturn(lua, err, "could not traverse directory '{s}': {any}", .{ path, err }, try get_error_handling(lua));
        }) |entry| {
            const name = pathToString(entry.name);
            try create_path_sub(lua, fullPath, name);
            lua.setIndexRaw(table, index);
            index += 1;
        }
    }
    return 1;
}

fn create_path(lua: *Lua) !i32 {
    const path = std.mem.sliceTo(lua.checkString(1), 0);
    const name = std.mem.sliceTo(lua.checkString(2), 0);
    try create_path_sub(lua, path, name);
    return 1;
}

fn create_path_sub(lua: *Lua, path: [:0]const u8, name: [:0]const u8) !void {
    lua.newTable();
    lua.pushValue(Lua.upvalueIndex(1));
    lua.setFuncs(&filesystem_path, 1);

    luax.setTableRegistryFunctions(lua, zli_filesystem, &filesystem_path_lua);

    _ = lua.getMetatableRegistry(zli_mt_path);
    lua.setMetatable(-2);

    _ = lua.pushString("path");
    _ = lua.pushString(path);
    lua.setTable(-3);

    _ = lua.pushString("name");
    _ = lua.pushString(name);
    lua.setTable(-3);

    const fullpath = full_path(path, name) catch |err|
        return luaerror.raise(err, "could not allocate memory: {any}", .{err});
    defer allocator.free(fullpath);

    _ = lua.pushString("full_path");
    _ = lua.pushString(fullpath);
    lua.setTable(-3);
}

fn full_path(path: [:0]const u8, name: [:0]const u8) ![:0]u8 {
    const len = path.len + separator_string.len + name.len + 1;
    const buffer = try allocator.alloc(u8, len);
    @memcpy(buffer[0..path.len], path);
    @memcpy(buffer[path.len .. path.len + separator_string.len], separator_string);
    @memcpy(buffer[path.len + separator_string.len .. path.len + separator_string.len + name.len], name);
    buffer[len - 1] = 0;
    return buffer[0 .. len - 1 :0];
}

fn current_directory(lua: *Lua) !i32 {
    const realPath = getRealPath(".") catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not open path '.': {any}", .{err}, try get_error_handling(lua));
    _ = lua.pushString(realPath);
    return 1;
}

fn get_stat(fullpath: [:0]const u8) !std.Io.File.Stat {
    const file = std.Io.Dir.cwd().openFile(io, fullpath, .{}) catch {
        var directory = try std.Io.Dir.cwd().openDir(io, fullpath, .{});
        defer directory.close(io);
        return try directory.stat(io);
    };
    defer file.close(io);
    return try file.stat(io);
}

const SECONDS_DENOMINATOR = 1000000000;
const MILLISECONDS_DENOMINATOR = 1000000;
const TIMESTAMP_FORMAT = "%Y/%m/%d %H:%M:%S";

fn stat(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));

    lua.newTable();
    const table = lua.getTop();
    luax.setTableBoolean(lua, table, "is_directory", stats.kind == std.Io.File.Kind.directory);
    luax.setTableBoolean(lua, table, "is_file", stats.kind == std.Io.File.Kind.file);

    luax.setTableInteger(lua, table, "size", @intCast(stats.size));
    luax.setTableString(lua, table, "size_hr", size_human_readable(stats.size) catch |err|
        return luaerror.raise(err, "internal error: could not format human readable size: {any}", .{err}));

    if (stats.atime) |atime| {
        luax.setTableInteger(lua, table, "access_time", atime.toSeconds());
        luax.setTableInteger(lua, table, "access_time_ms", atime.toMilliseconds());
        _ = lua.pushString("access_time_stamp");
        push_time_stamp(lua, atime.toSeconds());
        lua.setTable(table);
    }
    luax.setTableInteger(lua, table, "create_time", stats.ctime.toSeconds());
    luax.setTableInteger(lua, table, "create_time_ms", stats.ctime.toMilliseconds());
    _ = lua.pushString("create_time_stamp");
    push_time_stamp(lua, stats.ctime.toSeconds());
    lua.setTable(table);

    luax.setTableInteger(lua, table, "modify_time", stats.mtime.toSeconds());
    luax.setTableInteger(lua, table, "modify_time_ms", stats.mtime.toMilliseconds());

    _ = lua.pushString("modify_time_stamp");
    push_time_stamp(lua, stats.mtime.toSeconds());
    lua.setTable(table);

    luax.setTableInteger(lua, table, "mode", @intFromEnum(stats.permissions));

    _ = lua.pushString("mode_flags");
    push_mode_flags(lua, stats);
    lua.setTable(table);

    return 1;
}

pub fn get_path(lua: *Lua) ![:0]const u8 {
    return get_path_index(lua, 1);
}

pub fn get_path_index(lua: *Lua, index: i32) ![:0]const u8 {
    const luaType = lua.typeOf(index);
    if (luaType == .table) {
        return luax.getTableString(lua, "full_path", index);
    } else if (luaType == .string) {
        const path = lua.toString(index) catch |err|
            return luaerror.raise(err, "internal error: get_path: {any}", .{err});
        return std.mem.sliceTo(path, 0);
    }
    lua.argError(index, "expected string representing a path or a path object");
}

fn is_directory(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    lua.pushBoolean(stats.kind == std.Io.File.Kind.directory);
    return 1;
}

fn is_file(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    lua.pushBoolean(stats.kind == std.Io.File.Kind.file);
    return 1;
}

fn size(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    lua.pushInteger(@intCast(stats.size));
    return 1;
}

fn access_time(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    if (stats.atime) |atime| {
        lua.pushInteger(atime.toSeconds());
    } else {
        lua.pushNil();
    }
    return 1;
}

fn create_time(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    lua.pushInteger(stats.ctime.toSeconds());
    return 1;
}

fn modify_time(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    lua.pushInteger(stats.mtime.toSeconds());
    return 1;
}

fn access_time_ms(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    if (stats.atime) |atime| {
        lua.pushInteger(atime.toSeconds());
    } else {
        lua.pushNil();
    }
    return 1;
}

fn create_time_ms(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    lua.pushInteger(stats.ctime.toSeconds());
    return 1;
}

fn modify_time_ms(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    lua.pushInteger(stats.mtime.toSeconds());
    return 1;
}

fn access_time_stamp(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    if (stats.atime) |atime| {
        push_time_stamp(lua, atime.toSeconds());
    } else {
        lua.pushNil();
    }
    return 1;
}

fn push_time_stamp(lua: *Lua, time: i64) void {
    luax.pushLibraryFunction(lua, "os", "date");
    _ = lua.pushString(TIMESTAMP_FORMAT);
    lua.pushInteger(time);
    lua.call(.{ .args = 2, .results = 1 });
}

fn create_time_stamp(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    push_time_stamp(lua, stats.ctime.toSeconds());
    return 1;
}

fn modify_time_stamp(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    push_time_stamp(lua, stats.mtime.toSeconds());
    return 1;
}

fn mode(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    lua.pushInteger(@intFromEnum(stats.permissions));
    return 1;
}

fn mode_flags(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    push_mode_flags(lua, stats);
    return 1;
}

fn push_mode_flags(lua: *Lua, stats: std.Io.File.Stat) void {
    if (builtin.os.tag == .windows) {
        var modeString = [10:0]u8{ '-', 'r', 'w', 'x', 'r', 'w', 'x', 'r', 'w', 'x' };

        if (stats.kind == std.Io.File.Kind.directory) {
            modeString[0] = 'd';
        }

        _ = lua.pushString(&modeString);
    } else {
        var modeString = [10:0]u8{ '-', '-', '-', '-', '-', '-', '-', '-', '-', '-' };
        const modeFlags = "drwxrwxrwx";

        if (stats.kind == std.Io.File.Kind.directory) {
            modeString[0] = 'd';
        }

        var current_flag: u32 = 0b100000000;
        const pmode = stats.permissions.toMode();
        inline for (1..10) |i| {
            if (pmode & current_flag == current_flag) {
                modeString[i] = modeFlags[i];
            }
            current_flag = current_flag >> 1;
        }

        _ = lua.pushString(&modeString);
    }
}

var size_hr_buffer: [20:0]u8 = undefined;

const KB = 1024.0;
const MB = KB * 1024.0;
const GB = MB * 1024.0;
const TB = GB * 1024.0;

pub fn size_human_readable(file_size: u64) ![:0]u8 {
    const float_size = @as(f64, @floatFromInt(file_size));
    if (file_size >= TB) {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d:0>1.2} TB", .{float_size / TB});
    } else if (file_size >= GB) {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d:0>1.2} GB", .{float_size / GB});
    } else if (file_size >= MB) {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d:0>1.2} MB", .{float_size / MB});
    } else if (file_size >= KB) {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d:0>1.2} KB", .{float_size / KB});
    } else {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d} B", .{@as(u64, @intCast(file_size))});
    }
}

fn size_to_hr(lua: *Lua) !i32 {
    const size_b = luax.getArgIntegerOrError(lua, 1, "expected integer");
    const sizehr = size_human_readable(@intCast(size_b)) catch |err|
        return luaerror.raise(err, "internal error: could not format human readable size: {any}", .{err});
    _ = lua.pushString(sizehr);
    return 1;
}

fn size_hr(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    const sizeHr = size_human_readable(stats.size) catch |err|
        return luaerror.raise(err, "internal error: could not format human readable size: {any}", .{err});
    _ = lua.pushString(sizeHr);
    return 1;
}

fn rename(lua: *Lua) !i32 {
    const old = try get_path_arg(lua, 1);
    const new = try get_path_arg(lua, 2);
    const cwd = std.Io.Dir.cwd();
    std.Io.Dir.rename(cwd, old, cwd, new, io) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not rename '{s}' to '{s}': {any}", .{ old, new, err }, try get_error_handling(lua));
    return 0;
}

fn get_path_arg(lua: *Lua, idx: i32) ![:0]const u8 {
    const luaType = lua.typeOf(idx);
    if (luaType == .table) {
        return luax.getTableString(lua, "full_path", idx);
    } else if (luaType == .string) {
        const value = lua.toString(idx) catch |err|
            return luaerror.raise(err, "get_path: internal error: {any}", .{err});
        return std.mem.sliceTo(value, 0);
    }
    lua.argError(idx, "expected string representing a path or a path object");
}

fn delete(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const stats = get_stat(path) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not get stats for '{s}': {any}", .{ path, err }, try get_error_handling(lua));

    if (stats.kind == std.Io.File.Kind.file) {
        std.Io.Dir.cwd().deleteFile(io, path) catch |err|
            return luaerror.raiseOrReturn(lua, err, "Could not delete file '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    } else {
        std.Io.Dir.cwd().deleteDir(io, path) catch |err|
            return luaerror.raiseOrReturn(lua, err, "Could not delete direcory '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    }
    return 0;
}

fn open(lua: *Lua) !i32 {
    const args = lua.getTop();
    const path = try get_path(lua);

    luax.pushLibraryFunction(lua, "io", "open");
    _ = lua.pushString(path);
    if (args == 2) {
        lua.pushValue(2);
    }

    lua.call(.{ .args = args, .results = 2 });
    return 2;
}

fn exists(lua: *Lua) !i32 {
    const path = try get_path(lua);

    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch {
        var directory = std.Io.Dir.cwd().openDir(io, path, .{}) catch {
            lua.pushBoolean(false);
            return 1;
        };
        defer directory.close(io);
        lua.pushBoolean(true);
        return 1;
    };
    file.close(io);
    lua.pushBoolean(true);
    return 1;
}

fn absolute(lua: *Lua) !i32 {
    const path = try get_path(lua);
    const realPath = std.Io.Dir.cwd().realPathFileAlloc(io, std.mem.sliceTo(path, 0), allocator) catch {
        lua.pushNil();
        return 1;
    };
    defer allocator.free(realPath);
    _ = lua.pushString(pathToString(realPath));
    return 1;
}

fn change_directory(lua: *Lua) !i32 {
    const path = try get_path(lua);
    var directory = std.Io.Dir.cwd().openDir(io, path, .{}) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not change direcory to '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    defer directory.close(io);
    std.process.setCurrentDir(io, directory) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not change direcory to '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    return 0;
}

fn create_directory(lua: *Lua) !i32 {
    const path = try get_path(lua);
    std.Io.Dir.cwd().createDir(io, path, std.Io.File.Permissions.default_dir) catch |err|
        return luaerror.raiseOrReturn(lua, err, "Could not create directory '{s}': {any}", .{ path, err }, try get_error_handling(lua));
    return 0;
}
