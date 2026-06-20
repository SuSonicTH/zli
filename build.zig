const std = @import("std");
const flags_c99 = &.{"-std=gnu99"};
const strip = @import("src/strip.zig").strip;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //normal build
    const exe = compileStep(b, target, optimize, "zli");
    b.installArtifact(exe);

    //release
    const release = b.step("release", "Build all cross-compilation targets in release mode");
    releasebuild(b, release);

    //native
    const native = b.step("native", "Build all cross-compilation targets in native mode");
    native.dependOn(nativebuild(b));

    //run
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);

    //test
    const test_step = b.step("test", "Test the interpreter and libs");
    const test_cmd = b.addRunArtifact(exe);
    test_cmd.step.dependOn(b.getInstallStep());
    test_cmd.addArgs(&[_][]const u8{"./test/test.lua"});
    test_step.dependOn(&test_cmd.step);
}

const TargetConfig = struct {
    query: std.Target.Query,
    suffix: []const u8,
};

const release_targets = [_]TargetConfig{
    .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .linux }, .suffix = "x86_64-linux" },
    .{ .query = .{ .cpu_arch = .aarch64, .os_tag = .linux }, .suffix = "aarch64-linux" },
    .{ .query = .{ .cpu_arch = .x86_64, .os_tag = .windows }, .suffix = "x86_64-windows" },
};

fn releasebuild(b: *std.Build, release: *std.Build.Step) void {
    const zupx = b.dependency("zupx", .{
        .optimize = std.builtin.OptimizeMode.ReleaseFast,
        .target = b.graph.host,
    });

    for (release_targets) |config| {
        const target = b.resolveTargetQuery(config.query);
        const exe_name = b.fmt("zli-{s}", .{config.suffix});
        const exe = compileStep(b, target, std.builtin.OptimizeMode.ReleaseFast, exe_name);
        const install_artifact = b.addInstallArtifact(exe, .{});

        //upx
        const upx_cmd = b.addRunArtifact(zupx.artifact("upx"));
        upx_cmd.addArgs(&.{ "--lzma", b.getInstallPath(.bin, exe.out_filename) });
        upx_cmd.step.dependOn(&install_artifact.step);

        release.dependOn(&upx_cmd.step);
    }
}

fn nativebuild(b: *std.Build) *std.Build.Step {
    const zupx = b.dependency("zupx", .{
        .optimize = std.builtin.OptimizeMode.ReleaseFast,
        .target = b.graph.host,
    });

    const exe = compileStep(b, b.graph.host, std.builtin.OptimizeMode.ReleaseFast, "zli");
    const install_artifact = b.addInstallArtifact(exe, .{});

    //upx
    const upx_cmd = b.addRunArtifact(zupx.artifact("upx"));
    upx_cmd.addArgs(&.{ "--lzma", b.getInstallPath(.bin, exe.out_filename) });
    upx_cmd.step.dependOn(&install_artifact.step);
    return &upx_cmd.step;
}

fn compileStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, exe_name: []const u8) *std.Build.Step.Compile {
    const zlua = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
        .lang = .lua55,
    });

    const lua = b.dependency("lua55", .{
        .target = target,
        .optimize = optimize,
    });
    const luaPath = lua.path("src/");

    //zli exe
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = optimize != std.builtin.OptimizeMode.Debug,
        }),
    });
    exe.root_module.addIncludePath(b.path("src/"));
    exe.root_module.addImport("zlua", zlua.module("zlua"));

    //add lualibs (strip for non debug)
    luaLibs(b, optimize, exe.root_module);

    //zlib and zip libraries
    const zlib_dep = b.dependency("zlib", .{});
    exe.root_module.addIncludePath(zlib_dep.path(""));
    exe.root_module.addIncludePath(zlib_dep.path("contrib/minizip/"));
    exe.root_module.linkLibrary(zlib(b, target, optimize, zlib_dep));
    exe.root_module.linkLibrary(luaZlib(b, target, optimize, zlib_dep, luaPath));
    exe.root_module.linkLibrary(miniZip(b, target, optimize, zlib_dep));

    //libraries
    exe.root_module.linkLibrary(lsqlite3(b, target, optimize, luaPath));
    exe.root_module.linkLibrary(lpeg(b, target, optimize, luaPath));
    exe.root_module.linkLibrary(luaCJson(b, target, optimize, luaPath));
    exe.root_module.linkLibrary(crossline(b, target, optimize, exe));
    exe.root_module.linkLibrary(timer(b, target, optimize));

    return exe;
}

