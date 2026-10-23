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

const unzip = [_]zlua.FnReg{
    .{ .name = "open", .func = luaerror.wrap(UnzipUdata.new) },
};

const zli_unzip = "zli_unzip";

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

pub fn register(lua: *Lua) i32 {
    UnzipUdata.register(lua);
    UnzipFile.register(lua);
    lua.newLib(&unzip);

    const exteded = @embedFile("unzip.lua");
    luax.registerExtended(lua, exteded, "unzip", zli_unzip);
    return 1;
}

const UnzipUdata = struct {
    uzfh: ?*anyopaque = undefined,
    path: [:0]u8,
    const name = "_UnzipUdata";
    const functions = [_]zlua.FnReg{
        .{ .name = "list", .func = zlua.wrap(list) },
        .{ .name = "dir", .func = zlua.wrap(dir) },
        .{ .name = "info", .func = zlua.wrap(info) },
        .{ .name = "extract", .func = zlua.wrap(extract) },
        // Convenience helpers; the same functions are also available on the
        // individual file entries returned by list()/dir().
        .{ .name = "read_all", .func = zlua.wrap(read_all) },
        .{ .name = "lines", .func = zlua.wrap(lines) },
        .{ .name = "payload_start", .func = luaerror.wrap(payload_start) },
        .{ .name = "close", .func = zlua.wrap(close) },
    };

    const file_functions = [_]zlua.FnReg{
        .{ .name = "read_all", .func = zlua.wrap(read_all) },
        .{ .name = "open", .func = zlua.wrap(UnzipFile.open) },
        .{ .name = "lines", .func = zlua.wrap(lines) },
        .{ .name = "extract", .func = zlua.wrap(extract) },
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
        const ud: *UnzipUdata = luax.getGcUserData(lua, UnzipUdata);
        if (ud.uzfh != null) {
            _ = c.unzClose(ud.uzfh);
            ud.uzfh = null;
        }
        allocator.free(ud.path);
        return 0;
    }

    fn new(lua: *Lua) !i32 {
        const path = try filesystem.get_path(lua);
        const uzfh = c.unzOpen64(path.ptr) orelse return luaerror.ret(lua, "could not open zip file '{s}'", .{path});
        const owned_path = try allocator.dupeSentinel(u8, std.mem.sliceTo(path, 0), 0);

        const ud: *UnzipUdata = luax.createUserDataTableSetFunctions(lua, name, UnzipUdata, &functions, 0);

        ud.path = owned_path;
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
        if (ud.uzfh == null) {
            return luaerror.ret(lua, "zip archive is closed", .{});
        }
        lua.newTable();
        const table = lua.getTop();

        var uzgi: c.unz_global_info = undefined;
        if (c.unzGetGlobalInfo(ud.uzfh, &uzgi) == c.UNZ_OK and uzgi.number_entry == 0) {
            return 1; // empty archive
        }

        const first_result = c.unzGoToFirstFile(ud.uzfh);
        if (first_result == c.UNZ_END_OF_LIST_OF_FILE) return 1; // empty archive
        if (first_result != c.UNZ_OK) file_info_error(lua, ud);

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
                lua.setIndexRaw(table, index);
            }
            if (c.unzGoToNextFile(ud.uzfh) != c.UNZ_OK) {
                break;
            }
        }
        return 1;
    }

    fn info(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, name, UnzipUdata);
        if (ud.uzfh == null) {
            return luaerror.ret(lua, "zip archive is closed", .{});
        }
        lua.newTable();
        const table = lua.getTop();

        var uzgi: c.unz_global_info = undefined;
        if (c.unzGetGlobalInfo(ud.uzfh, &uzgi) != c.UNZ_OK) file_info_error(lua, ud);

        luax.setTableInteger(lua, table, "entries", @intCast(uzgi.number_entry));
        _ = lua.pushString("comment");

        if (uzgi.size_comment == 0) {
            _ = lua.pushString("");
        } else {
            var lua_buffer: zlua.Buffer = undefined;
            const buffer = lua_buffer.initSize(lua, uzgi.size_comment);
            _ = c.unzGetGlobalComment(ud.uzfh, buffer.ptr, uzgi.size_comment);
            lua_buffer.addSize(@intCast(uzgi.size_comment));
            lua_buffer.pushResult();
        }
        lua.setTable(table);
        return 1;
    }

    fn create_file_table(lua: *Lua, zfname: [4096:0]u8, uzfi: c.unz_file_info, ud: *UnzipUdata) void {
        const file_name = zfname[0..uzfi.size_filename :0];

        lua.newTable();
        const table = lua.getTop();
        lua.setFuncs(&file_functions, 0);

        luax.setTableUserData(lua, table, name, ud);
        luax.setTableString(lua, table, "full_path", file_name);

        luax.pushRegistryFunction(lua, zli_unzip, "path_to_path_and_name");
        _ = lua.pushString("/");
        _ = lua.pushString(file_name);
        lua.call(.{ .args = 2, .results = 2 });

        luax.setTableValue(lua, table, "name", -1, true);
        luax.setTableValue(lua, table, "path", -1, true);

        const is_directory = file_name.len > 0 and file_name[file_name.len - 1] == '/';
        luax.setTableBoolean(lua, table, "is_directory", is_directory);
        luax.setTableBoolean(lua, table, "is_file", !is_directory);

        if (!is_directory) {
            luax.setTableInteger(lua, table, "uncompressed_size", @intCast(uzfi.uncompressed_size));
            luax.setTableString(lua, table, "uncompressed_size_hr", filesystem.size_human_readable(uzfi.uncompressed_size) catch lua.raiseErrorStr("internal error: could not convert size to human readable string", .{}));
            luax.setTableInteger(lua, table, "compressed_size", @intCast(uzfi.compressed_size));
            luax.setTableString(lua, table, "compressed_size_hr", filesystem.size_human_readable(uzfi.compressed_size) catch lua.raiseErrorStr("internal error: could not convert size to human readable string", .{}));

            const compression_ratio: f64 = if (uzfi.uncompressed_size > 0)
                @as(f64, @floatFromInt(uzfi.compressed_size)) / @as(f64, @floatFromInt(uzfi.uncompressed_size))
            else
                0;
            luax.setTableNumber(lua, table, "compression_ratio", compression_ratio);

            luax.setTableFunction(lua, table, "extract", zlua.wrap(extract));
        }

        luax.setTableInteger(lua, table, "crc", @intCast(uzfi.crc));

        _ = lua.pushString("time");
        pushTime(lua, uzfi);
        lua.setTable(table);

        var timestamp: [30:0]u8 = undefined;
        luax.setTableString(lua, table, "timestamp", std.fmt.bufPrintSentinel(&timestamp, "{}/{d:0>2}/{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
            @as(u32, @intCast(uzfi.tmu_date.tm_year)),
            @as(u32, @intCast(uzfi.tmu_date.tm_mon + 1)),
            @as(u32, @intCast(uzfi.tmu_date.tm_mday)),
            @as(u32, @intCast(uzfi.tmu_date.tm_hour)),
            @as(u32, @intCast(uzfi.tmu_date.tm_min)),
            @as(u32, @intCast(uzfi.tmu_date.tm_sec)),
        }, 0) catch lua.raiseErrorStr("internal error: could not format timestamp", .{}));
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
        const opened = UnzipFile.open(lua);
        if (opened != 1 or lua.typeOf(-1) != .table) {
            return opened;
        }
        lua.replace(1);
        _ = lua.pushString("a");
        lua.replace(2);
        lua.setTop(2);
        return UnzipFile.read(lua);
    }

    fn lines(lua: *Lua) i32 {
        const opened = UnzipFile.open(lua);
        if (opened != 1 or lua.typeOf(-1) != .table) {
            return opened;
        }
        _ = lua.pushString("lines");
        _ = lua.getTable(3);
        lua.replace(2);
        lua.call(.{ .args = 1, .results = 4 });
        return 4;
    }

    fn extract(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, UnzipUdata.name, UnzipUdata);
        if (ud.uzfh == null) {
            return luaerror.ret(lua, "zip archive is closed", .{});
        }
        const fname = getFileName(lua);
        var uzfi: c.unz_file_info = undefined;

        _ = c.unzCloseCurrentFile(ud.uzfh);
        if (c.unzLocateFile(ud.uzfh, fname, 0) != c.UNZ_OK) return luaerror.ret(lua, "File '{s}' not found inside '{s}'", .{ fname, ud.path });
        if (c.unzOpenCurrentFile(ud.uzfh) != c.UNZ_OK) lua.raiseErrorStr("Could not open file '%s' inside '%s'", .{ fname.ptr, ud.path.ptr });
        if (c.unzGetCurrentFileInfo(ud.uzfh, &uzfi, null, 0, null, 0, null, 0) != c.UNZ_OK) file_info_error(lua, ud);

        const destination_name: [:0]const u8 = luax.getTableStringOrError(lua, "full_path", -1) catch std.mem.sliceTo(lua.toString(-1) catch lua.argError(1, "expected file name to extract to"), 0);
        const file = std.Io.Dir.cwd().createFile(io, destination_name, .{}) catch return luaerror.ret(lua, "could not open output file '{s}'", .{destination_name});
        defer file.close(io);

        var buffer: [4096]u8 = undefined;

        while (true) {
            const bytes_read: usize = @intCast(c.unzReadCurrentFile(ud.uzfh, &buffer, buffer.len));
            if (bytes_read > 0) {
                file.writeStreamingAll(io, buffer[0..bytes_read]) catch return luaerror.ret(lua, "could not write to file '{s}'", .{destination_name});
            } else {
                break;
            }
        }

        lua.pushBoolean(true);
        return 1;
    }

    fn payload_start(lua: *Lua) !i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, name, UnzipUdata);
        if (ud.uzfh == null) {
            return luaerror.ret(lua, "zip archive is closed", .{});
        }

        if (c.unzGoToFirstFile(ud.uzfh) != c.UNZ_OK) {
            lua.pushNil();
            return 1;
        }

        if (c.unzOpenCurrentFile(ud.uzfh) != c.UNZ_OK) {
            return luaerror.ret(lua, "could not open first file in zip archive", .{});
        }
        defer _ = c.unzCloseCurrentFile(ud.uzfh);

        const data_pos = c.unzGetCurrentFileZStreamPos64(ud.uzfh);

        var file_info: c.unz_file_info = undefined;
        if (c.unzGetCurrentFileInfo(ud.uzfh, &file_info, null, 0, null, 0, null, 0) != c.UNZ_OK) {
            return luaerror.ret(lua, "could not read zip file information", .{});
        }

        const local_extra = c.unzGetLocalExtrafield(ud.uzfh, null, 0);
        if (local_extra < 0) {
            return luaerror.ret(lua, "could not read zip local extra field", .{});
        }

        const header_size: u64 = 30 + @as(u64, file_info.size_filename) + @as(u64, @intCast(local_extra));
        if (data_pos < header_size) {
            return luaerror.ret(lua, "could not determine payload offset", .{});
        }

        lua.pushInteger(@intCast(data_pos - header_size));
        return 1;
    }

    fn close(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, UnzipUdata.name, UnzipUdata);
        if (ud.uzfh != null) {
            _ = c.unzClose(ud.uzfh);
        }
        ud.uzfh = null;
        return 0;
    }
};

