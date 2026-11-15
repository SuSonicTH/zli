const std = @import("std");
const flags_c99 = &.{"-std=gnu99"};
const strip = @import("src/strip.zig").strip;
const shouldStrip = @import("src/strip.zig").shouldStrip;
const docgen = @import("src/docgen.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The package manifest is the single source of the project version.
    const version = packageVersion(b);

    const docs_payload = createDocsPayload(b);

    //normal build
    const exe = compileStep(b, target, optimize, "zli", version);
    const payload_exe = attachPayload(b, exe.getEmittedBin(), exe.out_filename, optimize, docs_payload);
    const install_exe = b.addInstallFileWithDir(payload_exe, .bin, exe.out_filename);
    b.getInstallStep().dependOn(&install_exe.step);

    //release
    const release = b.step("release", "Build all cross-compilation targets in release mode");
    releasebuild(b, release, docs_payload, version);

    //native
    const native = b.step("native", "Build an optimized release binary for the host");
    native.dependOn(nativebuild(b, docs_payload, version));

    //run
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunFile(payload_exe);
    run_cmd.addPassthruArgs();
    run_step.dependOn(&run_cmd.step);

    //test
    const test_step = b.step("test", "Test the interpreter and libs");
    const test_cmd = b.addRunFile(payload_exe);
    test_cmd.addArgs(&[_][]const u8{"./test/test.lua"});
    test_step.dependOn(&test_cmd.step);

    //regenerate the committed Markdown documentation mirror
    const docs_step = b.step("docs", "Regenerate doc/libraries.md from doc/libraries.lua");
    const docs_cmd = b.addRunFile(payload_exe);
    docs_cmd.addArgs(&[_][]const u8{ "@help", "--markdown", "--output", "doc/libraries.md" });
    docs_step.dependOn(&docs_cmd.step);

    // Zig unit tests (for example the Lua source stripper)
    const zig_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/strip.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_zig_tests = b.addRunArtifact(zig_tests);
    test_step.dependOn(&run_zig_tests.step);

    const webserver_util_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/webserver_util.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_webserver_util_tests = b.addRunArtifact(webserver_util_tests);
    test_step.dependOn(&run_webserver_util_tests.step);

    const docgen_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/docgen.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_docgen_tests = b.addRunArtifact(docgen_tests);
    test_step.dependOn(&run_docgen_tests.step);

    const termy_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/termy_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "termy", .module = b.dependency("termy", .{}).module("termy") }},
        }),
    });
    const run_termy_tests = b.addRunArtifact(termy_tests);
    test_step.dependOn(&run_termy_tests.step);

    for ([_][]const u8{
        "src/term_width.zig",
        "src/history.zig",
        "src/lineedit.zig",
        "src/prompt_editor.zig",
    }) |path| {
        var imports: []const std.Build.Module.Import = &.{};
        if (std.mem.eql(u8, path, "src/prompt_editor.zig")) {
            imports = &.{.{ .name = "termy", .module = b.dependency("termy", .{}).module("termy") }};
        }
        const unit_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(path),
                .target = target,
                .optimize = optimize,
                .imports = imports,
            }),
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}

const PackageManifest = struct {
    version: []const u8,
};

