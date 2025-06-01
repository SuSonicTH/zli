const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");

const allocator = std.heap.c_allocator;

const filesystem = [_]zlua.FnReg{
    .{ .name = "cwd", .func = zlua.wrap(current_directory) },
    .{ .name = "current_directory", .func = zlua.wrap(current_directory) },

    .{ .name = "create_path", .func = zlua.wrap(create_path) },
    .{ .name = "absolute", .func = zlua.wrap(absolute) },
    .{ .name = "size_to_hr", .func = zlua.wrap(size_to_hr) },
};

const filesystem_path = [_]zlua.FnReg{
    .{ .name = "dir", .func = zlua.wrap(dir) },
    .{ .name = "list", .func = zlua.wrap(list) },
    .{ .name = "stat", .func = zlua.wrap(stat) },
    .{ .name = "is_file", .func = zlua.wrap(is_file) },
    .{ .name = "is_directory", .func = zlua.wrap(is_directory) },
    .{ .name = "size", .func = zlua.wrap(size) },
    .{ .name = "size_hr", .func = zlua.wrap(size_hr) },
    .{ .name = "access_time", .func = zlua.wrap(access_time) },
    .{ .name = "create_time", .func = zlua.wrap(create_time) },
    .{ .name = "modify_time", .func = zlua.wrap(modify_time) },
    .{ .name = "access_time_ms", .func = zlua.wrap(access_time_ms) },
    .{ .name = "create_time_ms", .func = zlua.wrap(create_time_ms) },
    .{ .name = "modify_time_ms", .func = zlua.wrap(modify_time_ms) },
    .{ .name = "access_time_stamp", .func = zlua.wrap(access_time_stamp) },
    .{ .name = "create_time_stamp", .func = zlua.wrap(create_time_stamp) },
    .{ .name = "modify_time_stamp", .func = zlua.wrap(modify_time_stamp) },
    .{ .name = "mode", .func = zlua.wrap(mode) },
    .{ .name = "mode_flags", .func = zlua.wrap(mode_flags) },
    .{ .name = "open", .func = zlua.wrap(open) },
    .{ .name = "exists", .func = zlua.wrap(exists) },

    .{ .name = "rename", .func = zlua.wrap(rename) },
    .{ .name = "mv", .func = zlua.wrap(rename) },

    .{ .name = "delete", .func = zlua.wrap(delete) },
    .{ .name = "rm", .func = zlua.wrap(delete) },

    .{ .name = "change_directory", .func = zlua.wrap(change_directory) },
    .{ .name = "cd", .func = zlua.wrap(change_directory) },

    .{ .name = "create_directory", .func = zlua.wrap(create_directory) },
    .{ .name = "mkdir", .func = zlua.wrap(create_directory) },
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

pub fn luaopen_filesystem(lua: *Lua) i32 {
    lua.newLib(&filesystem);
    lua.setFuncs(&filesystem_path, 0);
    _ = lua.pushString("separator");
    _ = lua.pushString(separator_string);
    lua.setTable(-3);

    register_path_mt(lua);
    luax.registerExtended(lua, @embedFile("stripped/filesystem.lua"), "filesytem", zli_filesystem);
    return 1;
}

fn register_path_mt(lua: *Lua) void {
    lua.newMetatable(zli_mt_path) catch luax.raiseError(lua, "register_path_mt internal error: could not crete metatable");
    _ = lua.pushString("__tostring");
    lua.pushFunction(zlua.wrap(path__tostring));
    lua.setTable(-3);
    lua.pop(1);
}

var path_buffer: [fs.max_path_bytes]u8 = undefined;

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
    const realPath = fs.cwd().realpathAlloc(allocator, path) catch luax.raiseFormattedError(lua, "path '%s' does not exist", .{path.ptr});
    defer allocator.free(realPath);
    return pathToString(realPath);
}

fn list(lua: *Lua) i32 {
    return list_dir(lua, false);
}

fn dir(lua: *Lua) i32 {
    return list_dir(lua, true);
}

