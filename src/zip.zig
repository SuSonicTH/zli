const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const luax = @import("luax.zig");

const allocator = std.heap.c_allocator;

const c = @cImport({
    @cInclude("zip.h");
    @cInclude("zip_util.h");
});

const filesystem = @import("filesystem.zig");

const zip = [_]ziglua.FnReg{
    .{ .name = "create", .func = ziglua.wrap(ZipUdata.create) },
    .{ .name = "open", .func = ziglua.wrap(ZipUdata.open) },
    .{ .name = "create_after", .func = ziglua.wrap(ZipUdata.create_after) },
};

const zli_zip = "zli_zip";

pub export fn luaopen_zip(state: ?*ziglua.LuaState) callconv(.C) c_int {
    var lua: Lua = .{ .state = state.? };
    ZipUdata.register(&lua);
    lua.newLib(&zip);

    const exteded = @embedFile("stripped/zip.lua");
    luax.registerExtended(&lua, exteded, "zip", zli_zip);
    return 1;
}

const ZipUdata = struct {
    zfh: ?*anyopaque = undefined,
    path: [:0]const u8,
    const name = "_ZipUdata";

    const functions = [_]ziglua.FnReg{
        .{ .name = "add_file", .func = ziglua.wrap(add_file) },
        .{ .name = "create_directory", .func = ziglua.wrap(create_directory) },
        .{ .name = "mkdir", .func = ziglua.wrap(create_directory) },
        .{ .name = "open", .func = ziglua.wrap(open) },
        .{ .name = "write", .func = ziglua.wrap(write) },
        .{ .name = "close", .func = ziglua.wrap(close) },
        .{ .name = "close_zip", .func = ziglua.wrap(close_zip) },
    };

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, ziglua.wrap(garbageCollect));
    }

    fn garbageCollect(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getGcUserData(lua, ZipUdata);
        if (ud.zfh != null) {
            _ = c.zipCloseFileInZip(ud.zfh);
            _ = c.zipClose(ud.zfh, null);
        }
        return 0;
    }

    fn create(lua: *Lua) i32 {
        return create_or_open_zip(lua, c.APPEND_STATUS_CREATE);
    }

    fn open_zip(lua: *Lua) i32 {
        return create_or_open_zip(lua, c.APPEND_STATUS_ADDINZIP);
    }

    fn create_after(lua: *Lua) i32 {
        return create_or_open_zip(lua, c.APPEND_STATUS_CREATEAFTER);
    }

    fn create_or_open_zip(lua: *Lua, mode: c_int) i32 {
        const path = filesystem.get_path(lua);
        const zfh = c.zipOpen(path.ptr, mode) orelse return luax.returnFormattedError(lua, "could not create zip file '%s'", .{path.ptr});

        const ud: *ZipUdata = luax.createUserDataTableSetFunctions(lua, name, ZipUdata, &functions);
        luax.setTableRegistryFunction(lua, -1, "add_directory", zli_zip, "add_directory");

        ud.path = path;
        ud.zfh = zfh;
        return 1;
    }

    fn add_file(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        const source_name = filesystem.get_path_index(lua, 2);
        const destination_name = filesystem.get_path_index(lua, 3);
        const compression: i32 = @intCast(lua.optInteger(4, 6));
        var comment: ?[*:0]const u8 = null;

        if (lua.typeOf(5) == .string) {
            comment = lua.toString(5) catch unreachable;
        }

        _ = c.zipCloseFileInZip(ud.zfh);

        const file = fs.cwd().openFile(source_name, .{}) catch return luax.returnFormattedError(lua, "could not open input file '%s'", .{source_name.ptr});
        defer file.close();

        var zfi: c.zip_fileinfo = undefined;
        c.filetime_to_ziptime(source_name.ptr, &zfi);

        if (c.zipOpenNewFileInZip(ud.zfh, destination_name, &zfi, null, 0, null, 0, comment, c.Z_DEFLATED, compression) != c.ZIP_OK) {
            luax.raiseFormattedError(lua, "could not create file '%s' in zip ", .{destination_name.ptr});
        }
        defer _ = c.zipCloseFileInZip(ud.zfh);

        var buffer: [4096]u8 = undefined;
        while (true) {
            const size = file.readAll(&buffer) catch luax.raiseFormattedError(lua, "could not read from file '%s'", .{source_name.ptr});
            if (size > 0) {
                _ = c.zipWriteInFileInZip(ud.zfh, &buffer, @intCast(size));
            }
            if (size == 0 or size < buffer.len) {
                break;
            }
        }
        lua.pushBoolean(true);
        return 1;
    }

    fn create_directory(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        const path = lua.toString(2) catch unreachable;
        _ = c.zipCloseFileInZip(ud.zfh);

        var zfi: c.zip_fileinfo = undefined;
        c.systemtime_to_ziptime(&zfi);

        if (c.zipOpenNewFileInZip(ud.zfh, path, &zfi, null, 0, null, 0, path, c.Z_DEFLATED, 6) != c.ZIP_OK) {
            luax.raiseFormattedError(lua, "could not create directory '%s' in zip ", .{path});
        }
        _ = c.zipCloseFileInZip(ud.zfh);

        return 0;
    }

    fn open(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        const path = lua.toString(2) catch unreachable;
        const compression: i32 = @intCast(lua.optInteger(3, 6));
        var comment: ?[*:0]const u8 = null;

        if (lua.typeOf(4) == .string) {
            comment = lua.toString(4) catch unreachable;
        }

        _ = c.zipCloseFileInZip(ud.zfh);

        var zfi: c.zip_fileinfo = undefined;
        c.systemtime_to_ziptime(&zfi);

        if (c.zipOpenNewFileInZip(ud.zfh, path, &zfi, null, 0, null, 0, path, c.Z_DEFLATED, compression) != c.ZIP_OK) {
            luax.raiseFormattedError(lua, "could not create directory '%s' in zip ", .{path});
        }

        lua.pushValue(1);
        return 1;
    }

    fn write(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        const top = lua.getTop();
        var argument: i32 = 2;

        while (argument <= top) : (argument += 1) {
            const data = lua.toBytes(argument) catch lua.argError(argument, "expecting string or number");
            std.log.debug("writing arg {d} '{?s}'", .{ argument, data });
            _ = c.zipWriteInFileInZip(ud.zfh, data.ptr, @intCast(data.len));
        }

        lua.pushValue(1);
        return 1;
    }

    fn close(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        _ = c.zipCloseFileInZip(ud.zfh);

        lua.pushValue(1);
        return 1;
    }

    fn close_zip(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        var comment: ?[*:0]const u8 = null;

        if (lua.typeOf(4) == .string) {
            comment = lua.toString(4) catch unreachable;
        }

        if (ud.zfh != null) {
            _ = c.zipCloseFileInZip(ud.zfh);
            _ = c.zipClose(ud.zfh, comment);
            ud.zfh = null;
        }
        return 0;
    }
};
