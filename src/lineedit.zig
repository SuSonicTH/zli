//! Terminal independent line editor used by the `readline` binding.
//!
//! The editor owns the input buffer, cursor, history navigation, multiline
//! handling, completion cycling and rendering layout. All terminal access goes
//! through `Backend`, which makes the state machine testable with a virtual
//! screen.

const std = @import("std");
const width = @import("term_width.zig");
const history = @import("history.zig");

pub const Size = struct { rows: usize, columns: usize };

pub const KeyCode = union(enum) {
    char: u21,
    enter,
    backspace,
    delete,
    left,
    right,
    up,
    down,
    home,
    end,
    tab,
    page_up,
    page_down,
    esc,
    insert,
    f: u8,
    null_key,
};

/// Translate a raw ASCII control byte (as delivered by the Windows console)
/// into the key the editor understands. Returns null for unrelated codes.
pub fn controlCodeKey(cp: u21) ?KeyCode {
    return switch (cp) {
        0x00 => .{ .char = ' ' },
        0x01...0x07, 0x0b, 0x0c, 0x0e...0x1a => .{ .char = @as(u21, 'a') + (cp - 1) },
        0x08 => .backspace,
        0x09 => .tab,
        0x0a, 0x0d => .enter,
        0x1b => .esc,
        0x1c...0x1f => .{ .char = @as(u21, '4') + (cp - 0x1c) },
        else => null,
    };
}

pub const Key = struct {
    code: KeyCode,
    shift: bool = false,
    control: bool = false,
    alt: bool = false,
};

/// Normalise a key carrying a raw ASCII control byte (Windows console) to the
/// equivalent editor key.  Control is cleared for keys that already encode
/// their meaning (Backspace, Tab, Esc) so they reach the normal handlers.
pub fn applyControlCode(key: Key) Key {
    if (!key.control) return key;
    switch (key.code) {
        .char => |cp| {
            const normalised = controlCodeKey(cp) orelse return key;
            var result = key;
            result.code = normalised;
            switch (normalised) {
                .backspace, .tab, .esc => result.control = false,
                else => {},
            }
            return result;
        },
        else => return key,
    }
}

pub const Event = union(enum) {
    key: Key,
    resize: Size,
    paste: []const u8,
    other,
};

pub const Cursor = struct { row: usize, column: usize };

pub const PromptStyle = enum { normal, multiline, none };

pub const Backend = struct {
    ctx: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        size: *const fn (ctx: *anyopaque) Size,
        cursorPosition: *const fn (ctx: *anyopaque) anyerror!Cursor,
        write: *const fn (ctx: *anyopaque, bytes: []const u8) anyerror!void,
        moveTo: *const fn (ctx: *anyopaque, row: usize, column: usize) anyerror!void,
        clearLine: *const fn (ctx: *anyopaque) anyerror!void,
        clearScreen: *const fn (ctx: *anyopaque) anyerror!void,
        hideCursor: *const fn (ctx: *anyopaque) anyerror!void,
        showCursor: *const fn (ctx: *anyopaque) anyerror!void,
        promptStyle: *const fn (ctx: *anyopaque, style: PromptStyle) anyerror!void,
        flush: *const fn (ctx: *anyopaque) anyerror!void,
        readEvent: *const fn (ctx: *anyopaque) anyerror!?Event,
        scrollUp: *const fn (ctx: *anyopaque, rows: usize, count: usize) anyerror!void,
    };
};

pub const MultilineHook = struct {
    ctx: *anyopaque,
    call: *const fn (ctx: *anyopaque, buffer: []const u8) anyerror!bool,
};

pub const Completion = struct {
    /// Byte offsets into the edit buffer (0 based, end exclusive).
    start: usize,
    end: usize,
    /// Owned by the editor after the callback returns. Each string and the
    /// slice itself must be allocated with the allocator passed to the hook.
    candidates: []const []const u8,
};

pub const CompleteHook = struct {
    ctx: *anyopaque,
    call: *const fn (ctx: *anyopaque, buffer: []const u8, cursor: usize, allocator: std.mem.Allocator) anyerror!?Completion,
};

pub const Options = struct {
    prompt: []const u8 = "> ",
    continuation: []const u8 = ">> ",
    initial: []const u8 = "",
    multiline: ?MultilineHook = null,
    complete: ?CompleteHook = null,
    history: ?*history.History = null,
    multiline_color: bool = true,
    /// Enter submits instead of inserting a newline.  The line editor's
    /// historical behaviour stays the default so readline is unchanged.
    submit_on_enter: bool = false,
    /// Alt+Enter (or Ctrl+Enter, which terminals encode the same way) inserts
    /// a newline instead of submitting.
    alt_enter_newline: bool = false,
    /// Strip newlines from initial text and pasted text, and never insert one
    /// from a key.
    single_line: bool = false,
    /// Maximum number of codepoints accepted while editing.
    max_length: ?usize = null,
    /// Echo every codepoint as this mask character instead of the real text.
    mask: ?u21 = null,
};

pub const Result = union(enum) {
    line: []u8,
    eof,
    abort,
};

const Prefix = enum { prompt, continuation, indent, cont_indent };

const Row = struct {
    start: usize,
    end: usize,
    prefix: Prefix,
};

pub const Action = enum { continue_editing, submit, abort, eof };

const CompletionState = struct {
    start: usize,
    end: usize,
    index: usize,
};

const SearchState = struct {
    query: std.ArrayList(u8) = .empty,
    saved: std.ArrayList(u8) = .empty,
    match_index: ?usize = null,
};

