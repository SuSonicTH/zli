//! Reads whole files from the local filesystem, falling back to the payload
//! appended to the running executable.
//!
//! The payload archive is owned by `main.zig`; this module only keeps a
//! non-owning pointer to it.

const std = @import("std");
const zip_reader = @import("zip_reader.zig");

pub const Source = enum {
    filesystem,
    payload,
};

pub const ReadResult = struct {
    data: []u8,
    source: Source,
};

var io: std.Io = undefined;
var payload: ?*const zip_reader.Archive = null;

/// Configure the reader. `archive` must outlive all read calls.
pub fn setContext(_io: std.Io, archive: ?*const zip_reader.Archive) void {
    io = _io;
    payload = archive;
}

/// Read a file from the local filesystem or, when it does not exist there,
/// from the executable payload.
pub fn readAll(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const result = try readAllWithSource(allocator, path);
    return result.data;
}

/// Like `readAll`, but also reports where the data came from.
pub fn readAllWithSource(allocator: std.mem.Allocator, path: []const u8) !ReadResult {
    const cwd = std.Io.Dir.cwd();

    if (cwd.statFile(io, path, .{})) |stat| {
        if (stat.kind != .file) return error.NotAFile;
        const data = try cwd.readFileAlloc(io, path, allocator, std.Io.Limit.unlimited);
        return .{ .data = data, .source = .filesystem };
    } else |err| switch (err) {
        error.FileNotFound, error.NotDir => {},
        else => return err,
    }

    const data = try readPayload(allocator, path) orelse return error.FileNotFound;
    return .{ .data = data, .source = .payload };
}

fn readPayload(allocator: std.mem.Allocator, path: []const u8) !?[]u8 {
    const archive = payload orelse return null;

    if (try archive.readAll(path, allocator)) |data| {
        return data;
    }

    const normalized = try allocator.dupe(u8, path);
    defer allocator.free(normalized);
    for (normalized) |*byte| {
        if (byte.* == '\\') byte.* = '/';
    }

    if (!std.mem.eql(u8, normalized, path)) {
        if (try archive.readAll(normalized, allocator)) |data| {
            return data;
        }
    }

    if (normalized.len >= 2 and normalized[0] == '.' and normalized[1] == '/') {
        var start: usize = 1;
        while (start < normalized.len and normalized[start] == '/') : (start += 1) {}
        if (try archive.readAll(normalized[start..], allocator)) |data| {
            return data;
        }
    }

    return null;
}

/// Read a file directly from the payload archive, ignoring the local
/// filesystem. Used where the payload must not be shadowed by a local file.
pub fn readFromPayload(allocator: std.mem.Allocator, path: []const u8) !?[]u8 {
    return readPayload(allocator, path);
}
