const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");

const allocator = std.heap.c_allocator;

const filesystem = @import("filesystem.zig");
const zip_writer = @import("zip_writer.zig");

const zip = [_]zlua.FnReg{
    .{ .name = "create", .func = luaerror.wrap(ZipUdata.create) },
    .{ .name = "open", .func = luaerror.wrap(ZipUdata.open_zip) },
    .{ .name = "create_after", .func = luaerror.wrap(ZipUdata.create_after) },
};

const zli_zip = "zli_zip";

var io: std.Io = undefined;

pub fn setIo(_io: std.Io) void {
    io = _io;
}

pub fn register(lua: *Lua) i32 {
    ZipUdata.register(lua);
    lua.newLib(&zip);

    const extended = @embedFile("zip.lua");
    luax.registerExtended(lua, extended, "zip", zli_zip);
    return 1;
}

const ZipUdata = struct {
    writer: ?*zip_writer.Writer = null,
    path: [:0]u8,
    const name = "_ZipUdata";

    const functions = [_]zlua.FnReg{
        .{ .name = "add_file", .func = luaerror.wrap(add_file) },
        .{ .name = "create_directory", .func = luaerror.wrap(create_directory) },
        .{ .name = "mkdir", .func = luaerror.wrap(create_directory) },
        .{ .name = "open", .func = luaerror.wrap(open) },
        .{ .name = "write", .func = luaerror.wrap(write) },
        .{ .name = "close", .func = luaerror.wrap(close) },
        .{ .name = "close_zip", .func = luaerror.wrap(close_zip) },
    };

    fn register(lua: *Lua) void {
        if (lua.getMetatableRegistry(name) == .nil) {
            lua.pop(1);
            luax.registerUserData(lua, name, zlua.wrap(garbageCollect));
        } else {
            lua.pop(1);
        }
    }

    fn garbageCollect(lua: *Lua) i32 {
        const ud: *ZipUdata = luax.getGcUserData(lua, ZipUdata);
        if (ud.writer) |writer| {
            writer.deinit();
            ud.writer = null;
        }
        allocator.free(ud.path);
        return 0;
    }

    fn create(lua: *Lua) !i32 {
        return create_or_open_zip(lua, .create);
    }

    fn open_zip(lua: *Lua) !i32 {
        return create_or_open_zip(lua, .open);
    }

    fn create_after(lua: *Lua) !i32 {
        return create_or_open_zip(lua, .create_after);
    }

    const OpenMode = enum { create, open, create_after };

    fn create_or_open_zip(lua: *Lua, mode: OpenMode) !i32 {
        const path = try filesystem.get_path(lua);

        const writer = switch (mode) {
            .create => zip_writer.Writer.create(allocator, io, path),
            .open => zip_writer.Writer.open(allocator, io, path),
            .create_after => zip_writer.Writer.createAfter(allocator, io, path),
        } catch |err|
            return luaerror.ret(lua, "could not open zip file '{s}': {s}", .{ path, @errorName(err) });
        errdefer writer.deinit();

        const owned_path = try allocator.dupeSentinel(u8, std.mem.sliceTo(path, 0), 0);
        errdefer allocator.free(owned_path);

        const ud: *ZipUdata = luax.createUserDataTableSetFunctions(lua, name, ZipUdata, &functions, 0);
        ud.path = owned_path;
        ud.writer = writer;

        luax.setTableRegistryFunction(lua, -1, "add_directory", zli_zip, "add_directory");
        return 1;
    }

    fn get_writer(lua: *Lua) ?*zip_writer.Writer {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        if (ud.writer) |writer| {
            if (!writer.closed) return writer;
        }
        return null;
    }

    fn add_file(lua: *Lua) !i32 {
        const writer = get_writer(lua) orelse return luaerror.ret(lua, "zip archive is closed", .{});
        const source_name = try filesystem.get_path_index(lua, 2);
        const destination_name = try filesystem.get_path_index(lua, 3);
        const level_i = lua.optInteger(4) orelse 6;
        if (level_i < 0 or level_i > 9) {
            return luaerror.ret(lua, "zip compression level must be between 0 and 9", .{});
        }
        const level: u4 = @intCast(level_i);

        var comment: []const u8 = "";
        if (lua.typeOf(5) == .string) {
            const text = lua.toString(5) catch "";
            comment = std.mem.sliceTo(text, 0);
        }

        writer.addFile(source_name, destination_name, level, comment) catch |err|
            return luaerror.ret(lua, "could not add '{s}' to zip: {s}", .{ source_name, @errorName(err) });

        lua.pushBoolean(true);
        return 1;
    }

    fn create_directory(lua: *Lua) !i32 {
        const writer = get_writer(lua) orelse return luaerror.ret(lua, "zip archive is closed", .{});
        const path = lua.checkString(2);
        writer.createDirectory(path) catch |err|
            return luaerror.ret(lua, "could not create directory '{s}' in zip: {s}", .{ path, @errorName(err) });
        return 0;
    }

    fn open(lua: *Lua) !i32 {
        const writer = get_writer(lua) orelse return luaerror.ret(lua, "zip archive is closed", .{});
        const path = lua.checkString(2);
        const level_i = lua.optInteger(3) orelse 6;
        if (level_i < 0 or level_i > 9) {
            return luaerror.ret(lua, "zip compression level must be between 0 and 9", .{});
        }
        const level: u4 = @intCast(level_i);

        var comment: []const u8 = "";
        if (lua.typeOf(4) == .string) {
            const text = lua.toString(4) catch "";
            comment = std.mem.sliceTo(text, 0);
        }

        writer.beginEntry(path, .{ .level = level, .comment = comment }) catch |err|
            return luaerror.ret(lua, "could not open file '{s}' in zip: {s}", .{ path, @errorName(err) });

        lua.pushValue(1);
        return 1;
    }

    fn write(lua: *Lua) !i32 {
        const writer = get_writer(lua) orelse return luaerror.ret(lua, "zip archive is closed", .{});
        const top = lua.getTop();
        var argument: i32 = 2;

        while (argument <= top) : (argument += 1) {
            const data = lua.toString(argument) catch lua.argError(argument, "expecting string or number");
            writer.write(data) catch |err|
                return luaerror.ret(lua, "could not write to zip file: {s}", .{@errorName(err)});
        }

        lua.pushValue(1);
        return 1;
    }

    fn close(lua: *Lua) !i32 {
        const writer = get_writer(lua) orelse return luaerror.ret(lua, "zip archive is closed", .{});
        writer.endEntry() catch |err|
            return luaerror.ret(lua, "could not close entry in zip file: {s}", .{@errorName(err)});
        lua.pushValue(1);
        return 1;
    }

    fn close_zip(lua: *Lua) !i32 {
        const ud: *ZipUdata = luax.getUserData(lua, name, ZipUdata);
        const writer = ud.writer orelse return 0;
        if (writer.closed) return 0;

        var comment: ?[]const u8 = null;
        if (lua.typeOf(2) == .string) {
            const text = lua.toString(2) catch null;
            if (text) |value| comment = std.mem.sliceTo(value, 0);
        }

        writer.close(comment) catch |err| {
            return luaerror.ret(lua, "could not close zip file '{s}': {s}", .{ ud.path, @errorName(err) });
        };
        return 0;
    }
};
