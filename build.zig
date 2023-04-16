const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const c_flags = [_][]const u8{
        "-std=gnu99",
    };

    const lsqlite3 = b.addStaticLibrary(.{
        .name = "lsqlite3",
        .target = target,
        .optimize = optimize,
    });
    lsqlite3.addIncludePath("lua/src/");
    lsqlite3.addIncludePath("lsqlite3/");
    lsqlite3.addCSourceFile("lsqlite3/lsqlite3.c", &c_flags);
    lsqlite3.addCSourceFile("lsqlite3/sqlite3.c", &c_flags);
    lsqlite3.linkLibC();

    const lfs = b.addStaticLibrary(.{
        .name = "lfs",
        .target = target,
        .optimize = optimize,
    });
    lfs.addIncludePath("lua/src/");
    lfs.addIncludePath("luafilesystem/src/");
    lfs.addCSourceFile("luafilesystem/src/lfs.c", &c_flags);
    lfs.linkLibC();

    const lpeg = b.addStaticLibrary(.{
        .name = "lpeg",
        .target = target,
        .optimize = optimize,
    });

    lpeg.addIncludePath("lpeg/");
    lpeg.addIncludePath("lua/src/");
    lpeg.addCSourceFiles(&.{
        "lpeg/lpcap.c",
        "lpeg/lpcode.c",
        "lpeg/lpprint.c",
        "lpeg/lptree.c",
        "lpeg/lpvm.c",
    }, &c_flags);
    lpeg.linkLibC();

    const zlib = b.addStaticLibrary(.{
        .name = "zlib",
        .target = target,
        .optimize = optimize,
    });
    zlib.addIncludePath("zlib/");
    zlib.addCSourceFiles(&.{
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
    zlib.linkLibC();

    const lua_zlib = b.addStaticLibrary(.{
        .name = "lua_zlib",
        .target = target,
        .optimize = optimize,
    });
    lua_zlib.addIncludePath("lua/src/");
    lua_zlib.addIncludePath("zlib/");
    lua_zlib.addCSourceFile("lua-zlib/lua_zlib.c", &[_][]const u8{"-DLZLIB_COMPAT"});
    lua_zlib.linkLibC();

    const lua_flags = [_][]const u8{
        "-std=gnu99",
        //        switch (target.os.tag) {
        //            .linux => "-DLUA_USE_LINUX",
        //            .macos => "-DLUA_USE_MACOSX",
        //            .windows => "-DLUA_USE_WINDOWS",
        //            else => "-DLUA_USE_POSIX",
        //        },
    };

    const lua = b.addStaticLibrary(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
    });

    lua.addIncludePath("lua/src");
    lua.addCSourceFiles(&.{
        "lua/src/lapi.c",
        "lua/src/lauxlib.c",
        "lua/src/lbaselib.c",
        "lua/src/lcode.c",
        "lua/src/lcorolib.c",
        "lua/src/lctype.c",
        "lua/src/ldblib.c",
        "lua/src/ldebug.c",
        "lua/src/ldo.c",
        "lua/src/ldump.c",
        "lua/src/lfunc.c",
        "lua/src/lgc.c",
        "lua/src/liolib.c",
        "lua/src/llex.c",
        "lua/src/lmathlib.c",
        "lua/src/lmem.c",
        "lua/src/loadlib.c",
        "lua/src/lobject.c",
        "lua/src/lopcodes.c",
        "lua/src/loslib.c",
        "lua/src/lparser.c",
        "lua/src/lstate.c",
        "lua/src/lstring.c",
        "lua/src/lstrlib.c",
        "lua/src/ltable.c",
        "lua/src/ltablib.c",
        "lua/src/ltm.c",
        "lua/src/lundump.c",
        "lua/src/lutf8lib.c",
        "lua/src/lvm.c",
        "lua/src/lzio.c",
    }, &lua_flags);
    lua.linkLibC();

    const exe = b.addExecutable(.{
        .name = "fullmoon",
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath("src/");
    exe.addIncludePath("lua/src");
    exe.addCSourceFiles(&.{
        "src/linit.c",
        "src/lua.c",
        "src/fm_aux.c",
        "src/lx_value.c",
    }, &lua_flags);
    exe.linkLibrary(lua);
    exe.linkLibrary(lsqlite3);
    exe.linkLibrary(lpeg);
    exe.linkLibrary(lfs);
    exe.linkLibrary(zlib);
    exe.linkLibrary(lua_zlib);
    exe.linkLibC();

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_cmd = b.addRunArtifact(exe);

    test_cmd.step.dependOn(b.getInstallStep());
    test_cmd.addArgs(&[_][]const u8{"test.lua"});

    const test_step = b.step("test", "Test the app");
    test_step.dependOn(&test_cmd.step);
}
