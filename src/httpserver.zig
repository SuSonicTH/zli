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

    var extra_headers = std.ArrayList(std.http.Header).init(lua.allocator());
    defer extra_headers.deinit();

    var server = addr.listen(.{}) catch return luax.returnFormattedError(lua, "could not listen to %s:%d", .{ address.ptr, port });
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

        if (lua.typeOf(-1) != .table) {
            std.debug.print("Got non table result for request: {s} {s}\n", .{ @tagName(request.head.method), request.head.target });
            request.respond("", .{ .status = std.http.Status.internal_server_error }) catch |err| {
                std.debug.print("Could not handle request: {s} {s} error: {}\n", .{ @tagName(request.head.method), request.head.target, err });
            };
            continue;
        }
        const body = luax.getOptionString(lua, "body", -1, "");
        const status = luax.getOptionInteger(lua, "status", -1, @intFromEnum(std.http.Status.ok));

        var header_arena = std.heap.ArenaAllocator.init(lua.allocator());
        defer header_arena.deinit();
        parseHeader(lua, &extra_headers, header_arena.allocator()) catch luax.raiseError(lua, "could not allocate an extra header");

        request.respond(body, .{ .status = @enumFromInt(status), .extra_headers = extra_headers.items, .keep_alive = false }) catch |err| {
            std.debug.print("Could not handle request: {s} {s} error: {}\n", .{ @tagName(request.head.method), request.head.target, err });
            continue;
        };
    }
}

fn parseHeader(lua: *Lua, extra_headers: *std.ArrayList(std.http.Header), allocator: std.mem.Allocator) !void {
    extra_headers.clearRetainingCapacity();
    defer lua.pop(1);
    if (luax.getOptionalTable(lua, "header", -1)) {
        lua.pushNil();
        while (lua.next(-2)) {
            lua.pushValue(-2);
            defer lua.pop(2);
            const name = try allocator.dupe(u8, try lua.toString(-1));
            const value = try allocator.dupe(u8, try lua.toString(-2));
            try extra_headers.append(.{ .name = name, .value = value });
        }
    }
}
