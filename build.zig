const std = @import("std");
const flags_c99 = &.{"-std=gnu99"};
var luaPath: std.Build.LazyPath = undefined;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });
    luaPath = b.dependency("lua54", .{}).path("src/");

    const zigLuaStrip = b.dependency("zigLuaStrip", .{
        .optimize = std.builtin.OptimizeMode.Debug,
    });

    const smtp_client = b.dependency("smtp_client", .{
        .target = target,
        .optimize = optimize,
    });

    //zli exe
    const exe = b.addExecutable(.{
        .name = "zli",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(b.path("src/"));
    exe.root_module.addImport("ziglua", ziglua.module("ziglua"));
    exe.root_module.addImport("smtp_client", smtp_client.module("smtp_client"));

    //zlib and zip libraries
    const zlib_dep = b.dependency("zlib", .{});
    exe.addIncludePath(zlib_dep.path(""));
    exe.addIncludePath(zlib_dep.path("contrib/minizip/"));
    exe.linkLibrary(zlib(b, target, optimize, zlib_dep));
    exe.linkLibrary(luaZlib(b, target, optimize, zlib_dep));
    exe.linkLibrary(miniZip(b, target, optimize, zlib_dep));

    exe.linkLibrary(lsqlite3(b, target, optimize));
    exe.linkLibrary(lpeg(b, target, optimize));
    exe.linkLibrary(luaCJson(b, target, optimize));
    exe.linkLibrary(crossline(b, target, optimize, exe));
    exe.linkLibrary(timer(b, target, optimize));

    if (optimize != .Debug) {
        exe.root_module.strip = true;
        inline for (luastrip_list) |script| {
            var run_step = b.addRunArtifact(zigLuaStrip.artifact("zigluastrip"));
            if (script.dependency[0] == 0) {
                run_step.addArgs(&.{ script.input, script.output });
            } else {
                const dependency = b.dependency(script.dependency, .{});
                const source = dependency.path(script.input).getPath(b);
                run_step.addArgs(&.{ source, script.output });
            }
            exe.step.dependOn(&run_step.step);
        }
    } else {
        inline for (luastrip_list) |script| {
            if (script.dependency[0] == 0) {
                copyFile(script.input, script.output) catch unreachable;
            } else {
                const dependency = b.dependency(script.dependency, .{});
                const source = dependency.path(script.input).getPath(b);
                copyFile(source, script.output) catch unreachable;
            }
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
    test_cmd.addArgs(&[_][]const u8{"./test/test.lua"});

    const test_step = b.step("test", "Test the interpreter and libs");
    test_step.dependOn(&test_cmd.step);
}

const luastrip_entry = struct {
    input: [:0]const u8,
    output: [:0]const u8,
    dependency: [:0]const u8 = "",
};

const luastrip_list = [_]luastrip_entry{
    .{ .input = "F.lua", .output = "src/stripped/F.lua", .dependency = "fstring" },
    .{ .input = "ftcsv.lua", .output = "src/stripped/ftcsv.lua", .dependency = "ftcsv" },
    .{ .input = "lua/cjson/util.lua", .output = "src/stripped/cjson.util.lua", .dependency = "cjson" },
    .{ .input = "luaunit.lua", .output = "src/stripped/luaunit.lua", .dependency = "luaunit" },
    .{ .input = "re.lua", .output = "src/stripped/re.lua", .dependency = "lpeg" },
    .{ .input = "src/argparse.lua", .output = "src/stripped/argparse.lua", .dependency = "argparse" },
    .{ .input = "src/serpent.lua", .output = "src/stripped/serpent.lua", .dependency = "serpent" },

    .{ .input = "src/auxiliary.lua", .output = "src/stripped/auxiliary.lua" },
    .{ .input = "src/benchmark.lua", .output = "src/stripped/benchmark.lua" },
    .{ .input = "src/collection/init.lua", .output = "src/stripped/collection.init.lua" },
    .{ .input = "src/collection/list.lua", .output = "src/stripped/collection.list.lua" },
    .{ .input = "src/collection/map.lua", .output = "src/stripped/collection.map.lua" },
    .{ .input = "src/collection/set.lua", .output = "src/stripped/collection.set.lua" },
    .{ .input = "src/crossline.lua", .output = "src/stripped/crossline.lua" },
    .{ .input = "src/filesystem.lua", .output = "src/stripped/filesystem.lua" },
    .{ .input = "src/grid.lua", .output = "src/stripped/grid.lua" },
    .{ .input = "src/logger.lua", .output = "src/stripped/logger.lua" },
    .{ .input = "src/main.lua", .output = "src/stripped/main.lua" },
    .{ .input = "src/memoize.lua", .output = "src/stripped/memoize.lua" },
    .{ .input = "src/stream.lua", .output = "src/stripped/stream.lua" },
    .{ .input = "src/timer.lua", .output = "src/stripped/timer.lua" },
    .{ .input = "src/tools/compile.lua", .output = "src/stripped/compile.lua" },
    .{ .input = "src/tools/repl.lua", .output = "src/stripped/repl.lua" },
    .{ .input = "src/tools/sqlite_cli.lua", .output = "src/stripped/sqlite_cli.lua" },
    .{ .input = "src/unzip.lua", .output = "src/stripped/unzip.lua" },
    .{ .input = "src/zip.lua", .output = "src/stripped/zip.lua" },
};

fn copyFile(input_path: []const u8, output_path: []const u8) !void {
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

fn lsqlite3(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "lsqlite3",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    const dependency = b.dependency("lsqlite3", .{});
    lib.addIncludePath(dependency.path(""));
    lib.addCSourceFiles(.{ .root = dependency.path(""), .files = &[_][]const u8{
        "sqlite3.c",
        "lsqlite3.c",
    }, .flags = flags_c99 });
    lib.linkLibC();
    return lib;
}

fn lpeg(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "lpeg",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    const dependency = b.dependency("lpeg", .{});
    lib.addIncludePath(dependency.path(""));
    lib.addCSourceFiles(.{ .root = dependency.path(""), .files = &[_][]const u8{
        "lpcap.c",
        "lpcode.c",
        "lpcset.c",
        "lpprint.c",
        "lptree.c",
        "lpvm.c",
    }, .flags = flags_c99 });
    lib.linkLibC();
    return lib;
}

fn zlib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode, zlib_deb: *std.Build.Dependency) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "zlib",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(zlib_deb.path(""));
    lib.addCSourceFiles(.{ .root = zlib_deb.path(""), .files = &[_][]const u8{
        "adler32.c",
        "crc32.c",
        "gzclose.c",
        "gzread.c",
        "infback.c",
        "inflate.c",
        "trees.c",
        "zutil.c",
        "compress.c",
        "deflate.c",
        "gzlib.c",
        "gzwrite.c",
        "inffast.c",
        "inftrees.c",
        "uncompr.c",
    }, .flags = &.{"-std=gnu89"} });
    lib.linkLibC();
    return lib;
}

fn luaZlib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode, zlib_deb: *std.Build.Dependency) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "lua_zlib",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath(zlib_deb.path(""));
    const dependency = b.dependency("lua_zlib", .{});
    lib.addCSourceFile(.{ .file = dependency.path("lua_zlib.c"), .flags = &[_][]const u8{ "-std=c99", "-DLZLIB_COMPAT" } });
    lib.linkLibC();
    return lib;
}

