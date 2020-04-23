const std = @import("std");
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;

const stdout = &std.io.getStdOut().outStream();

pub fn atxHeader(self: *Tokenizer) !Token {
    try stdout.print("have atxHeader\n", .{});
    // if (c == '#') {
    //     return self.atxHeader();
    // }
    return Token{
        .ID = .EOF,
        .start = self.index,
        .end = undefined,
    };
}
