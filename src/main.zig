const std = @import("std");
const builtin = @import("builtin");
const zlua = @import("zlua");
const libraries = @import("libraries.zig");
const Utf8Output = @import("Utf8Output.zig");
const luax = @import("luax.zig");
const zip_reader = @import("zip_reader.zig");

const Lua = zlua.Lua;

const init_lua: [:0]const u8 = @embedFile("init.lua");
var prog_name: [:0]const u8 = undefined;
var payload: ?zip_reader.Archive = null;

const allocator = std.heap.c_allocator;

const Selection = struct {
    source: Source,
    skip_arg: usize,

    const Source = union(enum) {
        payload: [:0]const u8,
        file: [:0]const u8,
        stdin,
    };
};

pub fn main(init: std.process.Init) !void {
    Utf8Output.init();
    defer Utf8Output.deinit();

    var lua = try Lua.init(allocator);
    defer lua.deinit();

    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    // argv[0] is not necessarily a path (for example when the binary is found
    // through PATH). Resolve the real executable path for payload lookup.
    prog_name = std.process.executablePathAlloc(init.io, allocator) catch args[0];

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    _ = lua.gcSetGenerational(0, 0);
    _ = libraries.openlibs(init.io, lua);
    try create_payload_searcher(lua, init.io);
    defer if (payload) |*archive| archive.deinit();
    createZliTable(lua);

    const selection = selectScript(arena.allocator(), args, init.io) catch |err| {
        reportSelectionError(err, args);
        std.process.exit(1);
    };

    createArgTable(lua, args, selection.skip_arg);

    lua.pushFunction(zlua.wrap(messageHandler));
    runInit(lua);

    switch (selection.source) {
        .payload => |name| runPayload(lua, name),
        .file => |path| runFile(lua, path, init.io),
        .stdin => runStdin(lua, init.io),
    }
}

fn selectScript(a: std.mem.Allocator, args: []const [:0]const u8, io: std.Io) !Selection {
    if (args.len > 1 and args[1].len > 0 and args[1][0] == '@') {
        const name = args[1][1..];
        if (name.len == 0) return error.EmptyAtName;
        const entry = try findPayloadEntry(a, name) orelse return error.PayloadEntryNotFound;
        return .{ .source = .{ .payload = entry }, .skip_arg = 1 };
    }

    if (args.len > 1 and std.mem.eql(u8, args[1], "-")) {
        return .{ .source = .stdin, .skip_arg = 1 };
    }

    if (args.len > 1 and isExistingFile(io, args[1])) {
        return .{ .source = .{ .file = args[1] }, .skip_arg = 1 };
    }

    const exe_entry = try std.fmt.allocPrintSentinel(a, "{s}.lua", .{scriptBaseName(args)}, 0);
    if (payloadHasName(exe_entry)) {
        return .{ .source = .{ .payload = exe_entry }, .skip_arg = 0 };
    }
    if (payloadHasName("main.lua")) {
        return .{ .source = .{ .payload = "main.lua" }, .skip_arg = 0 };
    }
    if (payloadHasName("init.lua")) {
        return .{ .source = .{ .payload = "init.lua" }, .skip_arg = 0 };
    }
    return error.NoScript;
}

fn findPayloadEntry(a: std.mem.Allocator, name: []const u8) !?[:0]u8 {
    const exact = try a.dupeSentinel(u8, name, 0);
    if (payloadHasName(exact)) return exact;
    a.free(exact);

    const with_lua = try std.fmt.allocPrintSentinel(a, "{s}.lua", .{name}, 0);
    if (payloadHasName(with_lua)) return with_lua;
    a.free(with_lua);
    return null;
}

fn payloadHasName(name: []const u8) bool {
    if (payload == null) return false;
    return payload.?.find(name) != null;
}

fn isExistingFile(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .file;
}

fn scriptBaseName(args: []const [:0]const u8) []const u8 {
    var base: []const u8 = if (args.len > 0) std.fs.path.basename(args[0]) else "";
    if (base.len == 0) base = std.fs.path.basename(prog_name);
    if (builtin.os.tag == .windows and std.ascii.endsWithIgnoreCase(base, ".exe")) {
        base = base[0 .. base.len - 4];
    }
    if (base.len == 0) base = "zli";
    return base;
}

