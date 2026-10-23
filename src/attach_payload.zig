const std = @import("std");
const c = @import("c_zip");

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

    const zfh = c.zipOpen(output.ptr, c.APPEND_STATUS_CREATEAFTER) orelse {
        std.debug.print("attach_payload: could not open '{s}' as zip\n", .{output});
        std.process.exit(1);
    };

    var index: usize = 3;
    while (index + 1 < args.len) : (index += 2) {
        const name = args[index];
        const path = args[index + 1];

        const data = cwd.readFileAlloc(init.io, path, allocator, std.Io.Limit.unlimited) catch |err| {
            _ = c.zipClose(zfh, null);
            std.debug.print("attach_payload: could not read '{s}': {s}\n", .{ path, @errorName(err) });
            std.process.exit(1);
        };
        defer allocator.free(data);

        var zfi: c.zip_fileinfo = std.mem.zeroes(c.zip_fileinfo);
        zfi.tmz_date.tm_year = 2024;
        zfi.tmz_date.tm_mon = 0;
        zfi.tmz_date.tm_mday = 1;
        zfi.tmz_date.tm_hour = 0;
        zfi.tmz_date.tm_min = 0;
        zfi.tmz_date.tm_sec = 0;
        zfi.dosDate = 0;

        if (c.zipOpenNewFileInZip(zfh, name.ptr, &zfi, null, 0, null, 0, null, c.Z_DEFLATED, 9) != c.ZIP_OK) {
            _ = c.zipClose(zfh, null);
            std.debug.print("attach_payload: could not add '{s}'\n", .{name});
            std.process.exit(1);
        }

        if (data.len > 0 and c.zipWriteInFileInZip(zfh, data.ptr, @intCast(data.len)) != c.ZIP_OK) {
            _ = c.zipCloseFileInZip(zfh);
            _ = c.zipClose(zfh, null);
            std.debug.print("attach_payload: could not write '{s}'\n", .{name});
            std.process.exit(1);
        }
        _ = c.zipCloseFileInZip(zfh);
    }

    if (c.zipClose(zfh, "zli") != c.ZIP_OK) {
        std.debug.print("attach_payload: could not close '{s}'\n", .{output});
        std.process.exit(1);
    }
}
