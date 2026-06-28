const std = @import("std");
const filesystem = @import("filesystem.zig");
const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const flate = std.compress.flate;
const zstd = std.compress.zstd;
const xz = std.compress.xz;

const allocator = std.heap.c_allocator;

const exported_functions = [_]zlua.FnReg{
    .{ .name = "extract", .func = zlua.wrap(extract_all) },
    .{ .name = "open", .func = zlua.wrap(TarReader.new) },
    .{ .name = "create", .func = zlua.wrap(TarWriter.new) },
};

const zli_tar = "zli_tar";

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

pub fn luaopen_tar(lua: *Lua) i32 {
    TarReader.register(lua);
    TarWriter.register(lua);
    lua.newLib(&exported_functions);
    luax.registerExtended(lua, @embedFile("tar.lua"), "tar", zli_tar);
    return 1;
}

fn extract_all(lua: *Lua) i32 {
    const tarPath = filesystem.get_path_index(lua, 1);
    const extractPath = filesystem.get_path_index(lua, 2);

    var extractDir = std.Io.Dir.cwd().openDir(io, extractPath, .{ .follow_symlinks = false }) catch luax.raiseError(lua, "could not open output directory");
    defer extractDir.close(io);

    var fileReader = FileReader.init(tarPath) catch luax.raiseError(lua, "could not open tar file");
    defer fileReader.deinit();

    const reader = fileReader.reader() catch luax.raiseError(lua, "could not allocate memory");
    std.tar.extract(io, extractDir, reader, .{}) catch luax.raiseError(lua, "could not extract tar file");
    return 0;
}

const DeCompression = enum {
    uncompressed,
    gzip,
    zstd,
    xz,
};

const FileReader = struct {
    tarPath: []const u8,

    file: std.Io.File,
    file_buffer: [4096]u8 = undefined,
    file_reader: std.Io.File.Reader = undefined,
    decompress_buffer: ?[]u8 = null,
    decompressor: union(DeCompression) {
        uncompressed: void,
        gzip: flate.Decompress,
        zstd: zstd.Decompress,
        xz: xz.Decompress,
    } = .uncompressed,

    pub fn init(tarPath: []const u8) !FileReader {
        return .{
            .tarPath = tarPath,
            .file = try std.Io.Dir.cwd().openFile(io, tarPath, .{}),
        };
    }

    pub fn reader(self: *FileReader) !*std.Io.Reader {
        self.file_reader = self.file.reader(io, &self.file_buffer);
        const freader = &self.file_reader.interface;
        std.log.info("{any}", .{self.decompressor});
        if (self.pathEndsWith(".gz") or self.pathEndsWith(".gzip") or self.pathEndsWith(".tgz")) {
            self.decompress_buffer = try allocator.alloc(u8, flate.max_window_len);
            self.decompressor = .{ .gzip = flate.Decompress.init(freader, flate.Container.gzip, self.decompress_buffer.?) };
            return &self.decompressor.gzip.reader;
        } else if (self.pathEndsWith(".zstd") or self.pathEndsWith(".zst") or self.pathEndsWith(".tzstd") or self.pathEndsWith(".tzst")) {
            self.decompress_buffer = try allocator.alloc(u8, zstd.default_window_len + zstd.block_size_max);
            self.decompressor = .{ .zstd = zstd.Decompress.init(freader, self.decompress_buffer.?, .{}) };
            return &self.decompressor.zstd.reader;
        } else if (self.pathEndsWith(".xz") or self.pathEndsWith(".txz")) {
            self.decompress_buffer = try allocator.alloc(u8, 4 * 1024);
            self.decompressor = .{ .xz = try xz.Decompress.init(freader, allocator, self.decompress_buffer.?) };
            return &self.decompressor.xz.reader;
        } else {
            return freader;
        }
    }

    inline fn pathEndsWith(self: *FileReader, suffix: []const u8) bool {
        return self.tarPath.len > suffix.len and std.mem.eql(u8, self.tarPath[self.tarPath.len - suffix.len ..], suffix);
    }

    fn freeBuffer(self: *FileReader) void {
        if (self.decompress_buffer) |buffer| {
            allocator.free(buffer);
        }
    }

    pub fn deinit(self: *FileReader) void {
        switch (self.decompressor) {
            .gzip, .zstd => self.freeBuffer(),
            .xz => |*x| x.deinit(),
            else => {},
        }
        self.file.close(io);
    }
};

