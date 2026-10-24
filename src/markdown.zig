//! Markdown parsing and HTML rendering based on md4c.
//!
//! The Lua-facing module is `markdown`; the underlying C dependency is md4c.

const std = @import("std");

const zlua = @import("zlua");
const Lua = zlua.Lua;
const luax = @import("luax.zig");
const luaerror = @import("luaerror.zig");
const file_reader = @import("file_reader.zig");
const filesystem = @import("filesystem.zig");

const c = @import("md4c_c");

const allocator = std.heap.c_allocator;

const functions = [_]zlua.FnReg{
    .{ .name = "parse", .func = luaerror.wrap(parse) },
    .{ .name = "parse_file", .func = luaerror.wrap(parse_file) },
    .{ .name = "html", .func = luaerror.wrap(html) },
    .{ .name = "html_file", .func = luaerror.wrap(html_file) },
};

const FlagConstant = luax.NamedConstantInteger;

const dialect_constants = [_]FlagConstant{
    .{ .name = "commonmark", .number = @intCast(c.MD_DIALECT_COMMONMARK) },
    .{ .name = "github", .number = @intCast(c.MD_DIALECT_GITHUB) },
};

const flag_constants = [_]FlagConstant{
    .{ .name = "collapse_whitespace", .number = @intCast(c.MD_FLAG_COLLAPSEWHITESPACE) },
    .{ .name = "permissive_atx_headers", .number = @intCast(c.MD_FLAG_PERMISSIVEATXHEADERS) },
    .{ .name = "permissive_url_autolinks", .number = @intCast(c.MD_FLAG_PERMISSIVEURLAUTOLINKS) },
    .{ .name = "permissive_email_autolinks", .number = @intCast(c.MD_FLAG_PERMISSIVEEMAILAUTOLINKS) },
    .{ .name = "no_indented_code_blocks", .number = @intCast(c.MD_FLAG_NOINDENTEDCODEBLOCKS) },
    .{ .name = "no_html_blocks", .number = @intCast(c.MD_FLAG_NOHTMLBLOCKS) },
    .{ .name = "no_html_spans", .number = @intCast(c.MD_FLAG_NOHTMLSPANS) },
    .{ .name = "tables", .number = @intCast(c.MD_FLAG_TABLES) },
    .{ .name = "strikethrough", .number = @intCast(c.MD_FLAG_STRIKETHROUGH) },
    .{ .name = "permissive_www_autolinks", .number = @intCast(c.MD_FLAG_PERMISSIVEWWWAUTOLINKS) },
    .{ .name = "tasklists", .number = @intCast(c.MD_FLAG_TASKLISTS) },
    .{ .name = "task_lists", .number = @intCast(c.MD_FLAG_TASKLISTS) },
    .{ .name = "latex_math_spans", .number = @intCast(c.MD_FLAG_LATEXMATHSPANS) },
    .{ .name = "wikilinks", .number = @intCast(c.MD_FLAG_WIKILINKS) },
    .{ .name = "wiki_links", .number = @intCast(c.MD_FLAG_WIKILINKS) },
    .{ .name = "underline", .number = @intCast(c.MD_FLAG_UNDERLINE) },
    .{ .name = "hard_soft_breaks", .number = @intCast(c.MD_FLAG_HARD_SOFT_BREAKS) },
    .{ .name = "spoilers", .number = @intCast(c.MD_FLAG_SPOILERS) },
    .{ .name = "superscripts", .number = @intCast(c.MD_FLAG_SUPERSCRIPTS) },
    .{ .name = "subscripts", .number = @intCast(c.MD_FLAG_SUBSCRIPTS) },
    .{ .name = "admonitions", .number = @intCast(c.MD_FLAG_ADMONITIONS) },
    .{ .name = "footnotes", .number = @intCast(c.MD_FLAG_FOOTNOTES) },
    .{ .name = "highlight", .number = @intCast(c.MD_FLAG_HIGHLIGHT) },
    .{ .name = "preserve_blank_lines", .number = @intCast(c.MD_FLAG_PRESERVEBLANKLINES) },
    .{ .name = "insert", .number = @intCast(c.MD_FLAG_INSERT) },
};

