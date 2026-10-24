//! ZIP archive reading built on `std.zip` and `std.compress.flate`.
//!
//! This module has no Lua dependencies so that it can be shared by the runtime
//! payload loader and the `unzip` binding.

const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const File = std.Io.File;
const flate = std.compress.flate;
const zip = std.zip;

const read_buffer_size = 4096;
const end_record_size = @sizeOf(zip.EndRecord);
const max_comment_len = std.math.maxInt(u16);

pub const Entry = struct {
    name: []u8,
    method: zip.CompressionMethod,
    flags: u16,
    encrypted: bool,
    crc32: u32,
    compressed_size: u64,
    uncompressed_size: u64,
    local_header_offset: u64,
    data_offset: u64,
    dos_time: u16,
    dos_date: u16,
    is_directory: bool,
};

pub const Layout = struct {
    /// Absolute file position of the central directory.
    central_directory_start: u64,
    central_directory_size: u64,
    entry_count: u64,
    /// Absolute file position of the end-of-central-directory record.
    end_record_offset: u64,
    /// Start of the archive comment.
    comment_offset: u64,
    comment_len: u16,
    /// Offset stored in local/central headers is relative to this value.
    offset_base: u64,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    io: Io,
    file: File,
    entries: []Entry,
    comment: []u8,

    pub fn init(allocator: std.mem.Allocator, io: Io, path: []const u8) !Archive {
        const file = try Io.Dir.cwd().openFile(io, path, .{});
        errdefer file.close(io);

        var read_buffer: [read_buffer_size]u8 = undefined;
        var reader = file.reader(io, &read_buffer);
        const layout = try findLayout(&reader);

        const central_directory_size: usize = std.math.cast(usize, layout.central_directory_size) orelse
            return error.ZipCentralDirectoryTooLarge;
        const central_directory = try allocator.alloc(u8, central_directory_size);
        defer allocator.free(central_directory);
        try reader.seekTo(layout.central_directory_start);
        try readSliceAll(&reader, central_directory);

        var entries: std.ArrayList(Entry) = .empty;
        errdefer {
            for (entries.items) |entry| allocator.free(entry.name);
            entries.deinit(allocator);
        }

        var offset: usize = 0;
        var index: u64 = 0;
        while (index < layout.entry_count) : (index += 1) {
            if (offset + @sizeOf(zip.CentralDirectoryFileHeader) > central_directory.len)
                return error.ZipBadCentralDirectory;

            const header = sliceStruct(zip.CentralDirectoryFileHeader, central_directory, offset);
            if (!std.mem.eql(u8, &header.signature, &zip.central_file_header_sig))
                return error.ZipBadCentralDirectory;

            const variable_len = @as(usize, header.filename_len) +
                @as(usize, header.extra_len) +
                @as(usize, header.comment_len);
            if (offset + @sizeOf(zip.CentralDirectoryFileHeader) + variable_len > central_directory.len)
                return error.ZipBadCentralDirectory;

            const name_start = offset + @sizeOf(zip.CentralDirectoryFileHeader);
            const extra_start = name_start + header.filename_len;
            const extra = central_directory[extra_start .. extra_start + header.extra_len];

            var uncompressed_size: u64 = header.uncompressed_size;
            var compressed_size: u64 = header.compressed_size;
            var local_header_offset: u64 = header.local_file_header_offset;
            var disk_number: u16 = header.disk_number;
            var resolved: Zip64Resolution = .{
                .uncompressed = header.uncompressed_size != std.math.maxInt(u32),
                .compressed = header.compressed_size != std.math.maxInt(u32),
                .offset = header.local_file_header_offset != std.math.maxInt(u32),
                .disk = header.disk_number != std.math.maxInt(u16),
            };
            try readZip64Extra(
                extra,
                &uncompressed_size,
                &compressed_size,
                &local_header_offset,
                &disk_number,
                &resolved,
            );
            if (!resolved.uncompressed or !resolved.compressed or !resolved.offset or !resolved.disk)
                return error.ZipBadCentralDirectory;
            if (disk_number != 0) return error.ZipMultiDiskUnsupported;

            const absolute_local_offset = std.math.add(u64, layout.offset_base, local_header_offset) catch
                return error.ZipBadFileOffset;

            try reader.seekTo(absolute_local_offset);
            const local_header = try takeStruct(zip.LocalFileHeader, &reader);
            if (!std.mem.eql(u8, &local_header.signature, &zip.local_file_header_sig))
                return error.ZipBadFileOffset;

            const data_offset = std.math.add(
                u64,
                absolute_local_offset,
                @sizeOf(zip.LocalFileHeader) + @as(u64, local_header.filename_len) + @as(u64, local_header.extra_len),
            ) catch return error.ZipBadFileOffset;

            const name = try allocator.alloc(u8, header.filename_len);
            errdefer allocator.free(name);
            @memcpy(name, central_directory[name_start .. name_start + header.filename_len]);

            try entries.append(allocator, .{
                .name = name,
                .method = header.compression_method,
                .flags = @bitCast(header.flags),
                .encrypted = @as(u16, @bitCast(header.flags)) & 1 != 0,
                .crc32 = header.crc32,
                .compressed_size = compressed_size,
                .uncompressed_size = uncompressed_size,
                .local_header_offset = absolute_local_offset,
                .data_offset = data_offset,
                .dos_time = header.last_modification_time,
                .dos_date = header.last_modification_date,
                .is_directory = name.len > 0 and name[name.len - 1] == '/',
            });

            offset += @sizeOf(zip.CentralDirectoryFileHeader) + variable_len;
        }

        if (offset != central_directory.len) {
            const remaining = central_directory[offset..];
            const digital_signature = [_]u8{ 'P', 'K', 5, 5 };
            if (remaining.len < 6 or
                !std.mem.eql(u8, remaining[0..digital_signature.len], &digital_signature))
                return error.ZipBadCentralDirectory;
            const signature_size = std.mem.readInt(u16, remaining[4..6], .little);
            if (6 + @as(usize, signature_size) != remaining.len)
                return error.ZipBadCentralDirectory;
        }

        const owned_entries = try entries.toOwnedSlice(allocator);
        errdefer {
            for (owned_entries) |entry| allocator.free(entry.name);
            allocator.free(owned_entries);
        }

        const comment = try allocator.alloc(u8, layout.comment_len);
        errdefer allocator.free(comment);
        if (comment.len > 0) {
            try reader.seekTo(layout.comment_offset);
            try readSliceAll(&reader, comment);
        }

        return .{
            .allocator = allocator,
            .io = io,
            .file = file,
            .entries = owned_entries,
            .comment = comment,
        };
    }

    pub fn deinit(self: *Archive) void {
        for (self.entries) |entry| self.allocator.free(entry.name);
        self.allocator.free(self.entries);
        self.allocator.free(self.comment);
        self.file.close(self.io);
        self.* = undefined;
    }

    pub fn find(self: *const Archive, name: []const u8) ?usize {
        for (self.entries, 0..) |entry, index| {
            if (std.mem.eql(u8, entry.name, name)) return index;
        }
        return null;
    }

    pub fn readAll(self: *const Archive, name: []const u8, allocator: std.mem.Allocator) !?[]u8 {
        const index = self.find(name) orelse return null;
        return try self.readEntryAll(index, allocator);
    }

    pub fn readEntryAll(self: *const Archive, index: usize, allocator: std.mem.Allocator) ![]u8 {
        if (index < self.entries.len and self.entries[index].is_directory)
            return error.ZipIsDirectory;
        var entry_reader = try EntryReader.init(allocator, self, index);
        defer entry_reader.deinit();

        var output: Io.Writer.Allocating = .init(allocator);
        errdefer output.deinit();

        var buffer: [read_buffer_size]u8 = undefined;
        while (true) {
            const amount = try entry_reader.read(&buffer);
            if (amount == 0) break;
            try output.writer.writeAll(buffer[0..amount]);
        }
        return output.toOwnedSlice();
    }
};

