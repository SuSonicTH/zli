const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");

const allocator = std.heap.c_allocator;

const filesystem = @import("filesystem.zig");
const zip_reader = @import("zip_reader.zig");

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

    const extended = @embedFile("unzip.lua");
    luax.registerExtended(lua, extended, "unzip", zli_unzip);
    return 1;
}

const UnzipUdata = struct {
    archive: ?zip_reader.Archive = null,
    path: [:0]u8,
    const name = "_UnzipUdata";

    const functions = [_]zlua.FnReg{
        .{ .name = "list", .func = zlua.wrap(list) },
        .{ .name = "dir", .func = zlua.wrap(dir) },
        .{ .name = "info", .func = zlua.wrap(info) },
        .{ .name = "extract", .func = zlua.wrap(extract) },
        .{ .name = "read_all", .func = zlua.wrap(read_all) },
        .{ .name = "lines", .func = zlua.wrap(lines) },
        .{ .name = "payload_start", .func = luaerror.wrap(payload_start) },
        .{ .name = "close", .func = zlua.wrap(close) },
    };

    const file_functions = [_]zlua.FnReg{
        .{ .name = "read_all", .func = zlua.wrap(fileReadAll) },
        .{ .name = "open", .func = zlua.wrap(UnzipFile.open) },
        .{ .name = "lines", .func = zlua.wrap(fileLines) },
        .{ .name = "extract", .func = zlua.wrap(extract) },
    };

    fn fileReadAll(lua: *Lua) !i32 {
        const opened = UnzipFile.open(lua);
        if (opened != 1 or lua.typeOf(-1) != .table) {
            return opened;
        }
        lua.replace(1);
        const result = UnzipFile.read_all(lua) catch |err|
            return luaerror.raiseOrReturnLast(lua, err, .@"return");
        return result;
    }

    fn fileLines(lua: *Lua) i32 {
        const opened = UnzipFile.open(lua);
        if (opened != 1 or lua.typeOf(-1) != .table) {
            return opened;
        }
        lua.replace(1);
        return UnzipFile.lines(lua);
    }

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
        if (ud.archive) |*archive| {
            archive.deinit();
            ud.archive = null;
        }
        allocator.free(ud.path);
        return 0;
    }

    fn new(lua: *Lua) !i32 {
        const path = try filesystem.get_path(lua);
        var archive = zip_reader.Archive.init(allocator, io, path) catch |err|
            return luaerror.ret(lua, "could not open zip file '{s}': {s}", .{ path, @errorName(err) });
        errdefer archive.deinit();

        const owned_path = try allocator.dupeSentinel(u8, std.mem.sliceTo(path, 0), 0);
        errdefer allocator.free(owned_path);

        const ud: *UnzipUdata = luax.createUserDataTableSetFunctions(lua, name, UnzipUdata, &functions, 0);
        ud.path = owned_path;
        ud.archive = archive;
        return 1;
    }

    fn get(lua: *Lua) !*zip_reader.Archive {
        const ud: *UnzipUdata = luax.getUserData(lua, name, UnzipUdata);
        if (ud.archive) |*archive| return archive;
        return error.ZipClosed;
    }

    fn list(lua: *Lua) i32 {
        return list_dir(lua, false);
    }

    fn dir(lua: *Lua) i32 {
        return list_dir(lua, true);
    }

    fn list_dir(lua: *Lua, key_value: bool) i32 {
        const archive = get(lua) catch return luaerror.ret(lua, "zip archive is closed", .{});

        lua.newTable();
        const table = lua.getTop();
        for (archive.entries, 0..) |entry, index| {
            if (key_value) {
                _ = lua.pushString(entry.name);
                create_file_table(lua, entry, index);
                lua.setTable(table);
            } else {
                create_file_table(lua, entry, index);
                lua.setIndexRaw(table, @intCast(index + 1));
            }
        }
        return 1;
    }

    fn info(lua: *Lua) !i32 {
        const archive = get(lua) catch return luaerror.ret(lua, "zip archive is closed", .{});
        lua.newTable();
        const table = lua.getTop();
        luax.setTableInteger(lua, table, "entries", @intCast(archive.entries.len));
        luax.setTableString(lua, table, "comment", archive.comment);
        return 1;
    }

    fn create_file_table(lua: *Lua, entry: zip_reader.Entry, index: usize) void {
        lua.newTable();
        const table = lua.getTop();
        lua.setFuncs(&file_functions, 0);

        // Keep the archive userdata alive for as long as the entry table.
        _ = lua.pushString(UnzipUdata.name);
        _ = lua.pushString(UnzipUdata.name);
        _ = lua.getTable(1);
        lua.setTable(table);

        luax.setTableInteger(lua, table, "index", @intCast(index + 1));
        luax.setTableString(lua, table, "full_path", entry.name);

        luax.pushRegistryFunction(lua, zli_unzip, "path_to_path_and_name");
        _ = lua.pushString("/");
        _ = lua.pushString(entry.name);
        lua.call(.{ .args = 2, .results = 2 });

        luax.setTableValue(lua, table, "name", -1, true);
        luax.setTableValue(lua, table, "path", -1, true);

        luax.setTableBoolean(lua, table, "is_directory", entry.is_directory);
        luax.setTableBoolean(lua, table, "is_file", !entry.is_directory);

        if (!entry.is_directory) {
            luax.setTableInteger(lua, table, "uncompressed_size", @intCast(entry.uncompressed_size));
            luax.setTableString(lua, table, "uncompressed_size_hr", filesystem.size_human_readable(entry.uncompressed_size) catch lua.raiseErrorStr("internal error: could not convert size to human readable string", .{}));
            luax.setTableInteger(lua, table, "compressed_size", @intCast(entry.compressed_size));
            luax.setTableString(lua, table, "compressed_size_hr", filesystem.size_human_readable(entry.compressed_size) catch lua.raiseErrorStr("internal error: could not convert size to human readable string", .{}));

            const compression_ratio: f64 = if (entry.uncompressed_size > 0)
                @as(f64, @floatFromInt(entry.compressed_size)) / @as(f64, @floatFromInt(entry.uncompressed_size))
            else
                0;
            luax.setTableNumber(lua, table, "compression_ratio", compression_ratio);

            luax.setTableFunction(lua, table, "extract", zlua.wrap(extract));
        }

        luax.setTableInteger(lua, table, "crc", @intCast(entry.crc32));

        const date_time = dos_to_datetime(entry.dos_date, entry.dos_time);
        _ = lua.pushString("time");
        pushTime(lua, date_time);
        lua.setTable(table);

        var timestamp: [40:0]u8 = undefined;
        luax.setTableString(lua, table, "timestamp", std.fmt.bufPrintSentinel(&timestamp, "{d}/{d:0>2}/{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
            date_time.year,
            date_time.month + 1,
            date_time.day,
            date_time.hour,
            date_time.minute,
            date_time.second,
        }, 0) catch lua.raiseErrorStr("internal error: could not format timestamp", .{}));
    }

    const DateTime = struct {
        year: u16,
        month: u16, // 0 based, like the Lua time table
        day: u16,
        hour: u16,
        minute: u16,
        second: u16,
    };

    fn dos_to_datetime(dos_date: u16, dos_time: u16) DateTime {
        const month = (dos_date >> 5) & 0x0F;
        return .{
            .year = ((dos_date >> 9) & 0x7F) + 1980,
            .month = if (month > 0) month - 1 else 0,
            .day = dos_date & 0x1F,
            .hour = (dos_time >> 11) & 0x1F,
            .minute = (dos_time >> 5) & 0x3F,
            .second = (dos_time & 0x1F) * 2,
        };
    }

    fn pushTime(lua: *Lua, date_time: DateTime) void {
        lua.newTable();
        const table = lua.getTop();

        luax.setTableInteger(lua, table, "year", date_time.year);
        luax.setTableInteger(lua, table, "month", date_time.month);
        luax.setTableInteger(lua, table, "day", date_time.day);
        luax.setTableInteger(lua, table, "hour", date_time.hour);
        luax.setTableInteger(lua, table, "minute", date_time.minute);
        luax.setTableInteger(lua, table, "second", date_time.second);
    }

    fn resolve_entry(lua: *Lua, archive: *const zip_reader.Archive) !usize {
        if (luax.getTableStringOptional(lua, "full_path", 1)) |full_path| {
            if (archive.find(full_path)) |index| return index;
        }

        if (lua.typeOf(2) == .string) {
            const entry_name = std.mem.sliceTo(lua.toString(2) catch unreachable, 0);
            if (archive.find(entry_name)) |index| return index;
        }

        return error.ZipEntryNotFound;
    }

    fn read_all(lua: *Lua) !i32 {
        const archive = get(lua) catch return luaerror.ret(lua, "zip archive is closed", .{});
        const index = resolve_entry(lua, archive) catch {
            const entry_name = lua.toString(2) catch "?";
            return luaerror.ret(lua, "File '{s}' not found inside zip archive", .{std.mem.sliceTo(entry_name, 0)});
        };
        const data = archive.readEntryAll(index, allocator) catch |err|
            return luaerror.ret(lua, "could not read '{s}' from zip archive: {s}", .{ archive.entries[index].name, @errorName(err) });
        defer allocator.free(data);
        _ = lua.pushString(data);
        return 1;
    }

    fn lines(lua: *Lua) i32 {
        const opened = UnzipFile.open(lua);
        if (opened != 1 or lua.typeOf(-1) != .table) {
            return opened;
        }
        lua.replace(1);
        return UnzipFile.lines(lua);
    }

    fn extract(lua: *Lua) !i32 {
        const archive = get(lua) catch return luaerror.ret(lua, "zip archive is closed", .{});
        const index = resolve_entry(lua, archive) catch
            return luaerror.ret(lua, "file not found inside zip archive", .{});

        const destination = if (luax.getTableStringOptional(lua, "full_path", 1)) |_|
            (getDestination(lua, 2) orelse archive.entries[index].name)
        else
            (getDestination(lua, 3) orelse archive.entries[index].name);

        try extract_index(archive, index, std.mem.sliceTo(destination, 0));
        lua.pushBoolean(true);
        return 1;
    }

    fn payload_start(lua: *Lua) !i32 {
        const archive = get(lua) catch return luaerror.ret(lua, "zip archive is closed", .{});
        if (archive.entries.len == 0) {
            lua.pushNil();
            return 1;
        }
        lua.pushInteger(@intCast(archive.entries[0].local_header_offset));
        return 1;
    }

    fn close(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, name, UnzipUdata);
        if (ud.archive) |*archive| {
            archive.deinit();
            ud.archive = null;
        }
        return 0;
    }
};

