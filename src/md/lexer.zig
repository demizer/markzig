const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const ArrayList = std.ArrayList;
const json = std.json;
const utf8 = @import("../unicode/unicode.zig");

const log = @import("log.zig");
const ttyCode = log.logger.TTY.Code;
const Token = @import("token.zig").Token;
const TokenId = @import("token.zig").TokenId;
const atxRules = @import("lexer_atx_heading.zig");
const inlineRules = @import("lexer_inline.zig");
const listRules = @import("lexer_list.zig");

const lexerRuleFn = fn (lexer: *Lexer) anyerror!?Token;

const lexerRule = struct {
    name: []const u8,
    func: lexerRuleFn,

    const Self = @This();

    pub fn format(
        writer: anytype,
        comptime fmt: []const u8,
        args: anytype,
    ) !void {
        writer.print("{}\n", .{Self});
    }
};

pub const Lexer = struct {
    view: utf8.Utf8View,
    index: u32,
    rules: ArrayList(lexerRule),
    tokens: ArrayList(Token),
    tokenIndex: usize,
    lineNumber: u32,
    allocator: *mem.Allocator,

    pub fn init(allocator: *mem.Allocator, input: []const u8) !Lexer {
        // Skip the UTF-8 BOM if present
        var t = Lexer{
            .view = try utf8.Utf8View.init(input),
            .index = 0,
            .allocator = allocator,
            .rules = ArrayList(lexerRule).init(allocator),
            .tokens = ArrayList(Token).init(allocator),
            .tokenIndex = 0,
            .lineNumber = 1,
        };
        try t.registerRule("ruleWhitespace", ruleWhitespace);
        try t.registerRule("ruleList", listRules.ruleList);
        try t.registerRule("ruleAtxHeader", atxRules.ruleAtxHeader);
        try t.registerRule("ruleInline", inlineRules.ruleInline);
        try t.registerRule("ruleEOF", ruleEOF);
        return t;
    }

    pub fn deinit(l: *Lexer) void {
        l.rules.deinit();
        l.tokens.deinit();
    }

    pub fn registerRule(l: *Lexer, name: []const u8, rule: lexerRuleFn) !void {
        try l.rules.append(lexerRule{ .name = name, .func = rule });
    }

    /// Back the lexer up by one token
    pub fn backup(l: *Lexer) void {
        const offset = l.lastToken().?.startOffset - 1;
        l.index = offset;
        l.tokenIndex -= 1;
    }

    pub fn fastForward(l: *Lexer, tok: Token) void {
        l.index = tok.endOffset + 1;
        l.tokenIndex = tok.index;
    }

    /// Get the next token from the input.
    pub fn next(l: *Lexer) !?Token {
        log.Debugf("{}next: lexer pos: l.index: {} viewlen: {} l.tokenIndex: {} tokens.len: {}{}\n", .{ ttyCode(.Green), l.index, l.view.len, l.tokenIndex, l.tokens.items.len, ttyCode(.Reset) });
        if (l.tokens.items.len > 0 and l.tokenIndex < l.tokens.items.len - 1) {
            l.tokenIndex += 1;
            const lastTok = if (l.lastToken()) |tok| tok else return null;
            l.index = lastTok.endOffset + 1;
            log.Debugf("{}next: returning token from buffer: l.index: {} l.tokenIndex: {}{}\n", .{ ttyCode(.Green), l.index, l.tokenIndex, ttyCode(.Reset) });
            return lastTok;
        } else if (l.tokens.items.len > 0 and l.index == l.view.len) {
            if (l.lastToken()) |tok| {
                if (tok.ID == TokenId.EOF) {
                    return tok;
                }
            }
        }
        for (l.rules.items) |rule| {
            log.Debugf("next: trying rule: {}\n", .{rule.name});
            if (try rule.func(l)) |v| {
                log.Debugf("next: Returning token id: {} index: {} str: '{Z}' from rule: {}\n", .{ v.ID, v.index, v.string, rule.name });
                return v;
            }
        }
        return null;
    }

    /// Peek at the next token.
    pub fn peekNext(l: *Lexer) !?Token {
        log.Debugf("peekNext: peeking next token, current index: {}\n", .{l.tokenIndex});
        var indexBefore = l.index;
        var tokenIndexBefore = l.tokenIndex;
        var pNext = try l.next();
        l.index = indexBefore;
        l.tokenIndex = tokenIndexBefore;
        log.Debugf("peekNext: tokenIndex set to {}\n", .{l.tokenIndex});
        return pNext;
    }

    /// Peek at the next token that isn't whitespace.
    pub fn peekToNonWhitespace(l: *Lexer) !?Token {
        var indexBefore = l.index;
        var tokenIndexBefore = l.tokenIndex;
        var tok: ?Token = null;
        while (try l.next()) |ptok| {
            if (ptok.ID == TokenId.EOF) break;
            if (ptok.ID != TokenId.Whitespace and ptok.ID != TokenId.Newline) {
                log.Debugf("peekToNonWhitespace non whitespace {}\n", .{ptok.ID});
                tok = ptok;
                break;
            }
        }
        l.index = indexBefore;
        l.tokenIndex = tokenIndexBefore;
        return tok;
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
        }, buf.writer());
        log.Debugf("{}{}: {}{}\n", .{ ttyCode(.Magenta), msg, buf.items, ttyCode(.Reset) });
    }

    pub fn emit(l: *Lexer, tok: TokenId, startOffset: u32, endOffset: u32) !?Token {
        var str = l.view.slice(startOffset, endOffset);
        // check for diacritic
        var nEndOffset: u32 = endOffset - 1;
        if ((endOffset - startOffset) == 1 or nEndOffset < startOffset) {
            nEndOffset = startOffset;
        }
        var column: u32 = l.offsetToColumn(startOffset);
        if (tok == TokenId.EOF) {
            column = l.tokens.items[l.tokens.items.len - 1].column;
            l.lineNumber -= 1;
        }
        // check if token already emitted
        var newTok = Token{
            .index = l.tokens.items.len,
            .ID = tok,
            .startOffset = startOffset,
            .endOffset = nEndOffset,
            .string = str.bytes,
            .lineNumber = l.lineNumber,
            .column = column,
        };
        try l.tokens.append(newTok);
        l.index = endOffset;
        l.tokenIndex = l.tokens.items.len - 1;
        try l.debugPrintToken("lexer emit", l.tokens.items[l.tokenIndex]);
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
        // A whitespace character is a space (U+0020), tab (U+0009), line tabulation (U+000B).
        const runes = &[_][]const u8{
            "\u{0020}", "\u{0009}", "\u{000B}",
        };
        for (runes) |itrune|
            if (mem.eql(u8, itrune, rune))
                return true;
        return false;
    }

    /// Checks for a newline character
    pub fn isNewline(l: *Lexer, rune: []const u8) bool {
        // newline (U+000A), form feed (U+000C), or carriage return (U+000D)
        const runes = &[_][]const u8{
            "\u{000A}", "\u{000C}", "\u{000D}",
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
        if (!l.isPunctuation(rune) and !l.isWhitespace(rune) and !l.isNewline(rune)) {
            log.Debugf("isLetter have rune: {Z}\n", .{rune});
            return true;
        }
        return false;
    }

    /// Get the last token emitted, exclude peek tokens
    pub fn lastToken(l: *Lexer) ?Token {
        log.Debugf("lastToken l.tokens.items.len: {} tokenIndex: {}\n", .{ l.tokens.items.len, l.tokenIndex });
        if (l.tokens.items.len == 0) {
            return null;
        }
        return l.tokens.items[l.tokenIndex];
    }

    /// Get last token by index
    pub fn lastTokenByIndex(l: *Lexer, index: usize) ?Token {
        if (index < 0 or index > l.tokens.items.len) {
            return null;
        }
        log.Debugf("lastTokenByIndex index: {}\n", .{index});
        return l.tokens.items[index];
    }

    /// FIXME: code smell
    pub fn checkDupeToken(l: *Lexer, tok: Token) ?usize {
        for (l.tokens.items) |item| {
            if (item.ID == tok.ID and item.column == tok.column and item.startOffset == tok.startOffset and item.endOffset == tok.endOffset) {
                return item.index;
            }
        }
        return null;
    }

    /// Checks tok and tok2 to see if the columns are aligned converting tabs to spaces
    pub fn checkAlignment(l: *Lexer, tok: Token, tok2: Token) bool {
        const tokBeforePeek = if (l.lastTokenByIndex(tok2.index - 1)) |t| t else unreachable;
        const hazTabBeforePeek = if (mem.indexOf(u8, tokBeforePeek.string, "\t") != null) true else false;

        log.Debugf("checkAlignment: tokBeforePeek.index: {} string: {Z}\n", .{ tokBeforePeek.index, tokBeforePeek.string });
        log.Debugf("checkAlignment: hazTabBeforePeek: {} tok.col: {} tok2.col: {}\n", .{ hazTabBeforePeek, tok.column, tok2.column });

        if ((tok.column != tok2.column and !hazTabBeforePeek) or (hazTabBeforePeek and tok.column != tok2.column + 3)) {
            log.Debug("checkAlignment: tokens do not align");
            return false;
        }
        log.Debug("checkAlignment: tokens are in alignment!");
        return true;
    }

    /// Skip the next token
    pub fn skipNext(l: *Lexer) !void {
        log.Debug("in skipNext");
        if (try l.next()) |tok| {
            log.Debugf("skipped token id: {} index: {} str: {}\n", .{ tok.ID, tok.index, tok.string });
        }
    }
};

