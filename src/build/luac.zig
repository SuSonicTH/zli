const std = @import("std");
const ziglua = @import("ziglua");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len != 3) {
        std.log.err("usage luac input output", .{});
        return;
    }

    var lua = try ziglua.Lua.init(allocator);
    defer lua.deinit();

    try lua.loadFile(args[1], ziglua.Mode.text);

    const output = try std.fs.cwd().createFile(args[2], .{});
    defer output.close();

    try lua.dump(&luac_writer, @constCast(&output), true);
}

fn luac_writer(state: ?*ziglua.LuaState, buf: ?*const anyopaque, size: usize, data: ?*anyopaque) callconv(.C) c_int {
    _ = state;
    const file: *std.fs.File = @ptrCast(@alignCast(data));
    var buffer: []const u8 = @as([*]u8, @ptrCast(@constCast(buf)))[0..size];
    file.writeAll(buffer) catch unreachable;
    return 0;
}
