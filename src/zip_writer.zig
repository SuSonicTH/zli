//! ZIP archive writing built on `std.compress.flate`.
//!
//! The module is deliberately independent of Lua so the payload builder can
//! use the same implementation as the `zip` binding.

const std = @import("std");
const Io = std.Io;
const File = std.Io.File;
const flate = std.compress.flate;
const zip = std.zip;
const zip_reader = @import("zip_reader.zig");
const dos_time = @import("dos_time.zig");

const file_buffer_size = 64 * 1024;

pub const Options = struct {
    level: u4 = 6,
    comment: []const u8 = "",
    dos_time: ?u16 = null,
    dos_date: ?u16 = null,
};

pub const DosDateTime = dos_time.DosDateTime;

const Current = struct {
    name: []u8,
    comment: []u8,
    local_offset: u64,
    data_start: u64,
    method: zip.CompressionMethod,
    flags: u16,
    dos_time: u16,
    dos_date: u16,
    crc: std.hash.Crc32 = .init(),
    uncompressed: u64 = 0,
    compressed: u64 = 0,
    encoder: ?*flate.Compress = null,
    history: ?[]u8 = null,
};

pub const Writer = struct {
    allocator: std.mem.Allocator,
    io: Io,
    file: File,
    file_buffer: [file_buffer_size]u8 = undefined,
    file_writer: File.Writer = undefined,

    old_central_dir: []u8 = &.{},
    old_comment: []u8 = &.{},
    old_entry_count: u64 = 0,
    offset_base: u64 = 0,
    new_central_dir: Io.Writer.Allocating,

    current: ?Current = null,
    new_entry_count: u64 = 0,
    closed: bool = false,

    pub fn create(allocator: std.mem.Allocator, io: Io, path: []const u8) !*Writer {
        const file = try Io.Dir.cwd().createFile(io, path, .{});
        errdefer file.close(io);
        return initOwned(allocator, io, file, null);
    }

    pub fn createAfter(allocator: std.mem.Allocator, io: Io, path: []const u8) !*Writer {
        const file = try Io.Dir.cwd().openFile(io, path, .{ .mode = .read_write });
        errdefer file.close(io);

        const stat = try file.stat(io);
        const self = try initOwned(allocator, io, file, stat.size);
        return self;
    }

    pub fn open(allocator: std.mem.Allocator, io: Io, path: []const u8) !*Writer {
        const file = try Io.Dir.cwd().openFile(io, path, .{ .mode = .read_write });
        errdefer file.close(io);

        var read_buffer: [4096]u8 = undefined;
        var reader = file.reader(io, &read_buffer);
        const layout = try zip_reader.findLayout(&reader);

        const central_dir_size: usize = std.math.cast(usize, layout.central_directory_size) orelse
            return error.ZipCentralDirectoryTooLarge;
        var old_central_dir = try allocator.alloc(u8, central_dir_size);
        errdefer allocator.free(old_central_dir);
        if (central_dir_size > 0) {
            try reader.seekTo(layout.central_directory_start);
            reader.interface.readSliceAll(old_central_dir) catch |err| switch (err) {
                error.ReadFailed => return reader.err orelse error.ReadFailed,
                else => |e| return e,
            };
            old_central_dir = try stripDigitalSignature(allocator, old_central_dir);
        }

        const old_comment = try allocator.alloc(u8, layout.comment_len);
        errdefer allocator.free(old_comment);
        if (old_comment.len > 0) {
            try reader.seekTo(layout.comment_offset);
            reader.interface.readSliceAll(old_comment) catch |err| switch (err) {
                error.ReadFailed => return reader.err orelse error.ReadFailed,
                else => |e| return e,
            };
        }

        const self = try initOwned(allocator, io, file, layout.central_directory_start);
        self.old_central_dir = old_central_dir;
        self.old_comment = old_comment;
        self.old_entry_count = layout.entry_count;
        self.offset_base = layout.offset_base;
        return self;
    }

    fn initOwned(
        allocator: std.mem.Allocator,
        io: Io,
        file: File,
        start_position: ?u64,
    ) !*Writer {
        const self = try allocator.create(Writer);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .io = io,
            .file = file,
            .new_central_dir = .init(allocator),
        };
        self.file_writer = file.writer(io, &self.file_buffer);
        if (start_position) |position| {
            try self.file_writer.seekTo(position);
        }
        return self;
    }

    pub fn deinit(self: *Writer) void {
        if (!self.closed) self.close(null) catch {};
        self.allocator.free(self.old_central_dir);
        self.allocator.free(self.old_comment);
        self.new_central_dir.deinit();
        self.allocator.destroy(self);
    }

    pub fn beginEntry(self: *Writer, name: []const u8, options: Options) !void {
        if (self.closed) return error.ZipClosed;
        try self.endEntry();

        if (name.len > std.math.maxInt(u16)) return error.ZipNameTooLong;
        if (options.comment.len > std.math.maxInt(u16)) return error.ZipCommentTooLong;

        const now = dos_time.now(self.io);
        const dos_time_value = options.dos_time orelse now.time;
        const dos_date = options.dos_date orelse now.date;
        const method: zip.CompressionMethod = if (options.level == 0) .store else .deflate;
        const flags = utf8Flags(name, options.comment);
        const local_offset = self.file_writer.logicalPos();

        const owned_name = try self.allocator.dupe(u8, name);
        const owned_comment = self.allocator.dupe(u8, options.comment) catch |err| {
            self.allocator.free(owned_name);
            return err;
        };

        var current: Current = .{
            .name = owned_name,
            .comment = owned_comment,
            .local_offset = local_offset,
            .data_start = 0,
            .method = method,
            .flags = flags,
            .dos_time = dos_time_value,
            .dos_date = dos_date,
        };
        errdefer {
            if (current.encoder) |encoder| self.allocator.destroy(encoder);
            if (current.history) |history| self.allocator.free(history);
            self.allocator.free(current.name);
            self.allocator.free(current.comment);
        }

        const local_header: zip.LocalFileHeader = .{
            .signature = zip.local_file_header_sig,
            .version_needed_to_extract = 45,
            .flags = @bitCast(flags),
            .compression_method = method,
            .last_modification_time = dos_time_value,
            .last_modification_date = dos_date,
            .crc32 = 0,
            .compressed_size = std.math.maxInt(u32),
            .uncompressed_size = std.math.maxInt(u32),
            .filename_len = @intCast(name.len),
            .extra_len = 20,
        };
        try writeFileStruct(self, local_header);
        try writeFileAll(self, name);
        var zip64_local_extra: [20]u8 = undefined;
        std.mem.writeInt(u16, zip64_local_extra[0..2], 1, .little);
        std.mem.writeInt(u16, zip64_local_extra[2..4], 16, .little);
        std.mem.writeInt(u64, zip64_local_extra[4..12], 0, .little);
        std.mem.writeInt(u64, zip64_local_extra[12..20], 0, .little);
        try writeFileAll(self, &zip64_local_extra);
        current.data_start = self.file_writer.logicalPos();

        if (method == .deflate) {
            current.history = try self.allocator.alloc(u8, flate.max_window_len);
            const encoder = try self.allocator.create(flate.Compress);
            errdefer self.allocator.destroy(encoder);
            encoder.* = try flate.Compress.init(
                &self.file_writer.interface,
                current.history.?,
                .raw,
                optionsForLevel(options.level),
            );
            current.encoder = encoder;
        }

        self.current = current;
    }

    pub fn write(self: *Writer, data: []const u8) !void {
        if (self.closed) return error.ZipClosed;
        if (self.current == null) return error.ZipNoOpenEntry;

        const current = &self.current.?;
        if (current.encoder) |encoder| {
            try encoder.writer.writeAll(data);
        } else {
            try writeFileAll(self, data);
        }
        current.crc.update(data);
        current.uncompressed += data.len;
    }

    pub fn endEntry(self: *Writer) !void {
        if (self.current == null) return;

        var current = &self.current.?;
        errdefer self.discardCurrent();

        if (current.encoder) |encoder| {
            try encoder.finish();
            self.allocator.destroy(encoder);
            current.encoder = null;
        }
        if (current.history) |history| {
            self.allocator.free(history);
            current.history = null;
        }

        try self.file_writer.interface.flush();
        const data_end = self.file_writer.logicalPos();
        current.compressed = data_end - current.data_start;

        const crc = current.crc.final();
        try self.file_writer.seekTo(current.local_offset + 14);
        try self.file_writer.interface.writeInt(u32, crc, .little);

        // The local header stores Zip64 sentinel sizes.  Fill the Zip64 extra
        // field after the filename with the actual uncompressed and compressed
        // sizes.
        try self.file_writer.seekTo(current.local_offset +
            @sizeOf(zip.LocalFileHeader) +
            current.name.len +
            4);
        try self.file_writer.interface.writeInt(u64, current.uncompressed, .little);
        try self.file_writer.interface.writeInt(u64, current.compressed, .little);
        try self.file_writer.seekTo(data_end);

        try self.writeCentralDirectoryRecord(current);
        self.new_entry_count += 1;

        self.allocator.free(current.name);
        self.allocator.free(current.comment);
        self.current = null;
    }

    fn discardCurrent(self: *Writer) void {
        if (self.current) |*current| {
            if (current.encoder) |encoder| self.allocator.destroy(encoder);
            if (current.history) |history| self.allocator.free(history);
            self.allocator.free(current.name);
            self.allocator.free(current.comment);
            self.current = null;
        }
    }

    fn writeCentralDirectoryRecord(self: *Writer, current: *const Current) !void {
        const crc = current.crc.final();
        const stored_local_offset = try self.storedOffset(current.local_offset);

        const needs_uncompressed_extra = current.uncompressed >= std.math.maxInt(u32);
        const needs_compressed_extra = current.compressed >= std.math.maxInt(u32);
        const needs_offset_extra = stored_local_offset >= std.math.maxInt(u32);
        var extra_field_count: usize = 0;
        if (needs_uncompressed_extra) extra_field_count += 1;
        if (needs_compressed_extra) extra_field_count += 1;
        if (needs_offset_extra) extra_field_count += 1;
        const extra_len: u16 = @intCast(if (extra_field_count == 0) 0 else 4 + extra_field_count * 8);

        const header: zip.CentralDirectoryFileHeader = .{
            .signature = zip.central_file_header_sig,
            .version_made_by = 0x032D,
            .version_needed_to_extract = 45,
            .flags = @bitCast(current.flags),
            .compression_method = current.method,
            .last_modification_time = current.dos_time,
            .last_modification_date = current.dos_date,
            .crc32 = crc,
            .compressed_size = if (needs_compressed_extra) std.math.maxInt(u32) else @intCast(current.compressed),
            .uncompressed_size = if (needs_uncompressed_extra) std.math.maxInt(u32) else @intCast(current.uncompressed),
            .filename_len = @intCast(current.name.len),
            .extra_len = extra_len,
            .comment_len = @intCast(current.comment.len),
            .disk_number = 0,
            .internal_file_attributes = 0,
            .external_file_attributes = externalAttributes(current.name),
            .local_file_header_offset = if (needs_offset_extra) std.math.maxInt(u32) else @intCast(stored_local_offset),
        };

        const writer = &self.new_central_dir.writer;
        try writer.writeStruct(header, .little);
        try writer.writeAll(current.name);

        if (extra_field_count > 0) {
            try writer.writeInt(u16, 1, .little);
            try writer.writeInt(u16, @intCast(extra_field_count * 8), .little);
            if (needs_uncompressed_extra) try writer.writeInt(u64, current.uncompressed, .little);
            if (needs_compressed_extra) try writer.writeInt(u64, current.compressed, .little);
            if (needs_offset_extra) try writer.writeInt(u64, stored_local_offset, .little);
        }

        try writer.writeAll(current.comment);
    }

    fn storedOffset(self: *const Writer, absolute_offset: u64) !u64 {
        if (absolute_offset < self.offset_base) return error.ZipBadFileOffset;
        return absolute_offset - self.offset_base;
    }

    pub fn createDirectory(self: *Writer, name: []const u8) !void {
        var buffer: [std.fs.max_path_bytes]u8 = undefined;
        var directory_name = name;
        if (name.len == 0 or (name[name.len - 1] != '/' and name[name.len - 1] != '\\')) {
            if (name.len + 1 > buffer.len) return error.ZipNameTooLong;
            @memcpy(buffer[0..name.len], name);
            buffer[name.len] = '/';
            directory_name = buffer[0 .. name.len + 1];
        }
        try self.addFileData(directory_name, "", 0, "", null);
    }

    pub fn addFile(
        self: *Writer,
        source_path: []const u8,
        destination_name: []const u8,
        level: u4,
        comment: []const u8,
    ) !void {
        const file = try Io.Dir.cwd().openFile(self.io, source_path, .{});
        defer file.close(self.io);

        const stat = try file.stat(self.io);
        const timestamp = dos_time.fromTimestamp(stat.mtime.nanoseconds);

        try self.beginEntry(destination_name, .{
            .level = level,
            .comment = comment,
            .dos_time = timestamp.time,
            .dos_date = timestamp.date,
        });
        errdefer self.discardCurrent();

        var file_buffer: [4096]u8 = undefined;
        var data_buffer: [4096]u8 = undefined;
        var reader = file.reader(self.io, &file_buffer);
        while (true) {
            const amount = reader.interface.readSliceShort(&data_buffer) catch |err| switch (err) {
                error.ReadFailed => return reader.err orelse error.ReadFailed,
            };
            if (amount == 0) break;
            try self.write(data_buffer[0..amount]);
        }

        try self.endEntry();
    }

    pub fn addFileData(
        self: *Writer,
        destination_name: []const u8,
        data: []const u8,
        level: u4,
        comment: []const u8,
        timestamp: ?DosDateTime,
    ) !void {
        try self.beginEntry(destination_name, .{
            .level = level,
            .comment = comment,
            .dos_time = if (timestamp) |value| value.time else null,
            .dos_date = if (timestamp) |value| value.date else null,
        });
        errdefer self.discardCurrent();

        if (data.len > 0) try self.write(data);
        try self.endEntry();
    }

    pub fn close(self: *Writer, comment: ?[]const u8) !void {
        if (self.closed) return;

        // Validate all representability constraints before writing anything so
        // a rejected comment cannot leave the archive without an EOCD.
        const archive_comment = comment orelse self.old_comment;
        if (archive_comment.len > std.math.maxInt(u16)) return error.ZipCommentTooLong;

        errdefer {
            self.closed = true;
            self.file.close(self.io);
        }

        try self.endEntry();
        try self.file_writer.interface.flush();

        const central_dir_start = self.file_writer.logicalPos();
        const stored_central_dir_start = try self.storedOffset(central_dir_start);
        try writeFileAll(self, self.old_central_dir);
        const new_central_dir = self.new_central_dir.written();
        try writeFileAll(self, new_central_dir);

        const central_dir_size: u64 = @as(u64, self.old_central_dir.len) + new_central_dir.len;
        const total_entries = self.old_entry_count + self.new_entry_count;

        const needs_zip64 = total_entries >= std.math.maxInt(u16) or
            central_dir_size >= std.math.maxInt(u32) or
            stored_central_dir_start >= std.math.maxInt(u32);

        if (needs_zip64) {
            const zip64_offset = self.file_writer.logicalPos();
            const stored_zip64_offset = try self.storedOffset(zip64_offset);
            const zip64_record: zip.EndRecord64 = .{
                .signature = zip.end_record64_sig,
                .end_record_size = 44,
                .version_made_by = 45,
                .version_needed_to_extract = 45,
                .disk_number = 0,
                .central_directory_disk_number = 0,
                .record_count_disk = total_entries,
                .record_count_total = total_entries,
                .central_directory_size = central_dir_size,
                .central_directory_offset = stored_central_dir_start,
            };
            try writeFileStruct(self, zip64_record);

            const locator: zip.EndLocator64 = .{
                .signature = zip.end_locator64_sig,
                .zip64_disk_count = 0,
                .record_file_offset = stored_zip64_offset,
                .total_disk_count = 1,
            };
            try writeFileStruct(self, locator);
        }

        const end_record: zip.EndRecord = .{
            .signature = zip.end_record_sig,
            .disk_number = 0,
            .central_directory_disk_number = 0,
            .record_count_disk = if (total_entries >= std.math.maxInt(u16)) std.math.maxInt(u16) else @intCast(total_entries),
            .record_count_total = if (total_entries >= std.math.maxInt(u16)) std.math.maxInt(u16) else @intCast(total_entries),
            .central_directory_size = if (central_dir_size >= std.math.maxInt(u32)) std.math.maxInt(u32) else @intCast(central_dir_size),
            .central_directory_offset = if (stored_central_dir_start >= std.math.maxInt(u32)) std.math.maxInt(u32) else @intCast(stored_central_dir_start),
            .comment_len = @intCast(archive_comment.len),
        };
        try writeFileStruct(self, end_record);
        try writeFileAll(self, archive_comment);
        try self.file_writer.end();

        self.closed = true;
        self.file.close(self.io);
    }
};

