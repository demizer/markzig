const std = @import("std");

const log = @import("log.zig");
const Token = @import("token.zig").Token;
const Tokenizer = @import("token.zig").Tokenizer;

pub fn atxHeader(tok: *Tokenizer) !Token {
    const c = tok.buffer[tok.index];
    if (c == '#') {
        // log.debug("have atxHeader\n");
        // log.debugf("time {}\n", .{std.time.timestamp()});
    }
    // while (self.index < self.buffer.len) : (self.index += 1) {
    //     try stdout.print("have char: {c}\n", .{c});
    return Token{
        .ID = .EOF,
        .start = tok.index,
        .end = undefined,
    };
}
