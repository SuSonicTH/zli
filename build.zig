const std = @import("std");
const ziglua = @import("src/lib/ziglua/build.zig");
const flags_c99 = &.{"-std=gnu99"};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //zli exe
    const exe = b.addExecutable(.{
        .name = "zli",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath("src/lib/Crossline/");
    exe.addIncludePath("src/lib/zlib/contrib/minizip/");
    exe.addIncludePath("src/lib/zlib/");
    exe.addModule("ziglua", ziglua.compileAndCreateModule(b, exe, .{}));

    exe.linkLibrary(lsqlite3(b, target, optimize));
    exe.linkLibrary(lfs(b, target, optimize));
    exe.linkLibrary(lpeg(b, target, optimize));
    exe.linkLibrary(zlib(b, target, optimize));
    exe.linkLibrary(luaZlib(b, target, optimize));
    exe.linkLibrary(luaCJson(b, target, optimize));
    exe.linkLibrary(crossline(b, target, optimize));
    exe.linkLibrary(miniZip(b, target, optimize));
    exe.linkLibrary(luaZip(b, target, optimize));
    exe.linkLibrary(zliLibraries(b, target, optimize));
    if (optimize != .Debug) {
        exe.strip = true;
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

const luaPath: []const u8 = "src/lib/ziglua/lib/lua-5.4/src/";

fn lsqlite3(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "lsqlite3",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath("src/lib/lsqlite3/");
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/lsqlite3/sqlite3.c",
        "src/lib/lsqlite3/lsqlite3.c",
    }, flags_c99);
    lib.linkLibC();
    return lib;
}

fn lfs(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "lfs",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath("src/lib/luafilesystem/src/");
    lib.addCSourceFile("src/lib/luafilesystem/src/lfs.c", flags_c99);
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
    lib.addIncludePath("lpeg/");
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
    lib.addIncludePath("src/lib/zlib/");
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
    lib.addIncludePath("src/lib/zlib/");
    lib.addCSourceFile("src/lib/lua-zlib/lua_zlib.c", &[_][]const u8{ "-std=c99", "-DLZLIB_COMPAT" });
    lib.linkLibC();
    return lib;
}

fn miniZip(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "miniZip",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath("src/");
    lib.addIncludePath("src/lib/zlib/");
    lib.addIncludePath("src/lib/zlib/contrib/minizip/");
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/zlib/contrib/minizip/zip.c",
        "src/lib/zlib/contrib/minizip/unzip.c",
        "src/lib/zlib/contrib/minizip/ioapi.c",
    }, flags_c99);
    switch (target.getOsTag()) {
        .windows => {
            lib.addCSourceFile("src/lib/zlib/contrib/minizip/iowin32.c", flags_c99);
        },
        else => {},
    }
    lib.linkLibC();
    return lib;
}

fn luaZip(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "luaZip",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath("src/");
    lib.addIncludePath("src/luax");
    lib.addIncludePath(luaPath);
    lib.addIncludePath("src/lib/zlib/");
    lib.addIncludePath("src/lib/zlib/contrib/minizip/");
    lib.addCSourceFile("src/lua_zip.c", flags_c99);
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
    lib.addIncludePath("src/lib/lua-cjson/");
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
    lib.addIncludePath("src/lib/Crossline/");
    lib.addCSourceFile("src/lib/Crossline/crossline.c", flags_c99);
    lib.linkLibC();
    return lib;
}

fn zliLibraries(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "zliLibraries",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath("src/");
    lib.addIncludePath("src/luax");
    lib.addCSourceFiles(&[_][]const u8{
        "src/auxiliary.c",
        "src/csv.c",
        "src/sbuilder.c",
        "src/luax/luax_value.c",
        "src/luax/luax_gcptr.c",
    }, &[_][]const u8{ "-std=c99", "-DSBUILDER_LUA" });
    lib.linkLibC();

    return lib;
}
