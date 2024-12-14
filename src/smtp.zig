const std = @import("std");
const smptClient = @import("smtp_client");

const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const luax = @import("luax.zig");

const smtp = [_]ziglua.FnReg{
    .{ .name = "send", .func = ziglua.wrap(send) },
};

pub fn luaopen_smpt(lua: *Lua) i32 {
    lua.newLib(&smtp);
    return 1;
}

const allocator = std.heap.c_allocator;

fn send(lua: *Lua) i32 {
    _ = lua;
    const config = smptClient.Config{
        .port = 587,
        .encryption = .tls,
        .host = "mail.gmx.net",
        .allocator = allocator,
        .username = "miwo@gmx.at",
        .password = "password",
        .timeout = 5,
    };

    smptClient.send(.{
        .from = "miwo@gmx.at",
        .to = &.{"susonicth@gmail.com"},
        .data = "From: Michael Wolf <miwo@gmx.at>\r\nTo: Mike <susonicth@gmail.com>\r\nSubject: Test\r\n\r\nThis is karl, I'm testing a SMTP client for Zig\r\n.\r\n",
    }, config) catch unreachable;

    return 0;
}