const TarReader = struct {
    const name = "_TarReader";

    buffer: [4096]u8 = undefined,
    file_name_buffer: [std.fs.max_path_bytes]u8 = undefined,
    link_name_buffer: [std.fs.max_path_bytes]u8 = undefined,

    fileReader: FileReader = undefined,
    reader: std.Io.File.Reader = undefined,
    iterator: std.tar.Iterator = undefined,

    file_in_tar: ?std.tar.Iterator.File = null,

    fn new(lua: *Lua) i32 {
        const path = filesystem.get_path(lua);

        const tarReader: *TarReader = luax.createUserData(lua, name, TarReader);
        tarReader.fileReader = FileReader.init(path) catch luax.raiseError(lua, "could not open tar file");
        const reader = tarReader.fileReader.reader() catch luax.raiseError(lua, "could not allocate memory");
        tarReader.iterator = std.tar.Iterator.init(reader, .{
            .file_name_buffer = &tarReader.file_name_buffer,
            .link_name_buffer = &tarReader.link_name_buffer,
        });

        lua.pushClosure(zlua.wrap(TarReader.iterate), 1);
        return 1;
    }

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, zlua.wrap(garbageCollect));
    }

    fn garbageCollect(lua: *Lua) i32 {
        const self: *TarReader = luax.getGcUserData(lua, TarReader);
        self.fileReader.deinit();
        return 0;
    }

    fn getSelf(lua: *Lua) *TarReader {
        return lua.toUserdata(TarReader, Lua.upvalueIndex(1)) catch luax.raiseError(lua, "could not get TarReader");
    }

    fn iterate(lua: *Lua) i32 {
        const self = getSelf(lua);
        self.file_in_tar = self.iterator.next() catch luax.raiseError(lua, "could not iterate on tar file");
        if (self.file_in_tar) |file| {
            lua.newTable();
            luax.setTableString(lua, -1, "name", file.name);
            luax.setTableString(lua, -1, "type", @tagName(file.kind));
            luax.setTableInteger(lua, -1, "size", @intCast(file.size));
            const size_hr = filesystem.size_human_readable(file.size) catch luax.raiseError(lua, "could not convert size to size_hr");
            luax.setTableString(lua, -1, "size_hr", size_hr);
            luax.setTableString(lua, -1, "link_name", file.link_name);
            luax.setTableInteger(lua, -1, "mode", @intCast(file.mode));
            luax.setTableString(lua, -1, "mode_flags", &modeToPosixString(file.mode));
            luax.setTableBoolean(lua, -1, "is_directory", file.kind == .directory);
            luax.setTableBoolean(lua, -1, "is_file", file.kind == .file);
            luax.setTableBoolean(lua, -1, "is_link", file.kind == .sym_link);
            lua.pushLightUserdata(self);
            luax.setTableClosure(lua, -2, "extract", zlua.wrap(extract), 1);
            lua.pushLightUserdata(self);
            luax.setTableClosure(lua, -2, "bytes", zlua.wrap(toslice), 1);
        } else {
            lua.pushNil();
        }
        return 1;
    }

    fn modeToPosixString(mode: u32) [10]u8 {
        // 0o170000 is the POSIX bitmask for file types
        const file_type: u8 = switch (mode & 0o170000) {
            0o140000 => 's', // Socket
            0o120000 => 'l', // Symlink
            0o100000 => '-', // Regular file
            0o060000 => 'b', // Block device
            0o040000 => 'd', // Directory
            0o020000 => 'c', // Character device
            0o010000 => 'p', // FIFO / pipe
            0 => '-', // Raw permission passed without a type; default to file
            else => '?', // Unknown
        };

        return .{
            file_type,
            if ((mode & 0o0400) != 0) 'r' else '-',
            if ((mode & 0o0200) != 0) 'w' else '-',
            if ((mode & 0o0100) != 0) 'x' else '-',
            if ((mode & 0o0040) != 0) 'r' else '-',
            if ((mode & 0o0020) != 0) 'w' else '-',
            if ((mode & 0o0010) != 0) 'x' else '-',
            if ((mode & 0o0004) != 0) 'r' else '-',
            if ((mode & 0o0002) != 0) 'w' else '-',
            if ((mode & 0o0001) != 0) 'x' else '-',
        };
    }

    fn toslice(lua: *Lua) i32 {
        const self = getSelf(lua);
        if (self.file_in_tar) |file| {
            if (file.kind == .file) {
                const slice = allocator.alloc(u8, file.size) catch luax.raiseError(lua, "could not allocate memory");
                var writer: std.Io.Writer = .fixed(slice);
                self.iterator.streamRemaining(file, &writer) catch luax.raiseError(lua, "could not read file");
                writer.flush() catch luax.raiseError(lua, "could not read file");
                _ = lua.pushString(slice);
                return 1;
            }
        }
        luax.raiseError(lua, "not a regular file");
    }

    fn extract(lua: *Lua) i32 {
        const self = getSelf(lua);
        const path = filesystem.get_path(lua);
        if (self.file_in_tar) |file| {
            if (file.kind == .file) {
                const ext_file = std.Io.Dir.cwd().createFile(io, path, .{}) catch luax.raiseError(lua, "could not open directory");
                defer ext_file.close(io);

                var writer = ext_file.writer(io, &self.buffer);

                self.iterator.streamRemaining(file, &writer.interface) catch luax.raiseError(lua, "could not read file");
                writer.flush() catch luax.raiseError(lua, "could not read file");

                return 0;
            }
        }
        luax.raiseError(lua, "not a regular file");
    }
};

