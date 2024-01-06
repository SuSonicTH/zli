const std = @import("std");
const fs = std.fs;

const builtin = @import("builtin");

const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const luax = @import("luax.zig");

const allocator = std.heap.c_allocator;

const c = @cImport({
    @cInclude("unzip.h");
});

const filesystem = @import("filesystem.zig");

const unzip = [_]ziglua.FnReg{
    .{ .name = "open", .func = ziglua.wrap(UnzipUdata.new) },
};

const zli_unzip = "zli_unzip";

pub export fn luaopen_unzip(state: ?*ziglua.LuaState) callconv(.C) c_int {
    var lua: Lua = .{ .state = state.? };
    UnzipUdata.register(&lua);
    UnzipFile.register(&lua);
    lua.newLib(&unzip);

    const exteded = @embedFile("stripped/unzip.lua");
    luax.registerExtended(&lua, exteded, "zip", zli_unzip);
    return 1;
}

const UnzipUdata = struct {
    uzfh: *anyopaque = undefined,
    path: [:0]const u8,
    const name = "_UnzipUdata";
    const functions = [_]ziglua.FnReg{
        .{ .name = "list", .func = ziglua.wrap(list) },
        .{ .name = "dir", .func = ziglua.wrap(dir) },
        .{ .name = "info", .func = ziglua.wrap(info) },
        .{ .name = "extract", .func = ziglua.wrap(extract) },
    };

    const file_functions = [_]ziglua.FnReg{
        .{ .name = "read_all", .func = ziglua.wrap(read_all) },
        .{ .name = "open", .func = ziglua.wrap(UnzipFile.open) },
        .{ .name = "lines", .func = ziglua.wrap(lines) },
        .{ .name = "extract", .func = ziglua.wrap(extract) },
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
        const path = filesystem.get_path(lua);
        const uzfh = c.unzOpen64(path.ptr) orelse return luax.returnFormattedError(lua, "could not open zip file '%s'", .{path.ptr});

        const ud: *UnzipUdata = luax.createUserDataTableSetFunctions(lua, name, UnzipUdata, &functions);
        lua.setFuncs(&file_functions, 0);

        ud.path = path;
        ud.uzfh = uzfh;
        return 1;
    }

    fn list(lua: *Lua) i32 {
        return list_dir(lua, false);
    }

    fn dir(lua: *Lua) i32 {
        return list_dir(lua, true);
    }

    fn list_dir(lua: *Lua, keyValue: bool) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, name, UnzipUdata);
        lua.newTable();
        const table = lua.getTop();

        if (c.unzGoToFirstFile(ud.uzfh) != c.UNZ_OK) file_info_error(lua, ud);

        var uzfi: c.unz_file_info = undefined;
        var index: u32 = 1;
        var zfname: [4096:0]u8 = undefined;

        while (true) : (index += 1) {
            if (c.unzGetCurrentFileInfo(ud.uzfh, &uzfi, &zfname, 4096, null, 0, null, 0) != c.UNZ_OK) file_info_error(lua, ud);

            if (keyValue) {
                _ = lua.pushString(zfname[0..uzfi.size_filename :0]);
                create_file_table(lua, zfname, uzfi, ud);
                lua.setTable(table);
            } else {
                create_file_table(lua, zfname, uzfi, ud);
                lua.rawSetIndex(table, index);
            }
            if (c.unzGoToNextFile(ud.uzfh) != c.UNZ_OK) {
                break;
            }
        }
        return 1;
    }

    fn info(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, name, UnzipUdata);
        lua.newTable();
        const table = lua.getTop();

        var uzgi: c.unz_global_info = undefined;
        if (c.unzGetGlobalInfo(ud.uzfh, &uzgi) != c.UNZ_OK) file_info_error(lua, ud);

        luax.setTableInteger(lua, table, "entries", @intCast(uzgi.number_entry));
        _ = lua.pushString("comment");

        if (uzgi.size_comment == 0) {
            _ = lua.pushString("");
        } else {
            var lua_buffer: ziglua.Buffer = undefined;
            var buffer = lua_buffer.initSize(lua.*, uzgi.size_comment);
            _ = c.unzGetGlobalComment(ud.uzfh, buffer.ptr, uzgi.size_comment);
            lua_buffer.addSize(@intCast(uzgi.size_comment));
            lua_buffer.pushResult();
        }
        lua.setTable(table);
        return 1;
    }

    fn create_file_table(lua: *Lua, zfname: [4096:0]u8, uzfi: c.unz_file_info, ud: *UnzipUdata) void {
        lua.newTable();
        const table = lua.getTop();
        lua.setFuncs(&file_functions, 0);

        luax.setTableUserData(lua, table, name, ud);
        luax.setTableString(lua, table, "full_path", zfname[0..uzfi.size_filename :0]);

        luax.pushRegistryFunction(lua, zli_unzip, "path_to_path_and_name");
        _ = lua.pushString("/");
        _ = lua.pushString(zfname[0..uzfi.size_filename :0]);
        lua.call(2, 2);

        luax.setTableValue(lua, table, "name", -1, true);
        luax.setTableValue(lua, table, "path", -1, true);

        const is_directory = zfname[uzfi.size_filename - 1] == '/';
        luax.setTableBoolean(lua, table, "is_directory", is_directory);
        luax.setTableBoolean(lua, table, "is_file", !is_directory);

        if (!is_directory) {
            luax.setTableInteger(lua, table, "uncompressed_size", @intCast(uzfi.uncompressed_size));
            luax.setTableString(lua, table, "uncompressed_size_hr", filesystem.size_human_readable(uzfi.uncompressed_size) catch luax.raiseError(lua, "internal error: could not convert size to human readable string"));
            luax.setTableInteger(lua, table, "compressed_size", @intCast(uzfi.compressed_size));
            luax.setTableString(lua, table, "compressed_size_hr", filesystem.size_human_readable(uzfi.compressed_size) catch luax.raiseError(lua, "internal error: could not convert size to human readable string"));

            const compression_ratio: f64 = @as(f64, @floatFromInt(uzfi.compressed_size)) / @as(f64, @floatFromInt(uzfi.uncompressed_size));
            luax.setTableNumber(lua, table, "compression_ratio", compression_ratio);

            luax.setTableFunction(lua, table, "extract", ziglua.wrap(extract));
        }

        luax.setTableInteger(lua, table, "crc", @intCast(uzfi.crc));

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
        _ = UnzipFile.open(lua);
        lua.replace(1);
        _ = lua.pushString("a");
        lua.replace(2);
        lua.setTop(2);
        return UnzipFile.read(lua);
    }

    fn lines(lua: *Lua) i32 {
        _ = UnzipFile.open(lua);
        if (lua.isNil(-1)) {
            return 1;
        }
        _ = lua.pushString("lines");
        _ = lua.getTable(3);
        lua.replace(2);
        lua.call(1, 4);
        return 4;
    }

    fn extract(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, UnzipUdata.name, UnzipUdata);
        const fname = getFileName(lua);
        var uzfi: c.unz_file_info = undefined;

        _ = c.unzCloseCurrentFile(ud.uzfh);
        if (c.unzLocateFile(ud.uzfh, fname, 0) != c.UNZ_OK) return luax.returnFormattedError(lua, "File '%s' not found inside '%s'", .{ fname.ptr, ud.path.ptr });
        if (c.unzOpenCurrentFile(ud.uzfh) != c.UNZ_OK) luax.raiseFormattedError(lua, "Could not open file '%s' inside '%s'", .{ fname.ptr, ud.path.ptr });
        if (c.unzGetCurrentFileInfo(ud.uzfh, &uzfi, null, 0, null, 0, null, 0) != c.UNZ_OK) file_info_error(lua, ud);

        const destination_name: [:0]const u8 = luax.getTableStringOrError(lua, "full_path", -1) catch std.mem.sliceTo(lua.toString(-1) catch lua.argError(1, "expected file name to extract to"), 0);
        const file = fs.cwd().createFile(destination_name, .{}) catch return luax.returnFormattedError(lua, "could not open output file '%s'", .{destination_name.ptr});
        defer file.close();

        var buffer: [4096]u8 = undefined;

        while (true) {
            const bytes_read: usize = @intCast(c.unzReadCurrentFile(ud.uzfh, &buffer, buffer.len));
            if (bytes_read > 0) {
                file.writeAll(buffer[0..bytes_read]) catch return luax.returnFormattedError(lua, "could not write to file '%s'", .{destination_name.ptr});
            } else {
                break;
            }
        }

        lua.pushBoolean(true);
        return 1;
    }
};

