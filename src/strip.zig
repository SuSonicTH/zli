const std = @import("std");

pub fn file(io: std.Io, input: [:0]const u8, output: [:0]const u8, allocator: std.mem.Allocator) !void {
    var input_file = try std.Io.Dir.cwd().openFile(io, input, .{});
    defer input_file.close(io);

    const file_size = (try input_file.stat(io)).size;
    var data = try allocator.alloc(u8, file_size + 1);
    defer allocator.free(data);
    var buffer: [1024]u8 = undefined;
    var reader_if = input_file.reader(io, &buffer);
    const reader = &reader_if.interface;
    _ = try reader.readSliceAll(data[0..file_size]);
    data[file_size] = 0;

    const stripped = try strip(data, allocator);
    defer allocator.free(stripped);

    var output_file = try std.Io.Dir.cwd().createFile(io, output, .{});
    defer output_file.close(io);

    var writer_if = output_file.writer(io, &buffer);
    const writer = &writer_if.interface;

    _ = try writer.write(stripped);
    try writer.flush();
}

pub fn strip(source: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var tokenizer = Tokenizer.init(source);

    const buffer = try allocator.alloc(u8, source.len);
    errdefer allocator.free(buffer);
    var pos: usize = 0;

    var token = tokenizer.next();
    while (token[0] != 0) : (token = tokenizer.next()) {
        std.mem.copyForwards(u8, buffer[pos..], token);
        pos += token.len;

        switch (token[0]) {
            '{', '}', '(', ')', '.', '+', '-', '*', '/', '"', '\'', '[', ']', '#', '=', ',', '~', ':' => {},
            else => {
                switch (tokenizer.peek[0]) {
                    0, '{', '}', '(', ')', '.', '+', '-', '*', '/', '"', '\'', '[', ']', '#', '=', ',', '~', ':' => {},
                    else => {
                        buffer[pos] = ' ';
                        pos += 1;
                    },
                }
            },
        }
    }

    const ret: []u8 = try allocator.realloc(buffer, pos);
    return ret;
}

const testing = std.testing;

test "strip just whitepaces" {
    const allocator = std.testing.allocator;

    const input = "  \r\n\t \r \n \t\t ";
    const output = try strip(std.mem.sliceTo(input, 0), allocator);
    defer allocator.free(output);
    try testing.expectEqualStrings("", output);
}

test "strip simple expression - not changed" {
    const allocator = std.testing.allocator;

    const input = "local a=1";
    const output = try strip(std.mem.sliceTo(input, 0), allocator);
    defer allocator.free(output);
    try testing.expectEqualStrings("local a=1", output);
}

test "strip simple expression - whitespace removed" {
    const allocator = std.testing.allocator;

    const input = "\t local\t a = 1 \n";
    const output = try strip(std.mem.sliceTo(input, 0), allocator);
    defer allocator.free(output);
    try testing.expectEqualStrings("local a=1", output);
}

test "strip bigger script" {
    const allocator = std.testing.allocator;

    const input =
        "\r\n " ++
        " -- Some bigger script \n" ++
        " \n\n " ++
        "\tlocal a = \t1\n" ++
        "   local   b =   2\n\n" ++
        " --[[ Big Block of comment \n" ++
        "      should be removed  \n" ++
        "]]" ++
        "print ( 'result =\\''  ..  \n( a + b ) ..\n '\\'') \r\n   \n";
    const output = try strip(std.mem.sliceTo(input, 0), allocator);
    defer allocator.free(output);
    try testing.expectEqualStrings("local a=1 local b=2 print('result =\\''..(a+b)..'\\'')", output);
}

