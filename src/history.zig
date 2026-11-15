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

        var parser: JsonParser = .{ .data = data };
        parser.skipWhitespace();
        try parser.expect('[');

        var fresh: std.ArrayList([]u8) = .empty;
        errdefer {
            for (fresh.items) |entry| self.allocator.free(entry);
            fresh.deinit(self.allocator);
        }

        parser.skipWhitespace();
        if (parser.peek() == ']') {
            parser.index += 1;
        } else {
            while (true) {
                parser.skipWhitespace();
                const text = try parser.parseString(self.allocator);
                if (text.len == 0) {
                    self.allocator.free(text);
                } else if (fresh.items.len > 0 and std.mem.eql(u8, fresh.items[fresh.items.len - 1], text)) {
                    self.allocator.free(text);
                } else {
                    try fresh.append(self.allocator, text);
                }

                parser.skipWhitespace();
                const separator = parser.peek() orelse return error.InvalidHistoryFile;
                parser.index += 1;
                if (separator == ',') continue;
                if (separator == ']') break;
                return error.InvalidHistoryFile;
            }
        }

        parser.skipWhitespace();
        if (parser.index != data.len) return error.InvalidHistoryFile;

        self.clear();
        self.entries.deinit(self.allocator);
        self.entries = fresh;
        self.trim();
    }

    /// Write a JSON array of strings, replacing the destination atomically.
    pub fn save(self: *History, io: std.Io, dir: std.Io.Dir, path: []const u8) !void {
        var allocating: std.Io.Writer.Allocating = .init(self.allocator);
        defer allocating.deinit();

        const writer = &allocating.writer;
        if (self.entries.items.len == 0) {
            try writer.writeAll("[]\n");
        } else {
            try writer.writeAll("[\n");
            for (self.entries.items, 0..) |entry, index| {
                try writer.writeAll("  ");
                try writeJsonString(writer, entry);
                if (index + 1 < self.entries.items.len) try writer.writeByte(',');
                try writer.writeByte('\n');
            }
            try writer.writeAll("]\n");
        }

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

fn writeJsonString(writer: *std.Io.Writer, text: []const u8) !void {
    try writer.writeByte('"');
    for (text) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0x08 => try writer.writeAll("\\b"),
            0x0c => try writer.writeAll("\\f"),
            else => {
                if (byte < 0x20) {
                    try writer.print("\\u{x:0>4}", .{byte});
                } else {
                    try writer.writeByte(byte);
                }
            },
        }
    }
    try writer.writeByte('"');
}