const lualib_entry = struct {
    input: [:0]const u8,
    name: [:0]const u8,
    dependency: [:0]const u8 = "",
};

var lualib_list = [_]lualib_entry{
    .{ .input = "F.lua", .name = "F.lua", .dependency = "fstring" },
    .{ .input = "ftcsv.lua", .name = "ftcsv.lua", .dependency = "ftcsv" },
    .{ .input = "lua/cjson/util.lua", .name = "cjson.util.lua", .dependency = "cjson" },
    .{ .input = "luaunit.lua", .name = "luaunit.lua", .dependency = "luaunit" },
    .{ .input = "re.lua", .name = "re.lua", .dependency = "lpeg" },
    .{ .input = "src/argparse.lua", .name = "argparse.lua", .dependency = "argparse" },
    .{ .input = "src/serpent.lua", .name = "serpent.lua", .dependency = "serpent" },

    .{ .input = "src/auxiliary.lua", .name = "auxiliary.lua" },
    .{ .input = "src/benchmark.lua", .name = "benchmark.lua" },
    .{ .input = "src/collection/init.lua", .name = "collection.init.lua" },
    .{ .input = "src/collection/list.lua", .name = "collection.list.lua" },
    .{ .input = "src/collection/map.lua", .name = "collection.map.lua" },
    .{ .input = "src/collection/set.lua", .name = "collection.set.lua" },
    .{ .input = "src/crossline.lua", .name = "crossline.lua" },
    .{ .input = "src/filesystem.lua", .name = "filesystem.lua" },
    .{ .input = "src/grid.lua", .name = "grid.lua" },
    .{ .input = "src/httpclient.lua", .name = "httpclient.lua" },
    .{ .input = "src/httpserver.lua", .name = "httpserver.lua" },
    .{ .input = "src/logger.lua", .name = "logger.lua" },
    .{ .input = "src/main.lua", .name = "main.lua" },
    .{ .input = "src/memoize.lua", .name = "memoize.lua" },
    .{ .input = "src/stream.lua", .name = "stream.lua" },
    .{ .input = "src/timer.lua", .name = "timer.lua" },
    .{ .input = "src/tools/compile.lua", .name = "compile.lua" },
    .{ .input = "src/tools/repl.lua", .name = "repl.lua" },
    .{ .input = "src/tools/sqlite_cli.lua", .name = "sqlite_cli.lua" },
    .{ .input = "src/unzip.lua", .name = "unzip.lua" },
    .{ .input = "src/xlsxmlwriter.lua", .name = "xlsxmlwriter.lua" },
    .{ .input = "src/zip.lua", .name = "zip.lua" },
};

fn luaLibs(b: *std.Build, optimize: std.builtin.OptimizeMode, module: *std.Build.Module) void {
    const lualibs = b.addWriteFiles();
    for (&lualib_list) |*script| {
        var source: []const u8 = undefined;

        if (script.dependency[0] == 0) {
            if (optimize == .Debug) {
                source = readFile(b, script.input);
            } else {
                source = strip(readFile(b, script.input), b.allocator) catch |err| {
                    std.debug.panic("Failed to strip Lua script '{s}': {any}\n", .{ script.name, err });
                };
            }
        } else {
            const dependency = b.dependency(script.dependency, .{});
            if (optimize == .Debug) {
                source = readFile(b, dependency.path(script.input).getPath(b));
            } else {
                source = strip(readFile(b, dependency.path(script.input).getPath(b)), b.allocator) catch |err| {
                    std.debug.panic("Failed to strip Lua script '{s}': {any}\n", .{ script.name, err });
                };
            }
        }
        module.addAnonymousImport(script.name, .{
            .root_source_file = lualibs.add(script.name, source),
        });
    }
}

fn readFile(b: *std.Build, path: []const u8) []const u8 {
    return b.build_root.handle.readFileAlloc(
        b.graph.io,
        path,
        b.graph.arena,
        std.Io.Limit.unlimited,
    ) catch |err| {
        std.debug.panic("Failed to read {s}: {any}\n", .{ path, err });
    };
}

