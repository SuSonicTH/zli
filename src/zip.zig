const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const luax = @import("luax.zig");

const allocator = std.heap.c_allocator;

const c = @cImport({
    @cInclude("zip.h");
});

const filesystem = @import("filesystem.zig");

const zip = [_]ziglua.FnReg{
    .{ .name = "create", .func = ziglua.wrap(ZipUdata.create) },
};

//const zli_unzip = "zli_unzip";

pub export fn luaopen_zip(state: ?*ziglua.LuaState) callconv(.C) c_int {
    var lua: Lua = .{ .state = state.? };
    ZipUdata.register(&lua);
    lua.newLib(&zip);

    //    const exteded = @embedFile("stripped/unzip.lua");
    //    luax.registerExtended(&lua, exteded, "zip", zli_unzip);
    return 1;
}

const ZipUdata = struct {
    zfh: *anyopaque = undefined,
    path: [:0]const u8,
    const name = "_ZipUdata";
    const functions = [_]ziglua.FnReg{
        .{ .name = "add_file", .func = ziglua.wrap(add_file) },
    };

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, ziglua.wrap(garbageCollect));
    }

    fn garbageCollect(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getGcUserData(lua, ZipUdata);
        _ = c.zipCloseFileInZip(ud.zfh);
        _ = c.zipClose(ud.zfh, null);
        return 0;
    }

    fn create(lua: *Lua) i32 {
        const path = filesystem.get_path(lua);
        const zfh = c.zipOpen(path.ptr, c.APPEND_STATUS_CREATE) orelse return luax.returnFormattedError(lua, "could not create zip file '%s'", .{path.ptr});

        const ud: *ZipUdata = luax.createUserDataTableSetFunctions(lua, name, ZipUdata, &functions);

        ud.path = path;
        ud.zfh = zfh;
        return 1;
    }

    fn add_file(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        const source_name = filesystem.get_path_index(lua, 2);
        const destination_name = filesystem.get_path_index(lua, 3);

        _ = c.zipCloseFileInZip(ud.zfh);

        const file = fs.cwd().openFile(source_name, .{}) catch return luax.returnFormattedError(lua, "could not open input file '%s'", .{source_name.ptr});
        defer file.close();

        const comment: ?[*:0]const u8 = null;
        const compression: i32 = 0;

        //var s: c.struct_stat = undefined;
        //_ = c.stat(source_name, &s);
        //        const tm: c.tm = c.localtime(s.st_mtime);
        //
        //        var zfi: c.zip_fileinfo = .{
        //            .tmz_date = .{
        //                .tm_sec = tm.tm_sec,
        //                .tm_min = tm.tm_min,
        //                .tm_hour = tm.tm_hour,
        //                .tm_mday = tm.tm_mday,
        //                .tm_mon = tm.tm_mon,
        //                .tm_year = tm.tm_year,

        var zfi: c.zip_fileinfo = .{
            .tmz_date = .{
                .tm_sec = 31,
                .tm_min = 10,
                .tm_hour = 12,
                .tm_mday = 2,
                .tm_mon = 3,
                .tm_year = 1980,
            },
            .dosDate = 0,
            .internal_fa = 0,
            .external_fa = 0,
        };

        if (c.zipOpenNewFileInZip(ud.zfh, destination_name, &zfi, null, 0, null, 0, comment, c.Z_DEFLATED, compression) != c.ZIP_OK) {
            luax.raiseFormattedError(lua, "could not create file in zip '%s", .{destination_name.ptr});
        }
        defer _ = c.zipCloseFileInZip(ud.zfh);

        var buffer: [4096]u8 = undefined;
        while (true) {
            const size = file.readAll(&buffer) catch luax.raiseFormattedError(lua, "could not read from file '%s", .{source_name.ptr});
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
};