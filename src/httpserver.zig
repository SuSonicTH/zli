const std = @import("std");

const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;
const luaerror = @import("luaerror.zig");

const exported_functions = [_]zlua.FnReg{
    .{ .name = "listen", .func = luaerror.wrap(listen) },
    .{ .name = "config", .func = luaerror.wrap(setConfig) },
};

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

const Config = struct {
    errorHandling: luaerror.Handling = undefined,
};

pub fn register(lua: *Lua) !i32 {
    var config = setup(lua);
    config.errorHandling = luaerror.getGlobalHandling(lua);
    luax.setTableString(lua, -1, "error_handling", @tagName(config.errorHandling));
    return 1;
}

fn setup(lua: *Lua) *Config {
    return luax.setupLibrary(lua, &exported_functions, Config, "httpserver");
}

pub fn setConfig(lua: *Lua) !i32 {
    lua.checkType(1, .table);
    const config = try lua.toUserdata(Config, Lua.upvalueIndex(1));
    const config_index: i32 = if (lua.typeOf(2) == .table) 2 else 1;

    if (luax.getOptionalString(lua, "error_handling", config_index)) |error_handling| {
        config.errorHandling = try luaerror.getHandling(error_handling);
        luax.setTableString(lua, 1, "error_handling", @tagName(config.errorHandling));
    }

    lua.pushValue(1);
    return 1;
}

fn get_error_handling(lua: *Lua) !luaerror.Handling {
    const config = try lua.toUserdata(Config, Lua.upvalueIndex(1));
    return config.errorHandling;
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
        return luaerror.raiseOrReturn(lua, err, "could not resolve ip '{s}': {any}", .{ address, err }, try get_error_handling(lua));
    const hasErrHandler = lua.typeOf(errorHandlerIndex) == .function;

    var extra_headers = std.array_list.Managed(std.http.Header).init(lua.allocator());
    defer extra_headers.deinit();

    var server = addr.listen(
        io,
        .{},
    ) catch |err|
        return luaerror.raiseOrReturn(lua, err, "could not listen to {s}:{d}: {any}", .{ address, port, err }, try get_error_handling(lua));

    connections: while (true) {
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

        // Reading the request body invalidates the head strings, so keep a
        // copy of the target for later error messages.
        var target_buffer: [4096]u8 = undefined;
        const target_len = @min(request.head.target.len, target_buffer.len);
        @memcpy(target_buffer[0..target_len], request.head.target[0..target_len]);
        const request_target: []const u8 = target_buffer[0..target_len];
        const request_method = request.head.method;

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

        // Read the request body (if any) before invoking the handler. The
        // handler receives it as the `body` field of the request table.
        var body_buffer: [1024 * 16]u8 = undefined;
        const body_reader = request.readerExpectContinue(&body_buffer) catch |err| {
            if (hasErrHandler) {
                luaerror.callErrorHandler(lua, errorHandlerIndex, "Could not read request body: {any}", .{err});
            }
            lua.pop(1);
            request.respond("", .{ .status = std.http.Status.bad_request }) catch {};
            continue :connections;
        };

        var lua_body: zlua.Buffer = undefined;
        lua_body.init(lua);
        var body_chunk: [4096]u8 = undefined;
        while (true) {
            // A read error on the request body closes the connection; pass the
            // bytes read so far to the handler and let it decide what to do.
            const n = body_reader.readSliceShort(&body_chunk) catch 0;
            if (n == 0) break;
            lua_body.addString(body_chunk[0..n]);
        }
        lua_body.pushResult();
        luax.setTableValue(lua, -2, "body", -1, true);

        lua.protectedCall(.{ .args = 2, .results = 1 }) catch |err| {
            const message = lua.toString(-1) catch @errorName(err);
            if (hasErrHandler) {
                luaerror.callErrorHandler(lua, errorHandlerIndex, "Could not handle request: {s} {s} error: {s}", .{ @tagName(request_method), request_target, message });
            }
            lua.pop(1);
            request.respond("", .{ .status = std.http.Status.internal_server_error }) catch {};
            continue;
        };
        defer lua.pop(1);

        if (lua.typeOf(-1) != .table) {
            request.respond("", .{ .status = std.http.Status.internal_server_error }) catch |err| {
                if (hasErrHandler) {
                    luaerror.callErrorHandler(lua, errorHandlerIndex, "Could not handle request: {s} {s} error: {any}", .{ @tagName(request_method), request_target, err });
                }
            };
            continue;
        }
        const body = luax.getOptionString(lua, "body", -1, "");
        const status_value = luax.getOptionInteger(lua, "status", -1, @backingInt(std.http.Status.ok));
        const status = std.enums.fromInt(std.http.Status, status_value) orelse std.http.Status.internal_server_error;

        var header_arena = std.heap.ArenaAllocator.init(lua.allocator());
        defer header_arena.deinit();
        parseHeader(lua, &extra_headers, header_arena.allocator()) catch |err|
            return luaerror.raiseOrReturn(lua, err, "could not allocate an extra header: {any}", .{err}, try get_error_handling(lua));

        request.respond(body, .{ .status = status, .extra_headers = extra_headers.items, .keep_alive = false }) catch |err| {
            if (hasErrHandler) {
                luaerror.callErrorHandler(lua, errorHandlerIndex, "Could not handle request: {s} {s} error: {any}", .{ @tagName(request_method), request_target, err });
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
            const raw_name = try lua.toString(-1);
            const header_name = if (std.mem.eql(u8, raw_name, "content_type"))
                "Content-Type"
            else if (std.mem.eql(u8, raw_name, "content_disposition"))
                "Content-Disposition"
            else
                raw_name;
            const name = try allocator.dupe(u8, header_name);
            const value = try allocator.dupe(u8, try lua.toString(-2));
            try extra_headers.append(.{ .name = name, .value = value });
        }
    }
}