/// Locate the end records and central directory.  Handles archives embedded
/// after arbitrary prefix data and tolerates trailing bytes after the EOCD.
pub fn findLayout(reader: *File.Reader) !Layout {
    const file_size = try reader.getSize();
    if (file_size < end_record_size) return error.ZipNoEndRecord;

    const tail_len: usize = @intCast(@min(file_size, end_record_size + max_comment_len));
    var tail: [end_record_size + max_comment_len]u8 = undefined;
    const buffer = tail[0..tail_len];
    try reader.seekTo(file_size - tail_len);
    try readSliceAll(reader, buffer);

    var exact: ?usize = null;
    var tolerant: ?usize = null;
    if (tail_len >= end_record_size) {
        var position: usize = tail_len - end_record_size + 1;
        while (position > 0) {
            position -= 1;
            if (position + end_record_size > tail_len) continue;
            if (!std.mem.eql(u8, buffer[position..][0..4], &zip.end_record_sig)) continue;

            const comment_len = std.mem.readInt(u16, buffer[position + 20 ..][0..2], .little);
            if (position + end_record_size + comment_len == tail_len) {
                exact = position;
                break;
            }
            if (tolerant == null and position + end_record_size + comment_len <= tail_len)
                tolerant = position;
        }
    }

    const relative_eocd = exact orelse tolerant orelse return error.ZipNoEndRecord;
    const eocd_offset = file_size - tail_len + relative_eocd;
    const eocd_bytes = buffer[relative_eocd..][0..end_record_size];

    const disk_number = std.mem.readInt(u16, eocd_bytes[4..6], .little);
    const central_directory_disk_number = std.mem.readInt(u16, eocd_bytes[6..8], .little);
    const record_count_disk = std.mem.readInt(u16, eocd_bytes[8..10], .little);
    const record_count_total = std.mem.readInt(u16, eocd_bytes[10..12], .little);
    const central_directory_size32 = std.mem.readInt(u32, eocd_bytes[12..16], .little);
    const central_directory_offset32 = std.mem.readInt(u32, eocd_bytes[16..20], .little);
    const comment_len = std.mem.readInt(u16, eocd_bytes[20..22], .little);

    if (disk_number != 0 or central_directory_disk_number != 0)
        return error.ZipMultiDiskUnsupported;

    var record_count: u64 = record_count_total;
    var central_directory_size: u64 = central_directory_size32;
    var central_directory_offset: u64 = central_directory_offset32;
    var central_directory_end_offset: u64 = eocd_offset;

    const sentinel_zip64 = record_count_disk == std.math.maxInt(u16) or
        record_count_total == std.math.maxInt(u16) or
        central_directory_size32 == std.math.maxInt(u32) or
        central_directory_offset32 == std.math.maxInt(u32);

    var zip64_record: ?Zip64Location = null;
    if (try hasZip64Locator(reader, eocd_offset)) {
        zip64_record = findZip64Record(reader, eocd_offset) catch null;
    }
    const needs_zip64 = sentinel_zip64 or zip64_record != null;

    if (needs_zip64) {
        const zip64 = zip64_record orelse return error.ZipBadEndRecord64Sig;
        if (zip64.record.disk_number != 0 or zip64.record.central_directory_disk_number != 0)
            return error.ZipMultiDiskUnsupported;
        if (zip64.record.record_count_disk != zip64.record.record_count_total)
            return error.ZipMultiDiskUnsupported;
        record_count = zip64.record.record_count_total;
        central_directory_size = zip64.record.central_directory_size;
        central_directory_offset = zip64.record.central_directory_offset;
        central_directory_end_offset = zip64.offset;
    } else {
        if (record_count_disk != record_count_total)
            return error.ZipMultiDiskUnsupported;
    }

    if (central_directory_size > central_directory_end_offset)
        return error.ZipBadCentralDirectory;
    const central_directory_start = central_directory_end_offset - central_directory_size;
    if (central_directory_offset > central_directory_start)
        return error.ZipBadCentralDirectory;

    return .{
        .central_directory_start = central_directory_start,
        .central_directory_size = central_directory_size,
        .entry_count = record_count,
        .end_record_offset = eocd_offset,
        .comment_offset = eocd_offset + end_record_size,
        .comment_len = comment_len,
        .offset_base = central_directory_start - central_directory_offset,
    };
}