const html_flag_constants = [_]FlagConstant{
    .{ .name = "debug", .number = @intCast(c.MD_HTML_FLAG_DEBUG) },
    .{ .name = "verbatim_entities", .number = @intCast(c.MD_HTML_FLAG_VERBATIM_ENTITIES) },
    .{ .name = "skip_utf8_bom", .number = @intCast(c.MD_HTML_FLAG_SKIP_UTF8_BOM) },
    .{ .name = "xhtml", .number = @intCast(c.MD_HTML_FLAG_XHTML) },
};

pub fn register(lua: *Lua) i32 {
    lua.newLib(&functions);
    const table = lua.getTop();
    luax.createConstantSubTable(lua, &dialect_constants, table, "dialects");
    luax.createConstantSubTable(lua, &flag_constants, table, "flags");
    luax.createConstantSubTable(lua, &html_flag_constants, table, "html_flags");
    return 1;
}

const ParseContext = struct {
    lua: *Lua,
    enter_block_ref: i32 = zlua.ref_nil,
    leave_block_ref: i32 = zlua.ref_nil,
    enter_span_ref: i32 = zlua.ref_nil,
    leave_span_ref: i32 = zlua.ref_nil,
    text_ref: i32 = zlua.ref_nil,
    debug_log_ref: i32 = zlua.ref_nil,
    single_callback_ref: i32 = zlua.ref_nil,
    error_ref: i32 = zlua.ref_nil,
    aborted: bool = false,

    fn deinit(self: *ParseContext) void {
        const lua = self.lua;
        lua.unref(zlua.registry_index, self.enter_block_ref);
        lua.unref(zlua.registry_index, self.leave_block_ref);
        lua.unref(zlua.registry_index, self.enter_span_ref);
        lua.unref(zlua.registry_index, self.leave_span_ref);
        lua.unref(zlua.registry_index, self.text_ref);
        lua.unref(zlua.registry_index, self.debug_log_ref);
        lua.unref(zlua.registry_index, self.single_callback_ref);
        lua.unref(zlua.registry_index, self.error_ref);
    }

    fn callbackRef(self: *const ParseContext, named_ref: i32) i32 {
        if (self.single_callback_ref != zlua.ref_nil) return self.single_callback_ref;
        return named_ref;
    }

    fn callbackPrefix(self: *const ParseContext) i32 {
        return if (self.single_callback_ref != zlua.ref_nil) 1 else 0;
    }

    fn pushCallback(self: *ParseContext, ref: i32, callback_type: []const u8) bool {
        if (self.aborted or ref == zlua.ref_nil) return false;
        _ = self.lua.getIndexRaw(zlua.registry_index, ref);
        if (self.single_callback_ref != zlua.ref_nil) {
            _ = self.lua.pushString(callback_type);
        }
        return true;
    }

    fn finishCallback(self: *ParseContext, arg_count: i32) c_int {
        const lua = self.lua;
        lua.protectedCall(.{ .args = arg_count, .results = 1 }) catch {
            self.error_ref = lua.ref(zlua.registry_index);
            self.aborted = true;
            return 1;
        };

        if (lua.typeOf(-1) == .boolean and !lua.toBoolean(-1)) {
            self.aborted = true;
            return 1;
        }
        return 0;
    }
};

fn parse(lua: *Lua) !i32 {
    const text = lua.checkString(1);
    return parseData(lua, text, 2, 3);
}

