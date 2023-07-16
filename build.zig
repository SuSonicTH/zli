const std = @import("std");
const ziglua = @import("src/lib/ziglua/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //FullMoon exe
    const exe = b.addExecutable(.{
        .name = "fullmoon",
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibrary(lsqlite3(b, target, optimize));
    exe.linkLibrary(lfs(b, target, optimize));
    exe.linkLibrary(lpeg(b, target, optimize));
    exe.linkLibrary(zlib(b, target, optimize));
    exe.linkLibrary(luaZlib(b, target, optimize));
    exe.linkLibrary(luaCJson(b, target, optimize));
    exe.linkLibrary(crossline(b, target, optimize));
    exe.linkLibrary(fmZip(b, target, optimize));
    exe.linkLibrary(fullmoon(b, target, optimize));
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
    }, &[_][]const u8{"-std=gnu99"});
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
    lib.addCSourceFile("src/lib/luafilesystem/src/lfs.c", &[_][]const u8{"-std=gnu99"});
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
    }, &[_][]const u8{"-std=gnu99"});
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
    }, &.{"-std=c89"});
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
    lib.addCSourceFile("src/lib/lua-zlib/lua_zlib.c", &[_][]const u8{ "-std=gnu99", "-DLZLIB_COMPAT" });
    lib.linkLibC();
    return lib;
}

fn fmZip(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "fmZip",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath("src/");
    lib.addIncludePath(luaPath);
    lib.addIncludePath("src/lib/zlib/");
    lib.addIncludePath("src/lib/zlib/contrib/minizip/");
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/zlib/contrib/minizip/zip.c",
        "src/lib/zlib/contrib/minizip/unzip.c",
        "src/lib/zlib/contrib/minizip/ioapi.c",
        "src/fm_zip.c",
    }, &.{"-std=c99"});
    switch (target.getOsTag()) {
        .windows => {
            lib.addCSourceFile("src/lib/zlib/contrib/minizip/iowin32.c", &.{"-std=c99"});
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
    lib.addIncludePath("src/lib/lua-cjson/");
    lib.addCSourceFiles(&[_][]const u8{
        "src/lib/lua-cjson/fpconv.c",
        "src/lib/lua-cjson/g_fmt.c",
        "src/lib/lua-cjson/lua_cjson.c",
        "src/lib/lua-cjson/strbuf.c",
    }, &[_][]const u8{"-std=gnu99"});
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
    lib.addCSourceFile("src/lib/Crossline/crossline.c", &[_][]const u8{"-std=gnu99"});
    lib.linkLibC();
    return lib;
}

fn fullmoon(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "fullmoonLib",
        .root_source_file = .{ .path = "src/fullmoon.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath("src/");
    lib.addIncludePath("src/lib/Crossline/");
    lib.addIncludePath("src/lib/zlib/contrib/minizip/");
    lib.addIncludePath("src/lib/zlib/");
    lib.addCSourceFiles(&[_][]const u8{
        "src/fm_aux.c",
        "src/fm_csv.c",
        "src/fm_sbuilder.c",
        "src/luax_value.c",
        "src/luax_gcptr.c",
    }, &[_][]const u8{ "-std=gnu99", "-DFM_SBUILDER_LUA" });
    lib.linkLibC();
    lib.addModule("ziglua", ziglua.compileAndCreateModule(b, lib, .{}));
    return lib;
}