fn runInit(lua: *Lua) void {
    lua.loadBuffer(init_lua, "init.lua", .binary_text) catch {
        reportLuaError(lua);
        std.process.exit(1);
    };
    callChunk(lua);
}

fn runPayload(lua: *Lua, name: [:0]const u8) void {
    if (payload == null) {
        std.debug.print("Error: no payload attached to '{s}'\n", .{prog_name});
        std.process.exit(1);
    }

    const data = payload.?.readAll(name, allocator) catch |err| {
        std.debug.print("Error: could not read script '{s}' from payload: {s}\n", .{ name, @errorName(err) });
        std.process.exit(1);
    } orelse {
        std.debug.print("Error: script '{s}' not found in payload\n", .{name});
        std.process.exit(1);
    };

    lua.loadBuffer(data, name, .binary_text) catch {
        allocator.free(data);
        reportLuaError(lua);
        std.process.exit(1);
    };
    allocator.free(data);
    callChunk(lua);
}

fn runFile(lua: *Lua, path: [:0]const u8, io: std.Io) void {
    const data = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, std.Io.Limit.unlimited) catch |err| {
        std.debug.print("Error: could not read script '{s}': {s}\n", .{ path, @errorName(err) });
        std.process.exit(1);
    };
    defer allocator.free(data);
    runData(lua, data, path);
}

