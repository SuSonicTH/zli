const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //FullMoon exe
    const exe = b.addExecutable(.{
        .name = "fullmoon",
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(lua(b, target, optimize));
    exe.linkLibrary(lsqlite3(b, target, optimize));
    exe.linkLibrary(lfs(b, target, optimize));
    exe.linkLibrary(lpeg(b, target, optimize));
    exe.linkLibrary(zlib(b, target, optimize));
    exe.linkLibrary(luaZlib(b, target, optimize));
    exe.linkLibrary(luaCJson(b, target, optimize));
    exe.linkLibrary(crossline(b, target, optimize));
    exe.linkLibrary(fullmoon(b, target, optimize));
    exe.strip = true;

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

const luaPath: []const u8 = "lua/src/";

const luaSources = [_][]const u8{
    luaPath ++ "lapi.c",
    luaPath ++ "lauxlib.c",
    luaPath ++ "lbaselib.c",
    luaPath ++ "lcode.c",
    luaPath ++ "lcorolib.c",
    luaPath ++ "lctype.c",
    luaPath ++ "ldblib.c",
    luaPath ++ "ldebug.c",
    luaPath ++ "ldo.c",
    luaPath ++ "ldump.c",
    luaPath ++ "lfunc.c",
    luaPath ++ "lgc.c",
    luaPath ++ "liolib.c",
    luaPath ++ "llex.c",
    luaPath ++ "lmathlib.c",
    luaPath ++ "lmem.c",
    luaPath ++ "loadlib.c",
    luaPath ++ "lobject.c",
    luaPath ++ "lopcodes.c",
    luaPath ++ "loslib.c",
    luaPath ++ "lparser.c",
    luaPath ++ "lstate.c",
    luaPath ++ "lstring.c",
    luaPath ++ "lstrlib.c",
    luaPath ++ "ltable.c",
    luaPath ++ "ltablib.c",
    luaPath ++ "ltm.c",
    luaPath ++ "lundump.c",
    luaPath ++ "lutf8lib.c",
    luaPath ++ "lvm.c",
    luaPath ++ "lzio.c",
};

fn lua(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(luaPath);
    lib.addCSourceFiles(&luaSources, &[_][]const u8{
        "-std=gnu99",
        switch (target.getOsTag()) {
            .linux => "-DLUA_USE_LINUX",
            .macos => "-DLUA_USE_MACOSX",
            .windows => "-DLUA_USE_WINDOWS",
            else => "-DLUA_USE_POSIX",
        },
    });
    lib.linkLibC();
    return lib;
}

fn lsqlite3(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "lsqlite3",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath("lsqlite3/");
    lib.addCSourceFiles(&[_][]const u8{
        "lsqlite3/sqlite3.c",
        "lsqlite3/lsqlite3.c",
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
    lib.addIncludePath("luafilesystem/src/");
    lib.addCSourceFile("luafilesystem/src/lfs.c", &[_][]const u8{"-std=gnu99"});
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
        "lpeg/lpcap.c",
        "lpeg/lpcode.c",
        "lpeg/lpprint.c",
        "lpeg/lptree.c",
        "lpeg/lpvm.c",
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
    lib.addIncludePath("zlib/");
    lib.addCSourceFiles(&[_][]const u8{
        "zlib/adler32.c",
        "zlib/crc32.c",
        "zlib/gzclose.c",
        "zlib/gzread.c",
        "zlib/infback.c",
        "zlib/inflate.c",
        "zlib/trees.c",
        "zlib/zutil.c",
        "zlib/compress.c",
        "zlib/deflate.c",
        "zlib/gzlib.c",
        "zlib/gzwrite.c",
        "zlib/inffast.c",
        "zlib/inftrees.c",
        "zlib/uncompr.c",
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
    lib.addIncludePath("zlib/");
    lib.addCSourceFile("lua-zlib/lua_zlib.c", &[_][]const u8{ "-std=gnu99", "-DLZLIB_COMPAT" });
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
    lib.addIncludePath("lua-cjson/");
    lib.addCSourceFiles(&[_][]const u8{
        "lua-cjson/fpconv.c",
        "lua-cjson/g_fmt.c",
        "lua-cjson/lua_cjson.c",
        "lua-cjson/strbuf.c",
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
    lib.addIncludePath("Crossline/");
    lib.addCSourceFile("Crossline/crossline.c", &[_][]const u8{"-std=gnu99"});
    lib.linkLibC();
    return lib;
}

fn fullmoon(b: *std.Build, target: std.zig.CrossTarget, optimize: std.builtin.Mode) *std.build.CompileStep {
    const lib = b.addStaticLibrary(.{
        .name = "fullmoonLib",
        .root_source_file = .{ .path = "fm_libraries.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(luaPath);
    lib.addIncludePath("./");
    lib.addIncludePath("Crossline/");
    lib.addCSourceFiles(&[_][]const u8{
        "fullmoon.c",
        "fm_aux.c",
        "fm_csv.c",
        "fm_crossline.c",
        "fm_sb.c",
        "lx_value.c",
    }, &[_][]const u8{"-std=gnu99"});
    lib.linkLibC();
    return lib;
}
