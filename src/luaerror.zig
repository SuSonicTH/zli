const std = @import("std");
const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");

pub const Handling = enum {
    raise,
    @"return",
};

var error_buffer: [1024:0]u8 = undefined;
var error_message: ?[:0]const u8 = null;

pub fn getGlobalErrorHanding(lua: *Lua) Handling {
    var handling: Handling = .@"return";

    if (lua.getGlobal("ZLI") == .table) {
        _ = lua.pushString("error_handling");
        if (lua.getTable(-2) == .string) {
            const str = lua.toString(-1) catch unreachable;
            if (std.mem.eql(u8, str, "raise")) {
                handling = .raise;
            }
        }
        lua.pop(1);
    }
    lua.pop(1);
    return handling;
}

pub fn getErrorHandling(lua: *Lua) !Handling {
    const handler = luax.getArgStringOrError(lua, 1, "expecting a string 'return', 'raise' or 'reset'");

    if (std.mem.eql(u8, handler, "raise")) {
        return .raise;
    } else if (std.mem.eql(u8, handler, "return")) {
        return .@"return";
    } else if (std.mem.eql(u8, handler, "reset")) {
        return getGlobalErrorHanding(lua);
    }
    return raise(error.wrongArgument, "expecting a string 'return', 'raise' or 'reset' but got '{s}'", .{handler});
}

pub fn argError(lua: *Lua, arg: i32, comptime format: []const u8, args: anytype) noreturn {
    const T = @TypeOf(args);
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => |struct_info| {
            if (struct_info.fields.len == 0) {
                lua.argError(arg, format);
            } else {
                const message = std.fmt.bufPrintSentinel(&error_buffer, format[0..format.len], args, 0) catch @panic("error message is too long");
                lua.argError(arg, message);
            }
        },
        else => @panic("expecting struct as args"),
    }
    unreachable;
}

pub fn callErrorHandler(lua: *Lua, handlerIndex: ?i32, comptime format: [:0]const u8, args: anytype) void {
    if (handlerIndex) |index| {
        lua.pushValue(index);
    }

    const T = @TypeOf(args);
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => |struct_info| {
            if (struct_info.fields.len == 0) {
                _ = lua.pushString(format);
            } else {
                const message = std.fmt.bufPrintSentinel(&error_buffer, format[0..format.len], args, 0) catch @panic("error message is too long");
                _ = lua.pushString(message);
            }
        },
        else => @panic("expecting struct as args"),
    }

    lua.call(.{ .args = 1, .results = 0 });
}

pub fn raise(err: anyerror, comptime format: [:0]const u8, args: anytype) anyerror {
    const T = @TypeOf(args);
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => |struct_info| {
            if (struct_info.fields.len == 0) {
                error_message = format;
            } else {
                error_message = std.fmt.bufPrintSentinel(&error_buffer, format[0..format.len], args, 0) catch @panic("error message is too long");
            }
        },
        else => @panic("expecting struct as args"),
    }
    return err;
}

pub fn ret(lua: *Lua, comptime format: []const u8, args: anytype) i32 {
    const T = @TypeOf(args);
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => |struct_info| {
            if (struct_info.fields.len == 0) {
                lua.pushNil();
                _ = lua.pushString(format);
            } else {
                const message = std.fmt.bufPrintSentinel(&error_buffer, format[0..format.len], args, 0) catch @panic("error message is too long");
                lua.pushNil();
                _ = lua.pushString(message);
            }
        },
        else => @panic("expecting struct as args"),
    }
    return 2;
}

pub fn raiseOrReturn(lua: *Lua, err: anyerror, comptime format: [:0]const u8, args: anytype, errorHandling: Handling) !i32 {
    return switch (errorHandling) {
        .raise => raise(err, format, args),
        .@"return" => ret(lua, format, args),
    };
}

pub fn wrap(comptime function: anytype) zlua.CFn {
    const info = @typeInfo(@TypeOf(function)).@"fn";
    const has_error_union = @typeInfo(info.return_type.?) == .error_union;
    return struct {
        fn inner(state: ?*zlua.LuaState) callconv(.c) c_int {
            // this is called by Lua, state should never be null
            var lua: *Lua = @ptrCast(state.?);
            if (has_error_union) {
                return @call(.always_inline, function, .{lua}) catch |err| {
                    if (error_message) |message| {
                        error_message = null;
                        lua.raiseErrorStr(message, .{});
                    } else {
                        lua.raiseErrorStr(@errorName(err), .{});
                    }
                };
            } else {
                return @call(.always_inline, function, .{lua});
            }
        }
    }.inner;
}
