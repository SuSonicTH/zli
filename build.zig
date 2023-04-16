const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "fullmoon",
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath("lua-5.4.4/src/");
    exe.addCSourceFile("lua-5.4.4/src/lua.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lapi.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lcode.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lctype.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/ldebug.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/ldo.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/ldump.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lfunc.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lgc.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/llex.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lmem.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lobject.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lopcodes.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lparser.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lstate.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lstring.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/ltable.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/ltm.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lundump.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lvm.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lzio.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lauxlib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lbaselib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lcorolib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/ldblib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/liolib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lmathlib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/loadlib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/loslib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lstrlib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/ltablib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/lutf8lib.c", &[_][]const u8{});
    exe.addCSourceFile("lua-5.4.4/src/linit.c", &[_][]const u8{});
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