fn parse_file(lua: *Lua) !i32 {
    const path = filesystem.get_path_index(lua, 1) catch |err|
        return luaerror.raiseOrReturnLast(lua, err, .@"return");
    const data = file_reader.readAll(allocator, path) catch |err|
        return luaerror.ret(lua, "could not read '{s}': {s}", .{ path, @errorName(err) });
    defer allocator.free(data);
    return parseData(lua, data, 2, 3);
}

fn parseData(lua: *Lua, data: []const u8, callback_index: i32, options_index: i32) !i32 {
    if (data.len > std.math.maxInt(c.MD_SIZE)) {
        return luaerror.ret(lua, "markdown input is too large", .{});
    }

    const callback_type = lua.typeOf(callback_index);
    if (callback_type != .table and callback_type != .function) {
        lua.argCheck(false, callback_index, "expecting a callback table or function");
    }

    const flags = try parserFlags(lua, options_index);
    var context = ParseContext{ .lua = lua };
    defer context.deinit();

    if (callback_type == .table) {
        const table_index = luax.getAbsoluteIndex(lua, callback_index);
        context.enter_block_ref = try callbackRef(lua, table_index, "enter_block");
        context.leave_block_ref = try callbackRef(lua, table_index, "leave_block");
        context.enter_span_ref = try callbackRef(lua, table_index, "enter_span");
        context.leave_span_ref = try callbackRef(lua, table_index, "leave_span");
        context.text_ref = try callbackRef(lua, table_index, "text");
        context.debug_log_ref = try callbackRef(lua, table_index, "debug_log");
    } else {
        lua.pushValue(callback_index);
        context.single_callback_ref = lua.ref(zlua.registry_index);
    }

    // md4c calls every callback unconditionally, so always install the
    // trampolines. They no-op when the corresponding Lua callback is absent.
    var parser = c.MD_PARSER{
        .abi_version = 0,
        .flags = flags,
        .enter_block = enterBlock,
        .leave_block = leaveBlock,
        .enter_span = enterSpan,
        .leave_span = leaveSpan,
        .text = textCallback,
        .debug_log = debugLog,
        .syntax = null,
    };

    const result = c.md_parse(@ptrCast(data.ptr), @intCast(data.len), &parser, &context);
    if (context.error_ref != zlua.ref_nil) {
        _ = lua.getIndexRaw(zlua.registry_index, context.error_ref);
        lua.raiseError();
    }
    if (context.aborted) {
        lua.pushBoolean(false);
        return 1;
    }
    if (result != 0) {
        return luaerror.ret(lua, "markdown parsing failed", .{});
    }
    lua.pushBoolean(true);
    return 1;
}

fn callbackRef(lua: *Lua, table_index: i32, name: [:0]const u8) !i32 {
    luax.getTable(lua, name, table_index);
    if (lua.isNil(-1)) {
        lua.pop(1);
        return zlua.ref_nil;
    }
    if (lua.typeOf(-1) != .function) {
        luaerror.argError(lua, table_index, "callback '{s}' must be a function", .{name});
    }
    return lua.ref(zlua.registry_index);
}

fn enterBlock(block_type: c.MD_BLOCKTYPE, detail: ?*anyopaque, userdata: ?*anyopaque) callconv(.c) c_int {
    const context: *ParseContext = @ptrCast(@alignCast(userdata.?));
    if (context.aborted) return 1;
    const ref = context.callbackRef(context.enter_block_ref);
    if (ref == zlua.ref_nil) return 0;

    const lua = context.lua;
    const top = lua.getTop();
    defer lua.setTop(top);
    if (!context.pushCallback(ref, "enter_block")) return 0;
    _ = lua.pushString(blockTypeName(block_type));
    pushBlockDetail(lua, block_type, detail);
    return context.finishCallback(2 + context.callbackPrefix());
}

