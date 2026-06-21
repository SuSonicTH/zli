const std = @import("std");
const filesystem = @import("filesystem.zig");
const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const allocator = std.heap.c_allocator;

const exported_functions = [_]zlua.FnReg{
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

fn open(lua: *Lua) i32 {
    const path = filesystem.get_path(lua);
    std.log.debug("PATH: {s}", .{path});
    const tar = TarReader.init(path) catch luax.raiseError(lua, "could not open tar file");
    lua.pushLightUserdata(@ptrCast(tar));
    lua.pushClosure(zlua.wrap(iterate), 1);
    return 1;
}

fn iterate(lua: *Lua) i32 {
    const tar = lua.toUserdata(TarReader, Lua.upvalueIndex(1)) catch luax.raiseError(lua, "could not get TarReader");
    const file_in_tar = tar.next() catch luax.raiseError(lua, "could not iterate on tar file");
    if (file_in_tar) |file| {
        _ = lua.pushString(file.name);
    } else {
        lua.pushNil();
    }
    return 1;
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

//pub fn main(init: std.process.Init) !void {
//    var tar = try TarReader.init(init.io, "test.tar", init.arena.allocator());
//    defer tar.deinit();
//    while (try tar.next()) |file| {
//        std.log.info("{s} {any}", .{ file.name, file.kind });
//        if (std.mem.eql(u8, "src/uuid.zig", file.name)) {
//            std.log.info("{s}", .{try tar.toslice()});
//        } else if (std.mem.eql(u8, "src/zip.lua", file.name)) {
//            try tar.extract("tartest/zip.lua");
//        }
//    }
//}

//pub fn main(init: std.process.Init) !void {
//    const tarFile = try std.Io.Dir.cwd().openFile(init.io, "test.tar", .{});
//    defer tarFile.close(init.io);
//    var buffer: [4096]u8 = undefined;
//
//    var reader_interface = tarFile.reader(init.io, &buffer);
//    const reader = &reader_interface.interface;
//
//    var file_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
//    var link_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
//
//    var it = std.tar.Iterator.init(reader, .{
//        .file_name_buffer = &file_name_buffer,
//        .link_name_buffer = &link_name_buffer,
//    });
//    while (try it.next()) |file| {
//        std.log.info("{s} {any}", .{ file.name, file.kind });
//        if (std.mem.eql(u8, file.name, "src/uuid.zig")) {
//            var stdout_buffer: [4096]u8 = undefined;
//            var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
//            const stdout = &stdout_writer.interface;
//            try it.streamRemaining(file, stdout);
//            try stdout.flush();
//        }
//    }
//}
