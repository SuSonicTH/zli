const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");

const crossline = [_]zlua.FnReg{
    .{ .name = "request", .func = zlua.wrap(do_request) },
};

pub fn luaopen_httpclient(lua: *Lua) i32 {
    lua.newLib(&crossline);
    return 1;
}

fn do_request(lua: *Lua) i32 {
    const allocator = lua.allocator();
    const url = luax.getArgStringOrError(lua, 1, "expecting url string");
    const uri = std.Uri.parse(url) catch return luax.returnFormattedError(lua, "invalid url '%s'", .{url.ptr});

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var buf: [4096]u8 = undefined;
    var request = client.open(.GET, uri, .{ .server_header_buffer = &buf }) catch return luax.returnFormattedError(lua, "could not open connection to '%s'", .{url.ptr});
    defer request.deinit();

    request.send() catch return luax.returnFormattedError(lua, "could not send to '%s'", .{url.ptr});
    request.finish() catch return luax.returnFormattedError(lua, "could not send to '%s'", .{url.ptr});
    request.wait() catch return luax.returnFormattedError(lua, "could not get response from '%s'", .{url.ptr});

    lua.pushInteger(@intFromEnum(request.response.status));

    const body = request.reader().readAllAlloc(allocator, 1 * 1024 * 1024) catch return luax.returnFormattedError(lua, "could not read body from '%s'", .{url.ptr});
    defer allocator.free(body);

    _ = lua.pushString(body);

    return 2;
}