const Zip64Location = struct {
    offset: u64,
    record: zip.EndRecord64,
};

fn hasZip64Locator(reader: *File.Reader, eocd_offset: u64) !bool {
    if (eocd_offset < @sizeOf(zip.EndLocator64)) return false;
    var signature: [4]u8 = undefined;
    try reader.seekTo(eocd_offset - @sizeOf(zip.EndLocator64));
    try readSliceAll(reader, &signature);
    return std.mem.eql(u8, &signature, &zip.end_locator64_sig);
}

fn findZip64Record(reader: *File.Reader, eocd_offset: u64) !Zip64Location {
    if (eocd_offset < @sizeOf(zip.EndLocator64)) return error.ZipBadEndRecord64;

    const locator_offset = eocd_offset - @sizeOf(zip.EndLocator64);
    try reader.seekTo(locator_offset);
    const locator = try takeStruct(zip.EndLocator64, reader);
    if (!std.mem.eql(u8, &locator.signature, &zip.end_locator64_sig))
        return error.ZipBadLocatorSig;
    if (locator.zip64_disk_count != 0 or locator.total_disk_count != 1)
        return error.ZipMultiDiskUnsupported;

    // The locator offset is relative to the archive start for prefixed
    // archives, so search backwards for the record signature instead of
    // assuming that it is an absolute file offset.
    const search_len: usize = @intCast(@min(locator_offset, 4096));
    var search_buffer: [4096]u8 = undefined;
    const search = search_buffer[0..search_len];
    try reader.seekTo(locator_offset - search_len);
    try readSliceAll(reader, search);

    if (search_len >= @sizeOf(zip.EndRecord64)) {
        var position: usize = search_len - @sizeOf(zip.EndRecord64) + 1;
        while (position > 0) {
            position -= 1;
            if (position + @sizeOf(zip.EndRecord64) > search_len) continue;
            if (!std.mem.eql(u8, search[position..][0..4], &zip.end_record64_sig)) continue;

            const record_offset = locator_offset - search_len + position;
            try reader.seekTo(record_offset);
            const record = try takeStruct(zip.EndRecord64, reader);
            if (record.end_record_size < @sizeOf(zip.EndRecord64) - 12)
                return error.ZipEndRecord64SizeTooSmall;
            if (record.end_record_size > @sizeOf(zip.EndRecord64) - 12)
                return error.ZipEndRecord64UnhandledExtraData;
            return .{ .offset = record_offset, .record = record };
        }
    }

    // Fall back to the offset stored in the locator when it is absolute.
    const fallback_end = std.math.add(u64, locator.record_file_offset, @sizeOf(zip.EndRecord64)) catch
        return error.ZipBadEndRecord64Sig;
    if (fallback_end <= locator_offset) {
        try reader.seekTo(locator.record_file_offset);
        const record = takeStruct(zip.EndRecord64, reader) catch return error.ZipBadEndRecord64Sig;
        if (std.mem.eql(u8, &record.signature, &zip.end_record64_sig)) {
            return .{ .offset = locator.record_file_offset, .record = record };
        }
    }

    return error.ZipBadEndRecord64Sig;
}

