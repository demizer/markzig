const std = @import("std");
const mem = std.mem;
const Lexer = @import("lexer.zig").Lexer;
const Token = @import("token.zig").Token;

pub fn ruleAtxHeader(l: *Lexer) !?Token {
    var index: u32 = l.index;
    while (l.getRune(index)) |val| {
        if (mem.eql(u8, "#", val)) {
            index += 1;
        } else {
            break;
        }
    }
    if (index > l.index) {
        return l.emit(.AtxHeader, l.index, index);
    }
    return null;
}
