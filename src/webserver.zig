//! Concurrent HTTP/1.1 server with keep-alive, an asset registry and user
//! routes.
//!
//! The Lua state has exactly one entering task: the task that calls
//! `webserver.serve()` runs the dispatch loop itself. Connection tasks are pure
//! I/O: they read a request, queue a job, wait for the response and write it.
//!
//! Shutdown wakes the blocking `accept` and every connection socket, then joins
//! all tasks before `serve` returns, because the payload archive and the Lua
//! state are released afterwards by `main.zig`.

const std = @import("std");
const zlua = @import("zlua");
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");
const file_reader = @import("file_reader.zig");
const util = @import("webserver_util.zig");

const Lua = zlua.Lua;
const Io = std.Io;

const allocator = std.heap.c_allocator;

/// Largest request head, including all headers.
const max_head = 16 * 1024;
/// Largest request body. Larger bodies are rejected with 413 and the connection
/// is closed.
const max_body = 1024 * 1024;
/// Largest number of concurrent connections.
const max_clients = 16;
const cookie_name = "webui_session";
const dispatch_key = "zli_webserver_dispatch";
const sse_path = "/__webui/events";
const sse_keepalive_ms = 20 * 1000;
const max_sse_queue_bytes = 1024 * 1024;

var io: Io = undefined;

pub fn setIo(_io: Io) void {
    io = _io;
}

const Config = struct {
    errorHandling: luaerror.Handling = undefined,
};

const exported_functions = [_]zlua.FnReg{
    .{ .name = "serve", .func = luaerror.wrap(serve) },
    .{ .name = "stop", .func = luaerror.wrap(stop) },
    .{ .name = "asset", .func = luaerror.wrap(asset) },
    .{ .name = "asset_set", .func = luaerror.wrap(assetSet) },
    .{ .name = "asset_list", .func = luaerror.wrap(assetList) },
    .{ .name = "clients", .func = luaerror.wrap(clients) },
    .{ .name = "sse", .func = luaerror.wrap(sse) },
    .{ .name = "broadcast", .func = luaerror.wrap(broadcast) },
    .{ .name = "info", .func = luaerror.wrap(info) },
    .{ .name = "config", .func = luaerror.wrap(setConfig) },
};

pub fn register(lua: *Lua) !i32 {
    var config = setup(lua);
    config.errorHandling = luaerror.getGlobalHandling(lua);
    luax.setTableString(lua, -1, "error_handling", @tagName(config.errorHandling));
    return 1;
}

fn setup(lua: *Lua) *Config {
    return luax.setupLibrary(lua, &exported_functions, Config, "webserver");
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

fn getErrorHandling(lua: *Lua) !luaerror.Handling {
    const config = try lua.toUserdata(Config, Lua.upvalueIndex(1));
    return config.errorHandling;
}

// ---------------------------------------------------------------------------
// assets
// ---------------------------------------------------------------------------

const AssetSource = enum { runtime, embedded };

const embedded_assets = [_]struct {
    name: []const u8,
    content_type: []const u8,
    data: []const u8,
}{
    .{
        .name = "webui/vendor.js",
        .content_type = "text/javascript; charset=utf-8",
        .data = @embedFile("webui/vendor.js"),
    },
    .{
        .name = "webui/app.js",
        .content_type = "text/javascript; charset=utf-8",
        .data = @embedFile("webui/app.js"),
    },
    .{
        .name = "webui/app.css",
        .content_type = "text/css; charset=utf-8",
        .data = @embedFile("webui/app.css"),
    },
};

const Asset = struct {
    name: []u8,
    content_type: []u8,
    data: []u8,
    source: AssetSource,
};

var assets: std.ArrayList(Asset) = .empty;
var assets_ready = false;

fn assetsInit() void {
    if (assets_ready) return;
    assets_ready = true;
    for (embedded_assets) |entry| {
        assets.append(allocator, .{
            .name = allocator.dupe(u8, entry.name) catch @panic("out of memory"),
            .content_type = allocator.dupe(u8, entry.content_type) catch @panic("out of memory"),
            .data = @constCast(entry.data),
            .source = .embedded,
        }) catch @panic("out of memory");
    }
}

fn findAsset(name: []const u8) ?*Asset {
    assetsInit();
    for (assets.items) |*entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry;
    }
    return null;
}

const active = struct {
    var server: ?*Server = null;
};

// ---------------------------------------------------------------------------
// server state
// ---------------------------------------------------------------------------

const Snapshot = struct {
    name: []u8,
    content_type: []u8,
    data: []u8,
    etag: u64,
};

const Transport = enum { http, sse };

const Client = struct {
    id: u64,
    stream: std.Io.net.Stream,
    transport: Transport = .http,
};

const SseMessage = struct {
    event: []u8,
    data: []u8,
};

/// One server sent events connection. The connection task owns the socket and
/// the response body writer; everybody else only appends to `queue`.
const SseClient = struct {
    id: u64,
    mutex: std.Io.Mutex = .init,
    condition: std.Io.Condition = .init,
    queue: std.ArrayList(SseMessage) = .empty,
    queued_bytes: usize = 0,
    closed: bool = false,

    fn clear(self: *SseClient) void {
        for (self.queue.items) |message| {
            allocator.free(message.event);
            allocator.free(message.data);
        }
        self.queue.clearRetainingCapacity();
        self.queued_bytes = 0;
    }
};