const Zip64Resolution = struct {
    uncompressed: bool,
    compressed: bool,
    offset: bool,
    disk: bool,
};

fn readZip64Extra(
    extra: []const u8,
    uncompressed_size: *u64,
    compressed_size: *u64,
    local_header_offset: *u64,
    disk_number: *u16,
    resolved: *Zip64Resolution,
) !void {
    var offset: usize = 0;
    while (offset + 4 <= extra.len) {
        const header_id = std.mem.readInt(u16, extra[offset..][0..2], .little);
        const data_size = std.mem.readInt(u16, extra[offset + 2 ..][0..2], .little);
        const data_start = offset + 4;
        const data_end = data_start + data_size;
        if (data_end > extra.len) return error.ZipBadExtraFieldSize;

        if (header_id == 1) {
            const data = extra[data_start..data_end];
            var cursor: usize = 0;

            if (!resolved.uncompressed) {
                if (cursor + 8 > data.len) return error.ZipBadCd64Size;
                uncompressed_size.* = std.mem.readInt(u64, data[cursor..][0..8], .little);
                cursor += 8;
                resolved.uncompressed = true;
            }
            if (!resolved.compressed) {
                if (cursor + 8 > data.len) return error.ZipBadCd64Size;
                compressed_size.* = std.mem.readInt(u64, data[cursor..][0..8], .little);
                cursor += 8;
                resolved.compressed = true;
            }
            if (!resolved.offset) {
                if (cursor + 8 > data.len) return error.ZipBadCd64Size;
                local_header_offset.* = std.mem.readInt(u64, data[cursor..][0..8], .little);
                cursor += 8;
                resolved.offset = true;
            }
            if (!resolved.disk) {
                if (cursor + 4 > data.len) return error.ZipBadCd64Size;
                const value = std.mem.readInt(u32, data[cursor..][0..4], .little);
                disk_number.* = std.math.cast(u16, value) orelse return error.ZipMultiDiskUnsupported;
                resolved.disk = true;
            }
        }

        offset = data_end;
    }
}

fn sliceStruct(comptime T: type, data: []const u8, offset: usize) T {
    var value = std.mem.bytesToValue(T, data[offset..][0..@sizeOf(T)]);
    if (comptime builtin.target.cpu.arch.endian() == .big) {
        std.mem.byteSwapAllFields(T, &value);
    }
    return value;
}

fn readSliceAll(reader: *File.Reader, buffer: []u8) !void {
    reader.interface.readSliceAll(buffer) catch |err| switch (err) {
        error.ReadFailed => return reader.err orelse error.ReadFailed,
        else => |e| return e,
    };
}

fn takeStruct(comptime T: type, reader: *File.Reader) !T {
    return reader.interface.takeStruct(T, .little) catch |err| switch (err) {
        error.ReadFailed => return reader.err orelse error.ReadFailed,
        else => |e| return e,
    };
}

