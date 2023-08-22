const std = @import("std");
const ziglua = @import("ziglua");
const libraries = @import("libraries.zig");
const c = @cImport({
    @cInclude("unzip.h");
});

const Lua = ziglua.Lua;
const debug = std.log.debug;

const main_lua: [:0]const u8 = @embedFile("stripped/main.lua");
var prog_name: [:0]u8 = undefined;
var uzfh: c.unzFile = undefined;

const allocator = std.heap.c_allocator;

pub fn main() !void {
    var lua = try Lua.init(allocator);
    defer lua.deinit();

    try createArgTable(&lua);
    _ = lua.gcSetGenerational(0, 0);
    _ = libraries.openlibs(&lua);
    try create_payload_searcher(&lua);

    lua.pushFunction(ziglua.wrap(messageHandler));
    try lua.loadBuffer(main_lua, prog_name, .binary_text);
    if (lua.protectedCall(0, 0, 1)) {} else |_| {
        const message = lua.toString(-1) catch "Unknown error";
        std.log.err("{s}: {s}", .{ prog_name, message });
        lua.pop(1);
    }
}

fn createArgTable(lua: *Lua) !void {
    const args = try std.process.argsAlloc(allocator);
    prog_name = args[0];

    lua.createTable(@intCast(args.len), 1);
    for (args, 0..) |arg, i| {
        _ = lua.pushString(arg);
        lua.rawSetIndex(-2, @intCast(i));
    }
    lua.setGlobal("arg");
}

fn messageHandler(lua: *Lua) i32 {
    if (lua.toString(1)) |message| {
        lua.traceback(lua, message[0..std.mem.len(message) :0], 1);
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

fn create_payload_searcher(lua: *Lua) !void {
    uzfh = c.unzOpen(prog_name);
    if (uzfh == null) {
        return;
    }
    const top = lua.getTop();

    _ = try lua.getGlobal("package");
    const package = lua.getTop();

    _ = lua.pushString("searchers");
    _ = lua.getTable(package);
    const len = lua.rawLen(-1);
    lua.pushFunction(ziglua.wrap(payload_searcher));
    lua.rawSetIndex(-2, @intCast(len + 1));
    lua.setTop(top);
}

const extention_lua = ".lua";
const extention_init = "/init.lua";

fn payload_searcher(lua: *Lua) i32 {
    const arg = lua.checkString(1);
    const filename = std.fmt.allocPrintZ(allocator, "{s}.lua", .{arg}) catch unreachable;
    defer allocator.free(filename);

    if (c.unzLocateFile(uzfh, filename, 0) != c.UNZ_OK) {
        const initName = std.fmt.allocPrintZ(allocator, "{s}.lua", .{arg}) catch unreachable;
        defer allocator.free(initName);

        if (c.unzLocateFile(uzfh, initName, 0) != c.UNZ_OK) {
            _ = lua.pushFString("no file '%s.lua' or '%s/init.lua' in %s", .{ arg, arg, prog_name.ptr });
            return 1;
        }
    }

    if (c.unzOpenCurrentFile(uzfh) != c.UNZ_OK) {
        lua.pushNil();
        return 1;
    }

    lua.pushFunction(ziglua.wrap(payload_loader));
    _ = lua.pushString(std.mem.sliceTo(arg, 0));
    return 2;
}

const BUFFER_SIZE: usize = 4096;
var buffer: [BUFFER_SIZE]u8 = undefined;

fn payload_reder(state: ?*ziglua.LuaState, data: ?*anyopaque, size: [*c]usize) callconv(.C) [*c]const u8 {
    _ = data;
    _ = state;
    size.* = @intCast(c.unzReadCurrentFile(uzfh, &buffer, BUFFER_SIZE));
    return &buffer;
}

fn payload_loader(lua: *Lua) i32 {
    const name: [*:0]const u8 = lua.toString(2) catch unreachable;
    lua.load(payload_reder, undefined, name[0..std.mem.len(name) :0], .binary_text) catch lua.raiseError();
    lua.call(0, -1);
    return 1;
}
