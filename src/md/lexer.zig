const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const ArrayList = std.ArrayList;
const json = std.json;
const utf8 = @import("../unicode/unicode.zig");

const log = @import("logger.zig");
const Token = @import("token.zig").Token;
const TokenRule = @import("token.zig").TokenRule;
const TokenId = @import("token.zig").TokenId;
const atxRules = @import("token_atx_heading.zig");
const inlineRules = @import("token_inline.zig");

pub const Lexer = struct {
    view: utf8.Utf8View,
    index: u32,
    rules: ArrayList(TokenRule),
    tokens: ArrayList(Token),
    tokenIndex: u64,
    lineNumber: u32,
    allocator: *mem.Allocator,

    pub fn init(allocator: *mem.Allocator, input: []const u8) !Lexer {
        // Skip the UTF-8 BOM if present
        var t = Lexer{
            .view = try utf8.Utf8View.init(input),
            .index = 0,
            .allocator = allocator,
            .rules = ArrayList(TokenRule).init(allocator),
            .tokens = ArrayList(Token).init(allocator),
            .tokenIndex = 0,
            .lineNumber = 1,
        };
        try t.registerRule(ruleWhitespace);
        try t.registerRule(atxRules.ruleAtxHeader);
        try t.registerRule(inlineRules.ruleInline);
        try t.registerRule(ruleEOF);
        return t;
    }

    pub fn deinit(l: *Lexer) void {
        l.rules.deinit();
        l.tokens.deinit();
    }

    pub fn registerRule(l: *Lexer, rule: TokenRule) !void {
        try l.rules.append(rule);
    }

    /// Get the next token from the input.
    pub fn next(l: *Lexer) !?Token {
        for (l.rules.items) |rule| {
            if (try rule(l)) |v| {
                return v;
            }
        }
        return null;
    }

    /// Peek at the next token.
    pub fn peekNext(l: *Lexer) !?Token {
        var indexBefore = l.index;
        var tokenIndexBefore = l.tokenIndex;
        var pNext = try l.next();
        l.index = indexBefore;
        l.tokenIndex = tokenIndexBefore;
        return pNext;
    }

    /// Gets a codepoint at index from the input. Returns null if index exceeds the length of the view.
    pub fn getRune(l: *Lexer, index: u32) ?[]const u8 {
        return l.view.index(index);
    }

    pub fn debugPrintToken(l: *Lexer, msg: []const u8, token: anytype) !void {
        // TODO: only stringify json if debug logging
        var buf = std.ArrayList(u8).init(l.allocator);
        defer buf.deinit();
        try json.stringify(token, json.StringifyOptions{
            // This works differently than normal StringifyOptions for Tokens, separator does not
            // add \n.
            .whitespace = .{
                .indent = .{ .Space = 1 },
                .separator = true,
            },
        }, buf.outStream());
        log.Debugf("{}: {}\n", .{ msg, buf.items });
    }

    pub fn emit(l: *Lexer, tok: TokenId, startOffset: u32, endOffset: u32) !?Token {
        // log.Debugf("start: {} end: {}\n", .{ start, end });
        var str = l.view.slice(startOffset, endOffset);
        // check for diacritic
        log.Debugf("str: '{Z}'\n", .{str.bytes});
        var nEndOffset: u32 = endOffset - 1;
        if ((endOffset - startOffset) == 1 or nEndOffset < startOffset) {
            nEndOffset = startOffset;
        }
        // check if token already emitted
        if (l.tokens.items.len > l.tokenIndex) {
            // try l.debugPrintToken("lexer last token", l.tokens.items[l.tokens.items.len - 1]);
            var lastTok = l.tokens.items[l.tokens.items.len - 1];
            if (lastTok.ID == tok and lastTok.startOffset == startOffset and lastTok.endOffset == nEndOffset) {
                log.Debug("Token already encountered");
                l.tokenIndex = l.tokens.items.len - 1;
                l.index = endOffset;
                return lastTok;
            }
        }
        var column: u32 = l.offsetToColumn(startOffset);
        if (tok == TokenId.EOF) {
            column = l.tokens.items[l.tokens.items.len - 1].column;
            l.lineNumber -= 1;
        }
        var newTok = Token{
            .ID = tok,
            .startOffset = startOffset,
            .endOffset = nEndOffset,
            .string = str.bytes,
            .lineNumber = l.lineNumber,
            .column = column,
        };
        try l.debugPrintToken("lexer emit", &newTok);
        try l.tokens.append(newTok);
        l.index = endOffset;
        l.tokenIndex = l.tokens.items.len - 1;
        if (mem.eql(u8, str.bytes, "\n")) {
            l.lineNumber += 1;
        }
        return newTok;
    }

    /// Returns the column number of offset translated from the start of the line
    pub fn offsetToColumn(l: *Lexer, offset: u32) u32 {
        var i: u32 = offset;
        var start: u32 = 1;
        var char: []const u8 = "";
        var foundLastNewline: bool = false;
        if (offset > 0) {
            i = offset - 1;
        }
        // Get the last newline starting from offset
        while (!mem.eql(u8, char, "\n")) : (i -= 1) {
            if (i == 0) {
                break;
            }
            char = l.view.index(i).?;
            start = i;
        }
        if (mem.eql(u8, char, "\n")) {
            foundLastNewline = true;
            start = i + 1;
        }
        char = "";
        i = offset;
        // Get the next newline starting from offset
        while (!mem.eql(u8, char, "\n")) : (i += 1) {
            if (i == l.view.len) {
                break;
            }
            char = l.view.index(i).?;
        }
        // only one line of input or on the first line of input
        if (!foundLastNewline) {
            return offset + 1;
        }
        return offset - start;
    }

    /// Checks for a single whitespace character. Returns true if char is a space character.
    pub fn isSpace(l: *Lexer, char: u8) bool {
        if (char == '\u{0020}') {
            return true;
        }
        return false;
    }

    /// Checks for all the whitespace characters. Returns true if the rune is a whitespace.
    pub fn isWhitespace(l: *Lexer, rune: []const u8) bool {
        // A whitespace character is a space (U+0020), tab (U+0009), newline (U+000A), line tabulation (U+000B), form feed
        // (U+000C), or carriage return (U+000D).
        const runes = &[_][]const u8{
            "\u{0020}", "\u{0009}", "\u{000A}", "\u{000B}", "\u{000C}", "\u{000D}",
        };
        for (runes) |itrune|
            if (mem.eql(u8, itrune, rune))
                return true;
        return false;
    }

    pub fn isPunctuation(l: *Lexer, rune: []const u8) bool {
        // Check for ASCII punctuation characters...
        //
        // FIXME: Check against the unicode punctuation tables... there isn't a Zig library that does this that I have found.
        //
        // A punctuation character is an ASCII punctuation character or anything in the general Unicode categories Pc, Pd,
        // Pe, Pf, Pi, Po, or Ps.
        const runes = &[_][]const u8{
            "!", "\"", "#", "$", "%", "&", "\'", "(", ")", "*", "+", ",", "-", ".", "/", ":", ";", "<", "=", ">", "?", "@", "[", "\\", "]", "^", "_", "`", "{", "|", "}", "~",
        };
        for (runes) |itrune|
            if (mem.eql(u8, itrune, rune))
                return true;
        return false;
    }

    pub fn isLetter(l: *Lexer, rune: []const u8) bool {
        // TODO: make this more robust by using unicode character sets
        if (!l.isPunctuation(rune) and !l.isWhitespace(rune)) {
            return true;
        }
        return false;
    }

    /// Get the last token emitted, exclude peek tokens
    pub fn lastToken(l: *Lexer) Token {
        return l.tokens.items[l.tokenIndex];
    }

    /// Skip the next token
    pub fn skipNext(l: *Lexer) !void {
        _ = try l.next();
    }
};