fn list_dir(lua: *Lua, keyValue: bool) i32 {
    var path: [:0]const u8 = undefined;
    if (lua.getTop() >= 1) {
        path = get_path(lua);
    } else {
        path = "./";
    }
    var directory = std.fs.cwd().openDir(path, .{ .iterate = true }) catch luax.raiseFormattedError(lua, "could not open directory '%s'", .{path.ptr});
    defer directory.close();

    const fullPath = lua.pushString(getRealPath(lua, std.mem.sliceTo(path, 0)));

    lua.newTable();
    const table = lua.getTop();
    var iterator = directory.iterate();
    if (keyValue) {
        while (iterator.next() catch luax.raiseFormattedError(lua, "could not traverse directory '%s'", .{path.ptr})) |entry| {
            const name = lua.pushString(pathToString(entry.name));
            create_path_sub(lua, fullPath, name);
            lua.setTable(table);
        }
    } else {
        var index: i32 = 1;
        while (iterator.next() catch luax.raiseFormattedError(lua, "could not traverse directory '%s'", .{path.ptr})) |entry| {
            const name = pathToString(entry.name);
            create_path_sub(lua, fullPath, name);
            lua.rawSetIndex(table, index);
            index += 1;
        }
    }
    return 1;
}

fn create_path(lua: *Lua) i32 {
    const path = std.mem.sliceTo(lua.checkString(1), 0);
    const name = std.mem.sliceTo(lua.checkString(2), 0);
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

    const fullpath = full_path(path, name) catch memoryError(lua);
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

fn memoryError(lua: *Lua) noreturn {
    luax.raiseError(lua, "could not allocate memory");
}

fn current_directory(lua: *Lua) i32 {
    _ = lua.pushString(getRealPath(lua, "."));
    return 1;
}

fn get_stat(lua: *Lua, fullpath: [:0]const u8) std.fs.File.Stat {
    const file = std.fs.cwd().openFile(fullpath, .{}) catch {
        var directory = std.fs.cwd().openDir(fullpath, .{}) catch luax.raiseFormattedError(lua, "Could not get stats for '%s", .{fullpath.ptr});
        defer directory.close();
        return directory.stat() catch luax.raiseFormattedError(lua, "Could not get directory stats for '%s'", .{fullpath.ptr});
    };
    defer file.close();
    return file.stat() catch luax.raiseFormattedError(lua, "Could not get file stats for '%s'", .{fullpath.ptr});
}

const SECONDS_DENOMINATOR = 1000000000;
const MILLISECONDS_DENOMINATOR = 1000000;
const TIMESTAMP_FORMAT = "%Y/%m/%d %H:%M:%S";

fn stat(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));

    lua.newTable();
    const table = lua.getTop();
    luax.setTableBoolean(lua, table, "is_directory", stats.kind == std.fs.File.Kind.directory);
    luax.setTableBoolean(lua, table, "is_file", stats.kind == std.fs.File.Kind.file);

    luax.setTableInteger(lua, table, "size", @intCast(stats.size));
    luax.setTableString(lua, table, "size_hr", size_human_readable(stats.size) catch luax.raiseError(lua, "internal error: could not format human readable size"));

    luax.setTableInteger(lua, table, "access_time", @intCast(@divTrunc(stats.atime, SECONDS_DENOMINATOR)));
    luax.setTableInteger(lua, table, "create_time", @intCast(@divTrunc(stats.ctime, SECONDS_DENOMINATOR)));
    luax.setTableInteger(lua, table, "modify_time", @intCast(@divTrunc(stats.mtime, SECONDS_DENOMINATOR)));

    luax.setTableInteger(lua, table, "access_time_ms", @intCast(@divTrunc(stats.atime, MILLISECONDS_DENOMINATOR)));
    luax.setTableInteger(lua, table, "create_time_ms", @intCast(@divTrunc(stats.ctime, MILLISECONDS_DENOMINATOR)));
    luax.setTableInteger(lua, table, "modify_time_ms", @intCast(@divTrunc(stats.mtime, MILLISECONDS_DENOMINATOR)));

    _ = lua.pushString("access_time_stamp");
    push_time_stamp(lua, stats.atime);
    lua.setTable(table);

    _ = lua.pushString("create_time_stamp");
    push_time_stamp(lua, stats.ctime);
    lua.setTable(table);

    _ = lua.pushString("modify_time_stamp");
    push_time_stamp(lua, stats.mtime);
    lua.setTable(table);

    luax.setTableInteger(lua, table, "mode", @intCast(stats.mode));

    _ = lua.pushString("mode_flags");
    push_mode_flags(lua, stats);
    lua.setTable(table);

    return 1;
}

