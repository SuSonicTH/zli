const std = @import("std");

const zlua = @import("zlua");
const luax = @import("luax.zig");
const Lua = zlua.Lua;

const crossline = [_]zlua.FnReg{
    .{ .name = "call", .func = zlua.wrap(call) },
};

pub fn luaopen_httpclient(lua: *Lua) i32 {
    lua.newLib(&crossline);
    luax.registerExtended(lua, @embedFile("stripped/httpclient.lua"), "httpclient", "zli_httpclient");
    return 1;
}

const readLength = 4096;
const RequestHeaders = std.http.Client.Request.Headers;
const Method = std.http.Method;

fn call(lua: *Lua) i32 {
    const methodName = luax.getArgStringOrError(lua, 1, "expecting http method string of [GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH]");
    const method = std.meta.stringToEnum(Method, methodName) orelse luax.raiseFormattedError(lua, "expecting http method [GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE, PATCH] got '%s'", .{methodName.ptr});
    const url = luax.getArgStringOrError(lua, 2, "expecting url string");
    const optionIndex = 3;
    const bodyIndex = 4;
    lua.argCheck(lua.typeOf(optionIndex) == .table, optionIndex, "expecting table with options");

    var arena = std.heap.ArenaAllocator.init(lua.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var header = Header.init(allocator);
    defer header.deinit();
    header.parseHeader(lua, optionIndex) catch return luax.raiseError(lua, "error while parsing header");

    const uri = std.Uri.parse(url) catch return luax.returnFormattedError(lua, "invalid url '%s'", .{url.ptr});

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var header_buffer: [4096]u8 = undefined;
    var request = client.open(method, uri, .{
        .server_header_buffer = &header_buffer,
        .headers = header.headers,
        .extra_headers = header.extra_headers.items,
        .privileged_headers = header.privileged_headers.items,
    }) catch return luax.returnFormattedError(lua, "could not open connection to '%s'", .{url.ptr});
    defer request.deinit();

    switch (method) {
        .POST => request.transfer_encoding = .chunked,
        else => {},
    }

    request.send() catch return luax.returnFormattedError(lua, "could not send to '%s'", .{url.ptr});
    if (lua.typeOf(bodyIndex) != .nil) {
        const body = lua.toString(bodyIndex) catch return luax.returnError(lua, "could not get body ");
        _ = request.write(body) catch return luax.returnFormattedError(lua, "could not send body to '%s'", .{url.ptr});
    }
    request.finish() catch return luax.returnFormattedError(lua, "could not send to '%s'", .{url.ptr});
    request.wait() catch return luax.returnFormattedError(lua, "could not get response from '%s'", .{url.ptr});

    const status: i32 = @intFromEnum(request.response.status);
    lua.pushInteger(status);

    var lua_buffer: zlua.Buffer = undefined;
    lua_buffer.init(lua);
    var buffer = lua_buffer.prepSize(readLength);
    while (true) {
        const length = request.readAll(buffer) catch luax.raiseFormattedError(lua, "could not read from '%s'", .{url.ptr});
        lua_buffer.addSize(length);
        if (length == readLength) {
            buffer = lua_buffer.prepSize(readLength);
        } else {
            break;
        }
    }

    lua_buffer.pushResult();
    return 2;
}

const Header = struct {
    allocator: std.mem.Allocator,
    headers: std.http.Client.Request.Headers = undefined,
    extra_headers: std.ArrayList(std.http.Header),
    privileged_headers: std.ArrayList(std.http.Header),

    host: ?[]const u8 = null,
    authorization: ?[]const u8 = null,
    user_agent: ?[]const u8 = null,
    connection: ?[]const u8 = null,
    accept_encoding: ?[]const u8 = null,
    content_type: ?[]const u8 = null,

    fn init(allocator: std.mem.Allocator) Header {
        return .{
            .allocator = allocator,
            .extra_headers = std.ArrayList(std.http.Header).init(allocator),
            .privileged_headers = std.ArrayList(std.http.Header).init(allocator),
        };
    }

    fn deinit(self: *Header) void {
        self.extra_headers.deinit();
        self.privileged_headers.deinit();
    }

    fn parseHeader(self: *Header, lua: *Lua, index: i32) !void {
        if (!luax.getOptionalTable(lua, "header", index)) {
            self.headers = .{};
            return;
        }

        lua.pushNil();
        while (lua.next(-2)) {
            lua.pushValue(-2);
            const name = try lua.toString(-1);
            const value = try self.allocator.dupe(u8, try lua.toString(-2));
            switch (std.meta.stringToEnum(DefaultHeader, name) orelse ._extra_headers) {
                .host, .Host => self.host = value,
                .authorization, .Authorization => self.authorization = value,
                .user_agent, .@"user-agent", .@"User-Agent" => self.user_agent = value,
                .connection, .Connection => self.connection = value,
                .accept_encoding, .@"accept-encoding", .@"Accept-Encoding" => self.accept_encoding = value,
                .content_type, .@"content-type", .@"Content-Type" => self.content_type = value,
                ._extra_headers => try self.extra_headers.append(.{
                    .name = try self.allocator.dupe(u8, name),
                    .value = value,
                }),
            }
            lua.pop(2);
        }

        self.headers = .{
            .host = if (self.host) |host| .{ .override = host } else .default,
            .authorization = if (self.authorization) |authorization| .{ .override = authorization } else .default,
            .user_agent = if (self.user_agent) |user_agent| .{ .override = user_agent } else .default,
            .connection = if (self.connection) |connection| .{ .override = connection } else .default,
            .accept_encoding = if (self.accept_encoding) |accept_encoding| .{ .override = accept_encoding } else .default,
            .content_type = if (self.content_type) |content_type| .{ .override = content_type } else .default,
        };

        if (!luax.getOptionalTable(lua, "privileged_headers", 2)) return;
        lua.pushNil();
        while (lua.next(-2)) {
            lua.pushValue(-2);
            try self.privileged_headers.append(.{
                .name = try self.allocator.dupe(u8, try lua.toString(-1)),
                .value = try self.allocator.dupe(u8, try lua.toString(-2)),
            });
            lua.pop(2);
        }
    }

    const DefaultHeader = enum {
        host,
        Host,
        authorization,
        Authorization,
        user_agent,
        @"user-agent",
        @"User-Agent",
        connection,
        Connection,
        accept_encoding,
        @"accept-encoding",
        @"Accept-Encoding",
        content_type,
        @"content-type",
        @"Content-Type",
        _extra_headers,
    };
};
