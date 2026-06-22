const std = @import("std");
const filesystem = @import("filesystem.zig");
const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const flate = std.compress.flate;
const zstd = std.compress.zstd;

const allocator = std.heap.c_allocator;

const exported_functions = [_]zlua.FnReg{
    .{ .name = "extract", .func = zlua.wrap(extract_all) },
    .{ .name = "open", .func = zlua.wrap(TarReader.new) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

pub fn luaopen_tar(lua: *Lua) i32 {
    TarReader.register(lua);
    lua.newLib(&exported_functions);
    return 1;
}

fn extract_all(lua: *Lua) i32 {
    const tarPath = filesystem.get_path_index(lua, 1);
    const extractPath = filesystem.get_path_index(lua, 2);

    var extractDir = std.Io.Dir.cwd().openDir(io, extractPath, .{ .follow_symlinks = false }) catch luax.raiseError(lua, "could not open output directory");
    defer extractDir.close(io);

    var fileReader = FileReader.init(tarPath) catch luax.raiseError(lua, "could not open tar file");
    defer fileReader.close();

    std.tar.extract(io, extractDir, fileReader.reader(), .{}) catch luax.raiseError(lua, "could not extract tar file");
    return 0;
}

const FileReader = struct {
    tarPath: []const u8,
    file: std.Io.File,
    file_buffer: [4096]u8 = undefined,
    file_reader: std.Io.File.Reader = undefined,
    decompress_buffer: [zstd.default_window_len + zstd.block_size_max]u8 = undefined,
    gzip: flate.Decompress = undefined,
    zstd: zstd.Decompress = undefined,

    pub fn init(tarPath: []const u8) !FileReader {
        return .{
            .tarPath = tarPath,
            .file = try std.Io.Dir.cwd().openFile(io, tarPath, .{}),
        };
    }

    pub fn reader(self: *FileReader) *std.Io.Reader {
        self.file_reader = self.file.reader(io, &self.file_buffer);
        const freader = &self.file_reader.interface;

        if (self.pathEndsWith(".gz") or self.pathEndsWith(".gzip") or self.pathEndsWith(".tgz")) {
            self.gzip = flate.Decompress.init(freader, flate.Container.gzip, &self.decompress_buffer);
            return &self.gzip.reader;
        } else if (self.pathEndsWith(".zstd") or self.pathEndsWith(".zst") or self.pathEndsWith(".tzstd") or self.pathEndsWith(".tzst")) {
            self.zstd = zstd.Decompress.init(freader, &self.decompress_buffer, .{});
            return &self.zstd.reader;
        } else {
            return freader;
        }
    }

    inline fn pathEndsWith(self: *FileReader, suffix: []const u8) bool {
        return self.tarPath.len > suffix.len and std.mem.eql(u8, self.tarPath[self.tarPath.len - suffix.len ..], suffix);
    }

    pub fn close(self: *FileReader) void {
        self.file.close(io);
    }
};

const TarReader = struct {
    const name = "_TarReader";

    buffer: [4096]u8 = undefined,
    file_name_buffer: [std.fs.max_path_bytes]u8 = undefined,
    link_name_buffer: [std.fs.max_path_bytes]u8 = undefined,

    file_reader: FileReader = undefined,
    reader: std.Io.File.Reader = undefined,
    iterator: std.tar.Iterator = undefined,

    file_in_tar: ?std.tar.Iterator.File = null,

    fn new(lua: *Lua) i32 {
        const path = filesystem.get_path(lua);

        const tarReader: *TarReader = luax.createUserData(lua, name, TarReader);
        tarReader.file_reader = FileReader.init(path) catch luax.raiseError(lua, "could not open tar file");

        tarReader.iterator = std.tar.Iterator.init(tarReader.file_reader.reader(), .{
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
        self.file_reader.close();
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
