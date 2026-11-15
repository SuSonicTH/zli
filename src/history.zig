//! Line editor history: an ordered list of entries with JSON persistence.

const std = @import("std");

pub const max_file_bytes: usize = 8 * 1024 * 1024;

pub const History = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList([]u8) = .empty,
    max: usize = 1000,

    pub fn init(allocator: std.mem.Allocator) History {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *History) void {
        self.clear();
        self.entries.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn count(self: *const History) usize {
        return self.entries.items.len;
    }

    pub fn get(self: *const History, index: usize) ?[]const u8 {
        if (index >= self.entries.items.len) return null;
        return self.entries.items[index];
    }

    pub fn setMax(self: *History, max: usize) void {
        self.max = @max(max, 1);
        self.trim();
    }

    pub fn add(self: *History, text: []const u8) !void {
        if (text.len == 0) return;

        // std.json only emits JSON strings for valid UTF-8.  Replace stray
        // bytes so a history file can always be loaded again.
        const clean = try sanitiseUtf8(self.allocator, text);
        defer self.allocator.free(clean);
        if (clean.len == 0) return;

        if (self.entries.items.len > 0) {
            const last = self.entries.items[self.entries.items.len - 1];
            if (std.mem.eql(u8, last, clean)) return;
        }
        if (self.entries.items.len >= self.max) {
            const first = self.entries.orderedRemove(0);
            self.allocator.free(first);
        }
        try self.entries.append(self.allocator, try self.allocator.dupe(u8, clean));
    }

    pub fn clear(self: *History) void {
        for (self.entries.items) |entry| self.allocator.free(entry);
        self.entries.clearRetainingCapacity();
    }

    fn trim(self: *History) void {
        while (self.entries.items.len > self.max) {
            const first = self.entries.orderedRemove(0);
            self.allocator.free(first);
        }
    }

    /// Replace the current entries with the contents of a JSON array of
    /// strings. The file is left untouched when it cannot be parsed.
    pub fn load(self: *History, io: std.Io, dir: std.Io.Dir, path: []const u8) !void {
        const data = dir.readFileAlloc(io, path, self.allocator, .limited(max_file_bytes)) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        defer self.allocator.free(data);

        var parsed = std.json.parseFromSlice(std.json.Value, self.allocator, data, .{}) catch return error.InvalidHistoryFile;
        defer parsed.deinit();

        var fresh: std.ArrayList([]u8) = .empty;
        errdefer {
            for (fresh.items) |entry| self.allocator.free(entry);
            fresh.deinit(self.allocator);
        }

        switch (parsed.value) {
            .array => |array| {
                for (array.items) |item| {
                    switch (item) {
                        .string => |text| {
                            if (text.len == 0) continue;
                            if (fresh.items.len > 0 and std.mem.eql(u8, fresh.items[fresh.items.len - 1], text)) continue;
                            try fresh.append(self.allocator, try self.allocator.dupe(u8, text));
                        },
                        else => return error.InvalidHistoryFile,
                    }
                }
            },
            else => return error.InvalidHistoryFile,
        }

        self.clear();
        self.entries.deinit(self.allocator);
        self.entries = fresh;
        self.trim();
    }

    /// Write a JSON array of strings, replacing the destination atomically.
    pub fn save(self: *History, io: std.Io, dir: std.Io.Dir, path: []const u8) !void {
        var allocating: std.Io.Writer.Allocating = .init(self.allocator);
        defer allocating.deinit();

        var stringify: std.json.Stringify = .{
            .writer = &allocating.writer,
            .options = .{ .whitespace = .indent_2 },
        };
        try stringify.beginArray();
        for (self.entries.items) |entry| try stringify.write(entry);
        try stringify.endArray();
        try allocating.writer.writeByte('\n');

        const bytes = try allocating.toOwnedSlice();
        defer self.allocator.free(bytes);

        const temporary = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{path});
        defer self.allocator.free(temporary);

        const file = try dir.createFile(io, temporary, .{});
        errdefer dir.deleteFile(io, temporary) catch {};
        file.writeStreamingAll(io, bytes) catch |err| {
            file.close(io);
            return err;
        };
        file.sync(io) catch {};
        file.close(io);

        try std.Io.Dir.rename(dir, temporary, dir, path, io);
    }
};