fn miniZip(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode, zlib_deb: *std.Build.Dependency) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "miniZip",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(b.path("src/"));
    lib.addIncludePath(zlib_deb.path(""));
    lib.addIncludePath(zlib_deb.path("contrib/minizip/"));
    lib.addCSourceFiles(.{ .root = zlib_deb.path(""), .files = &[_][]const u8{
        "contrib/minizip/zip.c",
        "contrib/minizip/unzip.c",
        "contrib/minizip/ioapi.c",
    }, .flags = flags_c99 });
    lib.addCSourceFile(.{ .file = b.path("src/zip_util.c"), .flags = flags_c99 });
    switch (target.result.os.tag) {
        .windows => {
            lib.addCSourceFile(.{ .file = zlib_deb.path("contrib/minizip/iowin32.c"), .flags = flags_c99 });
        },
        else => {},
    }
    lib.linkLibC();
    return lib;
}

fn luaCJson(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "lua_cjson",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    const dependency = b.dependency("cjson", .{});
    lib.addIncludePath(dependency.path(""));
    lib.addCSourceFiles(.{ .root = dependency.path(""), .files = &[_][]const u8{
        "fpconv.c",
        "g_fmt.c",
        "lua_cjson.c",
        "strbuf.c",
    }, .flags = flags_c99 });
    lib.linkLibC();
    return lib;
}

fn crossline(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode, exe: *std.Build.Step.Compile) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "crossline",
        .target = target,
        .optimize = optimize,
    });
    const dependency = b.dependency("crossline", .{});
    lib.addIncludePath(dependency.path(""));
    exe.addIncludePath(dependency.path(""));
    lib.addCSourceFile(.{ .file = dependency.path("crossline.c"), .flags = flags_c99 });
    lib.linkLibC();
    return lib;
}

fn timer(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.Mode) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "timer",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(b.path("src/"));
    lib.addCSourceFile(.{ .file = b.path("src/timer.c"), .flags = flags_c99 });
    lib.linkLibC();
    return lib;
}
