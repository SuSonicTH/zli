const std = @import("std");

const zip_writer = @import("zip_writer.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.c_allocator;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    if (args.len < 4 or (args.len - 3) % 2 != 0) {
        std.debug.print("usage: {s} <input> <output> <name> <file> ...\n", .{args[0]});
        std.process.exit(2);
    }

    const input = args[1];
    const output = args[2];
    const cwd = std.Io.Dir.cwd();

    cwd.copyFile(input, cwd, output, init.io, .{}) catch |err| {
        std.debug.print("attach_payload: could not copy '{s}' to '{s}': {s}\n", .{ input, output, @errorName(err) });
        std.process.exit(1);
    };

    const writer = zip_writer.Writer.createAfter(allocator, init.io, output) catch |err| {
        std.debug.print("attach_payload: could not open '{s}' as zip: {s}\n", .{ output, @errorName(err) });
        std.process.exit(1);
    };
    defer writer.deinit();

    // Keep payload entries reproducible across builds.
    const timestamp: zip_writer.DosDateTime = .{
        .time = 0,
        .date = ((2024 - 1980) << 9) | (1 << 5) | 1,
    };

    var index: usize = 3;
    while (index + 1 < args.len) : (index += 2) {
        const name = args[index];
        const path = args[index + 1];

        const data = cwd.readFileAlloc(init.io, path, allocator, std.Io.Limit.unlimited) catch |err| {
            std.debug.print("attach_payload: could not read '{s}': {s}\n", .{ path, @errorName(err) });
            std.process.exit(1);
        };
        defer allocator.free(data);

        writer.addFileData(name, data, 9, "", timestamp) catch |err| {
            std.debug.print("attach_payload: could not add '{s}': {s}\n", .{ name, @errorName(err) });
            std.process.exit(1);
        };
    }

    writer.close("zli") catch |err| {
        std.debug.print("attach_payload: could not close '{s}': {s}\n", .{ output, @errorName(err) });
        std.process.exit(1);
    };
}
