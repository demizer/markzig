const std = @import("std");

pub const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    pub const Id = enum {
        invalid,
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
        return Token{
            .id =  .eof,
            .start =  self.index,
            .end =  undefined,
        };
    }
};