fn leaveBlock(block_type: c.MD_BLOCKTYPE, detail: ?*anyopaque, userdata: ?*anyopaque) callconv(.c) c_int {
    const context: *ParseContext = @ptrCast(@alignCast(userdata.?));
    if (context.aborted) return 1;
    const ref = context.callbackRef(context.leave_block_ref);
    if (ref == zlua.ref_nil) return 0;

    const lua = context.lua;
    const top = lua.getTop();
    defer lua.setTop(top);
    if (!context.pushCallback(ref, "leave_block")) return 0;
    _ = lua.pushString(blockTypeName(block_type));
    pushBlockDetail(lua, block_type, detail);
    return context.finishCallback(2 + context.callbackPrefix());
}

fn enterSpan(span_type: c.MD_SPANTYPE, detail: ?*anyopaque, userdata: ?*anyopaque) callconv(.c) c_int {
    const context: *ParseContext = @ptrCast(@alignCast(userdata.?));
    if (context.aborted) return 1;
    const ref = context.callbackRef(context.enter_span_ref);
    if (ref == zlua.ref_nil) return 0;

    const lua = context.lua;
    const top = lua.getTop();
    defer lua.setTop(top);
    if (!context.pushCallback(ref, "enter_span")) return 0;
    _ = lua.pushString(spanTypeName(span_type));
    pushSpanDetail(lua, span_type, detail);
    return context.finishCallback(2 + context.callbackPrefix());
}

fn leaveSpan(span_type: c.MD_SPANTYPE, detail: ?*anyopaque, userdata: ?*anyopaque) callconv(.c) c_int {
    const context: *ParseContext = @ptrCast(@alignCast(userdata.?));
    if (context.aborted) return 1;
    const ref = context.callbackRef(context.leave_span_ref);
    if (ref == zlua.ref_nil) return 0;

    const lua = context.lua;
    const top = lua.getTop();
    defer lua.setTop(top);
    if (!context.pushCallback(ref, "leave_span")) return 0;
    _ = lua.pushString(spanTypeName(span_type));
    pushSpanDetail(lua, span_type, detail);
    return context.finishCallback(2 + context.callbackPrefix());
}

fn textCallback(text_type: c.MD_TEXTTYPE, text: [*c]const c.MD_CHAR, size: c.MD_SIZE, userdata: ?*anyopaque) callconv(.c) c_int {
    const context: *ParseContext = @ptrCast(@alignCast(userdata.?));
    if (context.aborted) return 1;
    const ref = context.callbackRef(context.text_ref);
    if (ref == zlua.ref_nil) return 0;

    const lua = context.lua;
    const top = lua.getTop();
    defer lua.setTop(top);
    if (!context.pushCallback(ref, "text")) return 0;
    _ = lua.pushString(textTypeName(text_type));
    _ = lua.pushString(text[0..size]);
    return context.finishCallback(2 + context.callbackPrefix());
}

fn debugLog(message: [*c]const u8, userdata: ?*anyopaque) callconv(.c) void {
    const context: *ParseContext = @ptrCast(@alignCast(userdata.?));
    if (context.aborted) return;
    const ref = context.callbackRef(context.debug_log_ref);
    if (ref == zlua.ref_nil) return;

    const lua = context.lua;
    const top = lua.getTop();
    defer lua.setTop(top);

    const text = if (message == null) "" else std.mem.span(message);
    if (!context.pushCallback(ref, "debug_log")) return;
    _ = lua.pushString(text);
    _ = context.finishCallback(1 + context.callbackPrefix());
}

