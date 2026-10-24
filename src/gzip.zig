//! Gzip file reading and writing built on `std.compress.flate`.

const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");
const filesystem = @import("filesystem.zig");

const flate = std.compress.flate;
const allocator = std.heap.c_allocator;

const exported = [_]zlua.FnReg{
    .{ .name = "open", .func = luaerror.wrap(open) },
    .{ .name = "compress", .func = luaerror.wrap(compress) },
    .{ .name = "decompress", .func = luaerror.wrap(decompress) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

pub fn register(lua: *Lua) i32 {
    GzipReader.register(lua);
    GzipWriter.register(lua);
    lua.newLib(&exported);
    return 1;
}

fn open(lua: *Lua) !i32 {
    const path = try filesystem.get_path_index(lua, 1);
    const mode = if (lua.typeOf(2) == .string)
        std.mem.sliceTo(lua.toString(2) catch unreachable, 0)
    else
        "r";

    if (mode.len == 0) {
        return luaerror.ret(lua, "invalid gzip open mode", .{});
    }

    const level = parseLevel(lua, 3, 6) catch |err| {
        return luaerror.ret(lua, "invalid gzip compression level: {s}", .{@errorName(err)});
    };

    return switch (mode[0]) {
        'r' => GzipReader.open(lua, path),
        'w' => GzipWriter.open(lua, path, level),
        else => luaerror.ret(lua, "invalid gzip open mode '{s}'", .{mode}),
    };
}

fn parseLevel(lua: *Lua, index: i32, default: u4) !u4 {
    if (lua.typeOf(index) == .nil or lua.typeOf(index) == .none) return default;

    if (lua.typeOf(index) == .number) {
        const value = lua.toInteger(index) catch return error.InvalidLevel;
        if (value < 0 or value > 9) return error.InvalidLevel;
        return @intCast(value);
    }

    if (lua.typeOf(index) == .string) {
        const name = std.mem.sliceTo(lua.toString(index) catch return error.InvalidLevel, 0);
        if (std.mem.eql(u8, name, "store")) return 0;
        if (std.mem.eql(u8, name, "fastest")) return 1;
        if (std.mem.eql(u8, name, "fast")) return 3;
        if (std.mem.eql(u8, name, "normal")) return 5;
        if (std.mem.eql(u8, name, "default")) return 6;
        if (std.mem.eql(u8, name, "high")) return 7;
        if (std.mem.eql(u8, name, "max") or std.mem.eql(u8, name, "best")) return 9;
    }

    return error.InvalidLevel;
}

fn compressionOptions(level: u4) flate.Compress.Options {
    return switch (level) {
        0, 1 => flate.Compress.Options.level_1,
        2 => flate.Compress.Options.level_2,
        3 => flate.Compress.Options.level_3,
        4 => flate.Compress.Options.level_4,
        5 => flate.Compress.Options.level_5,
        6 => flate.Compress.Options.level_6,
        7 => flate.Compress.Options.level_7,
        8 => flate.Compress.Options.level_8,
        else => flate.Compress.Options.level_9,
    };
}

fn compress(lua: *Lua) !i32 {
    const data = lua.checkString(1);
    const level = parseLevel(lua, 2, 6) catch
        return luaerror.ret(lua, "invalid gzip compression level", .{});

    var output: std.Io.Writer.Allocating = try .initCapacity(allocator, 4096);
    defer output.deinit();
    const history = try allocator.alloc(u8, flate.max_window_len);
    defer allocator.free(history);

    if (level == 0) {
        var compressor = flate.Compress.Raw.init(&output.writer, history, .gzip) catch
            return luaerror.ret(lua, "could not start gzip compression", .{});
        compressor.writer.writeAll(data) catch
            return luaerror.ret(lua, "could not compress data", .{});
        compressor.finish() catch
            return luaerror.ret(lua, "could not finish gzip compression", .{});
    } else {
        var compressor = flate.Compress.init(&output.writer, history, .gzip, compressionOptions(level)) catch
            return luaerror.ret(lua, "could not start gzip compression", .{});
        compressor.writer.writeAll(data) catch
            return luaerror.ret(lua, "could not compress data", .{});
        compressor.finish() catch
            return luaerror.ret(lua, "could not finish gzip compression", .{});
    }

    _ = lua.pushString(output.written());
    return 1;
}

fn decompress(lua: *Lua) !i32 {
    const data = lua.checkString(1);

    var input = std.Io.Reader.fixed(data);
    const history = try allocator.alloc(u8, flate.max_window_len);
    defer allocator.free(history);

    var decompressor = flate.Decompress.init(&input, .gzip, history);
    var output: std.Io.Writer.Allocating = try .initCapacity(allocator, 4096);
    defer output.deinit();

    var crc: std.hash.Crc32 = .init();
    var produced: u64 = 0;
    var buffer: [4096]u8 = undefined;
    while (true) {
        const amount = decompressor.reader.readSliceShort(&buffer) catch |err| {
            const detail: anyerror = decompressor.err orelse err;
            return luaerror.ret(lua, "could not decompress gzip data: {s}", .{@errorName(detail)});
        };
        if (amount == 0) break;
        crc.update(buffer[0..amount]);
        produced += amount;
        try output.writer.writeAll(buffer[0..amount]);
    }
    verifyGzip(&decompressor, crc, produced) catch |err|
        return luaerror.ret(lua, "could not decompress gzip data: {s}", .{@errorName(err)});

    _ = lua.pushString(output.written());
    return 1;
}

fn verifyGzip(decompressor: *const flate.Decompress, crc: std.hash.Crc32, produced: u64) !void {
    const metadata = switch (decompressor.container_metadata) {
        .gzip => |value| value,
        else => return error.NotGzip,
    };
    if (crc.final() != metadata.crc) return error.WrongGzipChecksum;
    if (@as(u32, @truncate(produced)) != metadata.count) return error.WrongGzipSize;
}

const GzipReader = struct {
    file: std.Io.File,
    file_buffer: [4096]u8 = undefined,
    file_reader: std.Io.File.Reader = undefined,
    history: []u8,

    decompressor: flate.Decompress = undefined,
    buffer: [4096]u8 = undefined,
    pos: u32 = 0,
    end: u32 = 0,
    fpos: u64 = 0,
    eof: bool = false,
    closed: bool = false,
    crc: std.hash.Crc32 = .init(),
    produced: u64 = 0,
    checksum_verified: bool = false,

    const name = "_GzipReader";
    const functions = [_]zlua.FnReg{
        .{ .name = "read", .func = luaerror.wrap(read) },
        .{ .name = "read_all", .func = luaerror.wrap(read_all) },
        .{ .name = "lines", .func = zlua.wrap(lines) },
        .{ .name = "seek", .func = luaerror.wrap(seek) },
        .{ .name = "close", .func = zlua.wrap(close) },
    };

    fn register(lua: *Lua) void {
        if (lua.getMetatableRegistry(name) == .nil) {
            lua.pop(1);
            luax.registerUserData(lua, name, zlua.wrap(garbageCollect));
        } else {
            lua.pop(1);
        }
    }

    fn open(lua: *Lua, path: [:0]const u8) !i32 {
        const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err|
            return luaerror.ret(lua, "could not open gzip file '{s}': {s}", .{ path, @errorName(err) });
        errdefer file.close(io);

        const history = try allocator.alloc(u8, flate.max_window_len);
        errdefer allocator.free(history);

        const reader: *GzipReader = luax.createUserDataTableSetFunctions(lua, name, GzipReader, &functions, 0);
        reader.file = file;
        reader.history = history;
        reader.file_reader = file.reader(io, &reader.file_buffer);
        reader.decompressor = flate.Decompress.init(&reader.file_reader.interface, .gzip, history);
        reader.pos = 0;
        reader.end = 0;
        reader.fpos = 0;
        reader.eof = false;
        reader.closed = false;
        reader.crc = .init();
        reader.produced = 0;
        reader.checksum_verified = false;
        return 1;
    }

    fn garbageCollect(lua: *Lua) i32 {
        const reader: *GzipReader = luax.getGcUserData(lua, GzipReader);
        closeReader(reader);
        return 0;
    }

    fn closeReader(reader: *GzipReader) void {
        if (reader.closed) return;
        reader.closed = true;
        reader.file.close(io);
        allocator.free(reader.history);
    }

    fn restart(reader: *GzipReader) !void {
        reader.file_reader.seekTo(0) catch |err|
            return err;
        reader.decompressor = flate.Decompress.init(&reader.file_reader.interface, .gzip, reader.history);
        reader.pos = 0;
        reader.end = 0;
        reader.fpos = 0;
        reader.eof = false;
        reader.crc = .init();
        reader.produced = 0;
        reader.checksum_verified = false;
    }

    fn pump(reader: *GzipReader, buffer: []u8) !usize {
        const amount = reader.decompressor.reader.readSliceShort(buffer) catch |err| {
            const detail: anyerror = reader.decompressor.err orelse err;
            return luaerror.raise(detail, "could not decompress gzip data: {s}", .{@errorName(detail)});
        };
        if (amount > 0) {
            reader.crc.update(buffer[0..amount]);
            reader.produced += amount;
        }
        return amount;
    }

    fn fillBuffer(reader: *GzipReader) !void {
        if (reader.eof) return;
        try ensureOpen(reader);

        const amount = try pump(reader, &reader.buffer);
        reader.fpos += @as(u64, reader.end);
        reader.pos = 0;
        if (amount > 0) {
            reader.end = @intCast(amount);
        } else {
            reader.end = 0;
            reader.eof = true;
            verifyChecksum(reader) catch |err|
                return luaerror.raise(err, "could not decompress gzip data: {s}", .{@errorName(err)});
        }
    }

    fn verifyChecksum(reader: *GzipReader) !void {
        if (reader.checksum_verified) return;
        reader.checksum_verified = true;
        try verifyGzip(&reader.decompressor, reader.crc, reader.produced);
    }

    fn ensureOpen(reader: *GzipReader) !void {
        if (reader.closed) return luaerror.raise(error.FileClosed, "gzip file is closed", .{});
    }

    fn read(lua: *Lua) !i32 {
        const reader: *GzipReader = luax.getUserData(lua, name, GzipReader);
        try ensureOpen(reader);
        if (lua.isNumber(2)) {
            const amount = lua.toInteger(2) catch
                lua.argError(2, "expecting an integer, 'a', 'l' or 'L'");
            if (amount < 0) lua.argError(2, "expecting a non-negative integer");
            return read_bytes(lua, reader, @intCast(amount));
        }

        const option = lua.optString(2) orelse "l";
        const option_slice = std.mem.sliceTo(option, 0);
        if (std.mem.eql(u8, option_slice, "a")) return read_all_contents(lua, reader);
        if (std.mem.eql(u8, option_slice, "l")) return try read_line(lua, reader, false);
        if (std.mem.eql(u8, option_slice, "L")) return try read_line(lua, reader, true);
        return lua.argError(2, "expecting an integer, 'a', 'l' or 'L'");
    }

    fn read_bytes(lua: *Lua, reader: *GzipReader, len: usize) !i32 {
        try ensureOpen(reader);
        if (len == 0) {
            _ = lua.pushString("");
            return 1;
        }

        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        var remaining = len;
        while (remaining > 0) {
            if (reader.pos >= reader.end) {
                try fillBuffer(reader);
                if (reader.eof) break;
            }
            const available: usize = @intCast(reader.end - reader.pos);
            const take = @min(available, remaining);
            const start: usize = @intCast(reader.pos);
            lua_buffer.addString(reader.buffer[start .. start + take]);
            reader.pos += @intCast(take);
            remaining -= take;
        }

        // If this read consumed the exact end of the stream, probe for EOF so
        // the gzip trailer is verified instead of silently accepting a corrupt
        // CRC or ISIZE.
        if (remaining == 0 and reader.pos >= reader.end and !reader.eof)
            try fillBuffer(reader);

        if (remaining == len) {
            lua.pushNil();
            return 1;
        }
        lua_buffer.pushResult();
        return 1;
    }

    fn read_all(lua: *Lua) !i32 {
        const reader: *GzipReader = luax.getUserData(lua, name, GzipReader);
        return read_all_contents(lua, reader);
    }

    fn read_all_contents(lua: *Lua, reader: *GzipReader) !i32 {
        try ensureOpen(reader);
        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        while (true) {
            if (reader.pos >= reader.end) {
                try fillBuffer(reader);
                if (reader.eof) break;
            }
            lua_buffer.addString(reader.buffer[reader.pos..reader.end]);
            reader.pos = reader.end;
        }

        lua_buffer.pushResult();
        return 1;
    }

    fn read_line(lua: *Lua, reader: *GzipReader, include_eol: bool) !i32 {
        try ensureOpen(reader);
        var lua_buffer: zlua.Buffer = undefined;
        lua_buffer.init(lua);

        var produced = false;
        while (true) {
            if (reader.pos >= reader.end) {
                try fillBuffer(reader);
                if (reader.eof) break;
            }

            const ch = reader.buffer[reader.pos];
            if (ch == '\n') {
                reader.pos += 1;
                if (include_eol) lua_buffer.addChar('\n');
                produced = true;
                break;
            }
            if (ch == '\r') {
                reader.pos += 1;
                if (reader.pos >= reader.end) try fillBuffer(reader);
                if (!reader.eof and reader.buffer[reader.pos] == '\n') {
                    reader.pos += 1;
                    if (include_eol) lua_buffer.addChar('\n');
                } else if (include_eol) {
                    lua_buffer.addChar('\r');
                }
                produced = true;
                break;
            }

            lua_buffer.addChar(ch);
            reader.pos += 1;
            produced = true;
        }

        if (!produced) {
            lua.pushNil();
            return 1;
        }
        lua_buffer.pushResult();
        return 1;
    }

    fn lines(lua: *Lua) i32 {
        const reader: *GzipReader = luax.getUserData(lua, name, GzipReader);
        if (reader.closed) return luaerror.ret(lua, "gzip file is closed", .{});
        lua.pushFunction(luaerror.wrap(lines_iterator));
        lua.pushValue(1);
        lua.pushNil();
        lua.pushNil();
        return 4;
    }

    fn lines_iterator(lua: *Lua) !i32 {
        const reader: *GzipReader = luax.getUserData(lua, name, GzipReader);
        return read_line(lua, reader, false);
    }

    fn seek(lua: *Lua) !i32 {
        const reader: *GzipReader = luax.getUserData(lua, name, GzipReader);
        if (reader.closed) return luaerror.ret(lua, "gzip file is closed", .{});

        const whence = std.mem.sliceTo(lua.optString(2) orelse "cur", 0);
        const offset = lua.optInteger(3) orelse 0;
        if (whence.len == 0) return luaerror.ret(lua, "invalid seek mode", .{});

        var target: i64 = 0;
        switch (whence[0]) {
            's' => target = offset,
            'c' => target = @as(i64, @intCast(reader.fpos + @as(u64, reader.pos))) + offset,
            'e' => {
                const size = try scanSize(reader);
                target = @as(i64, @intCast(size)) + offset;
            },
            else => return luaerror.ret(lua, "invalid seek mode '{s}'", .{whence}),
        }

        if (target < 0) return luaerror.ret(lua, "seek position outside of file", .{});

        try restart(reader);
        var remaining: u64 = @intCast(target);
        while (remaining > 0) {
            if (reader.pos >= reader.end) {
                try fillBuffer(reader);
                if (reader.eof) break;
            }
            const available: u64 = @intCast(reader.end - reader.pos);
            const take = @min(available, remaining);
            reader.pos += @intCast(take);
            remaining -= take;
        }

        lua.pushInteger(@intCast(reader.fpos + @as(u64, reader.pos)));
        return 1;
    }

    fn scanSize(reader: *GzipReader) !u64 {
        try restart(reader);
        var buffer: [4096]u8 = undefined;
        while (true) {
            const amount = try pump(reader, &buffer);
            if (amount == 0) break;
        }
        verifyChecksum(reader) catch |err|
            return luaerror.raise(err, "could not decompress gzip data: {s}", .{@errorName(err)});
        return reader.produced;
    }

    fn close(lua: *Lua) i32 {
        const reader: *GzipReader = luax.getUserData(lua, name, GzipReader);
        closeReader(reader);
        return 0;
    }
};

const GzipWriter = struct {
    file: std.Io.File,
    file_buffer: [64 * 1024]u8 = undefined,
    file_writer: std.Io.File.Writer = undefined,
    history: []u8,
    encoder: Encoder,
    closed: bool = false,

    const Encoder = union(enum) {
        raw: *flate.Compress.Raw,
        deflate: *flate.Compress,
    };

    const name = "_GzipWriter";
    const functions = [_]zlua.FnReg{
        .{ .name = "write", .func = zlua.wrap(write) },
        .{ .name = "flush", .func = luaerror.wrap(flush) },
        .{ .name = "close", .func = luaerror.wrap(close) },
    };

    fn register(lua: *Lua) void {
        if (lua.getMetatableRegistry(name) == .nil) {
            lua.pop(1);
            luax.registerUserData(lua, name, zlua.wrap(garbageCollect));
        } else {
            lua.pop(1);
        }
    }

    fn open(lua: *Lua, path: [:0]const u8, level: u4) !i32 {
        const file = std.Io.Dir.cwd().createFile(io, path, .{}) catch |err|
            return luaerror.ret(lua, "could not create gzip file '{s}': {s}", .{ path, @errorName(err) });
        errdefer file.close(io);

        const history = try allocator.alloc(u8, flate.max_window_len);
        errdefer allocator.free(history);

        const writer: *GzipWriter = luax.createUserDataTableSetFunctions(lua, name, GzipWriter, &functions, 0);
        writer.file = file;
        writer.history = history;
        writer.file_writer = file.writer(io, &writer.file_buffer);
        writer.encoder = undefined;
        // Mark the partially constructed userdata as closed so that a garbage
        // collection between here and successful initialisation does not try
        // to use an undefined encoder.
        writer.closed = true;

        if (level == 0) {
            const encoder = try allocator.create(flate.Compress.Raw);
            errdefer allocator.destroy(encoder);
            encoder.* = flate.Compress.Raw.init(&writer.file_writer.interface, history, .gzip) catch |err| {
                allocator.destroy(encoder);
                allocator.free(history);
                file.close(io);
                return luaerror.ret(lua, "could not start gzip compression: {s}", .{@errorName(err)});
            };
            writer.encoder = .{ .raw = encoder };
        } else {
            const encoder = try allocator.create(flate.Compress);
            errdefer allocator.destroy(encoder);
            encoder.* = flate.Compress.init(&writer.file_writer.interface, history, .gzip, compressionOptions(level)) catch |err| {
                allocator.destroy(encoder);
                allocator.free(history);
                file.close(io);
                return luaerror.ret(lua, "could not start gzip compression: {s}", .{@errorName(err)});
            };
            writer.encoder = .{ .deflate = encoder };
        }

        writer.closed = false;
        return 1;
    }

    fn garbageCollect(lua: *Lua) i32 {
        const writer: *GzipWriter = luax.getGcUserData(lua, GzipWriter);
        closeWriter(writer) catch {};
        return 0;
    }

    fn closeWriter(writer: *GzipWriter) !void {
        if (writer.closed) return;
        writer.closed = true;

        switch (writer.encoder) {
            .raw => |encoder| {
                encoder.finish() catch |err| {
                    allocator.destroy(encoder);
                    allocator.free(writer.history);
                    writer.file.close(io);
                    return err;
                };
                allocator.destroy(encoder);
            },
            .deflate => |encoder| {
                encoder.finish() catch |err| {
                    allocator.destroy(encoder);
                    allocator.free(writer.history);
                    writer.file.close(io);
                    return err;
                };
                allocator.destroy(encoder);
            },
        }
        allocator.free(writer.history);
        writer.file_writer.end() catch |err| {
            writer.file.close(io);
            return err;
        };
        writer.file.close(io);
    }

    fn write(lua: *Lua) !i32 {
        const writer: *GzipWriter = luax.getUserData(lua, name, GzipWriter);
        if (writer.closed) return luaerror.ret(lua, "gzip file is closed", .{});

        const top = lua.getTop();
        var argument: i32 = 2;
        while (argument <= top) : (argument += 1) {
            const data = lua.toString(argument) catch
                lua.argError(argument, "expecting string or number");
            switch (writer.encoder) {
                .raw => |encoder| encoder.writer.writeAll(data) catch
                    return luaerror.ret(lua, "could not write gzip data", .{}),
                .deflate => |encoder| encoder.writer.writeAll(data) catch
                    return luaerror.ret(lua, "could not write gzip data", .{}),
            }
        }

        lua.pushValue(1);
        return 1;
    }

    fn flush(lua: *Lua) !i32 {
        const writer: *GzipWriter = luax.getUserData(lua, name, GzipWriter);
        if (writer.closed) return luaerror.ret(lua, "gzip file is closed", .{});

        switch (writer.encoder) {
            .raw => |encoder| encoder.writer.flush() catch
                return luaerror.ret(lua, "could not flush gzip data", .{}),
            .deflate => |encoder| encoder.writer.flush() catch
                return luaerror.ret(lua, "could not flush gzip data", .{}),
        }
        writer.file_writer.interface.flush() catch
            return luaerror.ret(lua, "could not flush gzip file", .{});
        lua.pushValue(1);
        return 1;
    }

    fn close(lua: *Lua) !i32 {
        const writer: *GzipWriter = luax.getUserData(lua, name, GzipWriter);
        closeWriter(writer) catch |err|
            return luaerror.ret(lua, "could not close gzip file: {s}", .{@errorName(err)});
        return 0;
    }
};