fn file_info_error(lua: *Lua, ud: *UnzipUdata) noreturn {
    luax.raiseFormattedError(lua, "internal error: could not get zip file information from '%s'", .{ud.path.ptr});
}

fn getFileName(lua: *Lua) [:0]const u8 {
    return luax.getTableStringOrError(lua, "full_path", 1) catch return std.mem.sliceTo(lua.toString(2) catch lua.argError(1, "expected file name in zip"), 0);
}

const UnzipFile = struct {
    fname: [:0]const u8,
    uzfh: *anyopaque = undefined,
    buffer: [4096]u8 = undefined,
    size: u32 = undefined,
    fpos: u32 = undefined,
    pos: u32 = undefined,
    end: u32 = undefined,
    eof: bool = false,

    const name = "_UnzipFile";
    const functions = [_]ziglua.FnReg{
        .{ .name = "read", .func = ziglua.wrap(read) },
        .{ .name = "close", .func = ziglua.wrap(close) },
        .{ .name = "setvbuf", .func = ziglua.wrap(setvbuf) },
        .{ .name = "seek", .func = ziglua.wrap(seek) },
        .{ .name = "lines", .func = ziglua.wrap(lines) },
    };

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, ziglua.wrap(garbageCollect));
    }

    fn garbageCollect(lua: *Lua) i32 {
        _ = lua;
        return 0;
    }

    fn open(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, UnzipUdata.name, UnzipUdata);
        const fname = getFileName(lua);
        var uzfi: c.unz_file_info = undefined;

        _ = c.unzCloseCurrentFile(ud.uzfh);
        if (c.unzLocateFile(ud.uzfh, fname, 0) != c.UNZ_OK) return luax.returnFormattedError(lua, "File '%s' not found inside '%s'", .{ fname.ptr, ud.path.ptr });
        if (c.unzOpenCurrentFile(ud.uzfh) != c.UNZ_OK) luax.raiseFormattedError(lua, "Could not open file '%s' inside '%s'", .{ fname.ptr, ud.path.ptr });
        if (c.unzGetCurrentFileInfo(ud.uzfh, &uzfi, null, 0, null, 0, null, 0) != c.UNZ_OK) file_info_error(lua, ud);

        const uzf: *UnzipFile = luax.createUserDataTableSetFunctions(lua, name, UnzipFile, &functions);
        uzf.fname = fname;
        uzf.size = @intCast(uzfi.uncompressed_size);
        uzf.uzfh = ud.uzfh;
        uzf.pos = 0;
        uzf.fpos = 0;
        uzf.end = 0;
        uzf.eof = false;
        return 1;
    }

    fn close(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, UnzipUdata.name, UnzipUdata);
        _ = c.unzCloseCurrentFile(ud.uzfh);
        return 0;
    }

    fn setvbuf(lua: *Lua) i32 {
        _ = lua;
        return 0;
    }

    fn seek(lua: *Lua) i32 {
        _ = lua;
        //todo: implement
        return 0;
    }

    fn lines(lua: *Lua) i32 {
        lua.pushFunction(ziglua.wrap(lines_iterator));
        lua.pushValue(1);
        lua.pushNil();
        lua.pushNil();
        return 4;
    }

    fn lines_iterator(lua: *Lua) i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        return read_line(lua, uzf, false);
    }

    fn fillBuffer(uzf: *UnzipFile) void {
        if (uzf.eof) return;

        const bytes_read = c.unzReadCurrentFile(uzf.uzfh, &uzf.buffer, uzf.buffer.len);
        uzf.fpos += uzf.end;
        uzf.pos = 0;

        if (bytes_read > 0) {
            uzf.end = @intCast(bytes_read);
        } else if (bytes_read == 0) {
            uzf.end = 0;
            uzf.eof = true;
        }
    }

    const read_option = enum { n, a, l, L };

    fn read(lua: *Lua) i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        if (lua.isNumber(2)) {
            return read_bytes(lua, uzf, @as(u32, @intCast(lua.toInteger(2) catch luax.raiseError(lua, "argument to read has to be an integer or one of 'n', 'a', 'l' or 'L'"))));
        }
        switch (lua.checkOption(read_option, 2, .l)) {
            .n => return NumberReader.init(lua, uzf).read_number(),
            .a => return read_all(lua, uzf),
            .l => return read_line(lua, uzf, false),
            .L => return read_line(lua, uzf, true),
        }
    }

    fn read_bytes(lua: *Lua, uzf: *UnzipFile, len: u32) i32 {
        if (uzf.eof) {
            lua.pushNil();
            return 1;
        }

        if (uzf.pos == uzf.end) {
            var lua_buffer: ziglua.Buffer = undefined;
            var buffer = lua_buffer.initSize(lua.*, len);
            const bytes_read = c.unzReadCurrentFile(uzf.uzfh, buffer.ptr, len);
            lua_buffer.addSize(@intCast(bytes_read));
            lua_buffer.pushResult();
            if (bytes_read == 0) {
                lua.pushNil();
            }
            return 1;
        } else if (uzf.end - uzf.pos >= len) {
            _ = lua.pushBytes(uzf.buffer[uzf.pos .. uzf.pos + len]);
            uzf.pos += len;
            return 1;
        } else {
            var lua_buffer: ziglua.Buffer = undefined;
            lua_buffer.init(lua.*);
            lua_buffer.addBytes(uzf.buffer[uzf.pos..uzf.end]);
            var size = len - (uzf.end - uzf.pos);
            while (true) {
                fillBuffer(uzf);
                if (uzf.eof) {
                    lua_buffer.pushResult();
                    return 1;
                }
                if (uzf.end - uzf.pos >= size) {
                    lua_buffer.addBytes(uzf.buffer[0..size]);
                    lua_buffer.pushResult();
                    uzf.pos += size;
                    return 1;
                } else {
                    lua_buffer.addBytes(uzf.buffer[0..uzf.end]);
                    size -= uzf.end;
                }
            }
        }
        return 1;
    }

    fn read_all(lua: *Lua, uzf: *UnzipFile) i32 {
        var lua_buffer: ziglua.Buffer = undefined;
        const size = uzf.size - uzf.fpos + uzf.end;
        var buffer = lua_buffer.initSize(lua.*, size);
        const bytes_read = c.unzReadCurrentFile(uzf.uzfh, buffer.ptr, size);
        lua_buffer.addSize(@intCast(bytes_read));
        lua_buffer.pushResult();
        return 1;
    }

    fn read_line(lua: *Lua, uzf: *UnzipFile, include_eol: bool) i32 {
        if (uzf.pos == uzf.end) {
            uzf.fillBuffer();
        }
        if (uzf.eof) {
            lua.pushNil();
            return 1;
        }
        var start = uzf.pos;

        var lua_buffer: ziglua.Buffer = undefined;
        lua_buffer.init(lua.*);
        while (uzf.buffer[uzf.pos] != '\r' and uzf.buffer[uzf.pos] != '\n') {
            if (uzf.pos == uzf.end - 1) {
                lua_buffer.addBytes(uzf.buffer[start..uzf.end]);
                uzf.fillBuffer();
                start = 0;
                if (uzf.eof) {
                    lua_buffer.pushResult();
                    return 1;
                }
            } else {
                uzf.pos += 1;
            }
        }
        if (include_eol) {
            lua_buffer.addBytes(uzf.buffer[start .. uzf.pos + 1]);
        } else {
            lua_buffer.addBytes(uzf.buffer[start..uzf.pos]);
        }

        if (uzf.buffer[uzf.pos] == '\r') {
            if (uzf.pos == uzf.end - 1) {
                uzf.fillBuffer();
                if (uzf.eof) {
                    lua_buffer.pushResult();
                    return 1;
                }
            }
            if (uzf.buffer[uzf.pos + 1] == '\n') {
                uzf.pos += 1;
                if (include_eol) {
                    lua_buffer.addChar('\n');
                }
            }
        }
        uzf.pos += 1;

        lua_buffer.pushResult();
        return 1;
    }
};