fn blockTypeName(block_type: c.MD_BLOCKTYPE) [:0]const u8 {
    return switch (block_type) {
        c.MD_BLOCK_DOC => "doc",
        c.MD_BLOCK_QUOTE => "quote",
        c.MD_BLOCK_UL => "ul",
        c.MD_BLOCK_OL => "ol",
        c.MD_BLOCK_LI => "li",
        c.MD_BLOCK_HR => "hr",
        c.MD_BLOCK_H => "h",
        c.MD_BLOCK_CODE => "code",
        c.MD_BLOCK_HTML => "html",
        c.MD_BLOCK_P => "p",
        c.MD_BLOCK_TABLE => "table",
        c.MD_BLOCK_THEAD => "thead",
        c.MD_BLOCK_TBODY => "tbody",
        c.MD_BLOCK_TR => "tr",
        c.MD_BLOCK_TH => "th",
        c.MD_BLOCK_TD => "td",
        c.MD_BLOCK_FOOTNOTE_DEF_SECTION => "footnote_def_section",
        c.MD_BLOCK_FOOTNOTE_DEF => "footnote_def",
        c.MD_BLOCK_ADMONITION => "admonition",
        c.MD_BLOCK_BLANK => "blank",
        else => "unknown",
    };
}

fn spanTypeName(span_type: c.MD_SPANTYPE) [:0]const u8 {
    return switch (span_type) {
        c.MD_SPAN_EM => "em",
        c.MD_SPAN_STRONG => "strong",
        c.MD_SPAN_A => "a",
        c.MD_SPAN_IMG => "img",
        c.MD_SPAN_CODE => "code",
        c.MD_SPAN_INS => "ins",
        c.MD_SPAN_DEL => "del",
        c.MD_SPAN_LATEXMATH => "latexmath",
        c.MD_SPAN_LATEXMATH_DISPLAY => "latexmath_display",
        c.MD_SPAN_WIKILINK => "wikilink",
        c.MD_SPAN_U => "u",
        c.MD_SPAN_SPOILER => "spoiler",
        c.MD_SPAN_SUPERSCRIPT => "superscript",
        c.MD_SPAN_SUBSCRIPT => "subscript",
        c.MD_SPAN_FOOTNOTE_REF => "footnote_ref",
        c.MD_SPAN_MARK => "mark",
        else => "unknown",
    };
}

fn textTypeName(text_type: c.MD_TEXTTYPE) [:0]const u8 {
    return switch (text_type) {
        c.MD_TEXT_NORMAL => "normal",
        c.MD_TEXT_NULLCHAR => "nullchar",
        c.MD_TEXT_BR => "br",
        c.MD_TEXT_SOFTBR => "softbr",
        c.MD_TEXT_ENTITY => "entity",
        c.MD_TEXT_CODE => "code",
        c.MD_TEXT_HTML => "html",
        c.MD_TEXT_LATEXMATH => "latexmath",
        else => "unknown",
    };
}

fn alignmentName(alignment: c.MD_ALIGN) [:0]const u8 {
    return switch (alignment) {
        c.MD_ALIGN_DEFAULT => "default",
        c.MD_ALIGN_LEFT => "left",
        c.MD_ALIGN_CENTER => "center",
        c.MD_ALIGN_RIGHT => "right",
        else => "unknown",
    };
}