const Tokenizer = struct {
    data: []const u8 = undefined,
    pos: usize = 0,
    peek: []const u8 = " ",

    pub fn init(data: []const u8) Tokenizer {
        var iterator: Tokenizer = .{
            .data = data,
        };
        iterator.peek = iterator.next_token();
        return iterator;
    }

    pub fn next(self: *Tokenizer) []const u8 {
        const token = self.peek;
        self.peek = self.next_token();
        return token;
    }

    fn next_token(self: *Tokenizer) []const u8 {
        if (self.pos >= self.data.len) {
            return "\x00";
        }
        switch (self.data[self.pos]) {
            ' ', '\t', '\r', '\n' => {
                while (self.pos < self.data.len and (self.data[self.pos] == ' ' or self.data[self.pos] == '\t' or self.data[self.pos] == '\r' or self.data[self.pos] == '\n')) {
                    self.pos += 1;
                }
                return self.next_token();
            },
            '-' => {
                if (self.pos < self.data.len - 1 and self.data[self.pos + 1] == '-') {
                    const blockLen = getBlockLen(self.data[self.pos + 2 ..]);
                    if (blockLen > 0) {
                        self.pos += blockLen + 2;
                    } else {
                        while (self.pos < self.data.len and self.data[self.pos] != '\r' and self.data[self.pos] != '\n') {
                            self.pos += 1;
                        }
                    }
                    return self.next_token();
                } else {
                    self.pos += 1;
                    return "-";
                }
            },
            '_', 'a'...'z', 'A'...'Z', '0'...'9' => {
                const start = self.pos;
                self.pos += 1;
                while (self.pos < self.data.len) {
                    switch (self.data[self.pos]) {
                        '_', 'a'...'z', 'A'...'Z', '0'...'9' => {
                            self.pos += 1;
                        },
                        else => {
                            return self.data[start..self.pos];
                        },
                    }
                }
                self.pos += 1;
                return self.data[start .. self.pos - 1];
            },
            '"' => {
                const start = self.pos;
                self.pos += 1;
                while (self.pos < self.data.len - 1 and (self.data[self.pos] != '"' or (self.data[self.pos - 1] == '\\' and self.data[self.pos - 2] != '\\'))) {
                    self.pos += 1;
                }
                self.pos += 1;
                return self.data[start..self.pos];
            },
            '\'' => {
                const start = self.pos;
                self.pos += 1;
                while (self.pos < self.data.len - 1 and (self.data[self.pos] != '\'' or (self.data[self.pos - 1] == '\\' and self.data[self.pos - 2] != '\\'))) {
                    self.pos += 1;
                }
                self.pos += 1;
                return self.data[start..self.pos];
            },
            '[' => {
                const blockLen = getBlockLen(self.data[self.pos..]);
                if (blockLen > 0) {
                    const start = self.pos;
                    self.pos += blockLen;
                    return self.data[start .. start + blockLen];
                } else {
                    self.pos += 1;
                    return "[";
                }
            },
            '.' => {
                if (self.data[self.pos + 1] == '.') {
                    if (self.data[self.pos + 2] == '.') {
                        self.pos += 3;
                        return "...";
                    } else {
                        self.pos += 2;
                        return "..";
                    }
                } else {
                    self.pos += 1;
                    return ".";
                }
            },
            else => {
                const cpos = self.pos;
                self.pos += 1;
                return self.data[cpos .. cpos + 1];
            },
        }
        unreachable;
    }
};

test "simple tokens" {
    var tokenizer = Tokenizer.init("a=1");

    try testing.expectEqualStrings("a", tokenizer.next());
    try testing.expectEqualStrings("=", tokenizer.next());
    try testing.expectEqualStrings("1", tokenizer.next());
    const end = tokenizer.next();
    try testing.expect(end[0] == 0);
}

test "simple tokens with spaces" {
    var tokenizer = Tokenizer.init("  a\t\n = \t\n\r1\t ");

    try testing.expectEqualStrings("a", tokenizer.next());
    try testing.expectEqualStrings("=", tokenizer.next());
    try testing.expectEqualStrings("1", tokenizer.next());
    const end = tokenizer.next();
    try testing.expect(end[0] == 0);
}

test "simple string with escaped quote" {
    var tokenizer = Tokenizer.init("a='test \\'123\\''");

    try testing.expectEqualStrings("a", tokenizer.next());
    try testing.expectEqualStrings("=", tokenizer.next());
    try testing.expectEqualStrings("'test \\'123\\''", tokenizer.next());
    const end = tokenizer.next();
    try testing.expect(end[0] == 0);
}

test "string with escaped quote" {
    var tokenizer = Tokenizer.init("a=\"test \\\"123\\\"\"");

    try testing.expectEqualStrings("a", tokenizer.next());
    try testing.expectEqualStrings("=", tokenizer.next());
    try testing.expectEqualStrings("\"test \\\"123\\\"\"", tokenizer.next());
    const end = tokenizer.next();
    try testing.expect(end[0] == 0);
}

test "block string" {
    var tokenizer = Tokenizer.init("a=[==[this is a test]==]");

    try testing.expectEqualStrings("a", tokenizer.next());
    try testing.expectEqualStrings("=", tokenizer.next());
    try testing.expectEqualStrings("[==[this is a test]==]", tokenizer.next());
    const end = tokenizer.next();
    try testing.expect(end[0] == 0);
}