fn validSequenceAt(text: []const u8, index: usize, len: usize) bool {
    switch (len) {
        1 => return true,
        2 => {
            _ = std.unicode.utf8Decode2(text[index..][0..2].*) catch return false;
        },
        3 => {
            _ = std.unicode.utf8Decode3(text[index..][0..3].*) catch return false;
        },
        4 => {
            _ = std.unicode.utf8Decode4(text[index..][0..4].*) catch return false;
        },
        else => return false,
    }
    return true;
}

fn sanitiseUtf8(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var index: usize = 0;
    while (index < text.len) {
        const len = std.unicode.utf8ByteSequenceLength(text[index]) catch {
            try out.append(allocator, '?');
            index += 1;
            continue;
        };
        if (index + len > text.len or !validSequenceAt(text, index, len)) {
            try out.append(allocator, '?');
            index += 1;
            continue;
        }
        try out.appendSlice(allocator, text[index..][0..len]);
        index += len;
    }

    return out.toOwnedSlice(allocator);
}

test "history de-duplicates and trims" {
    var history = History.init(std.testing.allocator);
    defer history.deinit();

    try history.add("one");
    try history.add("one");
    try history.add("two");
    try history.add("");
    try std.testing.expectEqual(@as(usize, 2), history.count());
    try std.testing.expectEqualStrings("one", history.get(0).?);
    try std.testing.expectEqualStrings("two", history.get(1).?);

    history.setMax(1);
    try std.testing.expectEqual(@as(usize, 1), history.count());
    try std.testing.expectEqualStrings("two", history.get(0).?);
}

test "history sanitises invalid utf8" {
    var history = History.init(std.testing.allocator);
    defer history.deinit();

    try history.add("ok\xff\xfe");
    try std.testing.expectEqualStrings("ok??", history.get(0).?);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try history.save(std.testing.io, tmp.dir, "history.json");

    var loaded = History.init(std.testing.allocator);
    defer loaded.deinit();
    try loaded.load(std.testing.io, tmp.dir, "history.json");
    try std.testing.expectEqualStrings("ok??", loaded.get(0).?);
}

test "history json is pretty printed" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var history = History.init(std.testing.allocator);
    defer history.deinit();
    try history.add("one");
    try history.add("two");
    try history.save(std.testing.io, tmp.dir, "history.json");

    const text = try tmp.dir.readFileAlloc(std.testing.io, "history.json", std.testing.allocator, .limited(max_file_bytes));
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("[\n  \"one\",\n  \"two\"\n]\n", text);
}

test "history json round trip and corrupt input" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var history = History.init(std.testing.allocator);
    defer history.deinit();

    try history.add("plain");
    try history.add("multi\nline");
    try history.save(std.testing.io, tmp.dir, "history.json");

    var loaded = History.init(std.testing.allocator);
    defer loaded.deinit();
    try loaded.load(std.testing.io, tmp.dir, "history.json");
    try std.testing.expectEqual(@as(usize, 2), loaded.count());
    try std.testing.expectEqualStrings("plain", loaded.get(0).?);
    try std.testing.expectEqualStrings("multi\nline", loaded.get(1).?);

    const corrupt = try tmp.dir.createFile(std.testing.io, "corrupt.json", .{});
    try corrupt.writeStreamingAll(std.testing.io, "not json");
    corrupt.close(std.testing.io);

    try std.testing.expectError(error.InvalidHistoryFile, loaded.load(std.testing.io, tmp.dir, "corrupt.json"));
    try std.testing.expectEqual(@as(usize, 2), loaded.count());

    try loaded.load(std.testing.io, tmp.dir, "missing.json");
    try std.testing.expectEqual(@as(usize, 2), loaded.count());
}
