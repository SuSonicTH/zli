const std = @import("std");
const ziglua = @import("ziglua/src/ziglua-5.4/lib.zig");
const libraries = @import("fm_libraries.zig");
const c = @cImport({
    @cInclude("unzip.h");
});

const Lua = ziglua.Lua;
const debug = std.log.debug;

const fullmoon_main: [:0]const u8 = @embedFile("fullmoon.lua");
var prog_name: [:0]u8 = undefined;
var uzfh: c.unzFile = undefined;

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var lua = try Lua.init(allocator);
    defer lua.deinit();

    try createArgTable(&lua, allocator);
    _ = lua.gcSetGenerational(0, 0);
    _ = libraries.fullmoon_openlibs(&lua);
    try create_payload_searcher(&lua);

    lua.pushFunction(ziglua.wrap(messageHandler));
    try lua.loadBuffer(fullmoon_main, prog_name, .binary_text);
    if (lua.protectedCall(0, 0, 1)) {} else |_| {
        const message = lua.toString(-1) catch "Unknown error";
        std.log.err("{s}: {s}", .{ prog_name, message });
        lua.pop(1);
    }
}

fn createArgTable(lua: *Lua, allocator: std.mem.Allocator) !void {
    const args = try std.process.argsAlloc(allocator);
    prog_name = args[0];

    lua.createTable(@intCast(i32, args.len), 1);
    for (args, 0..) |arg, i| {
        _ = lua.pushString(arg);
        lua.rawSetIndex(-2, @intCast(i32, i));
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
    lua.rawSetIndex(-2, @intCast(ziglua.Integer, len) + 1);
    lua.setTop(top);
}

const extention_lua = ".lua";
const extention_init = "/init.lua";

fn payload_searcher(lua: *Lua) i32 {
    const arg = lua.checkString(1);
    const module = arg[0..std.mem.len(arg) :0];
    var filename: [260:0]u8 = undefined;

    std.mem.copy(u8, &filename, module);
    std.mem.copy(u8, filename[module.len..], extention_lua);
    filename[module.len + extention_lua.len] = 0;
    if (c.unzLocateFile(uzfh, &filename, 0) != c.UNZ_OK) {
        std.mem.copy(u8, filename[module.len..], extention_init);
        filename[module.len + extention_init.len] = 0;
        if (c.unzLocateFile(uzfh, &filename, 0) != c.UNZ_OK) {
            _ = lua.pushFString("no file '%s.lua' or '%s/init.lua' in %s", .{ module.ptr, module.ptr, prog_name.ptr });
            return 1;
        }
    }

    if (c.unzOpenCurrentFile(uzfh) != c.UNZ_OK) {
        lua.pushNil();
        return 1;
    }

    lua.pushFunction(ziglua.wrap(payload_loader));
    _ = lua.pushString(filename[0..]);
    return 2;
}

const BUFFER_SIZE: usize = 4096;
var buffer: [BUFFER_SIZE]u8 = undefined;

fn payload_reder(state: ?*ziglua.LuaState, data: ?*anyopaque, size: [*c]usize) callconv(.C) [*c]const u8 {
    _ = data;
    _ = state;
    size.* = @intCast(usize, c.unzReadCurrentFile(uzfh, &buffer, BUFFER_SIZE));
    return &buffer;
}

fn payload_loader(lua: *Lua) i32 {
    const name: [*:0]const u8 = lua.toString(2) catch unreachable;
    lua.load(payload_reder, undefined, name[0..std.mem.len(name) :0], .binary_text) catch lua.raiseError();
    lua.call(0, -1);
    return 1;
}