test "line comment" {
    var tokenizer = Tokenizer.init("a=1--this is a comment");

    try testing.expectEqualStrings("a", tokenizer.next());
    try testing.expectEqualStrings("=", tokenizer.next());
    try testing.expectEqualStrings("1", tokenizer.next());
    const end = tokenizer.next();
    try testing.expect(end[0] == 0);
}

test "punctations" {
    var tokenizer = Tokenizer.init("{}()[].+-*/#=,~:");

    try testing.expectEqualStrings("{", tokenizer.next());
    try testing.expectEqualStrings("}", tokenizer.next());
    try testing.expectEqualStrings("(", tokenizer.next());
    try testing.expectEqualStrings(")", tokenizer.next());
    try testing.expectEqualStrings("[", tokenizer.next());
    try testing.expectEqualStrings("]", tokenizer.next());
    try testing.expectEqualStrings(".", tokenizer.next());
    try testing.expectEqualStrings("+", tokenizer.next());
    try testing.expectEqualStrings("-", tokenizer.next());
    try testing.expectEqualStrings("*", tokenizer.next());
    try testing.expectEqualStrings("/", tokenizer.next());
    try testing.expectEqualStrings("#", tokenizer.next());
    try testing.expectEqualStrings("=", tokenizer.next());
    try testing.expectEqualStrings(",", tokenizer.next());
    try testing.expectEqualStrings("~", tokenizer.next());
    try testing.expectEqualStrings(":", tokenizer.next());
    const end = tokenizer.next();
    try testing.expect(end[0] == 0);
}

test "names" {
    var tokenizer = Tokenizer.init(" a.test_4_names:_call( other5 ) ");

    try testing.expectEqualStrings("a", tokenizer.next());
    try testing.expectEqualStrings(".", tokenizer.next());
    try testing.expectEqualStrings("test_4_names", tokenizer.next());
    try testing.expectEqualStrings(":", tokenizer.next());
    try testing.expectEqualStrings("_call", tokenizer.next());
    try testing.expectEqualStrings("(", tokenizer.next());
    try testing.expectEqualStrings("other5", tokenizer.next());
    try testing.expectEqualStrings(")", tokenizer.next());
    const end = tokenizer.next();
    try testing.expect(end[0] == 0);
}

fn getBlockLen(data: []const u8) usize {
    const eqals = "========================================================================================================================";
    if (data[0] != '[') {
        return 0;
    }
    var eqlen: usize = 0;
    while (data[1 + eqlen] == '=' and eqlen <= eqals.len) {
        eqlen += 1;
    }
    if (data[eqlen + 1] != '[') {
        return 0;
    }

    var pos = eqlen + 2;
    while (pos < data.len - eqlen - 1) : (pos += 1) {
        if (data[pos] == ']') {
            if ((eqlen == 0 or std.mem.eql(u8, data[pos + 1 .. pos + 1 + eqlen], eqals[0..eqlen])) and data[pos + 1 + eqlen] == ']') {
                return pos + eqlen + 2;
            }
        }
    }
    return 0;
}

test "getBlockLen with simple block" {
    const string: []const u8 = "[[test]]";
    const len = getBlockLen(string);
    try testing.expectEqualStrings("[[test]]", string[0..len]);
}

test "getBlockLen with simple block additional text" {
    const string: []const u8 = "[[test]] outside block";
    const len = getBlockLen(string);
    try testing.expectEqualStrings("[[test]]", string[0..len]);
}

test "getBlockLen not starting with a block" {
    const string: []const u8 = " [[test]]";
    try testing.expect(getBlockLen(string) == 0);
}

test "getBlockLen with one eqauls block" {
    const string: []const u8 = "[=[test]=] outside block";
    const len = getBlockLen(string);
    try testing.expectEqualStrings("[=[test]=]", string[0..len]);
}

test "getBlockLen with multiple eqauls block" {
    const string: []const u8 = "[===[test]===] outside block";
    const len = getBlockLen(string);
    try testing.expectEqualStrings("[===[test]===]", string[0..len]);
}

test "getBlockLen with simple block with no mathcing end" {
    try testing.expect(getBlockLen("[===[test]====]") == 0);
    try testing.expect(getBlockLen("[===[test]==]") == 0);
    try testing.expect(getBlockLen("[===[test]]") == 0);
}
