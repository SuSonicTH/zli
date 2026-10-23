const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");

const allocator = std.heap.c_allocator;

const c = @import("c");

const filesystem = @import("filesystem.zig");

const zip = [_]zlua.FnReg{
    .{ .name = "create", .func = luaerror.wrap(ZipUdata.create) },
    .{ .name = "open", .func = luaerror.wrap(ZipUdata.open) },
    .{ .name = "create_after", .func = luaerror.wrap(ZipUdata.create_after) },
};

const zli_zip = "zli_zip";

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

pub fn register(lua: *Lua) i32 {
    ZipUdata.register(lua);
    lua.newLib(&zip);

    const exteded = @embedFile("zip.lua");
    luax.registerExtended(lua, exteded, "zip", zli_zip);
    return 1;
}

const ZipUdata = struct {
    zfh: ?*anyopaque = undefined,
    path: [:0]u8,
    const name = "_ZipUdata";

    const functions = [_]zlua.FnReg{
        .{ .name = "add_file", .func = luaerror.wrap(add_file) },
        .{ .name = "create_directory", .func = luaerror.wrap(create_directory) },
        .{ .name = "mkdir", .func = luaerror.wrap(create_directory) },
        .{ .name = "open", .func = luaerror.wrap(open) },
        .{ .name = "write", .func = luaerror.wrap(write) },
        .{ .name = "close", .func = luaerror.wrap(close) },
        .{ .name = "close_zip", .func = luaerror.wrap(close_zip) },
    };

    fn register(lua: *Lua) void {
        if (lua.getMetatableRegistry(name) == .nil) {
            lua.pop(1);
            luax.registerUserData(lua, name, zlua.wrap(garbageCollect));
        } else {
            lua.pop(1);
        }
    }

    fn garbageCollect(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getGcUserData(lua, ZipUdata);
        if (ud.zfh != null) {
            _ = c.zipCloseFileInZip(ud.zfh);
            _ = c.zipClose(ud.zfh, null);
            ud.zfh = null;
        }
        allocator.free(ud.path);
        return 0;
    }

    fn create(lua: *Lua) !i32 {
        return create_or_open_zip(lua, c.APPEND_STATUS_CREATE);
    }

    fn open_zip(lua: *Lua) !i32 {
        return create_or_open_zip(lua, c.APPEND_STATUS_ADDINZIP);
    }

    fn create_after(lua: *Lua) !i32 {
        return create_or_open_zip(lua, c.APPEND_STATUS_CREATEAFTER);
    }

    fn create_or_open_zip(lua: *Lua, mode: c_int) !i32 {
        const path = try filesystem.get_path(lua);
        const zfh = c.zipOpen(path.ptr, mode) orelse return luaerror.ret(lua, "could not create zip file '{s}'", .{path});
        const owned_path = try allocator.dupeSentinel(u8, std.mem.sliceTo(path, 0), 0);

        const ud: *ZipUdata = luax.createUserDataTableSetFunctions(lua, name, ZipUdata, &functions, 0);
        ud.path = owned_path;
        ud.zfh = zfh;

        luax.setTableRegistryFunction(lua, -1, "add_directory", zli_zip, "add_directory");
        return 1;
    }

    fn add_file(lua: *Lua) !i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        if (ud.zfh == null) return luaerror.ret(lua, "zip archive is closed", .{});
        const source_name = try filesystem.get_path_index(lua, 2);
        const destination_name = try filesystem.get_path_index(lua, 3);
        const level = lua.optInteger(4) orelse 6;
        if (level < 0 or level > 9) {
            return luaerror.ret(lua, "zip compression level must be between 0 and 9", .{});
        }
        const compression: i32 = @intCast(level);
        var comment: ?[*:0]const u8 = null;

        if (lua.typeOf(5) == .string) {
            comment = lua.toString(5) catch null;
        }

        _ = c.zipCloseFileInZip(ud.zfh);

        const file = std.Io.Dir.cwd().openFile(io, source_name, .{}) catch return luaerror.ret(lua, "could not open input file '{s}'", .{source_name});
        defer file.close(io);

        var zfi: c.zip_fileinfo = undefined;
        c.filetime_to_ziptime(source_name.ptr, &zfi);

        if (c.zipOpenNewFileInZip(ud.zfh, destination_name, &zfi, null, 0, null, 0, comment, c.Z_DEFLATED, compression) != c.ZIP_OK) {
            return luaerror.raise(error.CouldNotCreateFileInZip, "could not create file '{s}' in zip", .{destination_name});
        }
        defer _ = c.zipCloseFileInZip(ud.zfh);

        var buffer: [4096]u8 = undefined;
        var streaming_reader = file.readerStreaming(io, &buffer);
        const reader = &streaming_reader.interface;
        var data: [4096]u8 = undefined;
        while (true) {
            const size = reader.readSliceShort(&data) catch
                return luaerror.ret(lua, "could not read from file '{s}'", .{source_name});
            if (size == 0) break;
            if (c.zipWriteInFileInZip(ud.zfh, &data, @intCast(size)) != c.ZIP_OK) {
                return luaerror.ret(lua, "could not write '{s}' to zip", .{source_name});
            }
        }
        lua.pushBoolean(true);
        return 1;
    }

    fn create_directory(lua: *Lua) !i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        if (ud.zfh == null) return luaerror.ret(lua, "zip archive is closed", .{});
        var path = lua.checkString(2);
        var with_slash: ?[:0]u8 = null;
        defer if (with_slash) |s| allocator.free(s);

        // ZIP directory entries have to end with a separator.
        if (path.len == 0 or (path[path.len - 1] != '/' and path[path.len - 1] != '\\')) {
            with_slash = std.fmt.allocPrintSentinel(allocator, "{s}/", .{path}, 0) catch
                return luaerror.ret(lua, "out of memory", .{});
            path = with_slash.?;
        }

        _ = c.zipCloseFileInZip(ud.zfh);

        var zfi: c.zip_fileinfo = undefined;
        c.systemtime_to_ziptime(&zfi);

        if (c.zipOpenNewFileInZip(ud.zfh, path, &zfi, null, 0, null, 0, null, c.Z_DEFLATED, 6) != c.ZIP_OK) {
            return luaerror.ret(lua, "could not create directory '{s}' in zip", .{path});
        }
        _ = c.zipCloseFileInZip(ud.zfh);

        return 0;
    }

    fn open(lua: *Lua) !i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        if (ud.zfh == null) return luaerror.ret(lua, "zip archive is closed", .{});
        const path = lua.checkString(2);
        const level = lua.optInteger(3) orelse 6;
        if (level < 0 or level > 9) {
            return luaerror.ret(lua, "zip compression level must be between 0 and 9", .{});
        }
        const compression: i32 = @intCast(level);
        var comment: ?[*:0]const u8 = null;

        if (lua.typeOf(4) == .string) {
            comment = lua.toString(4) catch null;
        }

        _ = c.zipCloseFileInZip(ud.zfh);

        var zfi: c.zip_fileinfo = undefined;
        c.systemtime_to_ziptime(&zfi);

        if (c.zipOpenNewFileInZip(ud.zfh, path, &zfi, null, 0, null, 0, comment, c.Z_DEFLATED, compression) != c.ZIP_OK) {
            return luaerror.ret(lua, "could not open file '{s}' in zip", .{path});
        }

        lua.pushValue(1);
        return 1;
    }

    fn write(lua: *Lua) !i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        if (ud.zfh == null) return luaerror.ret(lua, "zip archive is closed", .{});
        const top = lua.getTop();
        var argument: i32 = 2;

        while (argument <= top) : (argument += 1) {
            const data = lua.toString(argument) catch lua.argError(argument, "expecting string or number");
            if (c.zipWriteInFileInZip(ud.zfh, data.ptr, @intCast(data.len)) != c.ZIP_OK) {
                return luaerror.ret(lua, "could not write to zip file '{s}'", .{ud.path});
            }
        }

        lua.pushValue(1);
        return 1;
    }

    fn close(lua: *Lua) !i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        if (ud.zfh == null) return luaerror.ret(lua, "zip archive is closed", .{});
        _ = c.zipCloseFileInZip(ud.zfh);

        lua.pushValue(1);
        return 1;
    }

    fn close_zip(lua: *Lua) !i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        var comment: ?[*:0]const u8 = null;

        if (lua.typeOf(2) == .string) {
            comment = lua.toString(2) catch null;
        }

        if (ud.zfh != null) {
            _ = c.zipCloseFileInZip(ud.zfh);
            if (c.zipClose(ud.zfh, comment) != c.ZIP_OK) {
                ud.zfh = null;
                return luaerror.ret(lua, "could not close zip file '{s}'", .{ud.path});
            }
            ud.zfh = null;
        }
        return 0;
    }
};
