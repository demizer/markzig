const std = @import("std");
const mem = std.mem;
const log = @import("log.zig");
const State = @import("ast.zig").State;
const Parser = @import("parse.zig").Parser;
const Node = @import("parse.zig").Node;
const Lexer = @import("lexer.zig").Lexer;
const TokenId = @import("token.zig").TokenId;

pub fn stateCodeBlock(p: *Parser) !void {
    if (try p.lex.peekNext()) |tok| {
        var openTok = if (p.lex.lastToken()) |lt| lt else return;
        log.Debugf("parse block code before openTok: '{}' id: {} len: {}, tok: '{}' id: {} len: {}\n", .{
            openTok.string, openTok.ID, openTok.string.len,
            tok.string,     tok.ID,     tok.string.len,
        });
        var hazCodeBlockWhitespace: bool = false;
        // var hazCodeBlockWhitespaceNextToken: bool = false;
        if (openTok.ID == TokenId.Whitespace and openTok.string.len >= 1) {
            if (mem.indexOf(u8, openTok.string, "\t") != null or openTok.string.len >= 4) {
                hazCodeBlockWhitespace = true;
                // } else if (try p.lex.peekNext()) |peekTok| {
                //     if (peekTok.ID == TokenId.Whitespace and peekTok.string.len >= 1) {
                //         if (mem.indexOf(u8, peekTok.string, "\t") != null or peekTok.string.len >= 4) {
                //             hazCodeBlockWhitespaceNextToken = true;
                //         }
                //     }
            }
        }
        if (hazCodeBlockWhitespace and tok.ID == TokenId.Text) {
            log.Debug("Found a code block!");
            try p.lex.debugPrintToken("stateCodeBlock openTok", &openTok);
            try p.lex.debugPrintToken("stateCodeBlock tok", &tok);
            p.state = Parser.State.CodeBlock;
            var newChild = Node{
                .ID = Node.ID.CodeBlock,
                .Value = openTok.string,
                .PositionStart = Node.Position{
                    .Line = openTok.lineNumber,
                    .Column = openTok.column,
                    .Offset = openTok.startOffset,
                },
                .PositionEnd = undefined,
                .Children = std.ArrayList(Node).init(p.allocator),
                .Level = 0,
            };

            var buf = try std.ArrayListSentineled(u8, 0).init(p.allocator, tok.string);
            defer buf.deinit();

            // skip the whitespace after the codeblock opening
            try p.lex.skipNext();
            var startPos = Node.Position{
                .Line = tok.lineNumber,
                .Column = tok.column,
                .Offset = tok.startOffset,
            };

            while (try p.lex.next()) |ntok| {
                // if (ntok.ID == TokenId.Whitespace and mem.eql(u8, ntok.string, "\n")) {
                if (ntok.ID == TokenId.Whitespace and ntok.column == 1) {
                    continue;
                }
                if (ntok.ID == TokenId.EOF) {
                    // FIXME: loop until de-indent
                    // FIXME: blanklines or eof should cause the state to exit
                    try p.lex.debugPrintToken("stateCodeBlock ntok", &ntok);
                    log.Debug("Found a newline, exiting state");
                    try buf.appendSlice(ntok.string);
                    try newChild.Children.append(Node{
                        .ID = Node.ID.Text,
                        .Value = buf.toOwnedSlice(),
                        .PositionStart = startPos,
                        .PositionEnd = Node.Position{
                            .Line = ntok.lineNumber,
                            .Column = ntok.column,
                            .Offset = ntok.endOffset - 1,
                        },
                        .Children = std.ArrayList(Node).init(p.allocator),
                        .Level = 0,
                    });
                    break;
                }
                try buf.appendSlice(ntok.string);
            }

            newChild.PositionEnd = newChild.Children.items[newChild.Children.items.len - 1].PositionEnd;
            // p.lex.index = newChild.PositionEnd.Offset;
            try p.root.append(newChild);
            p.state = Parser.State.Start;
        }
    }
    log.Debug("stateCodeBlock exit");
}