fn lsqlite3(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, luaPath: std.Build.LazyPath) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "lsqlite3",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.root_module.addIncludePath(luaPath);
    const dependency = b.dependency("lsqlite3", .{});
    lib.root_module.addIncludePath(dependency.path(""));
    lib.root_module.addCSourceFiles(.{ .root = dependency.path(""), .files = &[_][]const u8{
        "sqlite3.c",
        "lsqlite3.c",
    }, .flags = flags_c99 });
    lib.root_module.link_libc = true;
    return lib;
}

fn lpeg(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, luaPath: std.Build.LazyPath) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "lpeg",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.root_module.addIncludePath(luaPath);
    const dependency = b.dependency("lpeg", .{});
    lib.root_module.addIncludePath(dependency.path(""));
    lib.root_module.addCSourceFiles(.{ .root = dependency.path(""), .files = &[_][]const u8{
        "lpcap.c",
        "lpcode.c",
        "lpcset.c",
        "lpprint.c",
        "lptree.c",
        "lpvm.c",
    }, .flags = flags_c99 });
    lib.root_module.link_libc = true;
    return lib;
}

fn zlib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, zlib_deb: *std.Build.Dependency) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "zlib",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.root_module.addIncludePath(zlib_deb.path(""));
    lib.root_module.addCSourceFiles(.{ .root = zlib_deb.path(""), .files = &[_][]const u8{
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
    lib.root_module.link_libc = true;
    return lib;
}

fn luaZlib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, zlib_deb: *std.Build.Dependency, luaPath: std.Build.LazyPath) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "lua_zlib",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.root_module.addIncludePath(luaPath);
    lib.root_module.addIncludePath(zlib_deb.path(""));
    const dependency = b.dependency("lua_zlib", .{});
    lib.root_module.addCSourceFile(.{ .file = dependency.path("lua_zlib.c"), .flags = &[_][]const u8{ "-std=c99", "-DLZLIB_COMPAT" } });
    lib.root_module.link_libc = true;
    return lib;
}

fn miniZip(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, zlib_deb: *std.Build.Dependency) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "miniZip",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.root_module.addIncludePath(b.path("src/"));
    lib.root_module.addIncludePath(zlib_deb.path(""));
    lib.root_module.addIncludePath(zlib_deb.path("contrib/minizip/"));
    lib.root_module.addCSourceFiles(.{ .root = zlib_deb.path(""), .files = &[_][]const u8{
        "contrib/minizip/zip.c",
        "contrib/minizip/unzip.c",
        "contrib/minizip/ioapi.c",
    }, .flags = flags_c99 });
    lib.root_module.addCSourceFile(.{ .file = b.path("src/zip_util.c"), .flags = flags_c99 });

    switch (target.result.os.tag) {
        .windows => {
            lib.root_module.addCSourceFile(.{ .file = zlib_deb.path("contrib/minizip/iowin32.c"), .flags = flags_c99 });
        },
        else => {},
    }
    lib.root_module.link_libc = true;
    return lib;
}

fn luaCJson(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, luaPath: std.Build.LazyPath) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "lua_cjson",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.root_module.addIncludePath(luaPath);
    const dependency = b.dependency("cjson", .{});
    lib.root_module.addIncludePath(dependency.path(""));
    lib.root_module.addCSourceFiles(.{ .root = dependency.path(""), .files = &[_][]const u8{
        "fpconv.c",
        "g_fmt.c",
        "lua_cjson.c",
        "strbuf.c",
    }, .flags = flags_c99 });
    lib.root_module.link_libc = true;
    return lib;
}

fn crossline(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, exe: *std.Build.Step.Compile) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "crossline",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    const dependency = b.dependency("crossline", .{});
    lib.root_module.addIncludePath(dependency.path(""));
    exe.root_module.addIncludePath(dependency.path(""));
    lib.root_module.addCSourceFile(.{ .file = dependency.path("crossline.c"), .flags = flags_c99 });
    lib.root_module.link_libc = true;
    return lib;
}

fn timer(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "timer",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    lib.root_module.addIncludePath(b.path("src/"));
    lib.root_module.addCSourceFile(.{ .file = b.path("src/timer.c"), .flags = flags_c99 });
    lib.root_module.link_libc = true;
    return lib;
}