const JsonParser = struct {
    data: []const u8,
    index: usize = 0,

    fn peek(self: *const JsonParser) ?u8 {
        if (self.index >= self.data.len) return null;
        return self.data[self.index];
    }

    fn expect(self: *JsonParser, byte: u8) !void {
        if (self.peek() != byte) return error.InvalidHistoryFile;
        self.index += 1;
    }

    fn skipWhitespace(self: *JsonParser) void {
        while (self.index < self.data.len and std.ascii.isWhitespace(self.data[self.index])) {
            self.index += 1;
        }
    }

    fn parseString(self: *JsonParser, allocator: std.mem.Allocator) ![]u8 {
        try self.expect('"');
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(allocator);

        while (self.index < self.data.len) {
            const byte = self.data[self.index];
            self.index += 1;
            switch (byte) {
                '"' => return out.toOwnedSlice(allocator),
                '\\' => {
                    const escaped = self.peek() orelse return error.InvalidHistoryFile;
                    self.index += 1;
                    switch (escaped) {
                        '"', '\\', '/' => try out.append(allocator, escaped),
                        'b' => try out.append(allocator, 0x08),
                        'f' => try out.append(allocator, 0x0c),
                        'n' => try out.append(allocator, '\n'),
                        'r' => try out.append(allocator, '\r'),
                        't' => try out.append(allocator, '\t'),
                        'u' => {
                            var codepoint: u21 = try self.parseHex4();
                            if (codepoint >= 0xd800 and codepoint <= 0xdbff) {
                                if (self.index + 1 >= self.data.len or self.data[self.index] != '\\' or self.data[self.index + 1] != 'u') {
                                    return error.InvalidHistoryFile;
                                }
                                self.index += 2;
                                const low = try self.parseHex4();
                                if (low < 0xdc00 or low > 0xdfff) return error.InvalidHistoryFile;
                                codepoint = 0x10000 + ((codepoint - 0xd800) << 10) + (low - 0xdc00);
                            } else if (codepoint >= 0xdc00 and codepoint <= 0xdfff) {
                                return error.InvalidHistoryFile;
                            }
                            var buffer: [4]u8 = undefined;
                            const length = std.unicode.utf8Encode(codepoint, &buffer) catch return error.InvalidHistoryFile;
                            try out.appendSlice(allocator, buffer[0..length]);
                        },
                        else => return error.InvalidHistoryFile,
                    }
                },
                else => {
                    if (byte < 0x20) return error.InvalidHistoryFile;
                    try out.append(allocator, byte);
                },
            }
        }
        return error.InvalidHistoryFile;
    }

    fn parseHex4(self: *JsonParser) !u21 {
        if (self.index + 4 > self.data.len) return error.InvalidHistoryFile;
        var value: u21 = 0;
        for (self.data[self.index..][0..4]) |byte| {
            const digit = std.fmt.charToDigit(byte, 16) catch return error.InvalidHistoryFile;
            value = value * 16 + digit;
        }
        self.index += 4;
        return value;
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

test "history json preserves line endings and literal escapes" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // `literal_escape` contains a backslash followed by `n`, not a newline.
    const literal_escape = "print(\"Hello\\n\")";
    const literal_cr = "print(\"Hello\\r\")";
    const lf = "line one\nline two";
    const cr = "line one\rline two";
    const crlf = "line one\r\nline two";
    const tabs_and_backslash = "tab\tand slash\\";

    var history = History.init(std.testing.allocator);
    defer history.deinit();
    try history.add(literal_escape);
    try history.add(literal_cr);
    try history.add(lf);
    try history.add(cr);
    try history.add(crlf);
    try history.add(tabs_and_backslash);
    try history.save(std.testing.io, tmp.dir, "history.json");

    const text = try tmp.dir.readFileAlloc(std.testing.io, "history.json", std.testing.allocator, .limited(max_file_bytes));
    defer std.testing.allocator.free(text);

    // Real control characters are escaped; literal backslash sequences keep
    // their extra backslash, so `\n` in source text survives as text.
    try std.testing.expect(std.mem.indexOf(u8, text, "Hello\\\\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Hello\\\\r") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "line one\\nline two") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "line one\\rline two") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "line one\\r\\nline two") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, text, '\r') == null);

    var loaded = History.init(std.testing.allocator);
    defer loaded.deinit();
    try loaded.load(std.testing.io, tmp.dir, "history.json");
    try std.testing.expectEqual(@as(usize, 6), loaded.count());
    try std.testing.expectEqualStrings(literal_escape, loaded.get(0).?);
    try std.testing.expectEqualStrings(literal_cr, loaded.get(1).?);
    try std.testing.expectEqualStrings(lf, loaded.get(2).?);
    try std.testing.expectEqualStrings(cr, loaded.get(3).?);
    try std.testing.expectEqualStrings(crlf, loaded.get(4).?);
    try std.testing.expectEqualStrings(tabs_and_backslash, loaded.get(5).?);

    const external = try tmp.dir.createFile(std.testing.io, "external.json", .{});
    try external.writeStreamingAll(std.testing.io, "[\"a\\u000db\\u000ac\", \"x\\u005cny\"]");
    external.close(std.testing.io);

    try loaded.load(std.testing.io, tmp.dir, "external.json");
    try std.testing.expectEqual(@as(usize, 2), loaded.count());
    try std.testing.expectEqualStrings("a\rb\nc", loaded.get(0).?);
    try std.testing.expectEqualStrings("x\\ny", loaded.get(1).?);
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