fn runStdin(lua: *Lua, io: std.Io) void {
    var stdin_buffer: [4096]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &stdin_buffer);
    const data = reader.interface.allocRemaining(allocator, std.Io.Limit.unlimited) catch |err| {
        std.debug.print("Error: could not read script from stdin: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer allocator.free(data);
    runData(lua, data, "=stdin");
}

fn runData(lua: *Lua, data: []const u8, name: [:0]const u8) void {
    lua.loadBuffer(data, name, .binary_text) catch {
        reportLuaError(lua);
        std.process.exit(1);
    };
    callChunk(lua);
}

fn callChunk(lua: *Lua) void {
    lua.protectedCall(.{ .args = 0, .results = 0, .msg_handler = 1 }) catch {
        reportLuaError(lua);
        std.process.exit(1);
    };
}

fn reportLuaError(lua: *Lua) void {
    const message = lua.toString(-1) catch "Unknown error";
    std.log.err("{s}: {s}", .{ prog_name, message });
    lua.pop(1);
}

fn reportSelectionError(err: anyerror, args: []const [:0]const u8) void {
    switch (err) {
        error.EmptyAtName => std.debug.print("Error: missing script name after '@'\n", .{}),
        error.PayloadEntryNotFound => {
            if (args.len > 1) {
                std.debug.print("Error: script '{s}' not found in payload\n", .{args[1][1..]});
            } else {
                std.debug.print("Error: script not found in payload\n", .{});
            }
        },
        error.NoScript => std.debug.print("Error: no script found\n", .{}),
        else => std.debug.print("Error: {s}\n", .{@errorName(err)}),
    }
    printUsage(displayName(args));
}

fn displayName(args: []const [:0]const u8) []const u8 {
    var name: []const u8 = if (args.len > 0) std.fs.path.basename(args[0]) else "";
    if (name.len == 0) name = std.fs.path.basename(prog_name);
    if (name.len == 0) name = "zli";
    return name;
}

fn printUsage(exe: []const u8) void {
    std.debug.print("Usage: {s} [@name | - | script.lua] [arguments...]\n", .{exe});
}

fn createZliTable(lua: *Lua) void {
    lua.newTable();
    luax.setTableString(lua, -1, "version", @embedFile("version"));
    luax.setTableString(lua, -1, "error_handling", "return");
    luax.setTableString(lua, -1, "exe_path", prog_name);
    luax.setTableFunction(lua, -1, "dofile", zlua.wrap(zli_dofile));
    lua.setGlobal("ZLI");
}

fn zli_dofile(lua: *Lua) i32 {
    const name = lua.checkString(1);
    if (payload == null) {
        return lua.raiseErrorStr("no payload attached", .{});
    }

    const entry = findPayloadEntry(allocator, name) catch return lua.raiseErrorStr("out of memory", .{});
    if (entry == null) {
        return lua.raiseErrorStr("script '%s' not found in payload", .{name.ptr});
    }

    const data = payload.?.readAll(entry.?, allocator) catch {
        allocator.free(entry.?);
        return lua.raiseErrorStr("could not read script '%s' from payload", .{name.ptr});
    };
    if (data == null) {
        allocator.free(entry.?);
        return lua.raiseErrorStr("script '%s' not found in payload", .{name.ptr});
    }

    lua.loadBuffer(data.?, entry.?, .binary_text) catch {
        allocator.free(data.?);
        allocator.free(entry.?);
        lua.raiseError();
    };
    allocator.free(data.?);
    allocator.free(entry.?);
    lua.call(.{ .args = 0, .results = 0 });
    return 0;
}

fn createArgTable(lua: *Lua, args: []const [:0]const u8, skip: usize) void {
    lua.createTable(@intCast(args.len), 1);
    var index: i64 = 0;
    if (args.len > 0) {
        _ = lua.pushString(args[0]);
        lua.setIndexRaw(-2, @intCast(index));
        index = 1;
    }

    var i: usize = 1 + skip;
    while (i < args.len) : (i += 1) {
        _ = lua.pushString(args[i]);
        lua.setIndexRaw(-2, @intCast(index));
        index += 1;
    }
    lua.setGlobal("arg");
}

fn messageHandler(lua: *Lua) i32 {
    if (lua.toString(1)) |message| {
        lua.traceback(lua, message, 1);
        return 1;
    } else |_| {
        if (lua.callMeta(1, "__tostring")) {
            if (lua.typeOf(-1) == .string) {
                return 1;
            }
        } else |_| {}
    }
    lua.traceback(lua, "(Object is not a string)", 1);
    return 1;
}

fn create_payload_searcher(lua: *Lua, io: std.Io) !void {
    payload = zip_reader.Archive.init(allocator, io, prog_name) catch null;
    if (payload == null) {
        return;
    }
    const top = lua.getTop();

    _ = lua.getGlobal("package");
    const package = lua.getTop();

    _ = lua.pushString("searchers");
    _ = lua.getTable(package);
    const len = lua.lenRaw(-1);
    lua.pushFunction(zlua.wrap(payload_searcher));
    lua.setIndexRaw(-2, @intCast(len + 1));
    lua.setTop(top);
}

const extension_lua = ".lua";
const extension_init = "/init.lua";

fn payload_searcher(lua: *Lua) i32 {
    const arg = lua.checkString(1);
    const filename = std.fmt.allocPrintSentinel(allocator, "{s}{s}", .{ arg, extension_lua }, 0) catch unreachable;
    defer allocator.free(filename);

    var found_name: []const u8 = filename;
    if (payload == null or payload.?.find(filename) == null) {
        const initName = std.fmt.allocPrintSentinel(allocator, "{s}{s}", .{ arg, extension_init }, 0) catch unreachable;
        defer allocator.free(initName);

        if (payload == null or payload.?.find(initName) == null) {
            _ = lua.pushFString("no file '%s.lua' or '%s/init.lua' in %s", .{ &arg, &arg, prog_name.ptr });
            return 1;
        }
        found_name = initName;
    }

    lua.pushFunction(zlua.wrap(payload_loader));
    _ = lua.pushString(found_name);
    return 2;
}

fn payload_loader(lua: *Lua) i32 {
    const name = lua.checkString(2);
    if (payload == null) {
        return lua.raiseErrorStr("no payload attached", .{});
    }

    const maybe_data = payload.?.readAll(name, allocator) catch
        return lua.raiseErrorStr("could not read module '%s' from payload", .{name.ptr});
    const data = maybe_data orelse
        return lua.raiseErrorStr("module '%s' not found in payload", .{name.ptr});

    lua.loadBuffer(data, name, .binary_text) catch {
        allocator.free(data);
        lua.raiseError();
    };
    allocator.free(data);
    lua.call(.{ .args = 0, .results = -1 });
    return 1;
}