const NumberReader = struct {
    uzf: *UnzipFile,
    lua: *Lua,

    var buffer: [200:0]u8 = undefined;
    var pos: u8 = 0;
    var is_hex: bool = false;

    fn init(lua: *Lua, uzf: *UnzipFile) NumberReader {
        return NumberReader{ .lua = lua, .uzf = uzf };
    }

    fn read_number(nr: *const NumberReader) i32 {
        if (!nr.parse_number()) {
            nr.lua.pushNil();
            return 1;
        }
        buffer[pos] = 0;
        _ = nr.lua.stringToNumber(&buffer) catch nr.lua.pushNil();
        return 1;
    }

    fn parse_number(nr: *const NumberReader) bool {
        pos = 0;
        is_hex = false;

        if (nr.uzf.pos >= nr.uzf.end) {
            nr.uzf.fillBuffer();
        }
        while (nr.is_space()) {
            if (!nr.move_next()) return false;
        }
        if (nr.current() == '+' or nr.current() == '-') {
            if (!nr.add_current()) return false;
        }
        if (nr.current() == '0') {
            if (!nr.add_current()) return false;
            if (nr.current() == 'x' or nr.current() == 'X') {
                is_hex = true;
                if (!nr.add_current()) return false;
            }
        }
        if (!nr.parse_digits()) return true;
        if (nr.current() == '.') {
            if (!nr.add_current()) return true;
        }
        if (!nr.parse_digits()) return true;
        if ((is_hex and (nr.current() == 'p' or nr.current() == 'P')) or (!is_hex and (nr.current() == 'e' or nr.current() == 'E'))) {
            if (!nr.add_current()) return false;
            if (nr.current() == '+' or nr.current() == '-') {
                if (!nr.add_current()) return false;
            }
            if (!nr.parse_digits()) return true;
        }
        return true;
    }

    inline fn current(nr: *const NumberReader) u8 {
        return nr.uzf.buffer[nr.uzf.pos];
    }

    inline fn move_next(nr: *const NumberReader) bool {
        const uzf = nr.uzf;
        uzf.pos += 1;
        if (uzf.pos == uzf.end) {
            uzf.fillBuffer();
        }
        return !uzf.eof;
    }

    inline fn add_current(nr: *const NumberReader) bool {
        buffer[pos] = nr.current();
        pos += 1;
        return nr.move_next();
    }

    inline fn is_space(nr: *const NumberReader) bool {
        switch (nr.current()) {
            ' ', '\t', '\r', '\n' => return true,
            else => return false,
        }
    }

    inline fn parse_digits(nr: *const NumberReader) bool {
        if (is_hex) {
            while (nr.is_hex_digit()) {
                if (!nr.add_current()) return false;
            }
            return true;
        } else {
            while (nr.is_digit()) {
                if (!nr.add_current()) return false;
            }
            return true;
        }
    }

    inline fn is_digit(nr: *const NumberReader) bool {
        switch (nr.current()) {
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => return true,
            else => return false,
        }
    }

    inline fn is_hex_digit(nr: *const NumberReader) bool {
        switch (nr.current()) {
            '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' => return true,
            'A', 'B', 'C', 'D', 'E', 'F' => return true,
            'a', 'b', 'c', 'd', 'e', 'f' => return true,
            else => return false,
        }
    }
};
