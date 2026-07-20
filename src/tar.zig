const std = @import("std");
const filesystem = @import("filesystem.zig");
const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;
const luaerror = @import("luaerror.zig");

const flate = std.compress.flate;
const zstd = std.compress.zstd;
const xz = std.compress.xz;

const allocator = std.heap.c_allocator;

const exported_functions = [_]zlua.FnReg{
    .{ .name = "extract", .func = luaerror.wrap(extract_all) },
    .{ .name = "open", .func = luaerror.wrap(TarReader.new) },
    .{ .name = "create", .func = luaerror.wrap(TarWriter.new) },
    .{ .name = "config", .func = luaerror.wrap(setConfig) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

const Config = struct {
    errorHandling: luaerror.Handling = undefined,
};

pub fn register(lua: *Lua) i32 {
    TarReader.register(lua);
    TarWriter.register(lua);
    var config = setup(lua);
    config.errorHandling = luaerror.getGlobalHanding(lua);
    return 1;
}

fn setup(lua: *Lua) *Config {
    return luax.setupLibrary(lua, &exported_functions, Config, "tar");
}

pub fn setConfig(lua: *Lua) !i32 {
    lua.checkType(1, .table);
    var config = setup(lua);

    if (luax.getOptionalString(lua, "error_handling", 1)) |error_handling| {
        config.errorHandling = try luaerror.getHandling(error_handling);
    }
    return 1;
}

fn get_error_handling(lua: *Lua) !luaerror.Handling {
    const config = try lua.toUserdata(Config, Lua.upvalueIndex(1));
    return config.errorHandling;
}

fn extract_all(lua: *Lua) !i32 {
    const tarPath = try filesystem.get_path_index(lua, 1);
    const extractPath = try filesystem.get_path_index(lua, 2);

    var extractDir = std.Io.Dir.cwd().openDir(io, extractPath, .{ .follow_symlinks = false }) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not open directory '{s}': {any}", .{ extractPath, err }, try get_error_handling(lua));

    defer extractDir.close(io);

    var fileReader = FileReader.init(tarPath) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not open tar file '{s}': {any}", .{ tarPath, err }, try get_error_handling(lua));
    defer fileReader.deinit();

    const reader = fileReader.reader() catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not extract tar file '{s}': {any}", .{ tarPath, err }, try get_error_handling(lua));

    std.tar.extract(io, extractDir, reader, .{}) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not extract tar file '{s}': {any}", .{ tarPath, err }, try get_error_handling(lua));

    lua.pushBoolean(true);
    return 1;
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

    fn new(lua: *Lua) !i32 {
        const path = try filesystem.get_path(lua);

        lua.pushValue(Lua.upvalueIndex(1));
        const tarReader: *TarReader = luax.createUserData(lua, name, TarReader);
        tarReader.fileReader = FileReader.init(path) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not open tar file '{s}': {any}", .{ path, err }, try get_error_handling(lua));

        const reader = tarReader.fileReader.reader() catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not open tar file '{s}': {any}", .{ path, err }, try get_error_handling(lua));

        tarReader.iterator = std.tar.Iterator.init(reader, .{
            .file_name_buffer = &tarReader.file_name_buffer,
            .link_name_buffer = &tarReader.link_name_buffer,
        });

        lua.pushClosure(zlua.wrap(TarReader.iterate), 2);
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

    fn getSelf(lua: *Lua) !*TarReader {
        return lua.toUserdata(TarReader, Lua.upvalueIndex(2));
    }

    fn iterate(lua: *Lua) !i32 {
        const config = try lua.toUserdata(Config, Lua.upvalueIndex(1));
        const self = try lua.toUserdata(TarReader, Lua.upvalueIndex(2));

        self.file_in_tar = try self.iterator.next();
        if (self.file_in_tar) |file| {
            lua.newTable();
            const top = lua.getTop();
            luax.setTableString(lua, top, "name", file.name);
            luax.setTableString(lua, top, "type", @tagName(file.kind));
            luax.setTableInteger(lua, top, "size", @intCast(file.size));
            const size_hr = try filesystem.size_human_readable(file.size);
            luax.setTableString(lua, top, "size_hr", size_hr);
            luax.setTableString(lua, top, "link_name", file.link_name);
            luax.setTableInteger(lua, top, "mode", @intCast(file.mode));
            const mode_str = modeToPosixString(file.mode);
            luax.setTableString(lua, top, "mode_flags", &mode_str);
            luax.setTableBoolean(lua, top, "is_directory", file.kind == .directory);
            luax.setTableBoolean(lua, top, "is_file", file.kind == .file);
            luax.setTableBoolean(lua, top, "is_link", file.kind == .sym_link);
            lua.pushLightUserdata(config);
            lua.pushLightUserdata(self);
            luax.setTableClosure(lua, top, "extract", luaerror.wrap(extract), 2);
            lua.pushLightUserdata(config);
            lua.pushLightUserdata(self);
            luax.setTableClosure(lua, top, "bytes", luaerror.wrap(toslice), 2);
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

    fn toslice(lua: *Lua) !i32 {
        const self = try getSelf(lua);

        if (self.file_in_tar) |file| {
            if (file.kind == .file) {
                var lua_buffer: zlua.Buffer = undefined;
                const buffer = lua_buffer.initSize(lua, file.size);

                var writer: std.Io.Writer = .fixed(buffer);
                self.iterator.streamRemaining(file, &writer) catch |err|
                    return luaerror.raiseOrReturn(lua, err, "could not extract '{s}' from tar: {any}", .{ file.name, err }, try get_error_handling(lua));
                writer.flush() catch |err|
                    return luaerror.raiseOrReturn(lua, err, "could not extract '{s}' from tar: {any}", .{ file.name, err }, try get_error_handling(lua));

                lua_buffer.pushResultSize(@intCast(file.size));
                return 1;
            }
        }
        return error.NoRegularFile;
    }

    fn extract(lua: *Lua) !i32 {
        const self = try getSelf(lua);
        const path = try filesystem.get_path(lua);

        if (self.file_in_tar) |file| {
            if (file.kind == .file) {
                const ext_file = std.Io.Dir.cwd().createFile(io, path, .{}) catch |err|
                    return luaerror.raiseOrReturn(lua, err, "could not extract '{s}' from tar: {any}", .{ file.name, err }, try get_error_handling(lua));
                defer ext_file.close(io);

                var writer = ext_file.writer(io, &self.buffer);

                self.iterator.streamRemaining(file, &writer.interface) catch |err|
                    return luaerror.raiseOrReturn(lua, err, "could not extract '{s}' from tar: {any}", .{ file.name, err }, try get_error_handling(lua));
                writer.flush() catch |err|
                    return luaerror.raiseOrReturn(lua, err, "could not extract '{s}' from tar: {any}", .{ file.name, err }, try get_error_handling(lua));

                return 0;
            }
        }
        return error.NoRegularFile;
    }
};

const Compression = enum {
    uncompressed,
    gzip,
};

const FileWriter = struct {
    tarPath: []const u8,
    compression: Compression,
    file: ?std.Io.File = null,
    file_buffer: [4096]u8 = undefined,
    file_writer: std.Io.File.Writer = undefined,

    compressor_buffer: ?[]u8 = null,
    compressor: union(Compression) {
        uncompressed: void,
        gzip: flate.Compress,
    } = .uncompressed,
    closed: bool = false,

    pub fn init(tarPath: []const u8, compression: Compression) FileWriter {
        return .{
            .tarPath = tarPath,
            .compression = compression,
        };
    }

    pub fn writer(self: *FileWriter, opts: std.compress.flate.Compress.Options) !*std.Io.Writer {
        self.file = try std.Io.Dir.cwd().createFile(io, self.tarPath, .{});
        self.file_writer = self.file.?.writer(io, &self.file_buffer);
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
            if (self.file) |file| {
                switch (self.compressor) {
                    .gzip => {
                        try self.compressor.gzip.finish();
                        self.freeBuffer();
                    },
                    else => {},
                }
                try self.file_writer.flush();
                file.close(io);
            }
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
        .{ .name = "setRoot", .func = luaerror.wrap(setRoot) },
        .{ .name = "add_dir", .func = luaerror.wrap(addDir) },
        .{ .name = "add_file", .func = luaerror.wrap(addFile) },
        .{ .name = "add_file_bytes", .func = luaerror.wrap(addFileBytes) },
        .{ .name = "add_link", .func = luaerror.wrap(addLink) },
        .{ .name = "close", .func = luaerror.wrap(close) },
    };

    fileWriter: FileWriter = undefined,
    writer: std.tar.Writer,

    fn new(lua: *Lua) !i32 {
        const path = try filesystem.get_path(lua);
        const level = toLevel(lua.toString(2) catch "default");

        var compression: Compression = .uncompressed;

        if (pathEndsWith(path, ".gz") or pathEndsWith(path, ".tgz")) {
            compression = .gzip;
        }
        const tarWriter = luax.createUserDataTable(lua, name, TarWriter);
        lua.pushValue(Lua.upvalueIndex(1));
        lua.setFuncs(&functions, 1);

        luax.setTableRegistryFunctions(lua, "zli_tar", &lua_functions);
        tarWriter.fileWriter = FileWriter.init(path, compression);
        const writer = tarWriter.fileWriter.writer(level) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not create tar file '{s}': {any}", .{ path, err }, try get_error_handling(lua));
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
        return .default;
    }

    inline fn pathEndsWith(path: [:0]const u8, suffix: []const u8) bool {
        return path.len > suffix.len and std.mem.eql(u8, path[path.len - suffix.len ..], suffix);
    }

    fn register(lua: *Lua) void {
        luax.registerUserData(lua, name, zlua.wrap(garbageCollect));
    }

    fn garbageCollect(lua: *Lua) !i32 {
        const self: *TarWriter = luax.getGcUserData(lua, TarWriter);
        self.fileWriter.deinit() catch lua.raiseErrorStr("could flush output", .{});
        return 0;
    }

    fn getSelf(lua: *Lua) *TarWriter {
        return luax.getUserDataIndex(lua, name, TarWriter, 1);
    }

    fn setRoot(lua: *Lua) !i32 {
        const tarWriter = getSelf(lua);
        const path = luax.getArgStringOrError(lua, 2, "expecting a file path as 1st argument");

        tarWriter.writer.setRoot(path) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not set root to '{s}': {any}", .{ path, err }, try get_error_handling(lua));

        lua.pushValue(1);
        return 1;
    }

    fn addDir(lua: *Lua) !i32 {
        const tarWriter = getSelf(lua);
        const path = pathToTar(tarWriter.writer, luax.getArgStringOrError(lua, 2, "expecting a file path as 1st argument"));

        tarWriter.writer.writeDir(path, .{}) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not set add directory '{s}': {any}", .{ path, err }, try get_error_handling(lua));

        lua.pushValue(1);
        return 1;
    }

    fn addFileBytes(lua: *Lua) !i32 {
        const tarWriter = getSelf(lua);
        const path = luax.getArgStringOrError(lua, 2, "expecting a file path as 1st argument");
        const content = luax.getArgStringOrError(lua, 3, "expecting a file data as 2st argument");

        tarWriter.writer.writeFileBytes(path, content, .{}) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not add file '{s}': {any}", .{ path, err }, try get_error_handling(lua));

        lua.pushValue(1);
        return 1;
    }

    fn addFile(lua: *Lua) !i32 {
        const tarWriter = getSelf(lua);
        const file_path = try filesystem.get_path_index(lua, 2);
        const path = pathToTar(tarWriter.writer, luax.getArgStringOrError(lua, 3, "expecting a file path as 2nd argument"));

        var input_file = std.Io.Dir.cwd().openFile(io, file_path, .{}) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not open input file '{s}': {any}", .{ file_path, err }, try get_error_handling(lua));
        defer input_file.close(io);

        const stats = try input_file.stat(io);
        var buffer: [4096]u8 = undefined;
        var reader = input_file.reader(io, &buffer);

        tarWriter.writer.writeFileStream(path, stats.size, &reader.interface, .{}) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not append input file '{s}': {any}", .{ file_path, err }, try get_error_handling(lua));

        lua.pushValue(1);
        return 1;
    }

    fn addLink(lua: *Lua) !i32 {
        const tarWriter = getSelf(lua);
        const sub_path = luax.getArgStringOrError(lua, 2, "expecting path");
        const link_name = luax.getArgStringOrError(lua, 3, "expecting link name");

        tarWriter.writer.writeLink(sub_path, link_name, .{}) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not append link '{s}' to '{s}': {any}", .{ link_name, sub_path, err }, try get_error_handling(lua));

        lua.pushValue(1);
        return 1;
    }

    fn close(lua: *Lua) !i32 {
        const tarWriter = getSelf(lua);

        tarWriter.fileWriter.deinit() catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not close tar file: {any}", .{err}, try get_error_handling(lua));

        return 0;
    }
};

var pathToTar_buffer: [1024]u8 = undefined;
fn pathToTar(writer: std.tar.Writer, path: [:0]const u8) []const u8 {
    _ = std.mem.replace(u8, path, "\\", "/", &pathToTar_buffer);
    if (writer.prefix.len > 0) {
        if (path.len >= writer.prefix.len and std.mem.eql(u8, writer.prefix, path[0..writer.prefix.len])) {
            return pathToTar_buffer[writer.prefix.len..];
        }
    }
    return pathToTar_buffer[0..path.len];
}