fn file_info_error(lua: *Lua, ud: *UnzipUdata) noreturn {
    lua.raiseErrorStr("internal error: could not get zip file information from '%s'", .{ud.path.ptr});
}

fn getFileName(lua: *Lua) [:0]const u8 {
    return luax.getTableStringOrError(lua, "full_path", 1) catch return std.mem.sliceTo(lua.toString(2) catch lua.argError(1, "expected file name in zip"), 0);
}

const UnzipFile = struct {
    uzfh: ?*anyopaque = undefined,
    buffer: [4096]u8 = undefined,
    size: u32 = undefined,
    fpos: u32 = undefined,
    pos: u32 = undefined,
    end: u32 = undefined,
    eof: bool = false,

    const name = "_UnzipFile";
    const functions = [_]zlua.FnReg{
        .{ .name = "read", .func = zlua.wrap(read) },
        .{ .name = "close", .func = zlua.wrap(close) },
        .{ .name = "setvbuf", .func = zlua.wrap(setvbuf) },
        .{ .name = "seek", .func = luaerror.wrap(seek) },
        .{ .name = "lines", .func = zlua.wrap(lines) },
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
        _ = lua;
        return 0;
    }

    fn open(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, UnzipUdata.name, UnzipUdata);
        if (ud.uzfh == null) {
            return luaerror.ret(lua, "zip archive is closed", .{});
        }
        const fname = getFileName(lua);
        var uzfi: c.unz_file_info = undefined;

        _ = c.unzCloseCurrentFile(ud.uzfh);
        if (c.unzLocateFile(ud.uzfh, fname, 0) != c.UNZ_OK) return luaerror.ret(lua, "File '{s}' not found inside '{s}'", .{ fname, ud.path });
        if (c.unzOpenCurrentFile(ud.uzfh) != c.UNZ_OK) lua.raiseErrorStr("Could not open file '%s' inside '%s'", .{ fname.ptr, ud.path.ptr });
        if (c.unzGetCurrentFileInfo(ud.uzfh, &uzfi, null, 0, null, 0, null, 0) != c.UNZ_OK) file_info_error(lua, ud);

        const uzf: *UnzipFile = luax.createUserDataTableSetFunctions(lua, name, UnzipFile, &functions, 0);
        luax.setTableString(lua, -1, "full_path", fname);
        uzf.size = @intCast(uzfi.uncompressed_size);
        uzf.uzfh = ud.uzfh;
        uzf.pos = 0;
        uzf.fpos = 0;
        uzf.end = 0;
        uzf.eof = false;
        return 1;
    }

    fn close(lua: *Lua) i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        _ = c.unzCloseCurrentFile(uzf.uzfh);
        return 0;
    }

    fn setvbuf(lua: *Lua) i32 {
        _ = lua;
        return 0;
    }

    fn seek(lua: *Lua) !i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        if (uzf.uzfh == null) {
            return luaerror.ret(lua, "zip archive is closed", .{});
        }
        const fname = luax.getTableString(lua, "full_path", 1);
        const whence = lua.optString(2) orelse "cur";
        const offset = lua.optInteger(3) orelse 0;

        const whence_slice = std.mem.sliceTo(whence, 0);
        if (whence_slice.len == 0) {
            return luaerror.ret(lua, "invalid seek mode '{s}'", .{whence});
        }

        const current: i64 = @as(i64, @intCast(uzf.fpos)) + @as(i64, @intCast(uzf.pos));
        const target: i64 = switch (whence_slice[0]) {
            's' => offset, // "set"
            'c' => current + offset, // "cur"
            'e' => @as(i64, @intCast(uzf.size)) + offset, // "end"
            else => return luaerror.ret(lua, "invalid seek mode '{s}'", .{whence}),
        };

        if (target < 0 or target > @as(i64, @intCast(uzf.size))) {
            return luaerror.ret(lua, "seek position outside of file", .{});
        }

        _ = c.unzCloseCurrentFile(uzf.uzfh);
        if (c.unzLocateFile(uzf.uzfh, fname.ptr, 0) != c.UNZ_OK) {
            return luaerror.ret(lua, "could not locate '{s}' in zip", .{fname});
        }
        if (c.unzOpenCurrentFile(uzf.uzfh) != c.UNZ_OK) {
            return luaerror.ret(lua, "could not open '{s}' in zip", .{fname});
        }

        var remaining: u64 = @intCast(target);
        var discard_buffer: [4096]u8 = undefined;
        while (remaining > 0) {
            const want: c_uint = @intCast(@min(remaining, @as(u64, discard_buffer.len)));
            const bytes_read = c.unzReadCurrentFile(uzf.uzfh, &discard_buffer, want);
            if (bytes_read <= 0) break;
            remaining -= @intCast(bytes_read);
        }

        uzf.fpos = @intCast(target);
        uzf.pos = 0;
        uzf.end = 0;
        uzf.eof = false;

        lua.pushInteger(@intCast(target));
        return 1;
    }

    fn lines(lua: *Lua) i32 {
        lua.pushFunction(zlua.wrap(lines_iterator));
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
        } else {
            uzf.end = 0;
            uzf.eof = true;
        }
    }

    const read_option = enum { n, a, l, L };

    fn read(lua: *Lua) i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        if (lua.isNumber(2)) {
            return read_bytes(lua, uzf, @as(u32, @intCast(lua.toInteger(2) catch lua.raiseErrorStr("argument to read has to be an integer or one of 'n', 'a', 'l' or 'L'", .{}))));
        }
        switch (lua.checkOption(read_option, 2, .l)) {
            .n => return NumberReader.init(lua, uzf).read_number(),
            .a => return read_all(lua, uzf),
            .l => return read_line(lua, uzf, false),
            .L => return read_line(lua, uzf, true),
        }
    }

    fn read_bytes(lua: *Lua, uzf: *UnzipFile, len: u32) i32 {
        if (len == 0) {
            _ = lua.pushString("");
            return 1;
        }

        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        var remaining: usize = len;
        while (remaining > 0) {
            if (uzf.pos >= uzf.end) {
                uzf.fillBuffer();
                if (uzf.eof) break;
            }
            const available = uzf.end - uzf.pos;
            const take = @min(available, remaining);
            lua_buffer.addString(uzf.buffer[uzf.pos .. uzf.pos + take]);
            uzf.pos += take;
            remaining -= take;
        }

        if (remaining == len) {
            lua.pushNil();
            return 1;
        }
        lua_buffer.pushResult();
        return 1;
    }

    fn read_all(lua: *Lua, uzf: *UnzipFile) i32 {
        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        while (true) {
            if (uzf.pos >= uzf.end) {
                uzf.fillBuffer();
                if (uzf.eof) break;
            }
            lua_buffer.addString(uzf.buffer[uzf.pos..uzf.end]);
            uzf.pos = uzf.end;
        }

        lua_buffer.pushResult();
        return 1;
    }

    fn read_line(lua: *Lua, uzf: *UnzipFile, include_eol: bool) i32 {
        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        var produced = false;
        while (true) {
            if (uzf.pos >= uzf.end) {
                uzf.fillBuffer();
                if (uzf.eof) break;
            }

            const ch = uzf.buffer[uzf.pos];
            if (ch == '\n') {
                uzf.pos += 1;
                if (include_eol) lua_buffer.addChar('\n');
                produced = true;
                break;
            }
            if (ch == '\r') {
                uzf.pos += 1;
                if (uzf.pos >= uzf.end) uzf.fillBuffer();
                if (!uzf.eof and uzf.buffer[uzf.pos] == '\n') {
                    uzf.pos += 1;
                    if (include_eol) lua_buffer.addChar('\n');
                } else if (include_eol) {
                    lua_buffer.addChar('\r');
                }
                produced = true;
                break;
            }

            lua_buffer.addChar(ch);
            uzf.pos += 1;
            produced = true;
        }

        if (!produced) {
            lua.pushNil();
            return 1;
        }
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