pub const Editor = struct {
    allocator: std.mem.Allocator,
    backend: Backend,
    options: Options,

    buffer: std.ArrayList(u8) = .empty,
    cursor: usize = 0,
    goal: ?usize = null,
    kill_buffer: std.ArrayList(u8) = .empty,
    draft: std.ArrayList(u8) = .empty,
    history_index: usize = 0,
    direct: bool = false,

    size: Size = .{ .rows = 24, .columns = 80 },
    anchor_row: usize = 0,
    rows: std.ArrayList(Row) = .empty,
    top: usize = 0,
    last_rows: usize = 0,
    prompt_scratch: std.ArrayList(u8) = .empty,

    completion: ?CompletionState = null,
    candidates: std.ArrayList([]u8) = .empty,
    search: ?SearchState = null,
    mask_scratch: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, backend: Backend, options: Options) Editor {
        return .{ .allocator = allocator, .backend = backend, .options = options };
    }

    pub fn deinit(self: *Editor) void {
        self.buffer.deinit(self.allocator);
        self.kill_buffer.deinit(self.allocator);
        self.draft.deinit(self.allocator);
        self.rows.deinit(self.allocator);
        self.prompt_scratch.deinit(self.allocator);
        self.mask_scratch.deinit(self.allocator);
        self.clearCandidates();
        self.candidates.deinit(self.allocator);
        if (self.search) |*search| {
            search.query.deinit(self.allocator);
            search.saved.deinit(self.allocator);
        }
    }

    /// Prepare the editor for externally driven rendering.  This performs the
    /// one-time setup that `run()` normally does, without reading events or
    /// touching the terminal.
    pub fn begin(self: *Editor, size: Size) !void {
        try self.appendSanitised(self.options.initial);
        self.applyInitialLimit();
        self.cursor = self.buffer.items.len;
        self.history_index = if (self.options.history) |h| h.count() else 0;
        self.size = size;
        self.anchor_row = 0;
    }

    pub fn feedKey(self: *Editor, key: Key) !Action {
        return self.handleKey(key);
    }

    pub fn feedPaste(self: *Editor, text: []const u8) !void {
        self.clearCompletion();
        self.exitSearch(false);
        try self.insertPaste(text);
    }

    pub fn renderFrame(self: *Editor) !void {
        try self.render();
    }

    pub fn textValue(self: *const Editor) []const u8 {
        return self.buffer.items;
    }

    pub fn textLength(self: *const Editor) usize {
        return self.buffer.items.len;
    }

    pub fn setSize(self: *Editor, size: Size) void {
        self.size = size;
    }

    pub fn setText(self: *Editor, text: []const u8) !void {
        self.buffer.clearRetainingCapacity();
        self.cursor = 0;
        self.goal = null;
        self.top = 0;
        try self.appendSanitised(text);
        self.applyInitialLimit();
        self.cursor = self.buffer.items.len;
    }

    fn applyInitialLimit(self: *Editor) void {
        const limit = self.options.max_length orelse return;
        var index: usize = 0;
        var count: usize = 0;
        while (index < self.buffer.items.len and count < limit) {
            index = width.nextBoundary(self.buffer.items, index);
            count += 1;
        }
        if (index < self.buffer.items.len) self.buffer.shrinkRetainingCapacity(index);
    }

    pub fn run(self: *Editor) !Result {
        try self.appendSanitised(self.options.initial);
        self.cursor = self.buffer.items.len;
        self.history_index = if (self.options.history) |h| h.count() else 0;
        self.size = self.backend.vtable.size(self.backend.ctx);
        if (self.backend.vtable.cursorPosition(self.backend.ctx)) |position| {
            self.anchor_row = @min(position.row, self.size.rows -| 1);
        } else |_| {
            // Without a CPR answer, edit on the last row so we never overwrite
            // earlier output.  The edit area is one row high and scrolls.
            self.anchor_row = self.size.rows -| 1;
        }

        while (true) {
            try self.render();

            const event = try self.backend.vtable.readEvent(self.backend.ctx) orelse
                return self.finish(.eof);

            switch (event) {
                .key => |key| {
                    const action = try self.handleKey(key);
                    switch (action) {
                        .continue_editing => {},
                        .submit => return self.finish(.line),
                        .abort => return self.finish(.abort),
                        .eof => return self.finish(.eof),
                    }
                },
                .resize => |event_size| {
                    var size = event_size;
                    if (size.rows == 0 or size.columns == 0) {
                        size = self.backend.vtable.size(self.backend.ctx);
                    }
                    const old_cursor_row = self.cursorRow();
                    self.size = size;
                    if (self.backend.vtable.cursorPosition(self.backend.ctx)) |position| {
                        const prompt_row = position.row -| (old_cursor_row -| self.top);
                        self.anchor_row = @min(prompt_row, size.rows -| 1);
                    } else |_| {
                        self.anchor_row = size.rows -| 1;
                    }
                },
                .paste => |text| {
                    self.clearCompletion();
                    self.exitSearch(false);
                    try self.insertPaste(text);
                },
                .other => {},
            }
        }
    }

    // -- key handling -----------------------------------------------------

    fn handleKey(self: *Editor, key: Key) !Action {
        if (self.completion != null and !(key.code == .tab)) {
            self.clearCompletion();
        }

        if (key.control and key.shift) {
            switch (key.code) {
                .char => |cp| if (cp == 'x' or cp == 'X') {
                    self.toggleDirect();
                    return .continue_editing;
                },
                else => {},
            }
        }

        if (key.alt) {
            switch (key.code) {
                .char => |cp| switch (cp) {
                    'x', 'X' => {
                        self.toggleDirect();
                        return .continue_editing;
                    },
                    '\r', '\n' => {
                        if (self.options.alt_enter_newline and !self.options.single_line) {
                            try self.insertByte('\n');
                            return .continue_editing;
                        }
                        return .submit;
                    },
                    0x7f, 0x08 => {
                        try self.killWordLeft();
                        return .continue_editing;
                    },
                    'b', 'B' => {
                        self.cursor = self.wordLeft(self.cursor);
                        self.goal = null;
                        return .continue_editing;
                    },
                    'f', 'F' => {
                        self.cursor = self.wordRight(self.cursor);
                        self.goal = null;
                        return .continue_editing;
                    },
                    'd', 'D' => {
                        try self.killWordRight();
                        return .continue_editing;
                    },
                    else => {},
                },
                .enter => {
                    if (self.options.alt_enter_newline and !self.options.single_line) {
                        try self.insertByte('\n');
                        return .continue_editing;
                    }
                    return .submit;
                },
                .backspace => {
                    try self.killWordLeft();
                    return .continue_editing;
                },
                .left => {
                    self.cursor = self.wordLeft(self.cursor);
                    self.goal = null;
                    return .continue_editing;
                },
                .right => {
                    self.cursor = self.wordRight(self.cursor);
                    self.goal = null;
                    return .continue_editing;
                },
                .up => {
                    self.moveVisual(-1);
                    return .continue_editing;
                },
                .down => {
                    self.moveVisual(1);
                    return .continue_editing;
                },
                else => {},
            }
        }

        if (key.control) {
            switch (key.code) {
                .char => |cp| {
                    switch (cp) {
                        'a' => {
                            self.cursor = self.lineStart(self.cursor);
                            self.goal = null;
                        },
                        'b' => self.moveChar(-1),
                        'c', 'g' => return .abort,
                        'd' => {
                            if (self.buffer.items.len == 0) return .eof;
                            if (self.cursor < self.buffer.items.len) self.deleteRight();
                        },
                        'e' => {
                            self.cursor = self.lineEnd(self.cursor);
                            self.goal = null;
                        },
                        'f' => self.moveChar(1),
                        'h' => self.deleteLeft(),
                        'i' => try self.handleTab(),
                        'k' => try self.killLineEnd(),
                        'l' => {
                            try self.backend.vtable.clearScreen(self.backend.ctx);
                            self.anchor_row = 0;
                            self.top = 0;
                            self.last_rows = 0;
                        },
                        'n' => {
                            if (!try self.historyDown()) self.moveVisual(1);
                        },
                        'p' => {
                            if (!try self.historyUp()) self.moveVisual(-1);
                        },
                        'r' => {
                            try self.startSearch();
                        },
                        'u' => try self.killLineStart(),
                        'w' => try self.killWordLeft(),
                        'y' => try self.yank(),
                        else => {},
                    }
                },
                .left => {
                    self.cursor = self.wordLeft(self.cursor);
                    self.goal = null;
                },
                .right => {
                    self.cursor = self.wordRight(self.cursor);
                    self.goal = null;
                },
                .up => self.moveVisual(-1),
                .down => self.moveVisual(1),
                .home => {
                    self.cursor = 0;
                    self.goal = null;
                },
                .end => {
                    self.cursor = self.buffer.items.len;
                    self.goal = null;
                },
                .enter => {
                    if (self.options.alt_enter_newline and !self.options.single_line) {
                        try self.insertByte('\n');
                    } else {
                        return .submit;
                    }
                },
                .tab => try self.handleTab(),
                .backspace => self.deleteLeft(),
                else => {},
            }
            return .continue_editing;
        }

        switch (key.code) {
            .char => |cp| {
                if (self.search != null) {
                    if (cp >= 0x20 and cp != 0x7f) {
                        try self.searchInput(cp);
                    }
                    return .continue_editing;
                }
                if (cp == '\r' or cp == '\n') return self.handleEnter();
                if (cp < 0x20 or cp == 0x7f) return .continue_editing;
                self.clearCompletion();
                try self.insertCodepoint(cp);
            },
            .enter => return self.handleEnter(),
            .backspace => {
                if (self.search != null) {
                    try self.searchBackspace();
                    return .continue_editing;
                }
                self.clearCompletion();
                self.deleteLeft();
            },
            .delete => {
                self.clearCompletion();
                self.deleteRight();
            },
            .left => self.moveChar(-1),
            .right => self.moveChar(1),
            .home => {
                self.cursor = self.lineStart(self.cursor);
                self.goal = null;
            },
            .end => {
                self.cursor = self.lineEnd(self.cursor);
                self.goal = null;
            },
            .up => {
                if (self.search != null) {
                    try self.searchNext();
                } else if (self.canMoveVisual(-1)) {
                    self.moveVisual(-1);
                } else {
                    _ = try self.historyUp();
                }
            },
            .down => {
                if (self.search != null) {
                    self.searchCancel();
                } else if (self.canMoveVisual(1)) {
                    self.moveVisual(1);
                } else {
                    _ = try self.historyDown();
                }
            },
            .tab => try self.handleTab(),
            .esc => {
                if (self.search != null) self.searchCancel();
            },
            .page_up, .page_down, .insert, .f, .null_key => {},
        }
        return .continue_editing;
    }

    fn handleEnter(self: *Editor) !Action {
        if (self.search != null) {
            self.exitSearch(true);
        }
        if (self.options.single_line) return .submit;
        if (self.options.submit_on_enter) return .submit;
        if (self.direct) {
            try self.insertByte('\n');
            return .continue_editing;
        }
        if (self.options.multiline) |hook| {
            const complete = hook.call(hook.ctx, self.buffer.items) catch |err| return err;
            if (!complete) {
                try self.insertByte('\n');
                return .continue_editing;
            }
        }
        return .submit;
    }

    fn toggleDirect(self: *Editor) void {
        self.direct = !self.direct;
    }

    // -- buffer editing ---------------------------------------------------

    fn codepointCount(text: []const u8) usize {
        var count: usize = 0;
        var i: usize = 0;
        while (i < text.len) {
            i = width.nextBoundary(text, i);
            count += 1;
        }
        return count;
    }

    fn atMaxLength(self: *const Editor) bool {
        const limit = self.options.max_length orelse return false;
        return codepointCount(self.buffer.items) >= limit;
    }

    fn insertCodepoint(self: *Editor, cp: u21) !void {
        if (self.atMaxLength()) return;
        var encoded: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(cp, &encoded) catch return;
        try self.buffer.replaceRange(self.allocator, self.cursor, 0, encoded[0..len]);
        self.cursor += len;
        self.goal = null;
    }

    fn insertByte(self: *Editor, byte: u8) !void {
        if (self.atMaxLength()) return;
        try self.buffer.replaceRange(self.allocator, self.cursor, 0, &.{byte});
        self.cursor += 1;
        self.goal = null;
    }

    fn insertSlice(self: *Editor, bytes: []const u8) !void {
        var end = bytes.len;
        if (self.options.max_length) |limit| {
            const remaining = limit -| codepointCount(self.buffer.items);
            var i: usize = 0;
            var count: usize = 0;
            while (i < bytes.len and count < remaining) {
                i = width.nextBoundary(bytes, i);
                count += 1;
            }
            end = i;
        }
        if (end == 0) return;
        try self.buffer.replaceRange(self.allocator, self.cursor, 0, bytes[0..end]);
        self.cursor += end;
        self.goal = null;
    }

    /// Normalise control characters and tabs for the editor's layout.
    fn sanitise(self: *Editor, text: []const u8, clean: *std.ArrayList(u8)) !void {
        var i: usize = 0;
        while (i < text.len) {
            const b = text[i];
            if (b == '\r') {
                if (i + 1 < text.len and text[i + 1] == '\n') i += 1;
                if (self.options.single_line) {
                    try clean.append(self.allocator, ' ');
                } else {
                    try clean.append(self.allocator, '\n');
                }
            } else if (b == '\t') {
                try clean.appendSlice(self.allocator, "    ");
            } else if (b == '\n') {
                if (self.options.single_line) {
                    try clean.append(self.allocator, ' ');
                } else {
                    try clean.append(self.allocator, '\n');
                }
            } else if (b >= 0x20 and b != 0x7f) {
                try clean.append(self.allocator, b);
            }
            i += 1;
        }
    }

    /// Append text with control characters and tabs normalised for the
    /// editor's one-column-per-character layout.
    fn appendSanitised(self: *Editor, text: []const u8) !void {
        var clean: std.ArrayList(u8) = .empty;
        defer clean.deinit(self.allocator);
        try self.sanitise(text, &clean);
        if (clean.items.len != 0) try self.buffer.appendSlice(self.allocator, clean.items);
    }

    fn insertPaste(self: *Editor, text: []const u8) !void {
        var clean: std.ArrayList(u8) = .empty;
        defer clean.deinit(self.allocator);
        try self.sanitise(text, &clean);
        if (clean.items.len != 0) try self.insertSlice(clean.items);
    }

    fn deleteLeft(self: *Editor) void {
        if (self.cursor == 0) return;
        const start = width.prevBoundary(self.buffer.items, self.cursor);
        self.buffer.replaceRangeAssumeCapacity(start, self.cursor - start, &.{});
        self.cursor = start;
        self.goal = null;
    }

    fn deleteRight(self: *Editor) void {
        if (self.cursor >= self.buffer.items.len) return;
        const end = width.nextBoundary(self.buffer.items, self.cursor);
        self.buffer.replaceRangeAssumeCapacity(self.cursor, end - self.cursor, &.{});
        self.goal = null;
    }

    fn moveChar(self: *Editor, direction: i8) void {
        if (direction < 0) {
            self.cursor = width.prevBoundary(self.buffer.items, self.cursor);
        } else {
            self.cursor = width.nextBoundary(self.buffer.items, self.cursor);
        }
        self.goal = null;
    }

    fn lineStart(self: *Editor, from: usize) usize {
        const bytes = self.buffer.items;
        const bounded = @min(from, bytes.len);
        var i = bounded;
        while (i > 0) : (i -= 1) {
            if (bytes[i - 1] == '\n') return i;
        }
        return 0;
    }

    fn lineEnd(self: *Editor, from: usize) usize {
        const bytes = self.buffer.items;
        const bounded = @min(from, bytes.len);
        if (std.mem.indexOfScalarPos(u8, bytes, bounded, '\n')) |index| return index;
        return bytes.len;
    }

    fn isSpace(cp: u21) bool {
        return cp == ' ' or cp == '\t' or cp == '\n';
    }

    fn isWord(cp: u21) bool {
        if (cp >= 0x80) return true;
        return std.ascii.isAlphanumeric(@intCast(cp)) or cp == '_';
    }

    fn wordLeft(self: *Editor, from: usize) usize {
        const bytes = self.buffer.items;
        var i = @min(from, bytes.len);
        while (i > 0) {
            const previous = width.prevBoundary(bytes, i);
            const decoded = width.decode(bytes, previous);
            if (!isSpace(decoded.codepoint)) break;
            i = previous;
        }
        while (i > 0) {
            const previous = width.prevBoundary(bytes, i);
            const decoded = width.decode(bytes, previous);
            if (!isWord(decoded.codepoint)) break;
            i = previous;
        }
        return i;
    }

    fn wordRight(self: *Editor, from: usize) usize {
        const bytes = self.buffer.items;
        var i = @min(from, bytes.len);
        while (i < bytes.len) {
            const decoded = width.decode(bytes, i);
            if (!isSpace(decoded.codepoint)) break;
            i += decoded.len;
        }
        while (i < bytes.len) {
            const decoded = width.decode(bytes, i);
            if (!isWord(decoded.codepoint)) break;
            i += decoded.len;
        }
        return i;
    }

    fn setKill(self: *Editor, start: usize, end: usize) !void {
        self.kill_buffer.clearRetainingCapacity();
        if (end <= start) return;
        try self.kill_buffer.appendSlice(self.allocator, self.buffer.items[start..end]);
    }

    fn killRange(self: *Editor, start: usize, end: usize) !void {
        try self.setKill(start, end);
        self.buffer.replaceRangeAssumeCapacity(start, end - start, &.{});
        self.cursor = start;
        self.goal = null;
    }

    fn killLineEnd(self: *Editor) !void {
        const end = self.lineEnd(self.cursor);
        if (end > self.cursor) try self.killRange(self.cursor, end);
    }

    fn killLineStart(self: *Editor) !void {
        const start = self.lineStart(self.cursor);
        if (self.cursor > start) try self.killRange(start, self.cursor);
    }

    fn killWordLeft(self: *Editor) !void {
        const start = self.wordLeft(self.cursor);
        if (self.cursor > start) try self.killRange(start, self.cursor);
    }

    fn killWordRight(self: *Editor) !void {
        const end = self.wordRight(self.cursor);
        if (end > self.cursor) try self.killRange(self.cursor, end);
    }

    fn yank(self: *Editor) !void {
        if (self.kill_buffer.items.len == 0) return;
        try self.insertSlice(self.kill_buffer.items);
    }

    // -- history ----------------------------------------------------------

    fn setBuffer(self: *Editor, text: []const u8) !void {
        self.buffer.clearRetainingCapacity();
        try self.buffer.appendSlice(self.allocator, text);
        self.cursor = self.buffer.items.len;
        self.goal = null;
    }

    fn historyUp(self: *Editor) !bool {
        const h = self.options.history orelse return false;
        if (self.history_index == 0) return false;
        if (self.history_index == h.count()) {
            self.draft.clearRetainingCapacity();
            try self.draft.appendSlice(self.allocator, self.buffer.items);
        }
        self.history_index -= 1;
        if (h.get(self.history_index)) |entry| try self.setBuffer(entry);
        return true;
    }

    fn historyDown(self: *Editor) !bool {
        const h = self.options.history orelse return false;
        if (self.history_index >= h.count()) return false;
        self.history_index += 1;
        if (self.history_index == h.count()) {
            const draft = self.draft.items;
            try self.setBuffer(draft);
        } else if (h.get(self.history_index)) |entry| {
            try self.setBuffer(entry);
        }
        return true;
    }

    fn canMoveVisual(self: *Editor, direction: i8) bool {
        self.ensureLayout() catch return false;
        const row = self.cursorRow();
        return if (direction < 0) row > 0 else row + 1 < self.rows.items.len;
    }

    fn moveVisual(self: *Editor, direction: i8) void {
        self.ensureLayout() catch return;
        const current_row = self.cursorRow();
        const row = self.rows.items[current_row];
        const prefix_width = self.prefixWidth(row.prefix);
        const text_column = self.cursorColumn() -| prefix_width;
        const goal = self.goal orelse text_column;
        self.goal = goal;

        const target_row: usize = if (direction < 0)
            (if (current_row == 0) 0 else current_row - 1)
        else
            @min(current_row + 1, self.rows.items.len - 1);

        if (target_row == current_row) return;

        const target = self.rows.items[target_row];
        self.cursor = width.byteAtColumn(self.buffer.items, target.start, target.end, goal);
    }

    // -- search -----------------------------------------------------------

    fn startSearch(self: *Editor) !void {
        if (self.search == null) {
            self.search = .{};
            self.search.?.saved.clearRetainingCapacity();
            try self.search.?.saved.appendSlice(self.allocator, self.buffer.items);
        }
        self.refreshSearchPrompt();
        try self.searchNext();
    }

    fn refreshSearchPrompt(self: *Editor) void {
        const search = if (self.search) |*value| value else return;
        self.prompt_scratch.clearRetainingCapacity();
        self.prompt_scratch.appendSlice(self.allocator, "(reverse-i-search)") catch {};
        self.prompt_scratch.appendSlice(self.allocator, search.query.items) catch {};
        self.prompt_scratch.appendSlice(self.allocator, "> ") catch {};
    }

    fn searchNext(self: *Editor) !void {
        if (self.search == null) return;
        const search = &self.search.?;
        const h = self.options.history orelse return;
        if (search.query.items.len == 0) return;

        const start = if (search.match_index) |index| (if (index == 0) return else index - 1) else h.count() -| 1;
        var index: usize = @min(start, h.count() -| 1);
        while (true) {
            if (h.get(index)) |entry| {
                if (containsIgnoreCase(entry, search.query.items)) {
                    search.match_index = index;
                    try self.setBuffer(entry);
                    return;
                }
            }
            if (index == 0) break;
            index -= 1;
        }
    }

    fn searchInput(self: *Editor, cp: u21) !void {
        if (self.search == null) return;
        const search = &self.search.?;
        var encoded: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(cp, &encoded) catch return;
        try search.query.appendSlice(self.allocator, encoded[0..len]);
        search.match_index = null;
        self.refreshSearchPrompt();
        try self.searchNext();
    }

    fn searchBackspace(self: *Editor) !void {
        if (self.search == null) return;
        const search = &self.search.?;
        if (search.query.items.len == 0) {
            self.searchCancel();
            return;
        }
        const start = width.prevBoundary(search.query.items, search.query.items.len);
        search.query.shrinkRetainingCapacity(start);
        search.match_index = null;
        self.refreshSearchPrompt();
        try self.searchNext();
    }

    fn searchCancel(self: *Editor) void {
        if (self.search) |*search| {
            self.buffer.clearRetainingCapacity();
            self.buffer.appendSlice(self.allocator, search.saved.items) catch {};
            self.cursor = self.buffer.items.len;
            self.goal = null;
            search.query.deinit(self.allocator);
            search.saved.deinit(self.allocator);
            self.search = null;
        }
    }

    fn exitSearch(self: *Editor, keep: bool) void {
        if (self.search) |*search| {
            if (!keep) {
                self.buffer.clearRetainingCapacity();
                self.buffer.appendSlice(self.allocator, search.saved.items) catch {};
                self.cursor = self.buffer.items.len;
                self.goal = null;
            }
            search.query.deinit(self.allocator);
            search.saved.deinit(self.allocator);
            self.search = null;
        }
    }

    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len == 0) return true;
        if (needle.len > haystack.len) return false;
        var i: usize = 0;
        while (i + needle.len <= haystack.len) : (i += 1) {
            var match = true;
            for (needle, 0..) |ch, k| {
                if (std.ascii.toLower(haystack[i + k]) != std.ascii.toLower(ch)) {
                    match = false;
                    break;
                }
            }
            if (match) return true;
        }
        return false;
    }

    // -- completion -------------------------------------------------------

    fn clearCandidates(self: *Editor) void {
        for (self.candidates.items) |candidate| self.allocator.free(candidate);
        self.candidates.clearRetainingCapacity();
    }

    fn clearCompletion(self: *Editor) void {
        self.completion = null;
        self.clearCandidates();
    }

    fn handleTab(self: *Editor) !void {
        if (self.search != null) return;

        if (self.completion != null and self.candidates.items.len > 0) {
            const state = &self.completion.?;
            state.index = (state.index + 1) % self.candidates.items.len;
            try self.applyCandidate(state, self.candidates.items[state.index]);
            return;
        }

        const hook = self.options.complete orelse {
            try self.insertSlice("    ");
            return;
        };
        self.clearCompletion();
        const result = try hook.call(hook.ctx, self.buffer.items, self.cursor, self.allocator);
        const completion = result orelse {
            try self.insertSlice("    ");
            return;
        };
        defer {
            for (completion.candidates) |candidate| self.allocator.free(candidate);
            self.allocator.free(completion.candidates);
        }

        if (completion.candidates.len == 0) {
            try self.insertSlice("    ");
            return;
        }

        for (completion.candidates) |candidate| {
            try self.candidates.append(self.allocator, try self.allocator.dupe(u8, candidate));
        }

        var state = CompletionState{
            .start = @min(completion.start, @min(completion.end, self.buffer.items.len)),
            .end = @min(@max(completion.start, completion.end), self.buffer.items.len),
            .index = 0,
        };
        self.completion = state;
        try self.applyCandidate(&state, self.candidates.items[0]);
        self.completion = state;
    }

    fn applyCandidate(self: *Editor, state: *CompletionState, candidate: []const u8) !void {
        try self.buffer.replaceRange(self.allocator, state.start, state.end - state.start, candidate);
        self.cursor = state.start + candidate.len;
        state.end = self.cursor;
        self.goal = null;
    }

    // -- layout and rendering ---------------------------------------------

    fn activePrompt(self: *const Editor) []const u8 {
        if (self.search != null) return self.prompt_scratch.items;
        return self.options.prompt;
    }

    fn isMultiline(self: *const Editor) bool {
        return self.direct or std.mem.indexOfScalar(u8, self.buffer.items, '\n') != null;
    }

    fn prefixWidth(self: *const Editor, prefix: Prefix) usize {
        return switch (prefix) {
            .prompt, .indent => width.visibleWidth(self.activePrompt()),
            .continuation, .cont_indent => width.visibleWidth(self.options.continuation),
        };
    }

    fn prefixText(self: *const Editor, prefix: Prefix) []const u8 {
        return switch (prefix) {
            .prompt, .indent => self.activePrompt(),
            .continuation, .cont_indent => self.options.continuation,
        };
    }

    fn ensureLayout(self: *Editor) !void {
        try self.buildRows();
    }

    fn buildRows(self: *Editor) !void {
        self.rows.clearRetainingCapacity();
        const columns = @max(@as(usize, 1), self.size.columns);
        const bytes = self.buffer.items;
        const multiline = self.isMultiline();

        var line_start: usize = 0;
        var line_index: usize = 0;

        while (true) {
            const line_end = std.mem.indexOfScalarPos(u8, bytes, line_start, '\n') orelse bytes.len;

            const first_prefix: Prefix = if (line_index == 0 and (self.search != null or !multiline)) .prompt else .continuation;
            const first_indent: Prefix = if (first_prefix == .prompt) .indent else .cont_indent;

            var prefix: Prefix = if (line_index == 0) first_prefix else .continuation;
            var avail = columns -| self.prefixWidth(prefix);
            if (avail == 0) avail = 1;

            var row_start = line_start;
            var column: usize = 0;
            var i = line_start;
            while (i < line_end) {
                const decoded = width.decode(bytes, i);
                if (decoded.len == 0) break;
                const cp_width = if (self.options.mask != null) 1 else width.codepointWidth(decoded.codepoint);
                if (column + cp_width > avail and column > 0) {
                    try self.rows.append(self.allocator, .{ .start = row_start, .end = i, .prefix = prefix });
                    prefix = if (line_index == 0) first_indent else .cont_indent;
                    avail = columns -| self.prefixWidth(prefix);
                    if (avail == 0) avail = 1;
                    row_start = i;
                    column = 0;
                }
                column += cp_width;
                i += decoded.len;
            }

            try self.rows.append(self.allocator, .{ .start = row_start, .end = line_end, .prefix = prefix });

            if (line_end == bytes.len) break;
            line_start = line_end + 1;
            line_index += 1;
        }
    }

    fn cursorRow(self: *const Editor) usize {
        var result: usize = 0;
        for (self.rows.items, 0..) |row, index| {
            if (self.cursor >= row.start and self.cursor <= row.end) result = index;
        }
        return result;
    }

    fn cursorColumn(self: *const Editor) usize {
        const index = self.cursorRow();
        const row = self.rows.items[index];
        if (self.options.mask != null) {
            return self.prefixWidth(row.prefix) + codepointCount(self.buffer.items[row.start..self.cursor]);
        }
        return self.prefixWidth(row.prefix) + width.visibleWidthSlice(self.buffer.items, row.start, self.cursor);
    }

    fn render(self: *Editor) !void {
        // Some terminals do not report window-only resizes, so refresh the
        // size before every frame.  The ioctl is cheap compared to a redraw.
        const current_size = self.backend.vtable.size(self.backend.ctx);
        if (current_size.rows != 0 and current_size.columns != 0) {
            self.size = current_size;
        }

        const screen_rows = @max(@as(usize, 1), self.size.rows);
        if (self.anchor_row >= screen_rows) {
            self.anchor_row = screen_rows - 1;
        }

        try self.buildRows();

        const available = screen_rows -| self.anchor_row;
        if (self.rows.items.len > available and self.anchor_row > 0) {
            const needed = self.rows.items.len - available;
            const scroll = @min(needed, self.anchor_row);
            try self.backend.vtable.scrollUp(self.backend.ctx, screen_rows, scroll);
            self.anchor_row -= scroll;
        }

        const columns = @max(@as(usize, 1), self.size.columns);
        const height = @max(@as(usize, 1), screen_rows -| self.anchor_row);
        const multiline = self.isMultiline();
        const cursor_row = self.cursorRow();

        if (cursor_row < self.top) self.top = cursor_row;
        if (cursor_row >= self.top + height) self.top = cursor_row - height + 1;
        if (self.top >= self.rows.items.len) self.top = self.rows.items.len - 1;
        // When the block shrinks, show as much of it as possible instead of
        // leaving the viewport scrolled down.
        if (self.rows.items.len <= height) {
            self.top = 0;
        } else if (self.top > self.rows.items.len - height) {
            self.top = self.rows.items.len - height;
        }

        const visible = @min(self.rows.items.len - self.top, height);
        try self.backend.vtable.hideCursor(self.backend.ctx);

        var k: usize = 0;
        while (k < visible) : (k += 1) {
            const row = self.rows.items[self.top + k];
            try self.backend.vtable.moveTo(self.backend.ctx, self.anchor_row + k, 0);
            try self.backend.vtable.clearLine(self.backend.ctx);
            const prompt_style: PromptStyle = if (self.search != null)
                .none
            else if (multiline)
                (if (self.options.multiline_color) .multiline else .none)
            else
                .normal;

            if (row.prefix == .prompt or row.prefix == .continuation) {
                try self.backend.vtable.promptStyle(self.backend.ctx, prompt_style);
                try self.backend.vtable.write(self.backend.ctx, self.prefixText(row.prefix));
                try self.backend.vtable.promptStyle(self.backend.ctx, .none);
            } else if (row.prefix == .indent or row.prefix == .cont_indent) {
                const spaces = try self.allocator.alloc(u8, self.prefixWidth(row.prefix));
                defer self.allocator.free(spaces);
                @memset(spaces, ' ');
                try self.backend.vtable.write(self.backend.ctx, spaces);
            } else {
                try self.backend.vtable.write(self.backend.ctx, self.prefixText(row.prefix));
            }
            if (self.options.mask) |mask| {
                self.mask_scratch.clearRetainingCapacity();
                var index = row.start;
                while (index < row.end) {
                    const decoded = width.decode(self.buffer.items, index);
                    if (decoded.len == 0) break;
                    var encoded: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(mask, &encoded) catch 1;
                    try self.mask_scratch.appendSlice(self.allocator, encoded[0..len]);
                    index += decoded.len;
                }
                try self.backend.vtable.write(self.backend.ctx, self.mask_scratch.items);
            } else {
                try self.backend.vtable.write(self.backend.ctx, self.buffer.items[row.start..row.end]);
            }
        }

        const stale_end = @min(self.last_rows, height);
        while (k < stale_end) : (k += 1) {
            try self.backend.vtable.moveTo(self.backend.ctx, self.anchor_row + k, 0);
            try self.backend.vtable.clearLine(self.backend.ctx);
        }
        self.last_rows = visible;

        const cursor_column = @min(self.cursorColumn(), columns - 1);
        try self.backend.vtable.moveTo(self.backend.ctx, self.anchor_row + cursor_row - self.top, cursor_column);
        try self.backend.vtable.showCursor(self.backend.ctx);
        try self.backend.vtable.flush(self.backend.ctx);
    }

    fn finish(self: *Editor, outcome: enum { line, eof, abort }) !Result {
        if (outcome == .line) {
            if (self.options.history) |h| h.add(self.buffer.items) catch {};
        }

        // Redraw once more so the complete block is visible, then leave the
        // cursor below the last visual row.  This keeps a submitted multiline
        // block on screen exactly like a recalled history entry.
        try self.render();

        const columns = @max(@as(usize, 1), self.size.columns);
        const last_row = @min(self.rows.items.len - 1, self.top + self.last_rows -| 1);
        const last = self.rows.items[last_row];
        const width_last = self.prefixWidth(last.prefix) + width.visibleWidthSlice(self.buffer.items, last.start, last.end);
        try self.backend.vtable.moveTo(self.backend.ctx, self.anchor_row + last_row - self.top, @min(width_last, columns - 1));

        try self.backend.vtable.write(self.backend.ctx, "\r\n");
        try self.backend.vtable.promptStyle(self.backend.ctx, .none);
        try self.backend.vtable.showCursor(self.backend.ctx);
        try self.backend.vtable.flush(self.backend.ctx);

        return switch (outcome) {
            .line => .{ .line = try self.allocator.dupe(u8, self.buffer.items) },
            .eof => .eof,
            .abort => .abort,
        };
    }
};

