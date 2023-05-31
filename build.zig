const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //LuaSQLite3
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

    //LuaFileSystem
    const lfs = b.addStaticLibrary(.{
        .name = "lfs",
        .target = target,
        .optimize = optimize,
    });
    lfs.addIncludePath("lua/src/");
    lfs.addIncludePath("luafilesystem/src/");
    lfs.addCSourceFile("luafilesystem/src/lfs.c", &c_flags);
    lfs.linkLibC();

    //LPeg
    const lpeg = b.addStaticLibrary(.{
        .name = "lpeg",
        .target = target,
        .optimize = optimize,
    });

    lpeg.addIncludePath("lpeg/");
    lpeg.addIncludePath("lua/src/");
    lpeg.addCSourceFiles(&lpeg_c_sources, &c_flags);
    lpeg.linkLibC();

    //zlib
    const zlib = b.addStaticLibrary(.{
        .name = "zlib",
        .target = target,
        .optimize = optimize,
    });
    zlib.addIncludePath("zlib/");
    zlib.addCSourceFiles(&zlib_c_sources, &.{"-std=c89"});
    zlib.linkLibC();

    //lua zlib
    const lua_zlib = b.addStaticLibrary(.{
        .name = "lua_zlib",
        .target = target,
        .optimize = optimize,
    });
    lua_zlib.addIncludePath("lua/src/");
    lua_zlib.addIncludePath("zlib/");
    lua_zlib.addCSourceFile("lua-zlib/lua_zlib.c", &[_][]const u8{"-DLZLIB_COMPAT"});
    lua_zlib.linkLibC();

    //lua-cjason
    const lua_cjson = b.addStaticLibrary(.{
        .name = "lua_cjson",
        .target = target,
        .optimize = optimize,
    });
    lua_cjson.addIncludePath("lua/src/");
    lua_cjson.addIncludePath("lua-cjson/");
    lua_cjson.addCSourceFiles(&lua_cjson_c_sources, &c_flags);
    lua_cjson.linkLibC();

    //crossline
    const crossline = b.addStaticLibrary(.{
        .name = "crossline",
        .target = target,
        .optimize = optimize,
    });
    crossline.addIncludePath("Crossline/");
    crossline.addCSourceFile("Crossline/crossline.c", &c_flags);
    crossline.linkLibC();

    //Lua
    const lua = b.addStaticLibrary(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
    });

    lua.addIncludePath("lua/src");
    lua.addCSourceFiles(&lua_c_sources, &[_][]const u8{
        "-std=gnu99",

        switch (target.getOsTag()) {
            .linux => "-DLUA_USE_LINUX",
            .macos => "-DLUA_USE_MACOSX",
            .windows => "-DLUA_USE_WINDOWS",
            else => "-DLUA_USE_POSIX",
        },
    });
    lua.linkLibC();

    //FullMoon
    const fullmoon = b.addStaticLibrary(.{
        .name = "fullmoon",
        .root_source_file = .{ .path = "fm_libraries.zig" },
        .target = target,
        .optimize = optimize,
    });
    fullmoon.addIncludePath("./");
    fullmoon.addIncludePath("lua/src/");
    fullmoon.addIncludePath("Crossline/");
    fullmoon.addCSourceFiles(&fullmoon_c_sources, &c_flags);
    fullmoon.linkLibC();

    //FullMoon exe
    const exe = b.addExecutable(.{
        .name = "fullmoon",
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(fullmoon);
    exe.linkLibrary(lua);
    exe.linkLibrary(lsqlite3);
    exe.linkLibrary(lpeg);
    exe.linkLibrary(lfs);
    exe.linkLibrary(zlib);
    exe.linkLibrary(lua_zlib);
    exe.linkLibrary(lua_cjson);
    exe.linkLibrary(crossline);
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

const c_flags = [_][]const u8{
    "-std=gnu99",
};

const lua_c_sources = [_][]const u8{
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
};

const lpeg_c_sources = [_][]const u8{
    "lpeg/lpcap.c",
    "lpeg/lpcode.c",
    "lpeg/lpprint.c",
    "lpeg/lptree.c",
    "lpeg/lpvm.c",
};

const zlib_c_sources = [_][]const u8{
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
};

const fullmoon_c_sources = [_][]const u8{
    "fullmoon.c",
    "fm_aux.c",
    "fm_csv.c",
    "fm_crossline.c",
    "fm_sb.c",
    "lx_value.c",
};

const lua_cjson_c_sources = [_][]const u8{
    "lua-cjson/fpconv.c",
    "lua-cjson/g_fmt.c",
    "lua-cjson/lua_cjson.c",
    "lua-cjson/strbuf.c",
};