/// Read the package version from build.zig.zon so the manifest remains the
/// single source of the project version.
fn packageVersion(b: *std.Build) []const u8 {
    const source = readFile(b, b.path("build.zig.zon"));
    var diagnostics: std.zon.parse.Diagnostics = undefined;

    const manifest = std.zon.parse.fromSlice(PackageManifest, .{
        .gpa = b.allocator,
        .arena = b.graph.arena,
        .source = b.graph.arena.dupeSentinel(u8, source, 0) catch @panic("OOM"),
        .diagnostics = &diagnostics,
        .ignore_unknown_fields = true,
    }) catch {
        diagnostics.fatal("build.zig.zon");
    };

    return manifest.version;
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

fn releasebuild(
    b: *std.Build,
    release: *std.Build.Step,
    docs_payload: std.Build.LazyPath,
    version: []const u8,
) void {
    const zupx = b.dependency("zupx", .{
        .optimize = std.builtin.OptimizeMode.fast,
        .target = b.graph.host,
    });

    for (release_targets) |config| {
        const target = b.resolveTargetQuery(config.query);
        const exe_name = b.fmt("zli-{s}-{s}", .{ config.suffix, version });
        const exe = compileStep(b, target, std.builtin.OptimizeMode.fast, exe_name, version);
        const packed_path = upxPack(b, zupx, exe, exe.out_filename);
        const payload_exe = attachPayload(b, packed_path, exe.out_filename, std.builtin.OptimizeMode.fast, docs_payload);
        const install_artifact = b.addInstallFileWithDir(payload_exe, .bin, exe.out_filename);
        release.dependOn(&install_artifact.step);
    }
}

/// Compresses the compiled executable with upx into a separate cached file.
fn upxPack(
    b: *std.Build,
    zupx: *std.Build.Dependency,
    exe: *std.Build.Step.Compile,
    exe_name: []const u8,
) std.Build.LazyPath {
    const upx_cmd = b.addRunArtifact(zupx.artifact("upx"));
    upx_cmd.addArg("-o");
    const packed_path = upx_cmd.addOutputFileArg(exe_name);
    upx_cmd.addFileArg(exe.getEmittedBin());
    return packed_path;
}

fn nativebuild(
    b: *std.Build,
    docs_payload: std.Build.LazyPath,
    version: []const u8,
) *std.Build.Step {
    const zupx = b.dependency("zupx", .{
        .optimize = std.builtin.OptimizeMode.fast,
        .target = b.graph.host,
    });

    const exe = compileStep(b, b.graph.host, std.builtin.OptimizeMode.fast, "zli", version);
    const packed_path = upxPack(b, zupx, exe, exe.out_filename);
    const payload_exe = attachPayload(b, packed_path, exe.out_filename, std.builtin.OptimizeMode.fast, docs_payload);
    const install_artifact = b.addInstallFileWithDir(payload_exe, .bin, exe.out_filename);
    return &install_artifact.step;
}

fn compileStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    exe_name: []const u8,
    version: []const u8,
) *std.Build.Step.Compile {
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
            .strip = optimize != .debug,
        }),
    });
    exe.root_module.addIncludePath(b.path("src/"));
    exe.root_module.addImport("zlua", zlua.module("zlua"));

    const options = b.addOptions();
    options.addOption([]const u8, "version", version);
    exe.root_module.addOptions("build_options", options);

    //add lualibs (strip for non debug)
    luaLibs(b, optimize, exe.root_module);

    //terminal manipulation used by the line editor, pager and REPL tools
    const termy_dep = b.dependency("termy", .{});
    exe.root_module.addImport("termy", termy_dep.module("termy"));

    const md4c_dep = b.dependency("md4c", .{});
    const translate_md4c = b.addTranslateC(.{
        .root_source_file = md4c_dep.path("src/md4c-html.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_md4c.addIncludePath(md4c_dep.path("src"));
    exe.root_module.addImport("md4c_c", translate_md4c.createModule());

    //libraries
    exe.root_module.linkLibrary(lsqlite3(b, target, optimize, luaPath));
    exe.root_module.linkLibrary(lpeg(b, target, optimize, luaPath));
    exe.root_module.linkLibrary(luaCJson(b, target, optimize, luaPath));
    exe.root_module.linkLibrary(md4c(b, target, optimize));
    exe.root_module.linkLibrary(lyaml(b, target, optimize, luaPath));

    return exe;
}

const payload_entry = struct {
    input: []const u8,
    name: []const u8,
};

const payload_entries = [_]payload_entry{
    .{ .input = "src/main.lua", .name = "main.lua" },
    .{ .input = "src/tools/repl.lua", .name = "repl.lua" },
    .{ .input = "src/tools/sqlite.lua", .name = "sqlite.lua" },
    .{ .input = "src/tools/compile.lua", .name = "compile.lua" },
    .{ .input = "src/tools/test.lua", .name = "test.lua" },
    .{ .input = "src/tools/manual.lua", .name = "manual.lua" },
    .{ .input = "src/tools/serve.lua", .name = "serve.lua" },
    .{ .input = "src/tools/serve_lib.lua", .name = "serve_lib.lua" },
    .{ .input = "src/tools/help.lua", .name = "help.lua" },
    .{ .input = "src/docs.lua", .name = "docs.lua" },
    .{ .input = "src/docs_markdown.lua", .name = "docs_markdown.lua" },
};

/// Copies a compiled executable and appends the zli Lua payload to it.
fn attachPayload(
    b: *std.Build,
    exe: std.Build.LazyPath,
    output_name: []const u8,
    optimize: std.builtin.OptimizeMode,
    docs_payload: std.Build.LazyPath,
) std.Build.LazyPath {
    const tool = payloadTool(b);
    const run = b.addRunArtifact(tool);
    run.addFileArg(exe);
    const output = run.addOutputFileArg(output_name);

    for (&payload_entries) |*entry| {
        run.addArg(entry.name);
        run.addFileArg(payloadFile(b, optimize, entry.input, entry.name));
    }

    // The generated Lua manual is already text; never run the source stripper
    // over it (it contains large Markdown literals).
    run.addArg("docs_manual.lua");
    run.addFileArg(docs_payload);

    // The authored structured library documentation.
    run.addArg("docs_libraries.lua");
    run.addFileArg(b.path("doc/libraries.lua"));

    return output;
}

/// Generate docs_manual.lua from the Lua manual bundled with the lua55
/// dependency.  This runs on the host, so it works for cross-compiled builds.
fn createDocsPayload(b: *std.Build) std.Build.LazyPath {
    const lua = b.dependency("lua55", .{
        .target = b.graph.host,
        .optimize = .fast,
    });
    const manual_html = readFile(b, lua.path("doc/manual.html"));
    const lua_header = readFile(b, lua.path("src/lua.h"));
    const generated = docgen.generate(b.allocator, manual_html, lua_header) catch |err| {
        std.debug.panic("Failed to generate the Lua manual: {any}\n", .{err});
    };
    const files = b.addWriteFiles();
    return files.add("docs_manual.lua", generated);
}

fn payloadFile(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    input: []const u8,
    name: []const u8,
) std.Build.LazyPath {
    if (optimize == .debug) {
        return b.path(input);
    }

    // Only Lua sources are stripped. Assets such as the web UI JavaScript and
    // CSS are shipped byte-identical.
    if (!shouldStrip(name)) {
        return b.path(input);
    }

    const files = b.addWriteFiles();
    const source = readFile(b, b.path(input));
    const stripped = strip(source, b.allocator) catch |err| {
        std.debug.panic("Failed to strip Lua script '{s}': {any}\n", .{ name, err });
    };
    return files.add(name, stripped);
}

fn payloadTool(b: *std.Build) *std.Build.Step.Compile {
    const host = b.graph.host;

    const tool = b.addExecutable(.{
        .name = "attach_payload",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/attach_payload.zig"),
            .target = host,
            .optimize = .fast,
            .strip = true,
        }),
    });
    tool.root_module.link_libc = true;

    return tool;
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
    .{ .input = "tinytoml.lua", .name = "toml.lua", .dependency = "tinytoml" },
    .{ .input = "lib/lyaml/explicit.lua", .name = "lyaml.explicit.lua", .dependency = "lyaml" },
    .{ .input = "lib/lyaml/functional.lua", .name = "lyaml.functional.lua", .dependency = "lyaml" },
    .{ .input = "lib/lyaml/implicit.lua", .name = "lyaml.implicit.lua", .dependency = "lyaml" },
    .{ .input = "lib/lyaml/init.lua", .name = "lyaml.lua", .dependency = "lyaml" },
    .{ .input = "src/yaml.lua", .name = "yaml.lua" },
    .{ .input = "xml2lua.lua", .name = "xml2lua.lua", .dependency = "xml2lua" },
    .{ .input = "XmlParser.lua", .name = "XmlParser.lua", .dependency = "xml2lua" },
    .{ .input = "xmlhandler/dom.lua", .name = "xmlhandler.dom.lua", .dependency = "xml2lua" },
    .{ .input = "xmlhandler/print.lua", .name = "xmlhandler.print.lua", .dependency = "xml2lua" },
    .{ .input = "xmlhandler/tree.lua", .name = "xmlhandler.tree.lua", .dependency = "xml2lua" },

    .{ .input = "src/auxiliary.lua", .name = "auxiliary.lua" },
    .{ .input = "src/benchmark.lua", .name = "benchmark.lua" },
    .{ .input = "src/collection/init.lua", .name = "collection.init.lua" },
    .{ .input = "src/collection/list.lua", .name = "collection.list.lua" },
    .{ .input = "src/collection/map.lua", .name = "collection.map.lua" },
    .{ .input = "src/collection/set.lua", .name = "collection.set.lua" },
    .{ .input = "src/term.lua", .name = "term.lua" },
    .{ .input = "src/readline.lua", .name = "readline.lua" },
    .{ .input = "src/pager.lua", .name = "pager.lua" },
    .{ .input = "src/prompt/init.lua", .name = "prompt.init.lua" },
    .{ .input = "src/prompt/config.lua", .name = "prompt.config.lua" },
    .{ .input = "src/prompt/theme.lua", .name = "prompt.theme.lua" },
    .{ .input = "src/prompt/render.lua", .name = "prompt.render.lua" },
    .{ .input = "src/prompt/input.lua", .name = "prompt.input.lua" },
    .{ .input = "src/prompt/items.lua", .name = "prompt.items.lua" },
    .{ .input = "src/prompt/fallback.lua", .name = "prompt.fallback.lua" },
    .{ .input = "src/prompt/select.lua", .name = "prompt.select.lua" },
    .{ .input = "src/prompt/text.lua", .name = "prompt.text.lua" },
    .{ .input = "src/prompt/multiline.lua", .name = "prompt.multiline.lua" },
    .{ .input = "src/prompt/password.lua", .name = "prompt.password.lua" },
    .{ .input = "src/prompt/confirm.lua", .name = "prompt.confirm.lua" },
    .{ .input = "src/filesystem.lua", .name = "filesystem.lua" },
    .{ .input = "src/grid.lua", .name = "grid.lua" },
    .{ .input = "src/httpclient.lua", .name = "httpclient.lua" },
    .{ .input = "src/httpserver.lua", .name = "httpserver.lua" },
    .{ .input = "src/webserver.lua", .name = "webserver.lua" },
    .{ .input = "src/webui/init.lua", .name = "webui.init.lua" },
    .{ .input = "src/webui/component.lua", .name = "webui.component.lua" },
    .{ .input = "src/webui/html.lua", .name = "webui.html.lua" },
    .{ .input = "src/webui/event.lua", .name = "webui.event.lua" },
    .{ .input = "src/init.lua", .name = "init.lua" },
    .{ .input = "src/logger.lua", .name = "logger.lua" },
    .{ .input = "src/memoize.lua", .name = "memoize.lua" },
    .{ .input = "src/stream.lua", .name = "stream.lua" },
    .{ .input = "src/timer.lua", .name = "timer.lua" },
    .{ .input = "src/unzip.lua", .name = "unzip.lua" },
    .{ .input = "src/xlsxmlwriter.lua", .name = "xlsxmlwriter.lua" },
    .{ .input = "src/zip.lua", .name = "zip.lua" },
};