const Header = struct {
    name: []u8,
    value: []u8,
};

const Response = struct {
    status: std.http.Status = .ok,
    body: []u8 = &.{},
    headers: []Header = &.{},

    fn deinit(self: *Response) void {
        if (self.body.len > 0) allocator.free(self.body);
        for (self.headers) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        if (self.headers.len > 0) allocator.free(self.headers);
        self.* = .{};
    }
};

const Job = struct {
    next: ?*Job = null,
    client_id: u64,
    method: []u8,
    target: []u8,
    path: []u8,
    query: []u8,
    body: []u8,
    headers: []Header,
    keep_alive: bool,
    response: Response = .{},
    done: bool = false,
    mutex: std.Io.Mutex = .init,
    condition: std.Io.Condition = .init,

    fn deinit(self: *Job) void {
        allocator.free(self.method);
        allocator.free(self.target);
        allocator.free(self.path);
        allocator.free(self.query);
        if (self.body.len > 0) allocator.free(self.body);
        for (self.headers) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        if (self.headers.len > 0) allocator.free(self.headers);
        self.response.deinit();
        allocator.destroy(self);
    }
};

const Server = struct {
    lua: *Lua,
    listener: std.Io.net.Server,
    group: Io.Group = .init,
    token: []u8,
    assets_dir: ?[]u8 = null,
    stop_path: ?[]u8 = null,
    warn_ms: i64 = 500,
    allow_remote: bool = false,
    host: []u8,
    port: u16,

    clients_mutex: std.Io.Mutex = .init,
    clients: std.ArrayList(Client) = .empty,
    next_client_id: u64 = 1,

    sse_mutex: std.Io.Mutex = .init,
    sse_clients: std.ArrayList(*SseClient) = .empty,

    jobs_mutex: std.Io.Mutex = .init,
    jobs_condition: std.Io.Condition = .init,
    jobs_head: ?*Job = null,
    jobs_tail: ?*Job = null,

    stopping: bool = false,
    inflight: std.atomic.Value(u32) = .init(0),

    snapshots: std.ArrayList(Snapshot) = .empty,

    fn registerClient(self: *Server, stream: std.Io.net.Stream) !u64 {
        self.clients_mutex.lockUncancelable(io);
        defer self.clients_mutex.unlock(io);
        if (self.clients.items.len >= max_clients) return error.TooManyClients;
        const id = self.next_client_id;
        self.next_client_id += 1;
        try self.clients.append(allocator, .{ .id = id, .stream = stream });
        return id;
    }

    fn markSse(self: *Server, handle: std.Io.net.Socket.Handle) void {
        self.clients_mutex.lockUncancelable(io);
        defer self.clients_mutex.unlock(io);
        for (self.clients.items) |*client| {
            if (client.stream.socket.handle == handle) {
                client.transport = .sse;
                return;
            }
        }
    }

    fn unregisterClient(self: *Server, handle: std.Io.net.Socket.Handle) void {
        self.clients_mutex.lockUncancelable(io);
        defer self.clients_mutex.unlock(io);
        for (self.clients.items, 0..) |client, index| {
            if (client.stream.socket.handle == handle) {
                _ = self.clients.swapRemove(index);
                return;
            }
        }
    }

    fn closeSseClients(self: *Server) void {
        self.sse_mutex.lockUncancelable(io);
        defer self.sse_mutex.unlock(io);
        for (self.sse_clients.items) |client| {
            client.mutex.lockUncancelable(io);
            client.closed = true;
            client.mutex.unlock(io);
            client.condition.broadcast(io);
        }
    }

    fn shutdownClients(self: *Server) void {
        self.clients_mutex.lockUncancelable(io);
        defer self.clients_mutex.unlock(io);
        for (self.clients.items) |client| {
            client.stream.shutdown(io, .both) catch {};
        }
    }

    fn pushJob(self: *Server, job: *Job) void {
        self.jobs_mutex.lockUncancelable(io);
        if (self.jobs_tail) |tail| {
            tail.next = job;
        } else {
            self.jobs_head = job;
        }
        self.jobs_tail = job;
        self.jobs_condition.signal(io);
        self.jobs_mutex.unlock(io);
    }

    fn popJob(self: *Server) ?*Job {
        self.jobs_mutex.lockUncancelable(io);
        while (self.jobs_head == null and !self.stopping) {
            self.jobs_condition.waitTimeout(io, &self.jobs_mutex, .{ .duration = .{
                .raw = std.Io.Duration.fromMilliseconds(100),
                .clock = .awake,
            } }) catch {};
        }
        const job = self.jobs_head;
        if (job) |head| {
            self.jobs_head = head.next;
            if (self.jobs_head == null) self.jobs_tail = null;
            head.next = null;
        }
        self.jobs_mutex.unlock(io);
        return job;
    }

    fn failPendingJobs(self: *Server) void {
        self.jobs_mutex.lockUncancelable(io);
        var job = self.jobs_head;
        self.jobs_head = null;
        self.jobs_tail = null;
        self.jobs_mutex.unlock(io);
        while (job) |pending| {
            const next = pending.next;
            pending.mutex.lockUncancelable(io);
            pending.done = true;
            pending.response = .{
                .status = .service_unavailable,
                .body = allocator.dupe(u8, "server stopping") catch &.{},
            };
            pending.mutex.unlock(io);
            pending.condition.broadcast(io);
            job = next;
        }
    }

    fn portString(self: *const Server, buffer: []u8) []const u8 {
        return std.fmt.bufPrint(buffer, "{d}", .{self.port}) catch "";
    }
};

