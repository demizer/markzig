const std = @import("std");
const mem = std.mem;
const log = @import("log.zig");
const Parser = @import("parse.zig").Parser;
const Node = @import("parse.zig").Node;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenId = @import("token.zig").TokenId;

// FIXME: should be part of the parser struct, but that would make the parse.zig file massive
// FIXME: https://github.com/ziglang/zig/issues/5132 solves this problem
pub fn stateCodeBlock(p: *Parser) !?Node {
    log.Debug("stateCodeBlock: BEGIN");
    defer log.Debug("stateCodeBlock: END");

    const openTok = if (p.lex.lastToken()) |lt| lt else return null;
    const openTokIsMinWhitespace = if (openTok.ID == TokenId.Whitespace and openTok.string.len >= 1) true else false;
    const openTokHasTabs = if ((mem.indexOf(u8, openTok.string, "\t") != null)) true else false;
    log.Debugf("openTokHasTabs: {}\n", .{openTokHasTabs});
    log.Debugf("openTokIsMinWhitespace: {}\n", .{openTokIsMinWhitespace});

    // var startTok: Token = if (p.lex.lastToken()) |ltok| ltok else return null;
    var startTok: Token = undefined;
    if (try p.lex.peekNext()) |peekTok| {
        // log.Debugf("parse block code before openTok: '{Z}' id: {} len: {}, peekTok: '{Z}' id: {} len: {}\n", .{ openTok.string, openTok.ID, openTok.string.len, peekTok.string, peekTok.ID, peekTok.string.len });
        if (peekTok.ID == TokenId.BulletListMarker or (!openTokIsMinWhitespace and !openTokHasTabs)) { //or openTok.string.len < 2) {
            log.Debug("stateCodeBlock: code block not found!");
            return null;
        }
        startTok = peekTok;
    }

    log.Debug("Found a code block!");
    try p.lex.debugPrintToken("stateCodeBlock: openTok", &openTok);
    try p.lex.debugPrintToken("stateCodeBlock: startTok", &startTok);

    var newChild = Node{
        .ID = Node.ID.CodeBlock,
        .Value = null,
        .PositionStart = Node.Position{
            .Line = openTok.lineNumber,
            .Column = openTok.column,
            .Offset = openTok.startOffset,
        },
        .PositionEnd = undefined,
        .Children = std.ArrayList(Node).init(p.allocator),
        .Level = 0,
    };

    var buf = std.ArrayListSentineled(u8, 0).initNull(p.allocator);
    defer buf.deinit();
    const strLen = p.lex.strLenWithTabConversion(openTok);
    log.Debugf("stateCodeBlock: openTok.string.len with tab conversion len: {}\n", .{strLen});
    if (strLen > startTok.column + 2) {
        log.Debug("in here yo");
        try buf.list.appendNTimes(' ', strLen - startTok.column - 2);
    } else {
        try buf.resize(0);
    }
    try buf.appendSlice(startTok.string);

    // skip the whitespace after the codeblock opening
    try p.lex.skipNext();
    var startPos = Node.Position{
        .Line = startTok.lineNumber,
        .Column = startTok.column,
        .Offset = startTok.startOffset,
    };

    var finalTok: Token = undefined;

    while (try p.lex.next()) |ntok| {
        if (ntok.column == 1 and ntok.ID == TokenId.Whitespace) {
            continue;
        }
        if (try p.lex.peekNext()) |nltok| {
            if (ntok.ID == TokenId.Newline and nltok.ID == TokenId.EOF) {
                continue;
            } else if (ntok.ID == TokenId.Newline) {
                try buf.appendSlice(ntok.string);
                continue;
            }
        }
        if (ntok.ID == TokenId.EOF) {
            log.Debug("stateCodeBlock: Found de-indent or EOF, exiting state");
            finalTok = if (p.lex.backupToNonWhitespace()) |btok| btok else return null;
            try p.lex.debugPrintToken("stateCodeBlock: finalTok: ", finalTok);
            break;
        }
        log.Debugf("stateCodeBlock: appending: '{Z}'\n", .{ntok.string});
        try buf.appendSlice(ntok.string);
    }

    try newChild.Children.append(Node{
        .ID = Node.ID.Text,
        .Value = buf.toOwnedSlice(),
        .PositionStart = startPos,
        .PositionEnd = Node.Position{
            .Line = finalTok.lineNumber,
            .Column = finalTok.column + finalTok.string.len - 1,
            .Offset = finalTok.endOffset,
        },
        .Children = std.ArrayList(Node).init(p.allocator),
        .Level = 0,
    });
    newChild.PositionEnd = newChild.Children.items[newChild.Children.items.len - 1].PositionEnd;
    try p.appendNode(newChild);
    return newChild;
}
