const std = @import("std");

usingnamespace @import("log.zig");

const token = @import("token.zig");
const Tokenizer = @import("token.zig").Tokenizer;

pub fn ruleInline(t: *Tokenizer) !?token.Token {
    var index: u32 = t.index;
    while (t.getChar(index)) |val| {
        if (t.isCharacter(t.buffer[index])) {
            index += 1;
        } else {
            break;
        }
    }
    if (index > t.index) {
        return t.emit(.Line, t.index, index);
    }
    return null;
}