fn readAssetFile(dir: []const u8, name: []const u8) ![]u8 {
    if (!util.safeAssetName(name)) return error.FileNotFound;
    const path = try std.fs.path.join(allocator, &.{ dir, name });
    defer allocator.free(path);
    const stat = try std.Io.Dir.cwd().statFile(io, path, .{});
    if (stat.kind != .file) return error.FileNotFound;
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, std.Io.Limit.limited(max_body));
}

fn hasSessionCookie(request: *const std.http.Server.Request, token: []const u8) bool {
    var iterator = request.iterateHeaders();
    while (iterator.next()) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "cookie")) continue;
        var parts = std.mem.splitScalar(u8, header.value, ';');
        while (parts.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");
            const eq = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
            if (std.mem.eql(u8, trimmed[0..eq], cookie_name) and
                std.mem.eql(u8, trimmed[eq + 1 ..], token)) return true;
        }
    }
    return false;
}

fn requestEtagMatches(request: *const std.http.Server.Request, etag: []const u8) bool {
    var iterator = request.iterateHeaders();
    while (iterator.next()) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "if-none-match")) continue;
        const value = std.mem.trim(u8, header.value, " ");
        if (std.mem.eql(u8, value, "*")) return true;
        if (std.mem.eql(u8, value, etag)) return true;
    }
    return false;
}

fn originAllowed(server: *const Server, request: *const std.http.Server.Request) bool {
    var found = false;
    var origin_buffer: [256]u8 = undefined;
    var origin: []const u8 = "";

    var iterator = request.iterateHeaders();
    while (iterator.next()) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "origin")) continue;
        const value = std.mem.trim(u8, header.value, " ");
        const len = @min(value.len, origin_buffer.len);
        @memcpy(origin_buffer[0..len], value[0..len]);
        origin = origin_buffer[0..len];
        found = true;
        break;
    }
    if (!found) return true; // non-browser client; the session cookie still applies

    var buffer: [128]u8 = undefined;
    var port_buffer: [16]u8 = undefined;
    const expected = std.fmt.bufPrint(&buffer, "http://{s}:{d}", .{ server.host, server.port }) catch return false;
    if (std.mem.eql(u8, origin, expected)) return true;

    const port_suffix = std.fmt.bufPrint(&port_buffer, ":{d}", .{server.port}) catch return false;
    if (!std.mem.endsWith(u8, origin, port_suffix)) return false;
    return std.mem.startsWith(u8, origin, "http://127.0.0.1") or
        std.mem.startsWith(u8, origin, "http://localhost");
}

// ---------------------------------------------------------------------------
// serve
// ---------------------------------------------------------------------------

fn serve(lua: *Lua) !i32 {
    if (lua.typeOf(1) != .table) {
        luaerror.argError(lua, 1, "expecting a table with server options", .{});
    }

    const error_handling = try getErrorHandling(lua);
    const address = luax.getOptionString(lua, "address", 1, "127.0.0.1");
    const port_value = luax.getOptionInteger(lua, "port", 1, 8080);
    if (port_value < 0 or port_value > 65535) {
        luaerror.argError(lua, 1, "port has to be between 0 and 65535", .{});
    }
    const port: u16 = @intCast(port_value);
    const allow_remote = luax.getOptionBool(lua, "allow_remote", 1, false);
    const warn_ms = luax.getOptionInteger(lua, "warn_ms", 1, 500);

    // The dispatch function stays in the Lua registry for the lifetime of the
    // server so the garbage collector cannot collect it.
    _ = lua.pushString("dispatch");
    const dispatch_type = lua.getTable(1);
    if (dispatch_type != .function) {
        luaerror.argError(lua, 1, "expecting options.dispatch to be a function", .{});
    }
    _ = lua.pushString(dispatch_key);
    lua.pushValue(-2);
    lua.setTable(zlua.registry_index);
    lua.pop(1);

    if (!allow_remote and !util.isLoopbackName(address)) {
        return luaerror.raiseOrReturn(lua, error.InvalidAddress, "refusing to listen on '{s}' without allow_remote", .{address}, error_handling);
    }

    assetsInit();

    var token: []u8 = undefined;
    if (luax.getOptionalString(lua, "token", 1)) |given| {
        token = try allocator.dupe(u8, given);
    } else {
        token = try allocator.alloc(u8, 32);
        var random: [16]u8 = undefined;
        std.Io.randomSecure(io, &random) catch std.Io.random(io, &random);
        _ = std.fmt.bufPrint(token, "{x}", .{random}) catch unreachable;
    }
    defer allocator.free(token);

    const ip = std.Io.net.IpAddress.parse(address, port) catch |err| {
        return luaerror.raiseOrReturn(lua, err, "could not resolve ip '{s}': {any}", .{ address, err }, error_handling);
    };

    var listener = ip.listen(io, .{ .reuse_address = true }) catch |err| {
        return luaerror.raiseOrReturn(lua, err, "could not listen to {s}:{d}: {any}", .{ address, port, err }, error_handling);
    };
    defer listener.deinit(io);

    const server = try allocator.create(Server);
    defer allocator.destroy(server);
    server.* = .{
        .lua = lua,
        .listener = listener,
        .token = token,
        .host = try allocator.dupe(u8, address),
        .port = listener.socket.address.getPort(),
        .warn_ms = warn_ms,
        .allow_remote = allow_remote,
    };
    defer {
        allocator.free(server.host);
        if (server.assets_dir) |value| allocator.free(value);
        if (server.stop_path) |value| allocator.free(value);
        for (server.snapshots.items) |snapshot| {
            allocator.free(snapshot.name);
            allocator.free(snapshot.content_type);
            if (snapshot.data.len > 0) allocator.free(snapshot.data);
        }
        server.snapshots.deinit(allocator);
        server.clients.deinit(allocator);
        server.sse_clients.deinit(allocator);
    }

    if (luax.getOptionalString(lua, "assets_dir", 1)) |dir| server.assets_dir = try allocator.dupe(u8, dir);
    if (luax.getOptionalString(lua, "stop_path", 1)) |path| server.stop_path = try allocator.dupe(u8, path);

    snapshotAssets(server) catch |err| {
        return luaerror.raiseOrReturn(lua, err, "could not prepare the assets: {any}", .{err}, error_handling);
    };

    active.server = server;
    defer active.server = null;

    if (lua.typeOf(2) == .function) {
        lua.pushValue(2);
        pushInfoTable(lua, server);
        lua.protectedCall(.{ .args = 1, .results = 0 }) catch |err| {
            const message = lua.toString(-1) catch @errorName(err);
            std.debug.print("webserver: on_start failed: {s}\n", .{message});
            lua.pop(1);
        };
    }

    server.group.concurrent(io, acceptLoop, .{server}) catch |err| {
        return luaerror.raiseOrReturn(lua, err, "could not start the accept loop: {any}", .{err}, error_handling);
    };

    // Dispatch loop: the only place that ever enters the Lua state.
    while (!server.stopping) {
        const job = server.popJob() orelse continue;
        handleJob(server, job);
    }

    // Tear down: give in-flight responses a chance to flush, then wake the
    // listener and every connection and join.
    server.stopping = true;
    waitInflight(server, 500);
    server.closeSseClients();
    const listener_stream = std.Io.net.Stream{ .socket = server.listener.socket };
    listener_stream.shutdown(io, .both) catch {};
    server.shutdownClients();
    server.failPendingJobs();
    server.group.cancel(io);
    server.group.await(io) catch {};

    return 0;
}