fn getDestination(lua: *Lua, index: i32) ?[:0]const u8 {
    return switch (lua.typeOf(index)) {
        .string, .table => filesystem.get_path_index(lua, index) catch null,
        else => null,
    };
}

fn extract_index(archive: *const zip_reader.Archive, index: usize, destination: []const u8) !void {
    if (archive.entries[index].is_directory) return;

    // Open the entry first so unsupported/encrypted entries do not truncate an
    // existing destination file.
    var reader = try zip_reader.EntryReader.init(allocator, archive, index);
    defer reader.deinit();

    const file = std.Io.Dir.cwd().createFile(io, destination, .{}) catch |err|
        return luaerror.raise(err, "could not open output file '{s}': {s}", .{ destination, @errorName(err) });
    defer file.close(io);

    var buffer: [4096]u8 = undefined;
    while (true) {
        const amount = reader.read(&buffer) catch |err|
            return luaerror.raise(err, "could not read '{s}' from zip archive: {s}", .{ archive.entries[index].name, @errorName(err) });
        if (amount == 0) break;
        file.writeStreamingAll(io, buffer[0..amount]) catch |err|
            return luaerror.raise(err, "could not write to file '{s}': {s}", .{ destination, @errorName(err) });
    }
}

const UnzipFile = struct {
    archive: *UnzipUdata,
    entry_index: usize,
    entry_name: ?[:0]u8 = null,

    reader: ?*zip_reader.EntryReader = null,
    buffer: [4096]u8 = undefined,
    size: u64 = 0,
    fpos: u64 = 0,
    pos: u32 = 0,
    end: u32 = 0,
    eof: bool = false,
    closed: bool = false,

    const name = "_UnzipFile";
    const functions = [_]zlua.FnReg{
        .{ .name = "read", .func = luaerror.wrap(read) },
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
        const uzf: *UnzipFile = luax.getGcUserData(lua, UnzipFile);
        closeReader(uzf);
        if (uzf.entry_name) |entry_name| allocator.free(entry_name);
        return 0;
    }

    fn closeReader(uzf: *UnzipFile) void {
        if (uzf.reader) |reader| {
            reader.deinit();
            uzf.reader = null;
        }
    }

    fn open(lua: *Lua) i32 {
        const ud: *UnzipUdata = luax.getUserData(lua, UnzipUdata.name, UnzipUdata);
        if (ud.archive == null) {
            return luaerror.ret(lua, "zip archive is closed", .{});
        }
        const archive = &ud.archive.?;

        const index = resolve_index(lua, archive) catch {
            return luaerror.ret(lua, "file not found inside zip archive", .{});
        };
        const entry = archive.entries[index];
        if (entry.is_directory)
            return luaerror.ret(lua, "cannot read directory entry '{s}'", .{entry.name});

        const uzf: *UnzipFile = luax.createUserDataTableSetFunctions(lua, name, UnzipFile, &functions, 0);
        const table = lua.getTop();
        _ = lua.pushString(UnzipUdata.name);
        _ = lua.pushString(UnzipUdata.name);
        _ = lua.getTable(1);
        lua.setTable(table);
        luax.setTableString(lua, table, "full_path", entry.name);
        luax.setTableInteger(lua, table, "index", @intCast(index + 1));

        uzf.archive = ud;
        uzf.entry_index = index;
        uzf.entry_name = null;
        uzf.size = entry.uncompressed_size;
        uzf.reader = null;
        uzf.pos = 0;
        uzf.fpos = 0;
        uzf.end = 0;
        uzf.eof = false;
        uzf.closed = false;

        const entry_name = allocator.dupeSentinel(u8, entry.name, 0) catch
            return luaerror.ret(lua, "out of memory", .{});
        uzf.entry_name = entry_name;
        return 1;
    }

    fn resolve_index(lua: *Lua, archive: *const zip_reader.Archive) !usize {
        luax.getTable(lua, "index", 1);
        if (lua.isNumber(-1)) {
            const index: usize = @intCast(lua.toInteger(-1) catch unreachable);
            lua.pop(1);
            if (index > 0 and index <= archive.entries.len) return index - 1;
            return error.ZipEntryNotFound;
        }
        lua.pop(1);

        const file_name = getFileName(lua);
        return archive.find(file_name) orelse error.ZipEntryNotFound;
    }

    fn getFileName(lua: *Lua) [:0]const u8 {
        return luax.getTableStringOrError(lua, "full_path", 1) catch
            return std.mem.sliceTo(lua.toString(2) catch lua.argError(1, "expected file name in zip"), 0);
    }

    fn ensureOpen(uzf: *UnzipFile) !void {
        if (uzf.closed) return luaerror.raise(error.FileClosed, "zip entry is closed", .{});
    }

    fn ensureReader(uzf: *UnzipFile) !void {
        try ensureOpen(uzf);
        if (uzf.reader != null) return;
        if (uzf.archive.archive == null)
            return luaerror.raise(error.ZipClosed, "zip archive is closed", .{});
        uzf.reader = zip_reader.EntryReader.init(allocator, &uzf.archive.archive.?, uzf.entry_index) catch |err|
            return luaerror.raise(err, "could not open '{s}' in zip: {s}", .{ uzf.entry_name orelse "zip entry", @errorName(err) });
        uzf.pos = 0;
        uzf.fpos = 0;
        uzf.end = 0;
        uzf.eof = false;
    }

    fn fillBuffer(uzf: *UnzipFile) !void {
        if (uzf.eof) return;
        try ensureReader(uzf);

        const amount = uzf.reader.?.read(&uzf.buffer) catch |err|
            return luaerror.raise(err, "could not read '{s}' from zip: {s}", .{ uzf.entry_name orelse "zip entry", @errorName(err) });
        uzf.fpos += uzf.end;
        uzf.pos = 0;

        if (amount > 0) {
            uzf.end = @intCast(amount);
        } else {
            uzf.end = 0;
            uzf.eof = true;
        }
    }

    fn close(lua: *Lua) i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        closeReader(uzf);
        uzf.closed = true;
        return 0;
    }

    fn setvbuf(lua: *Lua) i32 {
        _ = lua;
        return 0;
    }

    fn seek(lua: *Lua) !i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        try ensureOpen(uzf);
        if (uzf.archive.archive == null) {
            return luaerror.ret(lua, "zip archive is closed", .{});
        }
        const whence = lua.optString(2) orelse "cur";
        const offset = lua.optInteger(3) orelse 0;

        const whence_slice = std.mem.sliceTo(whence, 0);
        if (whence_slice.len == 0) {
            return luaerror.ret(lua, "invalid seek mode '{s}'", .{whence});
        }

        const current: i64 = @as(i64, @intCast(uzf.fpos)) + @as(i64, @intCast(uzf.pos));
        const target: i64 = switch (whence_slice[0]) {
            's' => offset,
            'c' => current + offset,
            'e' => @as(i64, @intCast(uzf.size)) + offset,
            else => return luaerror.ret(lua, "invalid seek mode '{s}'", .{whence}),
        };

        if (target < 0 or target > @as(i64, @intCast(uzf.size))) {
            return luaerror.ret(lua, "seek position outside of file", .{});
        }

        try ensureReader(uzf);
        uzf.reader.?.seek(@intCast(target)) catch |err|
            return luaerror.raise(err, "could not seek in '{s}': {s}", .{ uzf.entry_name orelse "zip entry", @errorName(err) });

        uzf.fpos = @intCast(target);
        uzf.pos = 0;
        uzf.end = 0;
        uzf.eof = false;

        lua.pushInteger(@intCast(target));
        return 1;
    }

    fn lines(lua: *Lua) i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        if (uzf.closed) return luaerror.ret(lua, "zip entry is closed", .{});
        lua.pushFunction(luaerror.wrap(lines_iterator));
        lua.pushValue(1);
        lua.pushNil();
        lua.pushNil();
        return 4;
    }

    fn lines_iterator(lua: *Lua) !i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        return read_line(lua, uzf, false);
    }

    const read_option = enum { n, a, l, L };

    fn read(lua: *Lua) !i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        try ensureOpen(uzf);
        if (lua.isNumber(2)) {
            return read_bytes(lua, uzf, @as(u32, @intCast(lua.toInteger(2) catch lua.raiseErrorStr("argument to read has to be an integer or one of 'n', 'a', 'l' or 'L'", .{}))));
        }
        return switch (lua.checkOption(read_option, 2, .l)) {
            .n => try NumberReader.init(lua, uzf).read_number(),
            .a => read_all_file(lua, uzf),
            .l => try read_line(lua, uzf, false),
            .L => try read_line(lua, uzf, true),
        };
    }

    fn read_bytes(lua: *Lua, uzf: *UnzipFile, len: u32) !i32 {
        try ensureOpen(uzf);
        if (len == 0) {
            _ = lua.pushString("");
            return 1;
        }

        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        var remaining: usize = len;
        while (remaining > 0) {
            if (uzf.pos >= uzf.end) {
                try fillBuffer(uzf);
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

    fn read_all(lua: *Lua) !i32 {
        const uzf: *UnzipFile = luax.getUserData(lua, name, UnzipFile);
        return read_all_file(lua, uzf);
    }

    fn read_all_file(lua: *Lua, uzf: *UnzipFile) !i32 {
        try ensureOpen(uzf);
        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        while (true) {
            if (uzf.pos >= uzf.end) {
                try fillBuffer(uzf);
                if (uzf.eof) break;
            }
            lua_buffer.addString(uzf.buffer[uzf.pos..uzf.end]);
            uzf.pos = uzf.end;
        }

        lua_buffer.pushResult();
        return 1;
    }

    fn read_line(lua: *Lua, uzf: *UnzipFile, include_eol: bool) !i32 {
        try ensureOpen(uzf);
        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        var produced = false;
        while (true) {
            if (uzf.pos >= uzf.end) {
                try fillBuffer(uzf);
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
                if (uzf.pos >= uzf.end) try fillBuffer(uzf);
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

    fn read_number(nr: *const NumberReader) !i32 {
        if (!(try nr.parse_number())) {
            nr.lua.pushNil();
            return 1;
        }
        buffer[pos] = 0;
        _ = nr.lua.stringToNumber(&buffer) catch nr.lua.pushNil();
        return 1;
    }

    fn parse_number(nr: *const NumberReader) !bool {
        pos = 0;
        is_hex = false;

        if (nr.uzf.pos >= nr.uzf.end) {
            try UnzipFile.fillBuffer(nr.uzf);
            if (nr.uzf.eof) return false;
        }
        while (nr.is_space()) {
            if (!(try nr.move_next())) return false;
        }
        if (nr.current() == '+' or nr.current() == '-') {
            if (!(try nr.add_current())) return false;
        }
        if (nr.current() == '0') {
            if (!(try nr.add_current())) return false;
            if (nr.current() == 'x' or nr.current() == 'X') {
                is_hex = true;
                if (!(try nr.add_current())) return false;
            }
        }
        if (!(try nr.parse_digits())) return true;
        if (nr.current() == '.') {
            if (!(try nr.add_current())) return true;
        }
        if (!(try nr.parse_digits())) return true;
        if ((is_hex and (nr.current() == 'p' or nr.current() == 'P')) or (!is_hex and (nr.current() == 'e' or nr.current() == 'E'))) {
            if (!(try nr.add_current())) return false;
            if (nr.current() == '+' or nr.current() == '-') {
                if (!(try nr.add_current())) return false;
            }
            if (!(try nr.parse_digits())) return true;
        }
        return true;
    }

    inline fn current(nr: *const NumberReader) u8 {
        return nr.uzf.buffer[nr.uzf.pos];
    }

    inline fn move_next(nr: *const NumberReader) !bool {
        const uzf = nr.uzf;
        uzf.pos += 1;
        if (uzf.pos == uzf.end) {
            try UnzipFile.fillBuffer(uzf);
        }
        return !uzf.eof;
    }

    inline fn add_current(nr: *const NumberReader) !bool {
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

    inline fn parse_digits(nr: *const NumberReader) !bool {
        if (is_hex) {
            while (nr.is_hex_digit()) {
                if (!(try nr.add_current())) return false;
            }
            return true;
        } else {
            while (nr.is_digit()) {
                if (!(try nr.add_current())) return false;
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
