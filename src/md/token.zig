const std = @import("std");
const test_util = @import("test_util.zig");
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;

usingnamespace @import("log.zig");

const ArrayList = std.ArrayList;

const atxRules = @import("token_atx_heading.zig");
const inlineRules = @import("token_inline.zig");

pub const TokenId = enum {
    Invalid,
    Whitespace,
    Line,
    LineEnding,
    AtxHeaderOpen,
    AtxHeaderClose,
    EOF,
};

pub const Token = struct {
    ID: TokenId,
    start: u32,
    end: u32,
    string: []const u8,
};

const tokenRule = fn (tokenizer: *Tokenizer) anyerror!?Token;

pub const Tokenizer = struct {
    buffer: []const u8,
    index: u32,
    rules: ArrayList(tokenRule),
    tokens: ArrayList(Token),
    atxOpener: bool,
    atxLevel: u8,
    start: u32,

    pub fn init(allocator: *mem.Allocator, buffer: []const u8) !Tokenizer {
        // Skip the UTF-8 BOM if present
        var t = Tokenizer{
            .buffer = buffer,
            .index = 0,
            .rules = ArrayList(tokenRule).init(allocator),
            .tokens = ArrayList(Token).init(allocator),
            .atxOpener = true,
            .atxLevel = 0,
            .start = 0,
        };
        try t.registerRule(ruleWhitespace);
        try t.registerRule(atxRules.ruleAtxHeader);
        try t.registerRule(inlineRules.ruleInline);
        try t.registerRule(ruleEOF);
        return t;
    }

    pub fn registerRule(self: *Tokenizer, rule: tokenRule) !void {
        try self.rules.append(rule);
    }

    pub fn next(self: *Tokenizer) !?Token {
        for (self.rules.items) |rule| {
            if (try rule(self)) |v| {
                return v;
            }
        }
        return null;
    }

    /// Gets a character at index from the source buffer. Returns null if index exceeds the length of the buffer.
    pub fn getChar(self: *Tokenizer, index: u32) ?u8 {
        if (index >= self.buffer.len) {
            return null;
        }
        return self.buffer[index];
    }

    pub fn peekNext(self: *Tokenizer) u8 {
        return self.buffer[self.index + 1];
    }

    pub fn emit(self: *Tokenizer, tok: TokenId, start: u32, end: u32) !?Token {
        // log.Debugf("start: {} end: {}\n", .{ start, end });
        var str = self.buffer[start..end];
        var token = Token{
            .ID = tok,
            .start = start,
            .end = end,
            .string = str,
        };
        log.Debugf("emit: {}\n", .{token});
        try self.tokens.append(token);
        self.index = end;
        return token;
    }

    /// Checks for a single whitespace character. Returns true if char is a space character.
    pub fn isSpace(self: *Tokenizer, char: u8) bool {
        if (char == '\u{0020}') {
            return true;
        }
        return false;
    }

    /// Checks for all the whitespace characters. Returns true if the char is a whitespace.
    pub fn isWhitespace(self: *Tokenizer, char: u8) bool {
        // A whitespace character is a space (U+0020), tab (U+0009), newline (U+000A), line tabulation (U+000B), form feed
        // (U+000C), or carriage return (U+000D).
        return switch (char) {
            '\u{0020}', '\u{0009}', '\u{000A}', '\u{000B}', '\u{000C}', '\u{000D}' => true,
            else => false,
        };
    }

    pub fn isPunctuation(self: *Tokenizer, char: u8) bool {
        // Check for ASCII punctuation characters...
        //
        // FIXME: Check against the unicode punctuation tables... there isn't a Zig library that does this that I have found.
        //
        // A punctuation character is an ASCII punctuation character or anything in the general Unicode categories Pc, Pd,
        // Pe, Pf, Pi, Po, or Ps.
        return switch (char) {
            '!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '<', '=', '>', '?', '@', '[', '\\', ']', '^', '_', '`', '{', '|', '}', '~' => true,
            else => false,
        };
    }

    pub fn isCharacter(self: *Tokenizer, char: u8) bool {
        // TODO: make this more robust by using unicode character sets
        if (!self.isPunctuation(char) and !self.isWhitespace(char)) {
            return true;
        }
        return false;
    }
};

/// Get all the whitespace characters greedly.
pub fn ruleWhitespace(t: *Tokenizer) !?Token {
    var index: u32 = t.index;
    while (t.getChar(index)) |val| {
        if (t.isWhitespace(val)) {
            index += 1;
        } else {
            break;
        }
    }
    if (index > t.index) {
        return t.emit(.Whitespace, t.index, index);
    }
    // log.Debugf("t.index: {} index: {}\n", .{ t.index, index });
    return null;
}

/// Return EOF at the end of the input
pub fn ruleEOF(t: *Tokenizer) !?Token {
    if (t.index == t.buffer.len) {
        return t.emit(.EOF, t.index, t.index);
    }
    return null;
}

fn checkToken(val: Token, expect: Token) void {
    assert(val.ID == expect.ID);
    assert(val.start == expect.start);
    assert(val.end == expect.end);
    assert(mem.eql(u8, val.string, expect.string));
}

test "atx headings - example 32" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    const out = try test_util.getTest(allocator, 32);

    // TODO: move this somplace else
    use_rfc3339_date_handler();

    log.Debugf("test: {}\n-- END OF TEST --\n", .{out});

    var t = try Tokenizer.init(allocator, out);

    while (true) {
        if (try t.next()) |token| {
            if (token.ID == TokenId.EOF) {
                log.Debug("Found EOF");
                break;
            }
        }
    }

    checkToken(t.tokens.items[0], Token{ .ID = TokenId.AtxHeaderOpen, .start = 0, .end = 1, .string = "#" });
    checkToken(t.tokens.items[1], Token{ .ID = TokenId.Whitespace, .start = 1, .end = 2, .string = " " });
    checkToken(t.tokens.items[2], Token{ .ID = TokenId.Line, .start = 2, .end = 5, .string = "foo" });
    checkToken(t.tokens.items[3], Token{ .ID = TokenId.Whitespace, .start = 5, .end = 6, .string = "\n" });
    checkToken(t.tokens.items[4], Token{ .ID = TokenId.AtxHeaderOpen, .start = 6, .end = 8, .string = "##" });
    checkToken(t.tokens.items[5], Token{ .ID = TokenId.Whitespace, .start = 8, .end = 9, .string = " " });
    checkToken(t.tokens.items[6], Token{ .ID = TokenId.Line, .start = 9, .end = 12, .string = "foo" });
    checkToken(t.tokens.items[7], Token{ .ID = TokenId.Whitespace, .start = 12, .end = 13, .string = "\n" });
    checkToken(t.tokens.items[8], Token{ .ID = TokenId.AtxHeaderOpen, .start = 13, .end = 16, .string = "###" });
    checkToken(t.tokens.items[9], Token{ .ID = TokenId.Whitespace, .start = 16, .end = 17, .string = " " });
    checkToken(t.tokens.items[10], Token{ .ID = TokenId.Line, .start = 17, .end = 20, .string = "foo" });
    checkToken(t.tokens.items[11], Token{ .ID = TokenId.Whitespace, .start = 20, .end = 21, .string = "\n" });
    checkToken(t.tokens.items[12], Token{ .ID = TokenId.AtxHeaderOpen, .start = 21, .end = 25, .string = "####" });
    checkToken(t.tokens.items[13], Token{ .ID = TokenId.Whitespace, .start = 25, .end = 26, .string = " " });
    checkToken(t.tokens.items[14], Token{ .ID = TokenId.Line, .start = 26, .end = 29, .string = "foo" });
    checkToken(t.tokens.items[15], Token{ .ID = TokenId.Whitespace, .start = 29, .end = 30, .string = "\n" });
    checkToken(t.tokens.items[16], Token{ .ID = TokenId.AtxHeaderOpen, .start = 30, .end = 35, .string = "#####" });
    checkToken(t.tokens.items[17], Token{ .ID = TokenId.Whitespace, .start = 35, .end = 36, .string = " " });
    checkToken(t.tokens.items[18], Token{ .ID = TokenId.Line, .start = 36, .end = 39, .string = "foo" });
    checkToken(t.tokens.items[19], Token{ .ID = TokenId.Whitespace, .start = 39, .end = 40, .string = "\n" });
    checkToken(t.tokens.items[20], Token{ .ID = TokenId.AtxHeaderOpen, .start = 40, .end = 46, .string = "######" });
    checkToken(t.tokens.items[21], Token{ .ID = TokenId.Whitespace, .start = 46, .end = 47, .string = " " });
    checkToken(t.tokens.items[22], Token{ .ID = TokenId.Line, .start = 47, .end = 50, .string = "foo" });
    checkToken(t.tokens.items[23], Token{ .ID = TokenId.Whitespace, .start = 50, .end = 51, .string = "\n" });
    checkToken(t.tokens.items[24], Token{ .ID = TokenId.EOF, .start = 51, .end = 51, .string = undefined });
}