fn snapshotAssets(server: *Server) !void {
    for (assets.items) |entry| {
        const data: []u8 = if (try file_reader.readFromPayload(allocator, entry.name)) |from_payload|
            from_payload
        else
            try allocator.dupe(u8, entry.data);
        try server.snapshots.append(allocator, .{
            .name = try allocator.dupe(u8, entry.name),
            .content_type = try allocator.dupe(u8, entry.content_type),
            .data = data,
            .etag = std.hash.Wyhash.hash(0, data),
        });
    }
}

fn formatUrl(server: *const Server, buffer: []u8) []const u8 {
    if (std.mem.indexOfScalar(u8, server.host, ':') != null) {
        return std.fmt.bufPrint(buffer, "http://[{s}]:{d}/", .{ server.host, server.port }) catch "";
    }
    return std.fmt.bufPrint(buffer, "http://{s}:{d}/", .{ server.host, server.port }) catch "";
}

fn pushInfoTable(lua: *Lua, server: *const Server) void {
    var url_buffer: [300]u8 = undefined;
    const url = formatUrl(server, &url_buffer);

    lua.newTable();
    luax.setTableString(lua, -1, "address", server.host);
    luax.setTableInteger(lua, -1, "port", server.port);
    luax.setTableString(lua, -1, "token", server.token);
    luax.setTableString(lua, -1, "url", url);
}

fn acceptLoop(server: *Server) Io.Cancelable!void {
    while (!server.stopping) {
        var stream = server.listener.accept(io) catch |err| switch (err) {
            error.SocketNotListening, error.Canceled => return,
            else => {
                if (server.stopping) return;
                continue;
            },
        };

        const client_id = server.registerClient(stream) catch {
            stream.close(io);
            continue;
        };
        server.group.concurrent(io, connectionLoop, .{ server, stream, client_id }) catch {
            server.unregisterClient(stream.socket.handle);
            stream.close(io);
            continue;
        };
    }
}

fn connectionLoop(server: *Server, stream: std.Io.net.Stream, client_id: u64) Io.Cancelable!void {
    defer {
        server.unregisterClient(stream.socket.handle);
        stream.close(io);
    }

    var read_buffer: [max_head]u8 = undefined;
    var write_buffer: [max_head]u8 = undefined;
    var reader = stream.reader(io, &read_buffer);
    var writer = stream.writer(io, &write_buffer);
    var http_server = std.http.Server.init(&reader.interface, &writer.interface);

    while (!server.stopping) {
        var request = http_server.receiveHead() catch return;
        if (std.mem.eql(u8, util.withoutQuery(request.head.target), sse_path)) {
            handleSse(server, &request, stream, client_id) catch {};
            return;
        }
        const keep_going = handleRequest(server, &request, client_id) catch false;
        if (!keep_going) return;
    }
}

