const std = @import("std");
const log = @import("log.zig");
const token = @import("token.zig");
const Lexer = @import("lexer.zig").Lexer;

pub fn ruleInline(l: *Lexer) !?token.Token {
    var index: u32 = l.index;
    while (l.getRune(index)) |val| {
        if (l.isLetter(val)) {
            index += 1;
        } else {
            break;
        }
    }
    if (index > l.index) {
        //     // log.Debug("in here yo");
        //     log.Debugf("foo: {}\n", .{l.index});
        // if (true) {
        //     @panic("boo!");
        // }
        return l.emit(.Text, l.index, index);
    }
    return null;
}
