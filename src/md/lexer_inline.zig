const std = @import("std");
const log = @import("log.zig");
const token = @import("token.zig");
const Lexer = @import("lexer.zig").Lexer;

pub fn ruleInline(l: *Lexer) !?token.Token {
    var index: u32 = l.index;
    while (l.getRune(index)) |val| {
        log.Debugf("ruleInline rune: {Z}\n", .{val});
        if (l.isLetter(val)) {
            index += 1;
        } else {
            // index -= 1;
            break;
        }
    }
    if (index > l.index) {
        // log.Debug("in here yo");
        return l.emit(.Text, l.index, index);
    }
    return null;
}