fn pushBlockDetail(lua: *Lua, block_type: c.MD_BLOCKTYPE, detail: ?*anyopaque) void {
    if (detail == null) {
        lua.pushNil();
        return;
    }

    switch (block_type) {
        c.MD_BLOCK_UL => {
            const value: *const c.MD_BLOCK_UL_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableBoolean(lua, -1, "is_tight", value.is_tight != 0);
            setCharField(lua, -1, "mark", value.mark);
        },
        c.MD_BLOCK_OL => {
            const value: *const c.MD_BLOCK_OL_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableInteger(lua, -1, "start", @intCast(value.start));
            luax.setTableBoolean(lua, -1, "is_tight", value.is_tight != 0);
            setCharField(lua, -1, "mark_delimiter", value.mark_delimiter);
        },
        c.MD_BLOCK_LI => {
            const value: *const c.MD_BLOCK_LI_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableBoolean(lua, -1, "is_task", value.is_task != 0);
            setCharField(lua, -1, "task_mark", value.task_mark);
            luax.setTableInteger(lua, -1, "task_mark_offset", @intCast(value.task_mark_offset));
        },
        c.MD_BLOCK_H => {
            const value: *const c.MD_BLOCK_H_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableInteger(lua, -1, "level", @intCast(value.level));
        },
        c.MD_BLOCK_CODE => {
            const value: *const c.MD_BLOCK_CODE_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            setAttributeField(lua, -1, "info", value.info);
            setAttributeField(lua, -1, "lang", value.lang);
            setCharField(lua, -1, "fence_char", value.fence_char);
        },
        c.MD_BLOCK_TABLE => {
            const value: *const c.MD_BLOCK_TABLE_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableInteger(lua, -1, "col_count", @intCast(value.col_count));
            luax.setTableInteger(lua, -1, "head_row_count", @intCast(value.head_row_count));
            luax.setTableInteger(lua, -1, "body_row_count", @intCast(value.body_row_count));
        },
        c.MD_BLOCK_TH, c.MD_BLOCK_TD => {
            const value: *const c.MD_BLOCK_TD_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableString(lua, -1, "align", alignmentName(value.@"align"));
        },
        c.MD_BLOCK_ADMONITION => {
            const value: *const c.MD_BLOCK_ADMONITION_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            setAttributeField(lua, -1, "type", value.type);
        },
        c.MD_BLOCK_FOOTNOTE_DEF => {
            const value: *const c.MD_BLOCK_FOOTNOTE_DEF_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableInteger(lua, -1, "id", @intCast(value.id));
            luax.setTableInteger(lua, -1, "ref_count", @intCast(value.ref_count));
            setAttributeField(lua, -1, "label", value.label);
        },
        c.MD_BLOCK_BLANK => {
            const value: *const c.MD_BLOCK_BLANK_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableInteger(lua, -1, "line_count", @intCast(value.line_count));
        },
        else => lua.pushNil(),
    }
}

fn pushSpanDetail(lua: *Lua, span_type: c.MD_SPANTYPE, detail: ?*anyopaque) void {
    if (detail == null) {
        lua.pushNil();
        return;
    }

    switch (span_type) {
        c.MD_SPAN_A => {
            const value: *const c.MD_SPAN_A_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            setAttributeField(lua, -1, "href", value.href);
            setAttributeField(lua, -1, "title", value.title);
            luax.setTableBoolean(lua, -1, "is_autolink", value.is_autolink != 0);
        },
        c.MD_SPAN_IMG => {
            const value: *const c.MD_SPAN_IMG_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            setAttributeField(lua, -1, "src", value.src);
            setAttributeField(lua, -1, "title", value.title);
        },
        c.MD_SPAN_WIKILINK => {
            const value: *const c.MD_SPAN_WIKILINK_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            setAttributeField(lua, -1, "target", value.target);
        },
        c.MD_SPAN_FOOTNOTE_REF => {
            const value: *const c.MD_SPAN_FOOTNOTE_REF_DETAIL = @ptrCast(@alignCast(detail.?));
            lua.newTable();
            luax.setTableInteger(lua, -1, "id", @intCast(value.id));
            luax.setTableInteger(lua, -1, "ref_id", @intCast(value.ref_id));
            setAttributeField(lua, -1, "label", value.label);
        },
        else => lua.pushNil(),
    }
}

fn setCharField(lua: *Lua, table_index: i32, key: []const u8, value: c.MD_CHAR) void {
    var buffer = [1]u8{@intCast(value)};
    luax.setTableString(lua, table_index, key, &buffer);
}

fn setAttributeField(lua: *Lua, table_index: i32, key: []const u8, attribute: c.MD_ATTRIBUTE) void {
    if (attribute.text == null) {
        luax.setTableString(lua, table_index, key, "");
        return;
    }
    luax.setTableString(lua, table_index, key, attribute.text[0..attribute.size]);
}

