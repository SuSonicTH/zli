const std = @import("std");
const flags_c99 = &.{"-std=gnu99"};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });

    const zigLuaStrip = b.dependency("zigLuaStrip", .{
        .optimize = std.builtin.OptimizeMode.Debug,
    });

    //zli exe
    const exe = b.addExecutable(.{
        .name = "zli",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(.{ .path = "src/" });
    exe.addIncludePath(.{ .path = "src/lib/Crossline/" });
    exe.addIncludePath(.{ .path = "src/lib/zlib/contrib/minizip/" });
    exe.addIncludePath(.{ .path = "src/lib/zlib/" });

    exe.addModule("ziglua", ziglua.module("ziglua"));
    exe.linkLibrary(ziglua.artifact("lua"));

    exe.linkLibrary(lsqlite3(b, target, optimize));
    exe.linkLibrary(lpeg(b, target, optimize));
    exe.linkLibrary(zlib(b, target, optimize));
    exe.linkLibrary(luaZlib(b, target, optimize));
    exe.linkLibrary(luaCJson(b, target, optimize));
    exe.linkLibrary(crossline(b, target, optimize));
    exe.linkLibrary(miniZip(b, target, optimize));
    exe.linkLibrary(timer(b, target, optimize));

    if (optimize != .Debug) {
        exe.strip = true;
    }

    if (optimize != .Debug) {
        inline for (luastrip_list) |script| {
            var run_step = b.addRunArtifact(zigLuaStrip.artifact("zigluastrip"));
            run_step.addArgs(&.{ script.input, script.output });
            exe.step.dependOn(&run_step.step);
        }
    } else {
        inline for (luastrip_list) |script| {
            copyFile(script.input, script.output) catch unreachable;
        }
    }

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    //run
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //test
    const test_cmd = b.addRunArtifact(exe);

    test_cmd.step.dependOn(b.getInstallStep());
    test_cmd.addArgs(&[_][]const u8{ "--test", "test.lua" });

    const test_step = b.step("test", "Test the app");
    test_step.dependOn(&test_cmd.step);
}

const luastrip_entry = struct {
    input: [:0]const u8,
    output: [:0]const u8,
};

const luastrip_list = [_]luastrip_entry{
    .{ .input = "src/auxiliary.lua", .output = "src/stripped/auxiliary.lua" },
    .{ .input = "src/crossline.lua", .output = "src/stripped/crossline.lua" },
    .{ .input = "src/filesystem.lua", .output = "src/stripped/filesystem.lua" },
    .{ .input = "src/lib/argparse/src/argparse.lua", .output = "src/stripped/argparse.lua" },
    .{ .input = "src/lib/f-string/F.lua", .output = "src/stripped/F.lua" },
    .{ .input = "src/lib/ftcsv/ftcsv.lua", .output = "src/stripped/ftcsv.lua" },
    .{ .input = "src/lib/lpeg/re.lua", .output = "src/stripped/re.lua" },
    .{ .input = "src/lib/luaunit/luaunit.lua", .output = "src/stripped/luaunit.lua" },
    .{ .input = "src/lib/serpent/src/serpent.lua", .output = "src/stripped/serpent.lua" },
    .{ .input = "src/logger.lua", .output = "src/stripped/logger.lua" },
    .{ .input = "src/main.lua", .output = "src/stripped/main.lua" },
    .{ .input = "src/stream.lua", .output = "src/stripped/stream.lua" },
    .{ .input = "src/timer.lua", .output = "src/stripped/timer.lua" },
    .{ .input = "src/tools/repl.lua", .output = "src/stripped/repl.lua" },
    .{ .input = "src/tools/sqlite_cli.lua", .output = "src/stripped/sqlite_cli.lua" },
    .{ .input = "src/unzip.lua", .output = "src/stripped/unzip.lua" },
    .{ .input = "src/zip.lua", .output = "src/stripped/zip.lua" },
    .{ .input = "src/collection/init.lua", .output = "src/stripped/collection.init.lua" },
    .{ .input = "src/collection/set.lua", .output = "src/stripped/collection.set.lua" },
    .{ .input = "src/collection/list.lua", .output = "src/stripped/collection.list.lua" },
    .{ .input = "src/collection/map.lua", .output = "src/stripped/collection.map.lua" },
    .{ .input = "src/benchmark.lua", .output = "src/stripped/benchmark.lua" },
    .{ .input = "src/grid.lua", .output = "src/stripped/grid.lua" },
    .{ .input = "src/memoize.lua", .output = "src/stripped/memoize.lua" },
};

fn copyFile(input_path: [:0]const u8, output_path: [:0]const u8) !void {
    const input = try std.fs.cwd().openFile(input_path, .{});
    defer input.close();

    const output = try std.fs.cwd().createFile(output_path, .{});
    defer output.close();

    var buffer: [4096]u8 = undefined;
    while (true) {
        const size = try input.readAll(&buffer);
        if (size > 0) {
            try output.writeAll(buffer[0..size]);
        } else {
            break;
        }
    }
}

const luaPath: std.Build.LazyPath = .{ .path = "src/lib/lua/" };

fn lsqlite3(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "lsqlite3",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath(.{ .path = "src/lib/lsqlite3/" });
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/lsqlite3/sqlite3.c",
        "src/lib/lsqlite3/lsqlite3.c",
    }, flags_c99);
    lib.linkLibC();
    return lib;
}

