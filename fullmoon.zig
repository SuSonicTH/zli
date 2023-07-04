const std = @import("std");
const ziglua = @import("ziglua/src/ziglua-5.4/lib.zig");
const libraries = @import("fm_libraries.zig");

const Lua = ziglua.Lua;

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

var prog_name: [:0]u8 = undefined;

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

const fullmoon_main: [:0]const u8 = @embedFile("fullmoon.lua");

//todo: implement signal handling?
//todo: implement fm_paylod (in seperate file?) in zig

pub fn main() !void {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //const allocator = gpa.allocator();
    //defer _ = gpa.deinit();

    //var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    //defer arena.deinit();
    //const allocator = arena.allocator();
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
