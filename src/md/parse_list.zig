const std = @import("std");
const mem = std.mem;
const log = @import("log.zig");
const ttyCode = log.logger.TTY.Code;
const State = @import("ast.zig").State;
const Parser = @import("parse.zig").Parser;
const Node = @import("parse.zig").Node;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;
const TokenId = @import("token.zig").TokenId;

pub fn stateBulletList(p: *Parser) !void {
    log.Debug("stateAtxHeader: START");
    var openTok = if (p.lex.lastToken()) |lt| lt else return;

    if (try p.lex.peekNext()) |tok| {
        // log.Debugf("{}stateBulletList tokenIndex: {} openTok: '{}' id: {} len: {}, tok: '{}' id: {} len: {}{}\n", .{
        //     ttyCode(.Green), p.lex.tokenIndex, openTok.string, openTok.ID, openTok.string.len,
        //     tok.string, tok.ID, tok.string.len, ttyCode(.Reset),
        // });
        if (openTok.ID != TokenId.BulletListMarker and (tok.ID != TokenId.Whitespace and tok.string.len > 4)) {
            log.Debug("Bullet list not found");
            return;
        }
    }
    log.Debugf("{}Found Bullet list!{}\n", .{ ttyCode(.Red), ttyCode(.Reset) });
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
    try p.lex.skipNext();

    // Only need to see the position for now
    var startTok = if (try p.lex.next()) |t| t else return;
    log.Debugf("{}stateBulletList startTok ID: {} String: {Z}{}\n", .{ ttyCode(.Yellow), startTok.ID, startTok.string, ttyCode(.Reset) });

    try new.Children.append(Node{
        .ID = Node.ID.ListItem,
        .Value = null,
        .PositionStart = .{ .Line = startTok.lineNumber, .Column = startTok.column, .Offset = startTok.startOffset },
        .PositionEnd = undefined,
        .Children = std.ArrayList(Node).init(p.allocator),
        .Level = 0,
    });

    var listItem: *std.ArrayList(Node) = &new.Children.items[0].Children;
    var buf = try std.ArrayListSentineled(u8, 0).init(p.allocator, startTok.string);
    defer buf.deinit();
    // log.Debugf("buf: '{Z}'\n", .{buf.span()});

    while (try p.lex.next()) |ntok| {
        log.Debugf("{}stateBulletList ntok {}{}\n", .{ ttyCode(.Magenta), ntok.ID, ttyCode(.Reset) });
        if (ntok.ID == TokenId.Whitespace) {
            log.Debug("skipping whitespace");
            continue;
        } else if (ntok.ID == TokenId.Newline) {
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
                    log.Debugf("listItem len: {} buf: '{Z}'\n", .{ listItem.items.len, buf.span() });
                    // and add the previous item as a child to the list item
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
            if (ntok.ID == TokenId.EOF) p.lex.backup();
            break;
        } else if (ntok.ID != TokenId.Newline and ntok.ID != TokenId.Whitespace) {
            try buf.appendSlice(ntok.string);
        }
    }

    // log.Debugf("before append: buf: '{Z}'\n", .{buf.span()});
    new.PositionEnd = new.Children.items[new.Children.items.len - 1].PositionEnd;
    try p.root.append(new);
    p.state = Parser.State.Start;
    // log.Debugf("index: {} viewlen: {}\n", .{ p.lex.index, p.lex.view.bytes.len });
    log.Debug("stateBulletList: END");
}
