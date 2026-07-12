const std = @import("std");

const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;
const luaerror = @import("luaerror.zig");

const httpserver = [_]zlua.FnReg{
    .{ .name = "listen", .func = luaerror.wrap(listen) },
    .{ .name = "error_handling", .func = luaerror.wrap(error_handling) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

var errorHandling: luaerror.Handling = undefined;

pub fn luaopen_httpserver(lua: *Lua) i32 {
    errorHandling = luaerror.getGlobalErrorHanding(lua);
    lua.newLib(&httpserver);
    luax.registerExtended(lua, @embedFile("httpserver.lua"), "httpserver", "zli_httpserver");
    return 1;
}

pub fn error_handling(lua: *Lua) !i32 {
    errorHandling = try luaerror.getErrorHandling(lua);
    return 0;
}

const addressIndex = 1;
const portIndex = 2;
const handlerIndex = 3;
const optionsIndex = 4;
const errorHandlerIndex = 5;

fn listen(lua: *Lua) !i32 {
    const address = luax.getArgStringOrError(lua, addressIndex, "expecting address to listen on");
    const port = luax.getArgIntegerOrError(lua, portIndex, "expecting port to listen on");
    const addr = std.Io.net.IpAddress.parse(address, @intCast(port)) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not resolve ip '{s}': {any}", .{ address, err }, errorHandling);
    const hasErrHandler = lua.typeOf(errorHandlerIndex) == .function;

    var extra_headers = std.array_list.Managed(std.http.Header).init(lua.allocator());
    defer extra_headers.deinit();

    var server = addr.listen(
        io,
        .{},
    ) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not listen to {s}:{d}: {any}", .{ address, port, err }, errorHandling);

    while (true) {
        var connection = server.accept(io) catch |err| {
            if (hasErrHandler) {
                luaerror.callErrorHandler(lua, errorHandlerIndex, "Connection to client interrupted: {any}\n", .{err});
            }
            continue;
        };
        defer connection.close(io);

        var read_buffer: [1024 * 16]u8 = undefined;
        var write_buffer: [1024 * 16]u8 = undefined;
        var reader = connection.reader(io, &read_buffer);
        var writer = connection.writer(io, &write_buffer);
        var http_server = std.http.Server.init(&reader.interface, &writer.interface);

        var request = http_server.receiveHead() catch |err| {
            if (hasErrHandler) {
                luaerror.callErrorHandler(lua, errorHandlerIndex, "Could not read head: {any}", .{err});
            }
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

        var headerIter = request.iterateHeaders();
        while (headerIter.next()) |header| {
            luax.setTableString(lua, -1, header.name, header.value);
        }

        lua.call(.{ .args = 2, .results = 1 });
        defer lua.pop(1);

        if (lua.typeOf(-1) != .table) {
            request.respond("", .{ .status = std.http.Status.internal_server_error }) catch |err| {
                if (hasErrHandler) {
                    luaerror.callErrorHandler(lua, errorHandlerIndex, "Could not handle request: {s} {s} error: {any}", .{ @tagName(request.head.method), request.head.target, err });
                }
            };
            continue;
        }
        const body = luax.getOptionString(lua, "body", -1, "");
        const status = luax.getOptionInteger(lua, "status", -1, @intFromEnum(std.http.Status.ok));

        var header_arena = std.heap.ArenaAllocator.init(lua.allocator());
        defer header_arena.deinit();
        parseHeader(lua, &extra_headers, header_arena.allocator()) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not allocate an extra header: {any}", .{err}, errorHandling);

        request.respond(body, .{ .status = @enumFromInt(status), .extra_headers = extra_headers.items, .keep_alive = false }) catch |err| {
            if (hasErrHandler) {
                luaerror.callErrorHandler(lua, errorHandlerIndex, "Could not handle request: {s} {s} error: {any}", .{ @tagName(request.head.method), request.head.target, err });
            }
            continue;
        };
    }
}

fn parseHeader(lua: *Lua, extra_headers: *std.array_list.Managed(std.http.Header), allocator: std.mem.Allocator) !void {
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