fn serveAsset(server: *Server, request: *std.http.Server.Request, name: []const u8) !bool {
    var cookie_buffer: [128]u8 = undefined;
    const has_cookie = hasSessionCookie(request, server.token);

    if (server.assets_dir) |dir| {
        if (readAssetFile(dir, name)) |data| {
            defer allocator.free(data);
            var headers: [2]std.http.Header = undefined;
            var count: usize = 0;
            headers[count] = .{ .name = "cache-control", .value = "no-store" };
            count += 1;
            if (!has_cookie) {
                headers[count] = .{ .name = "set-cookie", .value = util.formatCookie(&cookie_buffer, server.token) };
                count += 1;
            }
            try request.respond(data, .{ .status = .ok, .extra_headers = headers[0..count], .keep_alive = true });
            return true;
        } else |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {},
        }
    }

    for (server.snapshots.items) |snapshot| {
        if (!std.mem.eql(u8, snapshot.name, name)) continue;

        var etag_buffer: [24]u8 = undefined;
        const etag = std.fmt.bufPrint(&etag_buffer, "\"{x}\"", .{snapshot.etag}) catch "";
        if (requestEtagMatches(request, etag)) {
            const headers = [_]std.http.Header{.{ .name = "etag", .value = etag }};
            try request.respond("", .{ .status = .not_modified, .extra_headers = &headers, .keep_alive = true });
            return true;
        }

        var headers: [3]std.http.Header = undefined;
        var count: usize = 0;
        headers[count] = .{ .name = "content-type", .value = snapshot.content_type };
        count += 1;
        headers[count] = .{ .name = "etag", .value = etag };
        count += 1;
        if (!has_cookie) {
            headers[count] = .{ .name = "set-cookie", .value = util.formatCookie(&cookie_buffer, server.token) };
            count += 1;
        }
        try request.respond(snapshot.data, .{ .status = .ok, .extra_headers = headers[0..count], .keep_alive = true });
        return true;
    }

    return false;
}

fn waitInflight(server: *Server, timeout_ms: u32) void {
    var waited: u32 = 0;
    while (server.inflight.load(.acquire) > 0 and waited < timeout_ms) : (waited += 5) {
        std.Io.sleep(io, std.Io.Duration.fromMilliseconds(5), .awake) catch return;
    }
}

fn handleRequest(server: *Server, request: *std.http.Server.Request, client_id: u64) !bool {
    _ = server.inflight.fetchAdd(1, .acq_rel);
    defer _ = server.inflight.fetchSub(1, .acq_rel);

    const method = request.head.method;
    const keep_alive = request.head.keep_alive;
    const has_cookie = hasSessionCookie(request, server.token);
    const origin_ok = if (util.isMutating(@tagName(method))) originAllowed(server, request) else true;

    // copy everything that points into the head buffer before the body reader
    // invalidates it
    const target = try allocator.dupe(u8, request.head.target);
    errdefer allocator.free(target);
    const headers_copy = try copyHeaders(request);
    errdefer {
        for (headers_copy) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        allocator.free(headers_copy);
    }

    if (std.mem.startsWith(u8, target, "/__webui/")) {
        const path = util.withoutQuery(target);
        const rest = path["/__webui/".len..];
        var name_buffer: [256]u8 = undefined;
        const name = std.fmt.bufPrint(&name_buffer, "webui/{s}", .{rest}) catch "";
        if (name.len > 0 and try serveAsset(server, request, name)) {
            return keep_alive and !server.stopping;
        }
    }

    if (util.isMutating(@tagName(method)) and (!has_cookie or !origin_ok)) {
        try respondText(request, .forbidden, "forbidden");
        return false;
    }

    const declared_body = request.head.transfer_encoding == .chunked or
        (request.head.content_length orelse 0) > 0;

    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);

    var body_buffer: [4096]u8 = undefined;
    const body_reader = request.readerExpectContinue(&body_buffer) catch {
        try respondText(request, .bad_request, "bad request");
        return false;
    };
    if (declared_body) {
        var chunk: [4096]u8 = undefined;
        while (true) {
            const read = body_reader.readSliceShort(&chunk) catch 0;
            if (read == 0) break;
            if (body.items.len + read > max_body) {
                try respondText(request, .payload_too_large, "request body too large");
                return false;
            }
            try body.appendSlice(allocator, chunk[0..read]);
        }
    }

    if (server.stop_path) |stop_path| {
        if (method == .POST and std.mem.eql(u8, util.withoutQuery(target), stop_path)) {
            server.stopping = true;
            try respondText(request, .ok, "stopping");
            return false;
        }
    }

    const job = try allocator.create(Job);
    errdefer allocator.destroy(job);

    const path = util.withoutQuery(target);
    const query = if (std.mem.indexOfScalar(u8, target, '?')) |index| target[index + 1 ..] else "";
    job.* = .{
        .client_id = client_id,
        .method = try allocator.dupe(u8, @tagName(method)),
        .target = target,
        .path = try allocator.dupe(u8, path),
        .query = try allocator.dupe(u8, query),
        .body = try body.toOwnedSlice(allocator),
        .headers = headers_copy,
        .keep_alive = keep_alive,
    };
    body = .empty;

    server.pushJob(job);

    job.mutex.lockUncancelable(io);
    while (!job.done) job.condition.waitUncancelable(io, &job.mutex);
    job.mutex.unlock(io);

    const response_keep_alive = job.keep_alive;
    var response = job.response;
    job.response = .{};
    job.deinit();

    var headers: std.ArrayList(std.http.Header) = .empty;
    defer headers.deinit(allocator);

    for (response.headers) |header| {
        try headers.append(allocator, .{ .name = header.name, .value = header.value });
    }
    var cookie_buffer: [128]u8 = undefined;
    if (!has_cookie) {
        try headers.append(allocator, .{ .name = "set-cookie", .value = util.formatCookie(&cookie_buffer, server.token) });
    }

    const responded = request.respond(response.body, .{
        .status = response.status,
        .extra_headers = headers.items,
        .keep_alive = response_keep_alive,
    });
    response.deinit();
    responded catch return false;

    return response_keep_alive and !server.stopping;
}