// -- tests -----------------------------------------------------------------

const TestScreen = struct {
    rows: usize = 12,
    columns: usize = 40,
    cells: [12][40]u8 = undefined,
    cursor_row: usize = 0,
    cursor_column: usize = 0,
    keys: std.ArrayList(Event) = .empty,
    key_index: usize = 0,
    normal_styled: bool = false,
    styled_any: bool = false,
    scrolls: usize = 0,
    scrolled_lines: usize = 0,
    max_move_row: usize = 0,
    shrink_rows_to: ?usize = null,
    first_move_row: ?usize = null,
    first_move_column: ?usize = null,
    last_move_row: usize = 0,
    last_move_column: usize = 0,

    fn init() TestScreen {
        var screen: TestScreen = .{};
        screen.fill(' ');
        return screen;
    }

    fn deinit(self: *TestScreen) void {
        self.keys.deinit(std.testing.allocator);
    }

    fn fill(self: *TestScreen, value: u8) void {
        for (&self.cells) |*row| @memset(row, value);
    }

    fn shiftUp(self: *TestScreen, count: usize) void {
        const amount = @min(count, self.rows);
        var index: usize = 0;
        while (index + amount < self.rows) : (index += 1) {
            self.cells[index] = self.cells[index + amount];
        }
        while (index < self.rows) : (index += 1) {
            @memset(&self.cells[index], ' ');
        }
    }

    fn scrollUp(context: *anyopaque, rows: usize, count: usize) anyerror!void {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        _ = rows;
        if (count == 0) return;
        screen.shiftUp(count);
        screen.scrolls += 1;
        screen.scrolled_lines += count;
        screen.cursor_row = screen.rows - 1;
        screen.cursor_column = 0;
    }

    fn rowText(self: *const TestScreen, row: usize) []const u8 {
        var end: usize = self.columns;
        while (end > 0 and (self.cells[row][end - 1] == ' ' or self.cells[row][end - 1] == 0)) end -= 1;
        return self.cells[row][0..end];
    }

    fn size(context: *anyopaque) Size {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        return .{ .rows = screen.rows, .columns = screen.columns };
    }

    fn cursorPosition(context: *anyopaque) anyerror!Cursor {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        return .{ .row = screen.cursor_row, .column = screen.cursor_column };
    }

    fn write(context: *anyopaque, bytes: []const u8) anyerror!void {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        for (bytes) |byte| {
            switch (byte) {
                '\r' => screen.cursor_column = 0,
                '\n' => {
                    screen.cursor_column = 0;
                    if (screen.cursor_row + 1 >= screen.rows) {
                        screen.shiftUp(1);
                        screen.cursor_row = screen.rows - 1;
                    } else {
                        screen.cursor_row += 1;
                    }
                },
                else => {
                    if (screen.cursor_row < screen.rows and screen.cursor_column < screen.columns) {
                        screen.cells[screen.cursor_row][screen.cursor_column] = byte;
                        screen.cursor_column += 1;
                    }
                },
            }
        }
    }

    fn moveTo(context: *anyopaque, row: usize, column: usize) anyerror!void {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        if (screen.first_move_row == null) {
            screen.first_move_row = row;
            screen.first_move_column = column;
        }
        screen.last_move_row = row;
        screen.last_move_column = column;
        screen.max_move_row = @max(screen.max_move_row, row);
        screen.cursor_row = @min(row, screen.rows - 1);
        screen.cursor_column = @min(column, screen.columns - 1);
    }

    fn clearLine(context: *anyopaque) anyerror!void {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        if (screen.cursor_row >= screen.rows) return;
        // Erase from the cursor cell inclusive, like EL on a deferred-wrap
        // terminal.  Writing a full row and then clearing it would lose the
        // last character.
        const start = @min(screen.cursor_column, screen.columns - 1);
        @memset(screen.cells[screen.cursor_row][start..], ' ');
    }

    fn clearScreen(context: *anyopaque) anyerror!void {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        screen.fill(' ');
        screen.cursor_row = 0;
        screen.cursor_column = 0;
    }

    fn hideCursor(context: *anyopaque) anyerror!void {
        _ = context;
    }

    fn showCursor(context: *anyopaque) anyerror!void {
        _ = context;
    }

    fn promptStyle(context: *anyopaque, style: PromptStyle) anyerror!void {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        switch (style) {
            .normal => screen.normal_styled = true,
            .multiline => screen.styled_any = true,
            .none => {},
        }
    }

    fn flush(context: *anyopaque) anyerror!void {
        _ = context;
    }

    fn readEvent(context: *anyopaque) anyerror!?Event {
        const screen: *TestScreen = @ptrCast(@alignCast(context));
        if (screen.shrink_rows_to) |rows| {
            if (rows < screen.rows) {
                screen.rows = rows;
                screen.max_move_row = 0;
            }
            screen.shrink_rows_to = null;
        }
        if (screen.key_index >= screen.keys.items.len) return null;
        defer screen.key_index += 1;
        return screen.keys.items[screen.key_index];
    }

    const vtable: Backend.VTable = .{
        .size = size,
        .cursorPosition = cursorPosition,
        .write = write,
        .moveTo = moveTo,
        .clearLine = clearLine,
        .clearScreen = clearScreen,
        .hideCursor = hideCursor,
        .showCursor = showCursor,
        .promptStyle = promptStyle,
        .flush = flush,
        .readEvent = readEvent,
        .scrollUp = scrollUp,
    };
};

