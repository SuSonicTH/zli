//! Pure helpers shared by the web server. Kept free of Lua and socket state so
//! that they can be unit tested without a running server.

const std = @import("std");

pub fn contentType(name: []const u8) []const u8 {
    const dot = std.mem.lastIndexOfScalar(u8, name, '.') orelse return "application/octet-stream";
    const ext = name[dot..];
    const table = .{
        .{ ".js", "text/javascript; charset=utf-8" },
        .{ ".css", "text/css; charset=utf-8" },
        .{ ".html", "text/html; charset=utf-8" },
        .{ ".htm", "text/html; charset=utf-8" },
        .{ ".json", "application/json" },
        .{ ".svg", "image/svg+xml" },
        .{ ".png", "image/png" },
        .{ ".jpg", "image/jpeg" },
        .{ ".jpeg", "image/jpeg" },
        .{ ".gif", "image/gif" },
        .{ ".ico", "image/x-icon" },
        .{ ".woff2", "font/woff2" },
        .{ ".txt", "text/plain; charset=utf-8" },
        .{ ".map", "application/json" },
    };
    inline for (table) |entry| {
        if (std.mem.eql(u8, ext, entry[0])) return entry[1];
    }
    return "application/octet-stream";
}

/// An asset name is a relative, slash separated path without `.`/`..`
/// components. Anything else is rejected instead of being resolved.
pub fn safeAssetName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (name[0] == '/') return false;
    if (std.mem.indexOfScalar(u8, name, '\\') != null) return false;
    if (std.mem.indexOfScalar(u8, name, 0) != null) return false;
    var iterator = std.mem.splitScalar(u8, name, '/');
    while (iterator.next()) |part| {
        if (std.mem.eql(u8, part, "..")) return false;
        if (std.mem.eql(u8, part, ".")) return false;
    }
    return true;
}

pub fn withoutQuery(target: []const u8) []const u8 {
    const end = std.mem.indexOfScalar(u8, target, '?') orelse target.len;
    return target[0..end];
}

pub fn formatCookie(buffer: []u8, token: []const u8) []const u8 {
    return std.fmt.bufPrint(buffer, "webui_session={s}; HttpOnly; SameSite=Strict; Path=/", .{token}) catch "";
}

pub fn isLoopbackName(address: []const u8) bool {
    return std.mem.eql(u8, address, "127.0.0.1") or
        std.mem.eql(u8, address, "::1") or
        std.mem.eql(u8, address, "localhost");
}

pub fn isMutating(method: []const u8) bool {
    if (std.mem.eql(u8, method, "GET")) return false;
    if (std.mem.eql(u8, method, "HEAD")) return false;
    if (std.mem.eql(u8, method, "OPTIONS")) return false;
    return true;
}

const testing = std.testing;

test "contentType maps known extensions" {
    try testing.expectEqualStrings("text/javascript; charset=utf-8", contentType("webui/app.js"));
    try testing.expectEqualStrings("text/css; charset=utf-8", contentType("a/b/app.css"));
    try testing.expectEqualStrings("application/json", contentType("data.json"));
    try testing.expectEqualStrings("application/octet-stream", contentType("no-extension"));
    try testing.expectEqualStrings("application/octet-stream", contentType("weird.xyz"));
}

test "safeAssetName rejects traversal and absolute names" {
    try testing.expect(safeAssetName("webui/app.js"));
    try testing.expect(safeAssetName("a/b/c.txt"));

    try testing.expect(!safeAssetName(""));
    try testing.expect(!safeAssetName("/etc/passwd"));
    try testing.expect(!safeAssetName("../../etc/passwd"));
    try testing.expect(!safeAssetName("webui/../../x"));
    try testing.expect(!safeAssetName("./app.js"));
    try testing.expect(!safeAssetName("webui\\app.js"));
}

test "withoutQuery strips the query and fragment tail" {
    try testing.expectEqualStrings("/a", withoutQuery("/a?x=1"));
    try testing.expectEqualStrings("/a", withoutQuery("/a"));
    try testing.expectEqualStrings("", withoutQuery("?x=1"));
}

test "formatCookie marks the session cookie http only and same site strict" {
    var buffer: [128]u8 = undefined;
    const cookie = formatCookie(&buffer, "abc");
    try testing.expectEqualStrings("webui_session=abc; HttpOnly; SameSite=Strict; Path=/", cookie);
}

test "isLoopbackName only accepts loopback names" {
    try testing.expect(isLoopbackName("127.0.0.1"));
    try testing.expect(isLoopbackName("::1"));
    try testing.expect(isLoopbackName("localhost"));
    try testing.expect(!isLoopbackName("0.0.0.0"));
    try testing.expect(!isLoopbackName("192.168.1.1"));
}

test "isMutating" {
    try testing.expect(!isMutating("GET"));
    try testing.expect(!isMutating("HEAD"));
    try testing.expect(isMutating("POST"));
    try testing.expect(isMutating("DELETE"));
}