/// Get all the whitespace characters greedly.
pub fn ruleWhitespace(t: *Lexer) !?Token {
    var index: u32 = t.index;
    log.Debug("in ruleWhitespace");
    while (t.getRune(index)) |val| {
        if (t.isWhitespace(val)) {
            index += 1;
            if (mem.eql(u8, "\n", val)) {
                break;
            }
        } else {
            log.Debugf("index: {}\n", .{index});
            break;
        }
    }
    log.Debugf("t.index: {} index: {}\n", .{ t.index, index });
    if (index > t.index) {
        return t.emit(.Whitespace, t.index, index);
    }
    return null;
}

/// Return EOF at the end of the input
pub fn ruleEOF(t: *Lexer) !?Token {
    if (t.index == t.view.len) {
        return t.emit(.EOF, t.index, t.index);
    }
    return null;
}

test "lexer: peekNext " {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const input = "# foo";
    log.Debugf("input:\n{}-- END OF TEST --\n", .{input});

    var t = try Lexer.init(allocator, input);

    if (try t.next()) |tok| {
        assert(tok.ID == TokenId.AtxHeader);
    }

    // two consecutive peeks should return the same token
    if (try t.peekNext()) |tok| {
        assert(tok.ID == TokenId.Whitespace);
    }
    if (try t.peekNext()) |tok| {
        assert(tok.ID == TokenId.Whitespace);
    }
    // The last token does not include peek'd tokens
    assert(t.lastToken().ID == TokenId.AtxHeader);

    if (try t.next()) |tok| {
        assert(tok.ID == TokenId.Whitespace);
    }
}

test "lexer: offsetToColumn" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    const input = "foo\nbar \t\nbaz";
    var t = try Lexer.init(allocator, input);
    _ = try t.next();
    _ = try t.next();
    if (try t.next()) |tok| {
        assert(tok.column == 1);
    }
    _ = try t.next();
    _ = try t.next();
    _ = try t.next();
    if (try t.next()) |tok| {
        assert(tok.column == 1);
    }
}