fn copyHeaders(request: *const std.http.Server.Request) ![]Header {
    var list: std.ArrayList(Header) = .empty;
    errdefer {
        for (list.items) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        list.deinit(allocator);
    }
    var iterator = request.iterateHeaders();
    while (iterator.next()) |header| {
        try list.append(allocator, .{
            .name = try allocator.dupe(u8, header.name),
            .value = try allocator.dupe(u8, header.value),
        });
    }
    return list.toOwnedSlice(allocator);
}

fn respondText(request: *std.http.Server.Request, status: std.http.Status, body: []const u8) !void {
    try request.respond(body, .{
        .status = status,
        .extra_headers = &.{.{ .name = "content-type", .value = "text/plain; charset=utf-8" }},
        .keep_alive = false,
    });
}

// ---------------------------------------------------------------------------
// server sent events
// ---------------------------------------------------------------------------

fn queryValue(target: []const u8, key: []const u8) ?[]const u8 {
    const start = std.mem.indexOfScalar(u8, target, '?') orelse return null;
    var iterator = std.mem.splitScalar(u8, target[start + 1 ..], '&');
    while (iterator.next()) |pair| {
        const eq = std.mem.indexOfScalar(u8, pair, '=') orelse continue;
        if (std.mem.eql(u8, pair[0..eq], key)) return pair[eq + 1 ..];
    }
    return null;
}

fn writeSseEvent(body: *std.http.BodyWriter, event: []const u8, data: []const u8) !void {
    const writer = &body.writer;
    try writer.writeAll("event: ");
    try writer.writeAll(event);
    try writer.writeAll("\n");
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |line| {
        try writer.writeAll("data: ");
        try writer.writeAll(line);
        try writer.writeAll("\n");
    }
    try writer.writeAll("\n");
    // BodyWriter.flush only flushes the protocol output; the body buffer has to
    // be drained first.
    try body.writer.flush();
    try body.flush();
}

fn enqueueSse(client: *SseClient, event: []const u8, data: []const u8) void {
    client.mutex.lockUncancelable(io);
    defer client.mutex.unlock(io);

    if (client.closed) return;

    // Only the newest tree matters: drop pending html events.
    if (std.mem.eql(u8, event, "html")) {
        var index: usize = 0;
        while (index < client.queue.items.len) {
            if (std.mem.eql(u8, client.queue.items[index].event, "html")) {
                const removed = client.queue.orderedRemove(index);
                client.queued_bytes -= removed.event.len + removed.data.len;
                allocator.free(removed.event);
                allocator.free(removed.data);
                continue;
            }
            index += 1;
        }
    }

    client.queued_bytes += event.len + data.len;
    if (client.queued_bytes > max_sse_queue_bytes) {
        client.closed = true;
        client.condition.broadcast(io);
        return;
    }

    const duplicate_event = allocator.dupe(u8, event) catch return;
    const duplicate_data = allocator.dupe(u8, data) catch {
        allocator.free(duplicate_event);
        return;
    };
    client.queue.append(allocator, .{ .event = duplicate_event, .data = duplicate_data }) catch {
        allocator.free(duplicate_event);
        allocator.free(duplicate_data);
        return;
    };
    client.condition.signal(io);
}

fn broadcastTo(server: *Server, client_id: ?u64, event: []const u8, data: []const u8) usize {
    server.sse_mutex.lockUncancelable(io);
    defer server.sse_mutex.unlock(io);

    var count: usize = 0;
    for (server.sse_clients.items) |client| {
        if (client_id) |wanted| {
            if (client.id != wanted) continue;
        }
        enqueueSse(client, event, data);
        count += 1;
    }
    return count;
}