const Compression = enum {
    uncompressed,
    gzip,
};

const FileWriter = struct {
    tarPath: []const u8,
    compression: Compression,
    file: std.Io.File = undefined,
    file_buffer: [4096]u8 = undefined,
    file_writer: std.Io.File.Writer = undefined,

    compressor_buffer: ?[]u8 = null,
    compressor: union(Compression) {
        uncompressed: void,
        gzip: flate.Compress,
    } = undefined,
    closed: bool = false,

    pub fn init(tarPath: []const u8, compression: Compression) !FileWriter {
        return .{
            .tarPath = tarPath,
            .compression = compression,
            .file = try std.Io.Dir.cwd().createFile(io, tarPath, .{}),
        };
    }

    pub fn writer(self: *FileWriter, opts: std.compress.flate.Compress.Options) !*std.Io.Writer {
        self.file_writer = self.file.writer(io, &self.file_buffer);
        const fwriter = &self.file_writer.interface;
        switch (self.compression) {
            .uncompressed => {
                return fwriter;
            },
            .gzip => {
                self.compressor_buffer = try allocator.alloc(u8, flate.max_window_len);
                self.compressor = .{
                    .gzip = try std.compress.flate.Compress.init(fwriter, self.compressor_buffer.?, .gzip, opts),
                };
                return &self.compressor.gzip.writer;
            },
        }
    }

    fn freeBuffer(self: *FileWriter) void {
        if (self.compressor_buffer) |buffer| {
            allocator.free(buffer);
        }
    }

    pub fn deinit(self: *FileWriter) !void {
        if (!self.closed) {
            switch (self.compressor) {
                .gzip => {
                    try self.compressor.gzip.finish();
                    self.freeBuffer();
                },
                else => {},
            }
            try self.file_writer.flush();
            self.file.close(io);
            self.closed = true;
        }
    }
};