fn testEditor(screen: *TestScreen, options: Options) Editor {
    return Editor.init(std.testing.allocator, .{ .ctx = screen, .vtable = &TestScreen.vtable }, options);
}

fn addKey(screen: *TestScreen, key: Key) !void {
    try screen.keys.append(std.testing.allocator, .{ .key = key });
}

fn addChar(screen: *TestScreen, cp: u21) !void {
    try addKey(screen, .{ .code = .{ .char = cp } });
}

fn expectLine(result: Result, expected: []const u8) !void {
    switch (result) {
        .line => |line| {
            defer std.testing.allocator.free(line);
            try std.testing.expectEqualStrings(expected, line);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "typing and submitting a line" {
    var screen = TestScreen.init();
    defer screen.deinit();
    try addChar(&screen, 'a');
    try addChar(&screen, 'b');
    try addChar(&screen, 'c');
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();

    try expectLine(try editor.run(), "abc");
    try std.testing.expectEqualStrings("> abc", screen.rowText(0));
    try std.testing.expectEqual(@as(?usize, 0), screen.first_move_row);
    try std.testing.expectEqual(@as(?usize, 0), screen.first_move_column);
    try std.testing.expectEqual(@as(usize, 0), screen.last_move_row);
    try std.testing.expectEqual(@as(usize, 5), screen.last_move_column);
    try std.testing.expect(screen.normal_styled);
    try std.testing.expect(!screen.styled_any);
}

test "editing with cursor movement and backspace" {
    var screen = TestScreen.init();
    defer screen.deinit();
    for ("abc") |ch| try addChar(&screen, ch);
    try addKey(&screen, .{ .code = .left });
    try addKey(&screen, .{ .code = .backspace });
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();
    try expectLine(try editor.run(), "ac");
}

test "history recall and draft restore" {
    var screen = TestScreen.init();
    defer screen.deinit();
    var hist = history.History.init(std.testing.allocator);
    defer hist.deinit();
    try hist.add("first");
    try hist.add("second");

    try addChar(&screen, 'x');
    try addKey(&screen, .{ .code = .up });
    try addKey(&screen, .{ .code = .up });
    try addKey(&screen, .{ .code = .down });
    try addKey(&screen, .{ .code = .down });
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{ .history = &hist });
    defer editor.deinit();
    try expectLine(try editor.run(), "x");
}

test "multiline callback continues and submits" {
    const Hook = struct {
        fn call(_: *anyopaque, buffer: []const u8) anyerror!bool {
            return std.mem.indexOfScalar(u8, buffer, ';') != null;
        }
    };

    var screen = TestScreen.init();
    defer screen.deinit();
    try addChar(&screen, 'a');
    try addKey(&screen, .{ .code = .enter });
    try addChar(&screen, 'b');
    try addChar(&screen, ';');
    try addKey(&screen, .{ .code = .enter });

    var marker: u8 = 0;
    var editor = testEditor(&screen, .{ .multiline = .{ .ctx = &marker, .call = Hook.call } });
    defer editor.deinit();
    try expectLine(try editor.run(), "a\nb;");
    try std.testing.expectEqualStrings(">> a", screen.rowText(0));
    try std.testing.expectEqualStrings(">> b;", screen.rowText(1));
    try std.testing.expect(screen.styled_any);
}

test "direct multiline mode inserts newlines and ctrl+enter submits" {
    var screen = TestScreen.init();
    defer screen.deinit();
    try addKey(&screen, .{ .code = .{ .char = 'x' }, .alt = true });
    try addChar(&screen, 'a');
    try addKey(&screen, .{ .code = .enter });
    try addChar(&screen, 'b');
    try addKey(&screen, .{ .code = .enter, .control = true });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();
    try expectLine(try editor.run(), "a\nb");
    try std.testing.expectEqualStrings(">> a", screen.rowText(0));
    try std.testing.expectEqualStrings(">> b", screen.rowText(1));
    try std.testing.expect(screen.styled_any);
}

test "completion cycles candidates" {
    const Hook = struct {
        fn call(_: *anyopaque, buffer: []const u8, cursor: usize, allocation: std.mem.Allocator) anyerror!?Completion {
            if (buffer.len != 0 or cursor != 0) return null;
            const candidates = try allocation.alloc([]const u8, 2);
            candidates[0] = try allocation.dupe(u8, "foo");
            candidates[1] = try allocation.dupe(u8, "bar");
            return .{ .start = 0, .end = 0, .candidates = candidates };
        }
    };

    var screen = TestScreen.init();
    defer screen.deinit();
    try addKey(&screen, .{ .code = .tab });
    try addKey(&screen, .{ .code = .tab });
    try addKey(&screen, .{ .code = .enter });

    var marker: u8 = 0;
    var editor = testEditor(&screen, .{ .complete = .{ .ctx = &marker, .call = Hook.call } });
    defer editor.deinit();
    try expectLine(try editor.run(), "bar");
}

test "abort and end of input" {
    {
        var screen = TestScreen.init();
        defer screen.deinit();
        try addKey(&screen, .{ .code = .{ .char = 'c' }, .control = true });
        var editor = testEditor(&screen, .{});
        defer editor.deinit();
        switch (try editor.run()) {
            .abort => {},
            else => return error.TestUnexpectedResult,
        }
    }
    {
        var screen = TestScreen.init();
        defer screen.deinit();
        try addKey(&screen, .{ .code = .{ .char = 'd' }, .control = true });
        var editor = testEditor(&screen, .{});
        defer editor.deinit();
        switch (try editor.run()) {
            .eof => {},
            else => return error.TestUnexpectedResult,
        }
    }
}

test "wrapping keeps the prompt and cursor aligned" {
    var screen = TestScreen.init();
    screen.columns = 10;
    defer screen.deinit();
    for ("abcdefghij") |ch| try addChar(&screen, ch);
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();
    try expectLine(try editor.run(), "abcdefghij");
    try std.testing.expectEqualStrings("> abcdefgh", screen.rowText(0));
    try std.testing.expectEqualStrings("  ij", screen.rowText(1));
    try std.testing.expectEqual(@as(usize, 1), screen.last_move_row);
    try std.testing.expectEqual(@as(usize, 4), screen.last_move_column);
    try std.testing.expect(screen.normal_styled);
    try std.testing.expect(!screen.styled_any);
}

test "paste normalises line endings" {
    var screen = TestScreen.init();
    defer screen.deinit();
    try screen.keys.append(std.testing.allocator, .{ .paste = "one\r\ntwo" });
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();
    try expectLine(try editor.run(), "one\ntwo");
}

test "submitting adds a history entry" {
    var screen = TestScreen.init();
    defer screen.deinit();
    try addChar(&screen, 'z');
    try addKey(&screen, .{ .code = .enter });

    var hist = history.History.init(std.testing.allocator);
    defer hist.deinit();
    var editor = testEditor(&screen, .{ .history = &hist });
    defer editor.deinit();
    try expectLine(try editor.run(), "z");
    try std.testing.expectEqual(@as(usize, 1), hist.count());
}

test "tab without a completer inserts four spaces" {
    var screen = TestScreen.init();
    defer screen.deinit();
    try addKey(&screen, .{ .code = .tab });
    try addChar(&screen, 'x');
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();
    try expectLine(try editor.run(), "    x");
}

test "raw control codes are normalised" {
    switch (controlCodeKey(0x03).?) {
        .char => |cp| try std.testing.expectEqual(@as(u21, 'c'), cp),
        else => return error.TestUnexpectedResult,
    }
    switch (controlCodeKey(0x0d).?) {
        .enter => {},
        else => return error.TestUnexpectedResult,
    }
    switch (controlCodeKey(0x08).?) {
        .backspace => {},
        else => return error.TestUnexpectedResult,
    }
    switch (controlCodeKey(0x1b).?) {
        .esc => {},
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expect(controlCodeKey('a') == null);

    const ctrl_h = applyControlCode(.{ .code = .{ .char = 0x08 }, .control = true });
    switch (ctrl_h.code) {
        .backspace => try std.testing.expect(!ctrl_h.control),
        else => return error.TestUnexpectedResult,
    }
    const ctrl_i = applyControlCode(.{ .code = .{ .char = 0x09 }, .control = true });
    switch (ctrl_i.code) {
        .tab => try std.testing.expect(!ctrl_i.control),
        else => return error.TestUnexpectedResult,
    }
    const ctrl_c = applyControlCode(.{ .code = .{ .char = 0x03 }, .control = true });
    switch (ctrl_c.code) {
        .char => |cp| {
            try std.testing.expectEqual(@as(u21, 'c'), cp);
            try std.testing.expect(ctrl_c.control);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "up moves inside a multiline buffer before history" {
    var screen = TestScreen.init();
    defer screen.deinit();
    var hist = history.History.init(std.testing.allocator);
    defer hist.deinit();
    try hist.add("old");

    try addKey(&screen, .{ .code = .up });
    try addChar(&screen, 'X');
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{ .history = &hist, .initial = "a\nb" });
    defer editor.deinit();
    try expectLine(try editor.run(), "aX\nb");
}

test "control backspace and control tab use their normal handlers" {
    var screen = TestScreen.init();
    defer screen.deinit();
    try addChar(&screen, 'a');
    try addChar(&screen, 'b');
    try addKey(&screen, .{ .code = .backspace, .control = true });
    try addKey(&screen, .{ .code = .tab, .control = true });
    try addChar(&screen, 'c');
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();
    try expectLine(try editor.run(), "a    c");
}

test "submitting from the middle keeps the whole block visible" {
    var screen = TestScreen.init();
    defer screen.deinit();
    try addKey(&screen, .{ .code = .up });
    try addKey(&screen, .{ .code = .enter, .control = true });

    var editor = testEditor(&screen, .{ .initial = "a\nb" });
    defer editor.deinit();
    try expectLine(try editor.run(), "a\nb");
    try std.testing.expectEqualStrings(">> a", screen.rowText(0));
    try std.testing.expectEqualStrings(">> b", screen.rowText(1));
    try std.testing.expect(screen.styled_any);
}

test "recalled multiline history uses uniform prompts" {
    var screen = TestScreen.init();
    defer screen.deinit();
    var hist = history.History.init(std.testing.allocator);
    defer hist.deinit();
    try hist.add("first\nsecond");

    try addKey(&screen, .{ .code = .up });
    try addKey(&screen, .{ .code = .enter });

    var editor = testEditor(&screen, .{ .history = &hist });
    defer editor.deinit();
    try expectLine(try editor.run(), "first\nsecond");
    try std.testing.expectEqualStrings(">> first", screen.rowText(0));
    try std.testing.expectEqualStrings(">> second", screen.rowText(1));
    try std.testing.expect(screen.styled_any);
}

test "a multiline block at the bottom scrolls into view" {
    var screen = TestScreen.init();
    screen.rows = 6;
    screen.cursor_row = 5;
    defer screen.deinit();

    try addKey(&screen, .{ .code = .{ .char = 'x' }, .alt = true });
    try addChar(&screen, 'a');
    try addKey(&screen, .{ .code = .enter });
    try addChar(&screen, 'b');
    try addKey(&screen, .{ .code = .enter, .control = true });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();
    try expectLine(try editor.run(), "a\nb");
    try std.testing.expect(screen.scrolls >= 1);
    try std.testing.expectEqualStrings(">> a", screen.rowText(3));
    try std.testing.expectEqualStrings(">> b", screen.rowText(4));
}

test "shrinking the terminal clamps the anchor and scrolls once" {
    var screen = TestScreen.init();
    screen.rows = 10;
    screen.cursor_row = 9;
    screen.shrink_rows_to = 8;
    defer screen.deinit();

    try addKey(&screen, .{ .code = .{ .char = 'x' }, .alt = true });
    try addChar(&screen, 'a');
    try addKey(&screen, .{ .code = .enter });
    try addChar(&screen, 'b');
    try addKey(&screen, .{ .code = .enter });
    try addChar(&screen, 'c');
    try addKey(&screen, .{ .code = .enter, .control = true });

    var editor = testEditor(&screen, .{});
    defer editor.deinit();
    try expectLine(try editor.run(), "a\nb\nc");
    try std.testing.expectEqual(@as(usize, 2), screen.scrolls);
    try std.testing.expectEqual(@as(usize, 2), screen.scrolled_lines);
    try std.testing.expect(screen.max_move_row < 8);
    try std.testing.expectEqualStrings(">> a", screen.rowText(4));
    try std.testing.expectEqualStrings(">> b", screen.rowText(5));
    try std.testing.expectEqualStrings(">> c", screen.rowText(6));
}