fn handleSse(server: *Server, request: *std.http.Server.Request, stream: std.Io.net.Stream, client_id: u64) !void {
    if (!hasSessionCookie(request, server.token) or !originAllowed(server, request)) {
        try respondText(request, .forbidden, "forbidden");
        return;
    }

    const target = request.head.target;
    const once = queryValue(target, "once") != null;
    const push = queryValue(target, "push");

    var headers: [3]std.http.Header = .{
        .{ .name = "content-type", .value = "text/event-stream" },
        .{ .name = "cache-control", .value = "no-store" },
        .{ .name = "x-accel-buffering", .value = "no" },
    };

    var buffer: [4096]u8 = undefined;
    var body = try request.respondStreaming(&buffer, .{ .respond_options = .{
        .status = .ok,
        .keep_alive = false,
        .extra_headers = &headers,
    } });
    try body.flush();

    if (once) {
        if (push) |data| try writeSseEvent(&body, "html", data);
        body.end() catch {};
        return;
    }

    server.markSse(stream.socket.handle);

    const sse_client = allocator.create(SseClient) catch return;
    sse_client.* = .{ .id = client_id };
    defer {
        server.sse_mutex.lockUncancelable(io);
        for (server.sse_clients.items, 0..) |entry, index| {
            if (entry == sse_client) {
                _ = server.sse_clients.swapRemove(index);
                break;
            }
        }
        server.sse_mutex.unlock(io);
        sse_client.clear();
        sse_client.queue.deinit(allocator);
        allocator.destroy(sse_client);
    }

    server.sse_mutex.lockUncancelable(io);
    server.sse_clients.append(allocator, sse_client) catch {
        server.sse_mutex.unlock(io);
        return;
    };
    server.sse_mutex.unlock(io);

    while (true) {
        var timed_out = false;
        sse_client.mutex.lockUncancelable(io);
        while (sse_client.queue.items.len == 0 and !sse_client.closed) {
            sse_client.condition.waitTimeout(io, &sse_client.mutex, .{ .duration = .{
                .raw = std.Io.Duration.fromMilliseconds(sse_keepalive_ms),
                .clock = .awake,
            } }) catch {
                timed_out = true;
                break;
            };
        }
        const closed = sse_client.closed;
        var batch = sse_client.queue;
        sse_client.queue = .empty;
        sse_client.queued_bytes = 0;
        sse_client.mutex.unlock(io);

        if (timed_out and batch.items.len == 0) {
            body.writer.writeAll(":\n\n") catch return;
            body.writer.flush() catch return;
            body.flush() catch return;
            continue;
        }

        var failed = false;
        for (batch.items) |message| {
            if (!failed) {
                writeSseEvent(&body, message.event, message.data) catch {
                    failed = true;
                };
            }
            allocator.free(message.event);
            allocator.free(message.data);
        }
        batch.deinit(allocator);
        if (failed) return;

        body.writer.flush() catch return;
        body.flush() catch return;
        if (closed) break;
    }

    body.end() catch {};
}

// ---------------------------------------------------------------------------
// dispatch
// ---------------------------------------------------------------------------

fn handleJob(server: *Server, job: *Job) void {
    const lua = server.lua;
    const started = std.Io.Clock.Timestamp.now(io, .awake).raw.nanoseconds;

    pushDispatch(lua);
    pushRequestTable(lua, job);

    var failed = false;
    lua.protectedCall(.{ .args = 1, .results = 1 }) catch |err| {
        const message = lua.toString(-1) catch @errorName(err);
        std.debug.print("webserver: {s} {s} failed: {s}\n", .{ job.method, job.target, message });
        failed = true;
    };

    if (failed) {
        lua.pop(1);
        job.response = .{
            .status = .internal_server_error,
            .body = allocator.dupe(u8, "handler error") catch &.{},
        };
    } else {
        readResponse(lua, job) catch |err| {
            std.debug.print("webserver: invalid response for {s} {s}: {any}\n", .{ job.method, job.target, err });
            job.response.deinit();
            job.response = .{
                .status = .internal_server_error,
                .body = allocator.dupe(u8, "invalid response") catch &.{},
            };
        };
        lua.pop(1);
    }

    const elapsed = std.Io.Clock.Timestamp.now(io, .awake).raw.nanoseconds - started;
    const elapsed_ms = @divTrunc(elapsed, std.time.ns_per_ms);
    if (server.warn_ms > 0 and elapsed_ms > server.warn_ms) {
        std.debug.print("webserver: handler {s} {s} took {d} ms\n", .{ job.method, job.target, elapsed_ms });
    }

    job.mutex.lockUncancelable(io);
    job.done = true;
    job.mutex.unlock(io);
    job.condition.broadcast(io);
}

fn pushDispatch(lua: *Lua) void {
    _ = lua.pushString(dispatch_key);
    _ = lua.getTable(zlua.registry_index);
}

fn pushRequestTable(lua: *Lua, job: *const Job) void {
    lua.newTable();
    luax.setTableString(lua, -1, "method", job.method);
    luax.setTableString(lua, -1, "target", job.target);
    luax.setTableString(lua, -1, "path", job.path);
    luax.setTableString(lua, -1, "query", job.query);
    luax.setTableString(lua, -1, "body", job.body);
    luax.setTableInteger(lua, -1, "client", @intCast(job.client_id));
    luax.setTableBoolean(lua, -1, "keep_alive", job.keep_alive);
    lua.newTable();
    for (job.headers) |header| {
        luax.setTableString(lua, -1, header.name, header.value);
    }
    luax.setTableValue(lua, -2, "headers", -1, true);
}

fn dupeHeaders(pairs: []const [2][]const u8) ![]Header {
    const headers = try allocator.alloc(Header, pairs.len);
    for (pairs, 0..) |pair, index| {
        headers[index] = .{
            .name = try allocator.dupe(u8, pair[0]),
            .value = try allocator.dupe(u8, pair[1]),
        };
    }
    return headers;
}

