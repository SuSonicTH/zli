const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const luax = @import("luax.zig");

const allocator = std.heap.c_allocator;

const c = @cImport({
    @cInclude("unzip.h");
    @cInclude("zip.h");
});

const filesystem = @import("filesystem.zig");

const lzip = [_]ziglua.FnReg{
    .{ .name = "open", .func = ziglua.wrap(UnzipUdata.new) },
};

pub export fn luaopen_lzip(state: ?*ziglua.LuaState) callconv(.C) c_int {
    var lua: Lua = .{ .state = state.? };
    UnzipUdata.register(&lua);
    lua.newLib(&lzip);
    return 1;
}

const UnzipUdata = struct {
    uzfh: *anyopaque,
    const name = "_UnzipUdata";
    const functions = [_]ziglua.FnReg{
        .{ .name = "read_all", .func = ziglua.wrap(read_all) },
    };

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, ziglua.wrap(garbageCollect));
    }

    fn garbageCollect(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getGcUserData(lua, UnzipUdata);
        _ = c.unzClose(ud.uzfh);
        return 0;
    }

    fn new(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.createUserDataTableSetFunctions(lua, name, UnzipUdata, &functions);
        const table = lua.getTop();

        const path = filesystem.get_path(lua);
        ud.uzfh = c.unzOpen64(path.ptr) orelse return luax.returnError(lua, "could not open zip file");

        var uzgi: c.unz_global_info = undefined;
        if (c.unzGetGlobalInfo(ud.uzfh, &uzgi) != c.UNZ_OK) file_info_error(lua);
        if (c.unzGoToFirstFile(ud.uzfh) != c.UNZ_OK) file_info_error(lua);

        var uzfi: c.unz_file_info = undefined;
        var index: u32 = 1;
        var zfname: [4096:0]u8 = undefined;

        while (true) : (index += 1) {
            if (c.unzGetCurrentFileInfo(ud.uzfh, &uzfi, &zfname, 4096, null, 0, null, 0) != c.UNZ_OK) file_info_error(lua);

            create_file_table(lua, zfname, uzfi);
            lua.rawSetIndex(table, index);

            if (c.unzGoToNextFile(ud.uzfh) != c.UNZ_OK) {
                break;
            }
        }
        return 1;
    }

    fn file_info_error(lua: *Lua) noreturn {
        luax.raiseError(lua, "internal error: could not get zip file information");
    }

    fn create_file_table(lua: *Lua, zfname: [4096:0]u8, uzfi: c.unz_file_info) void {
        lua.newTable();
        const table = lua.getTop();

        luax.setTableString(lua, table, "name", zfname[0..uzfi.size_filename :0]);

        const is_directory = zfname[uzfi.size_filename - 1] == '/';
        luax.setTableBoolean(lua, table, "is_directory", is_directory);

        luax.setTableInteger(lua, table, "uncompressed_size", uzfi.uncompressed_size);
        luax.setTableString(lua, table, "uncompressed_size_hr", filesystem.size_human_readable(uzfi.uncompressed_size) catch luax.raiseError(lua, "internal error: could not convert size to human readable string"));
        luax.setTableInteger(lua, table, "compressed_size", uzfi.compressed_size);
        luax.setTableString(lua, table, "compressed_size_hr", filesystem.size_human_readable(uzfi.compressed_size) catch luax.raiseError(lua, "internal error: could not convert size to human readable string"));

        var compression_ratio: f64 = undefined;
        if (is_directory) {
            compression_ratio = 0;
        } else {
            compression_ratio = @as(f64, @floatFromInt(uzfi.compressed_size)) / @as(f64, @floatFromInt(uzfi.uncompressed_size));
        }
        luax.setTableNumber(lua, table, "compression_ratio", compression_ratio);

        luax.setTableInteger(lua, table, "crc", uzfi.crc);

        _ = lua.pushString("time");
        pushTime(lua, uzfi);
        lua.setTable(table);

        var timestamp: [30:0]u8 = undefined;
        luax.setTableString(lua, table, "timestamp", std.fmt.bufPrintZ(&timestamp, "{}/{d:0>2}/{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{ @as(u32, @intCast(uzfi.tmu_date.tm_year)), @as(u32, @intCast(uzfi.tmu_date.tm_mon)), @as(u32, @intCast(uzfi.tmu_date.tm_mday)), @as(u32, @intCast(uzfi.tmu_date.tm_hour)), @as(u32, @intCast(uzfi.tmu_date.tm_min)), @as(u32, @intCast(uzfi.tmu_date.tm_sec)) }) catch luax.raiseError(lua, "internal error: could not format timestamp"));
    }

    fn pushTime(lua: *Lua, uzfi: c.unz_file_info) void {
        lua.newTable();
        const table = lua.getTop();

        luax.setTableInteger(lua, table, "year", uzfi.tmu_date.tm_year);
        luax.setTableInteger(lua, table, "month", uzfi.tmu_date.tm_mon);
        luax.setTableInteger(lua, table, "day", uzfi.tmu_date.tm_mday);
        luax.setTableInteger(lua, table, "hour", uzfi.tmu_date.tm_hour);
        luax.setTableInteger(lua, table, "minute", uzfi.tmu_date.tm_min);
        luax.setTableInteger(lua, table, "second", uzfi.tmu_date.tm_sec);
    }
    fn read_all(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, name, UnzipUdata);
        const fname = lua.toString(2) catch luax.raiseError(lua, "expecting file name to read as argument");
        var uzfi: c.unz_file_info = undefined;

        _ = c.unzCloseCurrentFile(ud.uzfh);
        if (c.unzLocateFile(ud.uzfh, fname, 0) != c.UNZ_OK) return luax.returnError(lua, "File not found");
        if (c.unzOpenCurrentFile(ud.uzfh) != c.UNZ_OK) luax.raiseError(lua, "Could not open file");
        if (c.unzGetCurrentFileInfo(ud.uzfh, &uzfi, null, 0, null, 0, null, 0) != c.UNZ_OK) file_info_error(lua);
        var lua_buffer: ziglua.Buffer = undefined;
        var buffer = lua_buffer.initSize(lua.*, uzfi.uncompressed_size);
        const bytes_read = c.unzReadCurrentFile(ud.uzfh, buffer.ptr, uzfi.uncompressed_size);
        lua_buffer.addSize(@intCast(bytes_read));
        lua_buffer.pushResult();
        return 1;
    }
};