fn stripDigitalSignature(allocator: std.mem.Allocator, central_dir: []u8) ![]u8 {
    const signature = [_]u8{ 'P', 'K', 5, 5 };
    if (central_dir.len < 6) return central_dir;

    const max_signature_size: usize = std.math.maxInt(u16);
    const earliest = central_dir.len - 6 - @min(central_dir.len - 6, max_signature_size);
    var position: usize = central_dir.len - 6;
    while (true) {
        if (position + 6 <= central_dir.len and
            std.mem.eql(u8, central_dir[position..][0..4], &signature))
        {
            const size = std.mem.readInt(u16, central_dir[position + 4 ..][0..2], .little);
            if (position + 6 + @as(usize, size) == central_dir.len) {
                const stripped = try allocator.alloc(u8, position);
                @memcpy(stripped, central_dir[0..position]);
                allocator.free(central_dir);
                return stripped;
            }
        }
        if (position == earliest) break;
        position -= 1;
    }
    return central_dir;
}

fn optionsForLevel(level: u4) flate.Compress.Options {
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

fn utf8Flags(name: []const u8, comment: []const u8) u16 {
    if (!std.unicode.utf8ValidateSlice(name)) return 0;
    if (comment.len > 0 and !std.unicode.utf8ValidateSlice(comment)) return 0;

    // The general-purpose UTF-8 flag is only meaningful when at least one
    // multi-byte code point is present.  ASCII-only entries stay unflagged.
    for (name) |byte| {
        if (byte >= 0x80) return 0x0800;
    }
    for (comment) |byte| {
        if (byte >= 0x80) return 0x0800;
    }
    return 0;
}

fn externalAttributes(name: []const u8) u32 {
    if (name.len > 0 and name[name.len - 1] == '/') {
        return 0x41ED0010; // drwxr-xr-x plus the MS-DOS directory bit
    }
    return 0x81A40000; // regular file, mode 0644
}

fn writeFileAll(writer: *Writer, data: []const u8) !void {
    writer.file_writer.interface.writeAll(data) catch |err| switch (err) {
        error.WriteFailed => return writer.file_writer.err orelse error.WriteFailed,
    };
}

fn writeFileStruct(writer: *Writer, value: anytype) !void {
    writer.file_writer.interface.writeStruct(value, .little) catch |err| switch (err) {
        error.WriteFailed => return writer.file_writer.err orelse error.WriteFailed,
    };
}