/// A streaming reader for a single uncompressed archive entry.
pub const EntryReader = struct {
    allocator: std.mem.Allocator,
    io: Io,
    file: File,
    method: zip.CompressionMethod,
    expected_crc: u32,
    uncompressed_size: u64,
    data_offset: u64,

    file_buffer: [read_buffer_size]u8 = undefined,
    file_reader: File.Reader = undefined,
    history: ?[]u8 = null,
    decoder: Decoder = .store,
    crc: std.hash.Crc32 = .init(),
    produced: u64 = 0,
    remaining: u64 = 0,
    done: bool = false,

    const Decoder = union(enum) {
        store: void,
        deflate: flate.Decompress,
    };

    pub fn init(allocator: std.mem.Allocator, archive: *const Archive, index: usize) !*EntryReader {
        if (index >= archive.entries.len) return error.ZipEntryNotFound;
        const entry = archive.entries[index];
        if (entry.encrypted) return error.ZipEncryptionUnsupported;

        const self = try allocator.create(EntryReader);
        errdefer allocator.destroy(self);

        if (entry.method != .store and entry.method != .deflate)
            return error.UnsupportedCompressionMethod;

        self.* = .{
            .allocator = allocator,
            .io = archive.io,
            .file = archive.file,
            .method = entry.method,
            .expected_crc = entry.crc32,
            .uncompressed_size = entry.uncompressed_size,
            .data_offset = entry.data_offset,
        };
        try self.restart();

        return self;
    }

    pub fn deinit(self: *EntryReader) void {
        const allocator = self.allocator;
        self.freeHistory();
        allocator.destroy(self);
    }

    fn freeHistory(self: *EntryReader) void {
        if (self.history) |history| {
            self.allocator.free(history);
            self.history = null;
        }
    }

    fn restart(self: *EntryReader) !void {
        self.decoder = .store;
        self.crc = .init();
        self.produced = 0;
        self.done = false;
        self.remaining = self.uncompressed_size;

        self.file_reader = self.file.reader(self.io, &self.file_buffer);
        try self.file_reader.seekTo(self.data_offset);

        if (self.method == .deflate) {
            self.freeHistory();
            self.history = try self.allocator.alloc(u8, flate.max_window_len);
            self.decoder = .{ .deflate = flate.Decompress.init(
                &self.file_reader.interface,
                .raw,
                self.history.?,
            ) };
        }
    }

    /// Read up to `buffer.len` uncompressed bytes. Returns 0 at end of entry.
    pub fn read(self: *EntryReader, buffer: []u8) !usize {
        if (buffer.len == 0) return 0;
        if (self.done) return 0;

        var amount: usize = 0;
        switch (self.decoder) {
            .store => {
                if (self.remaining == 0) {
                    try self.finish();
                    return 0;
                }
                const want: usize = @intCast(@min(self.remaining, @as(u64, @intCast(buffer.len))));
                amount = self.file_reader.interface.readSliceShort(buffer[0..want]) catch |err| switch (err) {
                    error.ReadFailed => return self.file_reader.err orelse error.ReadFailed,
                    else => |e| return e,
                };
                self.remaining -= @intCast(amount);
            },
            .deflate => |*decompressor| {
                amount = decompressor.reader.readSliceShort(buffer) catch |err| switch (err) {
                    error.ReadFailed => return decompressor.err orelse (self.file_reader.err orelse error.ReadFailed),
                    else => |e| return e,
                };
            },
        }

        if (amount == 0) {
            try self.finish();
            return 0;
        }

        self.crc.update(buffer[0..amount]);
        self.produced += amount;
        return amount;
    }

    fn finish(self: *EntryReader) !void {
        if (self.done) return;
        self.done = true;

        if (self.produced != self.uncompressed_size)
            return error.ZipDecompressTruncated;
        if (self.crc.final() != self.expected_crc)
            return error.ZipCrcMismatch;
    }

    /// Restart the entry and discard bytes until `position` uncompressed bytes
    /// have been consumed.
    pub fn seek(self: *EntryReader, position: u64) !void {
        if (position > self.uncompressed_size) return error.ZipSeekOutOfRange;
        try self.restart();

        var remaining = position;
        var discard_buffer: [read_buffer_size]u8 = undefined;
        while (remaining > 0) {
            const want: usize = @intCast(@min(remaining, discard_buffer.len));
            const amount = try self.read(discard_buffer[0..want]);
            if (amount == 0) break;
            remaining -= amount;
        }
    }
};