fn readResponse(lua: *Lua, job: *Job) !void {
    const kind = lua.typeOf(-1);

    if (kind == .string) {
        const body = try lua.toString(-1);
        job.response = .{
            .status = .ok,
            .body = if (body.len > 0) try allocator.dupe(u8, body) else &.{},
            .headers = try dupeHeaders(&.{.{ "content-type", "text/html; charset=utf-8" }}),
        };
        return;
    }

    if (kind != .table) return error.InvalidResponse;

    var response: Response = .{};

    _ = lua.pushString("body");
    switch (lua.getTable(-2)) {
        .string, .number => {
            const body = try lua.toString(-1);
            if (body.len > 0) response.body = try allocator.dupe(u8, body);
        },
        else => {},
    }
    lua.pop(1);

    _ = lua.pushString("status");
    if (lua.getTable(-2) == .number) {
        const raw = lua.toInteger(-1) catch 200;
        response.status = std.enums.fromInt(std.http.Status, raw) orelse .internal_server_error;
    }
    lua.pop(1);

    var headers: std.ArrayList(Header) = .empty;
    errdefer {
        for (headers.items) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        headers.deinit(allocator);
    }

    _ = lua.pushString("header");
    if (lua.getTable(-2) == .table) {
        lua.pushNil();
        while (lua.next(-2)) {
            const raw_name = lua.toString(-2) catch "";
            const raw_value = lua.toString(-1) catch "";
            const name = if (std.mem.eql(u8, raw_name, "content_type"))
                "content-type"
            else if (std.mem.eql(u8, raw_name, "content_disposition"))
                "content-disposition"
            else
                raw_name;
            try headers.append(allocator, .{
                .name = try allocator.dupe(u8, name),
                .value = try allocator.dupe(u8, raw_value),
            });
            lua.pop(1);
        }
    }
    lua.pop(1);

    response.headers = try headers.toOwnedSlice(allocator);
    job.response = response;
}

// ---------------------------------------------------------------------------
// Lua API
// ---------------------------------------------------------------------------

fn stop(lua: *Lua) !i32 {
    _ = lua;
    if (active.server) |server| {
        server.stopping = true;
        server.jobs_condition.broadcast(io);
    }
    return 0;
}

fn info(lua: *Lua) !i32 {
    const server = active.server orelse {
        lua.pushNil();
        return 1;
    };
    pushInfoTable(lua, server);
    return 1;
}

fn clients(lua: *Lua) !i32 {
    const server = active.server orelse {
        lua.newTable();
        return 1;
    };

    server.clients_mutex.lockUncancelable(io);
    defer server.clients_mutex.unlock(io);

    lua.newTable();
    for (server.clients.items, 0..) |client, index| {
        lua.newTable();
        luax.setTableInteger(lua, -1, "id", @intCast(client.id));
        luax.setTableString(lua, -1, "transport", @tagName(client.transport));
        lua.setTable(@intCast(index + 1));
    }
    return 1;
}

fn sse(lua: *Lua) !i32 {
    const server = active.server orelse {
        lua.pushInteger(0);
        return 1;
    };
    const client_id = luax.getArgIntegerOrError(lua, 1, "expecting a client id");
    const event = luax.getArgStringOrError(lua, 2, "expecting an event name");
    const data = luax.getArgStringOrError(lua, 3, "expecting event data");
    lua.pushInteger(@intCast(broadcastTo(server, @intCast(client_id), event, data)));
    return 1;
}

fn broadcast(lua: *Lua) !i32 {
    const server = active.server orelse {
        lua.pushInteger(0);
        return 1;
    };
    const event = luax.getArgStringOrError(lua, 1, "expecting an event name");
    const data = luax.getArgStringOrError(lua, 2, "expecting event data");
    lua.pushInteger(@intCast(broadcastTo(server, null, event, data)));
    return 1;
}

fn asset(lua: *Lua) !i32 {
    const name = luax.getArgStringOrError(lua, 1, "expecting an asset name");
    assetsInit();

    if (findAsset(name)) |entry| {
        _ = lua.pushString(entry.data);
        _ = lua.pushString(entry.content_type);
        _ = lua.pushString(@tagName(entry.source));
        return 3;
    }

    const from_payload = file_reader.readFromPayload(allocator, name) catch null;
    if (from_payload) |data| {
        defer allocator.free(data);
        _ = lua.pushString(data);
        _ = lua.pushString(util.contentType(name));
        _ = lua.pushString("payload");
        return 3;
    }
    return 0;
}

fn assetSet(lua: *Lua) !i32 {
    const name = luax.getArgStringOrError(lua, 1, "expecting an asset name");
    const data = luax.getArgStringOrError(lua, 2, "expecting the asset content");
    const content_type = if (lua.typeOf(3) == .string)
        luax.getArgStringOrError(lua, 3, "expecting a content type")
    else
        util.contentType(name);

    if (active.server != null) {
        return luaerror.ret(lua, "cannot change assets while serving", .{});
    }

    assetsInit();

    if (findAsset(name)) |entry| {
        if (entry.source == .runtime and entry.data.len > 0) allocator.free(entry.data);
        allocator.free(entry.content_type);
        entry.data = try allocator.dupe(u8, data);
        entry.content_type = try allocator.dupe(u8, content_type);
        entry.source = .runtime;
        lua.pushBoolean(true);
        return 1;
    }

    try assets.append(allocator, .{
        .name = try allocator.dupe(u8, name),
        .content_type = try allocator.dupe(u8, content_type),
        .data = try allocator.dupe(u8, data),
        .source = .runtime,
    });
    lua.pushBoolean(true);
    return 1;
}

fn assetList(lua: *Lua) !i32 {
    assetsInit();
    lua.newTable();
    for (assets.items, 0..) |entry, index| {
        lua.newTable();
        luax.setTableString(lua, -1, "name", entry.name);
        luax.setTableString(lua, -1, "content_type", entry.content_type);
        luax.setTableString(lua, -1, "source", @tagName(entry.source));
        lua.setTable(@intCast(index + 1));
    }
    return 1;
}
