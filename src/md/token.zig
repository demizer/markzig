const std = @import("std");
const test_util = @import("test_util.zig");
const testing = std.testing;
const mem = std.mem;

const ArrayList = std.ArrayList;

const atxHeader = @import("token_atx_heading.zig").atxHeader;

pub const TokenId = enum {
    Invalid,
    Whitespace,
    Line,
    LineEnding,
    EOF,
};

pub const Token = struct {
    ID: ?TokenId = null,
    start: ?usize = null,
    end: ?usize = null,
};

const stdout = &std.io.getStdOut().outStream();

const tokenRule = fn (tokenizer: *Tokenizer) anyerror!Token;

pub const Tokenizer = struct {
    buffer: []const u8,
    index: usize,
    rules: ArrayList(tokenRule),

    pub fn init(allocator: *mem.Allocator, buffer: []const u8) Tokenizer {
        // Skip the UTF-8 BOM if present
        var t = Tokenizer{
            .buffer = buffer,
            .index = 0,
            .rules = ArrayList(tokenRule).init(allocator),
        };
        t.registerRule(atxHeader);
        return t;
    }

    pub fn registerRule(self: *Tokenizer, rule: tokenRule) void {
        self.rules.append(rule) catch unreachable;
    }

    pub fn next(self: *Tokenizer) !Token {
        var result = Token{};
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            if (std.ascii.isPrint(c)) {
                try stdout.print("have char: {c}\n", .{c});
            } else {
                try stdout.print("have char: {}\n", .{c});
            }
            for (self.rules.span()) |rule| {
                return try rule(self);
            }
        }
        return result;
    }
};

// test "tabs - example1" {
//     // var p - TokenStream.init(s)
//     // testing.expectEqual(true, encodesTo("false", "false"));
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     const allocator = &arena.allocator;
//     const stdout = &std.io.getStdOut().outStream();
//     const out = test_util.getTest(allocator, 1);
//     try stdout.print("test: {}\n", .{out});
//     // var p = TokenStream.init(out);
//     // checkNext(&p, .Whitespace);
//     // checkNext(&p, .Line);
//     // checkNext(&p, .LineEnding);
//     // checkNext(&p, .EOF);
//     // testing.expect((try p.next()) == null);
// }

test "atx headings - example 32" {
    // var p - TokenStream.init(s)
    // testing.expectEqual(true, encodesTo("false", "false"));
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;
    // const stdout = &std.io.getStdOut().outStream();
    const out = try test_util.getTest(allocator, 32);
    try stdout.print("test: {}\n", .{out});
    var p = Tokenizer.init(allocator, out);
    while (true) {
        var t = try p.next();
        if (t.ID) |tokenId| {
            if (tokenId == TokenId.EOF) {
                try stdout.print("breaking yo {}\n", .{tokenId});
                break;
            }
        }
    }
    // checkNext(&p, .Whitespace);
    // checkNext(&p, .Line);
    // checkNext(&p, .LineEnding);
    // checkNext(&p, .EOF);
    // testing.expect((try p.next()) == null);
}
