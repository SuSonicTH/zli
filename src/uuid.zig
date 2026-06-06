const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");

const time = std.time;

pub const Uuid = u128;

const functions = [_]zlua.FnReg{
    .{ .name = "v4", .func = zlua.wrap(uuid_v4) },
    .{ .name = "v7", .func = zlua.wrap(uuid_v7) },
};

var io: std.Io = undefined;
var random_impl: std.Random.IoSource = undefined;
var random: std.Random = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
    random_impl = .{ .io = io };
    random = random_impl.interface();
}

pub fn luaopen_uuid(lua: *Lua) i32 {
    lua.newLib(&functions);
    return 1;
}

fn new_v4() Uuid {
    var uuid: Uuid = random.int(Uuid);
    uuid &= 0xffffffffffffff3fff0fffffffffffff;
    uuid |= 0x00000000000000800040000000000000;
    return uuid;
}

fn new_v7() Uuid {
    const ts = @as(u48, @intCast(std.Io.Clock.real.now(io).toMilliseconds() & 0xffffffffffff));
    const ts_swapped = ((ts >> 40) & 0x0000000000ff) | ((ts >> 24) & 0x00000000ff00) | ((ts >> 8) & 0x000000ff0000) | ((ts << 8) & 0x0000ff000000) | ((ts << 24) & 0x00ff00000000) | ((ts << 40) & 0xff0000000000);
    var uuid: Uuid = @as(Uuid, @intCast(random.int(u80))) << 48;
    uuid |= @as(Uuid, @intCast(ts_swapped));
    uuid &= 0xffffffffffffff3fff0fffffffffffff;
    uuid |= 0x00000000000000800070000000000000;
    return uuid;
}

const stringPos = [16]u8{ 0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34 };
const hexChar = "0123456789abcdef";

fn toString(uuid: Uuid) [36]u8 {
    var buffer: [36]u8 = .{ 0, 0, 0, 0, 0, 0, 0, 0, '-', 0, 0, 0, 0, '-', 0, 0, 0, 0, '-', 0, 0, 0, 0, '-', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    inline for (stringPos, 0..) |o, s| {
        const b: u8 = @truncate(uuid >> (s * 8));
        buffer[o + 0] = hexChar[b >> 4];
        buffer[o + 1] = hexChar[b & 0x0f];
    }
    return buffer;
}

fn uuid_v4(lua: *Lua) i32 {
    _ = lua.pushString(&toString(new_v4()));
    return 1;
}

fn uuid_v7(lua: *Lua) i32 {
    _ = lua.pushString(&toString(new_v7()));
    return 1;
}
