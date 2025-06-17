const std = @import("std");

const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const httpserver = [_]zlua.FnReg{
    .{ .name = "listen", .func = zlua.wrap(listen) },
};

pub fn luaopen_httpserver(lua: *Lua) i32 {
    lua.newLib(&httpserver);
    luax.registerExtended(lua, @embedFile("stripped/httpserver.lua"), "httpserver", "zli_httpserver");
    return 1;
}

const addressIndex = 1;
const portIndex = 2;
const handlerIndex = 3;
const optionsIndex = 4;

fn listen(lua: *Lua) i32 {
    const address = luax.getArgStringOrError(lua, addressIndex, "expecting address to listen on");
    const port = luax.getArgIntegerOrError(lua, portIndex, "expecting port to listen on");
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

        lua.pushValue(handlerIndex);
        lua.pushValue(optionsIndex);
        lua.newTable();

        luax.setTableString(lua, -1, "method", @tagName(request.head.method));
        luax.setTableString(lua, -1, "target", request.head.target);
        luax.setTableString(lua, -1, "version", @tagName(request.head.version));
        luax.setTableString(lua, -1, "expect", request.head.expect orelse "");
        luax.setTableString(lua, -1, "content_type", request.head.content_type orelse "");
        luax.setTableInteger(lua, -1, "content_length", @intCast(request.head.content_length orelse 0));
        luax.setTableString(lua, -1, "transfer_encoding", @tagName(request.head.transfer_encoding));
        luax.setTableString(lua, -1, "transfer_compression", @tagName(request.head.transfer_compression));
        luax.setTableBoolean(lua, -1, "keep_alive", request.head.keep_alive);
        luax.setTableString(lua, -1, "compression", @tagName(request.head.compression));

        var headerIter = request.iterateHeaders();
        while (headerIter.next()) |header| {
            luax.setTableString(lua, -1, header.name, header.value);
        }

        lua.call(.{ .args = 2, .results = 1 });
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