fn luaLibs(b: *std.Build, optimize: std.builtin.OptimizeMode, module: *std.Build.Module) void {
    const lualibs = b.addWriteFiles();
    for (&lualib_list) |*script| {
        var source: []const u8 = undefined;

        if (script.dependency[0] == 0) {
            if (optimize == .debug or !shouldStrip(script.name)) {
                source = readFile(b, b.path(script.input));
            } else {
                source = strip(readFile(b, b.path(script.input)), b.allocator) catch |err| {
                    std.debug.panic("Failed to strip Lua script '{s}': {any}\n", .{ script.name, err });
                };
            }
        } else {
            const dependency = b.dependency(script.dependency, .{});
            const path = dependency.path(script.input);
            if (optimize == .debug or !shouldStrip(script.name)) {
                source = readFile(b, path);
            } else {
                source = strip(readFile(b, path), b.allocator) catch |err| {
                    std.debug.panic("Failed to strip Lua script '{s}': {any}\n", .{ script.name, err });
                };
            }
        }
        module.addAnonymousImport(script.name, .{
            .root_source_file = lualibs.add(script.name, source),
        });
    }
}

fn readFile(b: *std.Build, path: std.Build.LazyPath) []const u8 {
    b.dependOnFileContents(path);

    const root, const sub_path = switch (path) {
        .src_path => |sp| .{ sp.owner.root, sp.sub_path },
        .dependency => |dep| .{ dep.dependency.builder.root, dep.sub_path },
        else => @panic("unsupported build-time file path"),
    };

    const rel_path = std.fs.path.join(b.allocator, &.{ root.sub_path, sub_path }) catch @panic("OOM");
    return root.root_dir.handle.readFileAlloc(
        b.graph.io,
        rel_path,
        b.graph.arena,
        std.Io.Limit.unlimited,
    ) catch |err| {
        std.debug.panic("Failed to read {s}: {any}\n", .{ rel_path, err });
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

fn md4c(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "md4c",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });
    const dependency = b.dependency("md4c", .{});
    const source_dir = dependency.path("src");
    lib.root_module.addIncludePath(source_dir);
    lib.root_module.addCSourceFiles(.{ .root = source_dir, .files = &[_][]const u8{
        "md4c.c",
        "md4c-html.c",
        "entity.c",
    }, .flags = flags_c99 });
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

fn lyaml(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, luaPath: std.Build.LazyPath) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "lyaml",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    const lyaml_dep = b.dependency("lyaml", .{});
    const libyaml_dep = b.dependency("libyaml", .{});
    const lyaml_dir = lyaml_dep.path("ext/yaml");
    const libyaml_inc = libyaml_dep.path("include");
    const libyaml_src = libyaml_dep.path("src");

    lib.root_module.addIncludePath(luaPath);
    lib.root_module.addIncludePath(lyaml_dir);
    lib.root_module.addIncludePath(libyaml_inc);
    lib.root_module.addIncludePath(libyaml_src);

    lib.root_module.addCSourceFiles(.{
        .root = lyaml_dir,
        .files = &[_][]const u8{
            "yaml.c",
            "parser.c",
            "emitter.c",
            "scanner.c",
        },
        .flags = &[_][]const u8{
            "-std=gnu99",
            "-DYAML_DECLARE_STATIC",
            "-DVERSION=\"6.2.10\"",
            "-Wno-string-plus-int",
        },
    });

    lib.root_module.addCSourceFiles(.{
        .root = libyaml_src,
        .files = &[_][]const u8{
            "api.c",
            "dumper.c",
            "emitter.c",
            "loader.c",
            "parser.c",
            "reader.c",
            "scanner.c",
            "writer.c",
        },
        .flags = &[_][]const u8{
            "-std=gnu99",
            "-DYAML_DECLARE_STATIC",
            "-DYAML_VERSION_MAJOR=0",
            "-DYAML_VERSION_MINOR=2",
            "-DYAML_VERSION_PATCH=5",
            "-DYAML_VERSION_STRING=\"0.2.5\"",
        },
    });

    lib.root_module.link_libc = true;
    return lib;
}