fn parserFlags(lua: *Lua, options_index: i32) !c_uint {
    if (options_index > lua.getTop() or lua.typeOf(options_index) == .nil or lua.typeOf(options_index) == .none) {
        return 0;
    }
    if (lua.typeOf(options_index) != .table) {
        lua.argCheck(false, options_index, "expecting an options table");
    }

    var flags: c_uint = 0;

    luax.getTable(lua, "dialect", options_index);
    if (!lua.isNil(-1)) {
        switch (lua.typeOf(-1)) {
            .string => {
                const name = std.mem.sliceTo(lua.toString(-1) catch unreachable, 0);
                flags |= try constantByName(lua, &dialect_constants, name, options_index, "dialect");
            },
            .number => flags |= try flagsFromNumber(lua, -1, options_index, "dialect"),
            else => lua.argCheck(false, options_index, "dialect must be a string or integer"),
        }
    }
    lua.pop(1);

    luax.getTable(lua, "flags", options_index);
    if (!lua.isNil(-1)) {
        if (lua.typeOf(-1) == .number) {
            flags |= try flagsFromNumber(lua, -1, options_index, "flags");
        } else if (lua.typeOf(-1) == .table) {
            flags |= try flagsFromList(lua, -1, &flag_constants, options_index, "flags");
        } else {
            lua.argCheck(false, options_index, "flags must be an integer or an array of flag names");
        }
    }
    lua.pop(1);

    return flags;
}

fn rendererFlags(lua: *Lua, options_index: i32) !c_uint {
    if (options_index > lua.getTop() or lua.typeOf(options_index) == .nil or lua.typeOf(options_index) == .none) {
        return 0;
    }
    if (lua.typeOf(options_index) != .table) {
        lua.argCheck(false, options_index, "expecting an options table");
    }

    var flags: c_uint = 0;
    luax.getTable(lua, "renderer_flags", options_index);
    if (!lua.isNil(-1)) {
        if (lua.typeOf(-1) == .number) {
            flags |= try flagsFromNumber(lua, -1, options_index, "renderer_flags");
        } else if (lua.typeOf(-1) == .table) {
            flags |= try flagsFromList(lua, -1, &html_flag_constants, options_index, "renderer_flags");
        } else {
            lua.argCheck(false, options_index, "renderer_flags must be an integer or an array of flag names");
        }
    }
    lua.pop(1);
    return flags;
}

fn flagsFromNumber(lua: *Lua, index: i32, options_index: i32, name: []const u8) !c_uint {
    const value = lua.toInteger(index) catch {
        luaerror.argError(lua, options_index, "'{s}' must be a non-negative integer", .{name});
    };
    if (value < 0 or value > std.math.maxInt(c_uint)) {
        luaerror.argError(lua, options_index, "'{s}' is out of range", .{name});
    }
    return @intCast(value);
}

fn flagsFromList(lua: *Lua, table_index: i32, constants: []const FlagConstant, options_index: i32, name: []const u8) !c_uint {
    var flags: c_uint = 0;
    const length = lua.lenRaw(table_index);
    var index: usize = 1;
    while (index <= length) : (index += 1) {
        _ = lua.getIndexRaw(table_index, @intCast(index));
        switch (lua.typeOf(-1)) {
            .string => {
                const value = std.mem.sliceTo(lua.toString(-1) catch unreachable, 0);
                flags |= try constantByName(lua, constants, value, options_index, name);
            },
            .number => flags |= try flagsFromNumber(lua, -1, options_index, name),
            else => luaerror.argError(lua, options_index, "'{s}' entries must be strings or integers", .{name}),
        }
        lua.pop(1);
    }
    return flags;
}

fn constantByName(lua: *Lua, constants: []const FlagConstant, name: []const u8, options_index: i32, kind: []const u8) !c_uint {
    for (constants) |constant| {
        if (std.mem.eql(u8, name, constant.name)) return @intCast(constant.number);
    }
    luaerror.argError(lua, options_index, "unknown {s} '{s}'", .{ kind, name });
}

