const std = @import("std");
const filesystem = @import("filesystem.zig");
const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const allocator = std.heap.c_allocator;

const exported_functions = [_]zlua.FnReg{
    .{ .name = "extract", .func = zlua.wrap(extract) },
    .{ .name = "open", .func = zlua.wrap(open) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

pub fn luaopen_tar(lua: *Lua) i32 {
    lua.newLib(&exported_functions);
    return 1;
}

fn extract(lua: *Lua) i32 {
    const tarPath = filesystem.get_path_index(lua, 1);
    const extractPath = filesystem.get_path_index(lua, 2);
    var buffer: [4096]u8 = undefined;

    var extractDir = std.Io.Dir.cwd().openDir(io, extractPath, .{ .follow_symlinks = false }) catch luax.raiseError(lua, "could not open output directory");
    defer extractDir.close(io);

    var file = std.Io.Dir.cwd().openFile(io, tarPath, .{}) catch luax.raiseError(lua, "could not open tar file");
    var reader = file.reader(io, &buffer);

    std.tar.extract(io, extractDir, &reader.interface, .{}) catch luax.raiseError(lua, "could not extract tar file");

    return 0;
}

fn open(lua: *Lua) i32 {
    const path = filesystem.get_path(lua);
    const tar = TarReader.init(path) catch luax.raiseError(lua, "could not open tar file");
    lua.pushLightUserdata(@ptrCast(tar));
    lua.pushClosure(zlua.wrap(iterate), 1);
    return 1;
}

fn iterate(lua: *Lua) i32 {
    const tar = lua.toUserdata(TarReader, Lua.upvalueIndex(1)) catch luax.raiseError(lua, "could not get TarReader");
    const file_in_tar = tar.next() catch luax.raiseError(lua, "could not iterate on tar file");
    if (file_in_tar) |file| {
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
        lua.pushLightUserdata(tar);
        luax.setTableClosure(lua, -2, "extract", zlua.wrap(extract_file), 1);
    } else {
        lua.pushNil();
    }
    return 1;
}

fn extract_file(lua: *Lua) i32 {
    const tar = lua.toUserdata(TarReader, Lua.upvalueIndex(1)) catch luax.raiseError(lua, "could not get TarReader");
    const path = filesystem.get_path(lua);
    tar.extract(path) catch luax.raiseError(lua, "could not extract file form tar");
    return 0;
}

pub fn modeToPosixString(mode: u32) [10]u8 {
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

const TarReader = struct {
    buffer: [4096]u8 = undefined,
    file_name_buffer: [std.fs.max_path_bytes]u8 = undefined,
    link_name_buffer: [std.fs.max_path_bytes]u8 = undefined,

    file: std.Io.File = undefined,
    reader: std.Io.File.Reader = undefined,
    iterator: std.tar.Iterator = undefined,

    file_in_tar: ?std.tar.Iterator.File = null,

    fn init(path: []const u8) !*TarReader {
        var tarReader = try allocator.create(TarReader);

        tarReader.file = try std.Io.Dir.cwd().openFile(io, path, .{});
        tarReader.reader = tarReader.file.reader(io, &tarReader.buffer);

        tarReader.iterator = std.tar.Iterator.init(&tarReader.reader.interface, .{
            .file_name_buffer = &tarReader.file_name_buffer,
            .link_name_buffer = &tarReader.link_name_buffer,
        });

        return tarReader;
    }

    pub fn next(self: *TarReader) !?std.tar.Iterator.File {
        self.file_in_tar = null;
        self.file_in_tar = try self.iterator.next();
        return self.file_in_tar;
    }

    pub fn toslice(self: *TarReader) ![]u8 {
        if (self.file_in_tar) |file| {
            if (file.kind == .file) {
                const slice = try self.allocator.alloc(u8, file.size);
                var writer: std.Io.Writer = .fixed(slice);
                try self.iterator.streamRemaining(file, &writer);
                try writer.flush();
                return slice;
            }
        }
        return error.NotARegularFile;
    }

    pub fn extract(self: *TarReader, path: []const u8) !void {
        if (self.file_in_tar) |file| {
            if (file.kind == .file) {
                const ext_file = try std.Io.Dir.cwd().createFile(io, path, .{});
                defer ext_file.close(io);

                var buffer: [4096]u8 = undefined;
                var writer = ext_file.writer(io, &buffer);

                try self.iterator.streamRemaining(file, &writer.interface);
                try writer.flush();
                return;
            }
        }
        return error.NotARegularFile;
    }

    pub fn deinit(self: *TarReader) void {
        self.file.close(io);
        allocator.destroy(self);
    }
};
