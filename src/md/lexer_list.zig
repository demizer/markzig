const std = @import("std");
const log = @import("log.zig");
const token = @import("token.zig");
const Lexer = @import("lexer.zig").Lexer;

pub fn ruleList(l: *Lexer) !?token.Token {
    var index: u32 = l.index;
    if (l.lastToken()) |lt| {
        if (lt.ID != token.TokenId.Whitespace) {
            log.Debugf("Last token not whitespace, got {}\n", .{lt.ID});
            return null;
        }
    }
    var hazMarker: bool = false;
    const blMarker = &[_][]const u8{ "-", "+", "*" };
    if (l.getRune(index)) |val| {
        for (blMarker) |mark| {
            if (std.mem.eql(u8, mark, val)) {
                hazMarker = true;
                break;
            }
        }
    }
    if (hazMarker) {
        // log.Debug("Found bullet list marker");
        index += 1;
    }
    if (index > l.index) {
        // log.Debug("in here yo");
        return l.emit(.BulletListMarker, l.index, index);
    }
    return null;
}