fn lpeg(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "lpeg",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath(.{ .path = "lpeg/" });
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/lpeg/lpcap.c",
        "src/lib/lpeg/lpcode.c",
        "src/lib/lpeg/lpprint.c",
        "src/lib/lpeg/lptree.c",
        "src/lib/lpeg/lpvm.c",
    }, flags_c99);
    lib.linkLibC();
    return lib;
}

fn zlib(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "zlib",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(.{ .path = "src/lib/zlib/" });
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/zlib/adler32.c",
        "src/lib/zlib/crc32.c",
        "src/lib/zlib/gzclose.c",
        "src/lib/zlib/gzread.c",
        "src/lib/zlib/infback.c",
        "src/lib/zlib/inflate.c",
        "src/lib/zlib/trees.c",
        "src/lib/zlib/zutil.c",
        "src/lib/zlib/compress.c",
        "src/lib/zlib/deflate.c",
        "src/lib/zlib/gzlib.c",
        "src/lib/zlib/gzwrite.c",
        "src/lib/zlib/inffast.c",
        "src/lib/zlib/inftrees.c",
        "src/lib/zlib/uncompr.c",
    }, &.{"-std=gnu89"});
    lib.linkLibC();
    return lib;
}

fn luaZlib(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "lua_zlib",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath(.{ .path = "src/lib/zlib/" });
    lib.addCSourceFile(.{ .file = .{ .path = "src/lib/lua-zlib/lua_zlib.c" }, .flags = &[_][]const u8{ "-std=c99", "-DLZLIB_COMPAT" } });
    lib.linkLibC();
    return lib;
}

fn miniZip(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "miniZip",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(.{ .path = "src/" });
    lib.addIncludePath(.{ .path = "src/lib/zlib/" });
    lib.addIncludePath(.{ .path = "src/lib/zlib/contrib/minizip/" });
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/zlib/contrib/minizip/zip.c",
        "src/lib/zlib/contrib/minizip/unzip.c",
        "src/lib/zlib/contrib/minizip/ioapi.c",
        "src/zip_util.c",
    }, flags_c99);
    switch (target.getOsTag()) {
        .windows => {
            lib.addCSourceFile(.{ .file = .{ .path = "src/lib/zlib/contrib/minizip/iowin32.c" }, .flags = flags_c99 });
        },
        else => {},
    }
    lib.linkLibC();
    return lib;
}

fn luaCJson(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "lua_cjson",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath(.{ .path = "src/lib/lua-cjson/" });
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/lua-cjson/fpconv.c",
        "src/lib/lua-cjson/g_fmt.c",
        "src/lib/lua-cjson/lua_cjson.c",
        "src/lib/lua-cjson/strbuf.c",
    }, flags_c99);
    lib.linkLibC();
    return lib;
}

fn crossline(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "crossline",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(.{ .path = "src/lib/Crossline/" });
    lib.addCSourceFile(.{ .file = .{ .path = "src/lib/Crossline/crossline.c" }, .flags = flags_c99 });
    lib.linkLibC();
    return lib;
}

fn timer(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "timer",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(.{ .path = "src/" });
    lib.addCSourceFile(.{ .file = .{ .path = "src/timer.c" }, .flags = flags_c99 });
    lib.linkLibC();
    return lib;
}