pub fn get_path(lua: *Lua) [:0]const u8 {
    return get_path_index(lua, 1);
}

pub fn get_path_index(lua: *Lua, index: i32) [:0]const u8 {
    const luaType = lua.typeOf(index);
    if (luaType == .table) {
        return luax.getTableString(lua, "full_path", index);
    } else if (luaType == .string) {
        const path = lua.toString(index) catch luax.raiseError(lua, "get_path: internal error");
        return std.mem.sliceTo(path, 0);
    }
    lua.argError(index, "expected string representing a path or a path object");
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
    lua.call(.{ .args = 2, .results = 1 });
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

var size_hr_buffer: [20:0]u8 = undefined;

const KB = 1024;
const MB = KB * 1024;
const GB = MB * 1024;
const TB = GB * 1024;

pub fn size_human_readable(file_size: u64) ![:0]u8 {
    const float_size = @as(f64, @floatFromInt(file_size));
    if (file_size >= TB) {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d:0>1.2} TB", .{float_size / @as(f64, @floatFromInt(TB))});
    } else if (file_size >= GB) {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d:0>1.2} GB", .{float_size / @as(f64, @floatFromInt(GB))});
    } else if (file_size >= MB) {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d:0>1.2} MB", .{float_size / @as(f64, @floatFromInt(MB))});
    } else if (file_size >= KB) {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d:0>1.2} KB", .{float_size / @as(f64, @floatFromInt(KB))});
    } else {
        return std.fmt.bufPrintZ(&size_hr_buffer, "{d} B", .{@as(u64, @intCast(file_size))});
    }
}

fn size_to_hr(lua: *Lua) i32 {
    const size_b = lua.toNumber(1) catch luax.raiseError(lua, "internal error: could not format human readable size");
    const sizehr = size_human_readable(@as(u64, @intFromFloat(size_b))) catch luax.raiseError(lua, "internal error: could not format human readable size");
    _ = lua.pushString(sizehr);
    return 1;
}

fn size_hr(lua: *Lua) i32 {
    const stats = get_stat(lua, get_path(lua));
    _ = lua.pushString(size_human_readable(stats.size) catch luax.raiseError(lua, "internal error: could not format human readable size"));
    return 1;
}

fn rename(lua: *Lua) i32 {
    const old = get_path_arg(lua, 1);
    const new = get_path_arg(lua, 2);
    std.fs.cwd().rename(old, new) catch luax.raiseFormattedError(lua, "could not rename '%s' to '%s'", .{ old.ptr, new.ptr });
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
        std.fs.cwd().deleteFile(path) catch luax.raiseFormattedError(lua, "Could not delete file '%s'", .{path.ptr});
    } else {
        std.fs.cwd().deleteDir(path) catch luax.raiseFormattedError(lua, "Could not delete direcory '%s'", .{path.ptr});
    }
    return 0;
}

fn open(lua: *Lua) i32 {
    const args = lua.getTop();
    const path = get_path(lua);

    luax.pushLibraryFunction(lua, "io", "open");
    _ = lua.pushString(path);
    if (args == 2) {
        lua.pushValue(2);
    }

    lua.call(.{ .args = args, .results = 2 });
    return 2;
}

fn exists(lua: *Lua) i32 {
    const path = get_path(lua);

    const file = std.fs.cwd().openFile(path, .{}) catch {
        var directory = std.fs.cwd().openDir(path, .{}) catch {
            lua.pushBoolean(false);
            return 1;
        };
        defer directory.close();
        lua.pushBoolean(true);
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

fn change_directory(lua: *Lua) i32 {
    const path = get_path(lua);
    var directory = std.fs.cwd().openDir(path, .{}) catch luax.raiseFormattedError(lua, "Could not change directory to '%s", .{path.ptr});
    defer directory.close();
    directory.setAsCwd() catch luax.raiseFormattedError(lua, "Could not change directory to '%s", .{path.ptr});
    return 0;
}

fn create_directory(lua: *Lua) i32 {
    const path = get_path(lua);
    std.fs.cwd().makeDir(path) catch luax.raiseFormattedError(lua, "Could not create directory '%s", .{path.ptr});
    return 0;
}