/// Get all the whitespace characters greedly.
pub fn ruleWhitespace(t: *Lexer) !?Token {
    var index: u32 = t.index;
    while (t.getRune(index)) |val| {
        log.Debugf("ruleWhitespace val: {Z}\n", .{val});
        if (t.isWhitespace(val)) {
            index += 1;
        } else if (t.isNewline(val)) {
            index += 1;
            return t.emit(.Newline, t.index, index);
        } else {
            break;
        }
    }
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

test "lexer: peekNext" {
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
    assert(t.lastToken().?.ID == TokenId.AtxHeader);

    if (try t.next()) |tok| {
        assert(tok.ID == TokenId.Whitespace);
    }
}

test "lexer: next after peek accross lines" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const input = "# foo\n# bar\n# baz\n";
    log.Debugf("input:\n{}-- END OF TEST --\n", .{input});

    var t = try Lexer.init(allocator, input);

    if (try t.next()) |tok| {
        assert(tok.ID == TokenId.AtxHeader);
    }

    if (try t.peekNext()) |tok| {
        assert(tok.ID == TokenId.Whitespace);
    }
    if (try t.peekNext()) |tok| {
        assert(tok.ID == TokenId.Whitespace);
    }

    assert(t.lastToken().?.ID == TokenId.AtxHeader);

    _ = try t.next();
    _ = try t.next();

    if (try t.next()) |tok| {
        log.Debugf("tok: {}\n", .{tok});
        assert(tok.ID == TokenId.Newline);
    }

    _ = try t.peekNext();
    _ = try t.peekNext();

    assert(t.lastToken().?.ID == TokenId.Newline);
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
