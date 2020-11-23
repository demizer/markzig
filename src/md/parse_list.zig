const std = @import("std");
const mem = std.mem;
const log = @import("log.zig");
const ttyCode = log.logger.TTY.Code;
const Parser = @import("parse.zig").Parser;
const Node = @import("parse.zig").Node;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenId = @import("token.zig").TokenId;
const stateCodeBlock = @import("parse_codeblock.zig").stateCodeBlock;

// FIXME: should be part of the parser struct, but that would make the parse.zig file massive
// FIXME: https://github.com/ziglang/zig/issues/5132 solves this problem
pub fn stateBulletList(p: *Parser) !?Node {
    log.Debug("stateAtxHeader: START");
    defer log.Debug("stateBulletList: END");
    var openTok = if (p.lex.lastToken()) |lt| lt else return null;

    if (try p.lex.peekNext()) |tok| {
        if (openTok.ID != TokenId.BulletListMarker and (tok.ID != TokenId.Whitespace and tok.string.len > 4)) {
            log.Debug("Bullet list not found");
            return null;
        }
    }

    log.Debugf("{}Found Bullet list!{}\n", .{ ttyCode(.Yellow), ttyCode(.Reset) });
    try p.lex.skipNext();
    const startTok = if (try p.lex.next()) |t| t else return null;
    log.Debugf("{}stateBulletList startTok ID: {} String: {Z}{}\n", .{ ttyCode(.Yellow), startTok.ID, startTok.string, ttyCode(.Reset) });

    // The minimum indentation needed for subsequent lex items to be considered part of the list
    // item
    const indentMin = startTok.column - 1;

    var new = Node{
        .ID = Node.ID.BulletList,
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

    try new.Children.append(Node{
        .ID = Node.ID.ListItem,
        .Value = null,
        .PositionStart = .{ .Line = startTok.lineNumber, .Column = startTok.column, .Offset = startTok.startOffset },
        .PositionEnd = undefined,
        .Children = std.ArrayList(Node).init(p.allocator),
        .Level = 0,
    });

    var buf = try std.ArrayListSentineled(u8, 0).init(p.allocator, startTok.string);
    defer buf.deinit();

    var listItem: *std.ArrayList(Node) = &new.Children.items[0].Children;
    try listItem.append(Node{
        .ID = Node.ID.Text,
        .Value = buf.toOwnedSlice(),
        .PositionStart = Node.Position{
            .Line = startTok.lineNumber,
            .Column = startTok.column,
            .Offset = startTok.startOffset,
        },
        .PositionEnd = Node.Position{
            .Line = startTok.lineNumber,
            .Column = startTok.column + (startTok.endOffset - startTok.startOffset),
            .Offset = startTok.endOffset,
        },
        .Children = std.ArrayList(Node).init(p.allocator),
        .Level = 0,
    });
    p.childTarget = listItem;

    while (try p.lex.next()) |ntok| {
        log.Debugf("{}stateBulletList ntok {}{}\n", .{ ttyCode(.Magenta), ntok.ID, ttyCode(.Reset) });
        if (ntok.ID == TokenId.Whitespace) {
            log.Debug("skipping whitespace");
            continue;
        } else if (ntok.ID == TokenId.Newline) {
            log.Debug("stateBulletList: peek found newline");
            // See if next token would start a code block
            if (try p.lex.peekToID(TokenId.Whitespace)) |ptok| {
                if (p.lex.strLenWithTabConversion(ptok) > indentMin) {
                    log.Debugf("{}stateBulletList: found possible code block{}\n", .{ ttyCode(.Yellow), ttyCode(.Reset) });
                    p.lex.fastForward(ptok);
                    if (try stateCodeBlock(p)) |retTok| {
                        log.Debug("stateBulletList: stateCodeBlock returned a token!");
                        new.Children.items[0].PositionEnd = retTok.PositionEnd;
                        break;
                    }
                }
            }
            // Found a newline... look ahead and see if the columns line up
            log.Debug("peeking to next non-whitespace");
            if (try p.lex.peekToNonWhitespace()) |peekTok| {
                log.Debugf("peekTok.index: {} string: {Z}\n", .{ peekTok.index, peekTok.string });
                if (!p.lex.checkAlignment(startTok, peekTok)) {
                    log.Debugf("{}next non-whitespace columns not aligned {}{}\n", .{
                        ttyCode(.Green), peekTok.ID, ttyCode(.Reset),
                    });
                    break;
                } else {
                    log.Debug("next non-whitespace columns are aligned");
                    // log.Debugf("listItem len: {} buf: '{Z}'\n", .{ listItem.items.len, buf.span() });
                    try listItem.append(Node{
                        .ID = Node.ID.Text,
                        .Value = peekTok.string,
                        .PositionStart = Node.Position{
                            .Line = peekTok.lineNumber,
                            .Column = peekTok.column,
                            .Offset = peekTok.startOffset,
                        },
                        .PositionEnd = Node.Position{
                            .Line = peekTok.lineNumber,
                            .Column = peekTok.column + (peekTok.endOffset - peekTok.startOffset),
                            .Offset = peekTok.endOffset,
                        },
                        .Children = std.ArrayList(Node).init(p.allocator),
                        .Level = 0,
                    });
                    new.Children.items[0].PositionEnd = listItem.items[listItem.items.len - 1].PositionEnd;
                    buf = try std.ArrayListSentineled(u8, 0).init(p.allocator, "");
                    p.lex.fastForward(peekTok);
                    continue;
                }
            }
        }
        // Check if the next token has the same colum as the list start token
        if (ntok.ID == TokenId.EOF or !p.lex.checkAlignment(startTok, ntok)) {
            log.Debugf("{}found ({} = '{Z}') exiting {}\n", .{ ttyCode(.Red), ntok.ID, ntok.string, ttyCode(.Reset) });
            if (ntok.ID == TokenId.EOF) {
                _ = p.lex.backup().?;
            }
            break;
        } else if (ntok.ID != TokenId.Newline and ntok.ID != TokenId.Whitespace) {
            try buf.appendSlice(ntok.string);
        }
    }

    p.childTarget = null;
    new.PositionEnd = new.Children.items[new.Children.items.len - 1].PositionEnd;
    try p.appendNode(new);
    return new;
}