const HtmlContext = struct {
    lua: *Lua,
    callback_ref: i32 = zlua.ref_nil,
    error_ref: i32 = zlua.ref_nil,
    aborted: bool = false,
    buffer: ?*zlua.Buffer = null,

    fn deinit(self: *HtmlContext) void {
        self.lua.unref(zlua.registry_index, self.callback_ref);
        self.lua.unref(zlua.registry_index, self.error_ref);
    }
};

fn html(lua: *Lua) !i32 {
    const data = lua.checkString(1);
    return htmlData(lua, data, 2, 3);
}

fn html_file(lua: *Lua) !i32 {
    const path = filesystem.get_path_index(lua, 1) catch |err|
        return luaerror.raiseOrReturnLast(lua, err, .@"return");
    const data = file_reader.readAll(allocator, path) catch |err|
        return luaerror.ret(lua, "could not read '{s}': {s}", .{ path, @errorName(err) });
    defer allocator.free(data);
    return htmlData(lua, data, 2, 3);
}

fn htmlData(lua: *Lua, data: []const u8, callback_index: i32, options_index: i32) !i32 {
    if (data.len > std.math.maxInt(c.MD_SIZE)) {
        return luaerror.ret(lua, "markdown input is too large", .{});
    }

    const second_type = lua.typeOf(callback_index);
    var has_callback = false;
    var actual_options_index = options_index;

    switch (second_type) {
        .function => has_callback = true,
        .table => actual_options_index = callback_index,
        .nil, .none => {
            if (options_index <= lua.getTop() and lua.typeOf(options_index) == .table) {
                actual_options_index = options_index;
            }
        },
        else => lua.argCheck(false, callback_index, "expecting an output callback, options table, or nil"),
    }

    const parser_flags = try parserFlags(lua, actual_options_index);
    const render_flags = try rendererFlags(lua, actual_options_index);

    var context = HtmlContext{ .lua = lua };
    defer context.deinit();

    var buffer: zlua.Buffer = undefined;
    if (has_callback) {
        lua.pushValue(callback_index);
        context.callback_ref = lua.ref(zlua.registry_index);
    } else {
        buffer.init(lua);
        context.buffer = &buffer;
    }

    const result = c.md_html(
        @ptrCast(data.ptr),
        @intCast(data.len),
        htmlOutput,
        &context,
        parser_flags,
        render_flags,
    );

    if (context.error_ref != zlua.ref_nil) {
        if (!has_callback) {
            buffer.pushResult();
            lua.pop(1);
        }
        _ = lua.getIndexRaw(zlua.registry_index, context.error_ref);
        lua.raiseError();
    }

    if (result != 0) {
        if (!has_callback) {
            buffer.pushResult();
            lua.pop(1);
        }
        return luaerror.ret(lua, "markdown HTML rendering failed", .{});
    }

    if (has_callback) {
        lua.pushBoolean(!context.aborted);
        return 1;
    }

    buffer.pushResult();
    return 1;
}

fn htmlOutput(output: [*c]const c.MD_CHAR, size: c.MD_SIZE, userdata: ?*anyopaque) callconv(.c) void {
    const context: *HtmlContext = @ptrCast(@alignCast(userdata.?));
    if (context.aborted or output == null) return;

    const chunk = output[0..size];
    if (context.buffer) |buffer| {
        buffer.addString(chunk);
        return;
    }

    const lua = context.lua;
    const top = lua.getTop();
    defer lua.setTop(top);

    _ = lua.getIndexRaw(zlua.registry_index, context.callback_ref);
    _ = lua.pushString(chunk);
    lua.protectedCall(.{ .args = 1, .results = 1 }) catch {
        context.error_ref = lua.ref(zlua.registry_index);
        context.aborted = true;
        return;
    };

    if (lua.typeOf(-1) == .boolean and !lua.toBoolean(-1)) {
        context.aborted = true;
    }
}
