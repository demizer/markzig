const std = @import("std");
const testing = std.testing;

pub const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    pub const Id = enum {
        invalid,
        whitespace,
        line,
        line_ending,
        eof,
    };
};

pub const Tokenizer = struct {
    buffer: []const u8,
    index: usize,

    pub fn init(buffer: []const u8) Tokenizer {
        // Skip the UTF-8 BOM if present
        return Tokenizer{
            .buffer = buffer,
            .index = 0,
        };
    }

    pub fn next(self: *Tokenizer) Token {
        const result = Token{
            .id = .eof,
            .start = self.index,
            .end = undefined,
        };
        while (self.index < self.buffer.length) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (c) {}
        }
        return result;
    }
};

test "tabs - example1" {
    // var p - TokenStream.init(s)
    // testing.expectEqual(true, encodesTo("false", "false"));
}