const TarWriter = struct {
    const name = "_TarWriter";
    const lua_functions = [_][:0]const u8{
        "archive_path",
    };

    const functions = [_]zlua.FnReg{
        .{ .name = "add", .func = zlua.wrap(add) },
        .{ .name = "setRoot", .func = zlua.wrap(setRoot) },
        .{ .name = "addDir", .func = zlua.wrap(addDir) },
        .{ .name = "addFile", .func = zlua.wrap(addFile) },
        .{ .name = "close", .func = zlua.wrap(close) },
    };

    fileWriter: FileWriter = undefined,
    writer: std.tar.Writer,

    fn new(lua: *Lua) i32 {
        const path = filesystem.get_path(lua);
        const slevel = lua.toString(2) catch "default";
        const level = toLevel(slevel);
        std.log.info("{s} {any}", .{ slevel, level });
        var compression: Compression = .uncompressed;

        if (pathEndsWith(path, ".gz") or pathEndsWith(path, ".tgz")) {
            compression = .gzip;
        }

        const tarWriter = luax.createUserDataTableSetFunctions(lua, name, TarWriter, &functions);
        luax.setTableRegistryFunctions(lua, zli_tar, &lua_functions);

        tarWriter.fileWriter = FileWriter.init(path, compression) catch luax.raiseError(lua, "could not open output file");
        const writer = tarWriter.fileWriter.writer(level) catch luax.raiseError(lua, "could not open output file");
        tarWriter.writer = std.tar.Writer{ .underlying_writer = writer };

        return 1;
    }

    inline fn toLevel(level: [:0]const u8) std.compress.flate.Compress.Options {
        if (std.mem.eql(u8, level, "default")) return .default;
        if (std.mem.eql(u8, level, "fastest")) return .fastest;
        if (std.mem.eql(u8, level, "best")) return .best;
        if (std.mem.eql(u8, level, "1")) return .level_1;
        if (std.mem.eql(u8, level, "2")) return .level_2;
        if (std.mem.eql(u8, level, "3")) return .level_3;
        if (std.mem.eql(u8, level, "4")) return .level_4;
        if (std.mem.eql(u8, level, "5")) return .level_5;
        if (std.mem.eql(u8, level, "6")) return .level_6;
        if (std.mem.eql(u8, level, "7")) return .level_7;
        if (std.mem.eql(u8, level, "8")) return .level_8;
        if (std.mem.eql(u8, level, "9")) return .level_9;
        @panic("ERR"); //return .default;
    }

    inline fn pathEndsWith(path: [:0]const u8, suffix: []const u8) bool {
        return path.len > suffix.len and std.mem.eql(u8, path[path.len - suffix.len ..], suffix);
    }

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, zlua.wrap(garbageCollect));
    }

    fn garbageCollect(lua: *Lua) i32 {
        const self: *TarWriter = luax.getGcUserData(lua, TarWriter);
        self.fileWriter.deinit() catch luax.raiseError(lua, "could flush output");
        return 0;
    }

    fn getSelf(lua: *Lua) *TarWriter {
        return luax.getUserData(lua, name, TarWriter);
    }

    fn add(lua: *Lua) i32 {
        const tarWriter = getSelf(lua);
        const path = luax.getArgStringOrError(lua, 2, "expecting a file path as 1st argument");
        const content = luax.getArgStringOrError(lua, 3, "expecting a file data as 2st argument");
        tarWriter.writer.writeFileBytes(path, content, .{}) catch luax.raiseError(lua, "could not write to tar file");
        lua.pushValue(1);
        return 1;
    }

    fn setRoot(lua: *Lua) i32 {
        const tarWriter = getSelf(lua);
        const path = luax.getArgStringOrError(lua, 2, "expecting a file path as 1st argument");
        tarWriter.writer.setRoot(path) catch luax.raiseError(lua, "could not write to tar file");
        lua.pushValue(1);
        return 1;
    }

    fn addDir(lua: *Lua) i32 {
        const tarWriter = getSelf(lua);
        const path = luax.getArgStringOrError(lua, 2, "expecting a file path as 1st argument");
        tarWriter.writer.writeDir(path, .{}) catch luax.raiseError(lua, "could not write to tar file");
        lua.pushValue(1);
        return 1;
    }

    fn addFile(lua: *Lua) i32 {
        const tarWriter = getSelf(lua);
        const file_path = filesystem.get_path_index(lua, 2);
        var path: [:0]const u8 = undefined;
        if (lua.getTop() == 2) {
            path = file_path;
        } else {
            path = luax.getArgStringOrError(lua, 3, "expecting a file path as 1st argument");
        }

        var input_file = std.Io.Dir.cwd().openFile(io, file_path, .{}) catch luax.raiseError(lua, "could not open input file");
        defer input_file.close(io);

        const stats = input_file.stat(io) catch luax.raiseError(lua, "could not stat input file");
        var buffer: [4096]u8 = undefined;
        var reader = input_file.reader(io, &buffer);

        tarWriter.writer.writeFileStream(path, stats.size, &reader.interface, .{}) catch luax.raiseError(lua, "could not write to tar file");
        lua.pushValue(1);
        return 1;
    }

    fn close(lua: *Lua) i32 {
        const tarWriter = getSelf(lua);
        tarWriter.fileWriter.deinit() catch luax.raiseError(lua, "could not write to tar file");
        return 0;
    }
};
