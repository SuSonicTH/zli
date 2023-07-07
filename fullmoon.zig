const std = @import("std");
const ziglua = @import("ziglua/src/ziglua-5.4/lib.zig");
const libraries = @import("fm_libraries.zig");
const c = @cImport({
    @cInclude("unzip.h");
});

const Lua = ziglua.Lua;

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

    std.log.debug("prog_name {s}", .{prog_name});

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

    try lua.getGlobal("package");
    const package = lua.getTop();

    _ = lua.pushString("searchers");
    _ = lua.getTable(package);
    const len = lua.rawLen(-1);
    lua.pushFunction(ziglua.wrap(payload_searcher));
    lua.rawSetIndex(-2, len + 1);
    lua.setTop(top);
}

const extention_lua = ".lua";
const extention_init = "/init.lua";

fn payload_searcher(lua: *Lua) i32 {
    const module = lua.toString(1);
    var filename: u8[260] = undefined;

    std.mem.copy(filename, module, module.len);
    std.mem.copy(filename[filename.len..], extention_lua, extention_lua.len);
    if (c.unzLocateFile(uzfh, filename, 0) != c.UNZ_OK) {
        std.mem.copy(filename, module, module.len);
        std.mem.copy(filename[filename.len..], extention_init, extention_init.len);
        if (c.unzLocateFile(uzfh, filename, 0) != c.UNZ_OK) {
            lua.pushFString("no file '%s.lua' or '%s/init.lua' in %s", .{ module, module, prog_name });
            return 1;
        }
    }

    if (c.unzOpenCurrentFile(uzfh) != c.UNZ_OK) {
        lua.pushNil();
        return 1;
    }

    lua.pushFunction(ziglua.wrap(payload_loader));
    lua.pushstring(filename);
    return 2;
}

const BUFFER_SIZE = 4096;
fn payload_reder(state: ?*ziglua.LuaState, buf: ?*const anyopaque, size: usize, data: ?*anyopaque) callconv(.C) c_int {
    _ = data;
    _ = buf;
    _ = state;
    var buffer: u8[BUFFER_SIZE] = undefined;
    size = c.unzReadCurrentFile(uzfh, &buffer, BUFFER_SIZE);
    return buffer;
}

fn payload_loader(lua: *Lua) i32 {
    lua.load(payload_reder, null, lua.toString(2), "rt") orelse lua.raiseError();
    lua.call(0, -1, 0) orelse lua.raiseError();
    return 1;
}
