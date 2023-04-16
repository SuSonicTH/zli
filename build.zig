const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const c_flags = [_][]const u8{};

    const lua_path = "lua-5.4.4/src/";
    const zlib_path = "zlib-1.2.13/";

    const lsqlite3 = b.addStaticLibrary(.{
        .name = "lsqlite3",
        .target = target,
        .optimize = optimize,
    });
    lsqlite3.addIncludePath(lua_path);
    lsqlite3.addIncludePath("lsqlite3");
    lsqlite3.addCSourceFile("lsqlite3/lsqlite3.c", &c_flags);
    lsqlite3.addCSourceFile("lsqlite3/sqlite3.c", &c_flags);
    lsqlite3.linkLibC();

    const lfs = b.addStaticLibrary(.{
        .name = "lfs",
        .target = target,
        .optimize = optimize,
    });
    lfs.addIncludePath(lua_path);
    lfs.addIncludePath("luafilesystem/src/");
    lfs.addCSourceFile("luafilesystem/src/lfs.c", &c_flags);
    lfs.linkLibC();

    const zlib = b.addStaticLibrary(.{
        .name = "zlib",
        .target = target,
        .optimize = optimize,
    });
    zlib.addIncludePath(zlib_path);
    zlib.addCSourceFiles(&.{
        zlib_path ++ "adler32.c",
        zlib_path ++ "crc32.c",
        zlib_path ++ "gzclose.c",
        zlib_path ++ "gzread.c",
        zlib_path ++ "infback.c",
        zlib_path ++ "inflate.c",
        zlib_path ++ "trees.c",
        zlib_path ++ "zutil.c",
        zlib_path ++ "compress.c",
        zlib_path ++ "deflate.c",
        zlib_path ++ "gzlib.c",
        zlib_path ++ "gzwrite.c",
        zlib_path ++ "inffast.c",
        zlib_path ++ "inftrees.c",
        zlib_path ++ "uncompr.c",
    }, &c_flags);
    zlib.linkLibC();

    const lua_zlib = b.addStaticLibrary(.{
        .name = "lua_zlib",
        .target = target,
        .optimize = optimize,
    });
    lua_zlib.addIncludePath(lua_path);
    lua_zlib.addIncludePath(zlib_path);
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

    const exe = b.addExecutable(.{
        .name = "fullmoon",
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath("src/");
    exe.addIncludePath(lua_path);
    exe.addCSourceFiles(&.{
        "src/linit.c",
        lua_path ++ "lapi.c",
        lua_path ++ "lauxlib.c",
        lua_path ++ "lbaselib.c",
        lua_path ++ "lcode.c",
        lua_path ++ "lcorolib.c",
        lua_path ++ "lctype.c",
        lua_path ++ "ldblib.c",
        lua_path ++ "ldebug.c",
        lua_path ++ "ldo.c",
        lua_path ++ "ldump.c",
        lua_path ++ "lfunc.c",
        lua_path ++ "lgc.c",
        lua_path ++ "liolib.c",
        lua_path ++ "llex.c",
        lua_path ++ "lmathlib.c",
        lua_path ++ "lmem.c",
        lua_path ++ "loadlib.c",
        lua_path ++ "lobject.c",
        lua_path ++ "lopcodes.c",
        lua_path ++ "loslib.c",
        lua_path ++ "lparser.c",
        lua_path ++ "lstate.c",
        lua_path ++ "lstring.c",
        lua_path ++ "lstrlib.c",
        lua_path ++ "ltable.c",
        lua_path ++ "ltablib.c",
        lua_path ++ "ltm.c",
        lua_path ++ "lua.c",
        lua_path ++ "lundump.c",
        lua_path ++ "lutf8lib.c",
        lua_path ++ "lvm.c",
        lua_path ++ "lzio.c",
    }, &lua_flags);
    exe.linkLibrary(lsqlite3);
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

    //    const unit_tests = b.addTest(.{
    //        .root_source_file = .{ .path = "src/main.zig" },
    //        .target = target,
    //        .optimize = optimize,
    //    });
    //
    //    const run_unit_tests = b.addRunArtifact(unit_tests);
    //
    //    const test_step = b.step("test", "Run unit tests");
    //    test_step.dependOn(&run_unit_tests.step);

}
