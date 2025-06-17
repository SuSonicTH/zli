const std = @import("std");

const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const httpserver = [_]zlua.FnReg{
    .{ .name = "listen", .func = zlua.wrap(listen) },
};

pub fn luaopen_httpserver(lua: *Lua) i32 {
    lua.newLib(&httpserver);
    //luax.registerExtended(lua, @embedFile("stripped/httpserver.lua"), "httpserver", "zli_httpserver");
    return 1;
}

fn listen(lua: *Lua) i32 {
    const address = luax.getArgStringOrError(lua, 1, "expecting address to listen on");
    const port = luax.getArgIntegerOrError(lua, 2, "expecting port to listen on");
    const addr = std.net.Address.parseIp4(address, @intCast(port)) catch |err| {
        return luax.returnFormattedError(lua, "could not resolve ip '%s' error: %s", .{ address.ptr, @errorName(err).ptr });
    };

    var server = addr.listen(.{}) catch return luax.returnFormattedError(lua, "could not listen to %s:%d", .{ address.ptr, port });
    std.debug.print("listening http://{s}:{d}\n", .{ address, port });
    while (true) {
        var connection = server.accept() catch |err| {
            std.debug.print("Connection to client interrupted: {}\n", .{err});
            continue;
        };
        defer connection.stream.close();

        var read_buffer: [1024 * 16]u8 = undefined;
        var http_server = std.http.Server.init(connection, &read_buffer);

        var request = http_server.receiveHead() catch |err| {
            std.debug.print("Could not read head: {}", .{err});
            continue;
        };
        lua.pushValue(3);
        lua.call(.{ .args = 0, .results = 1 });
        defer lua.pop(1);
        const body = lua.toString(-1) catch {
            std.debug.print("Could not get string", .{});
            continue;
        };
        request.respond(body, .{}) catch |err| {
            std.debug.print("Could not handle request: {}", .{err});
            continue;
        };
    }
}
