// MIT License

// Copyright (c) 2018 Jimmi Holst Christensen

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// From https://github.com/TM35-Metronome/metronome
//
const std = @import("std");

const mem = std.mem;
const testing = std.testing;

const log = @import("../md/log.zig");

test "Utf8View Index" {
    const s = try Utf8View.init("noël n");
    var it = s.iterator();

    testing.expect(std.mem.eql(u8, "n", it.nextCodepointSlice().?));

    testing.expect(std.mem.eql(u8, "o", it.peek(1)));
    testing.expect(std.mem.eql(u8, "oë", it.peek(2)));
    testing.expect(std.mem.eql(u8, "oël", it.peek(3)));
    testing.expect(std.mem.eql(u8, "oël ", it.peek(4)));
    testing.expect(std.mem.eql(u8, "oël n", it.peek(10)));

    testing.expect(std.mem.eql(u8, "o", it.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "ë", it.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "l", it.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, " ", it.nextCodepointSlice().?));
    testing.expect(std.mem.eql(u8, "n", it.nextCodepointSlice().?));
    testing.expect(it.nextCodepointSlice() == null);

    testing.expect(std.mem.eql(u8, "n", s.index(0).?));
    testing.expect(std.mem.eql(u8, "ë", s.index(2).?));
    testing.expect(std.mem.eql(u8, "o", s.index(1).?));
    testing.expect(std.mem.eql(u8, "l", s.index(3).?));

    testing.expect(std.mem.eql(u8, &[_]u8{}, it.peek(1)));
}

/// Improved Utf8View which also keeps track of the length in codepoints
pub const Utf8View = struct {
    bytes: []const u8,
    len: usize,

    pub fn init(str: []const u8) !Utf8View {
        return Utf8View{
            .bytes = str,
            .len = try utf8Len(str),
        };
    }

    /// Returns the codepoint at i. Returns null if i is greater than the length of the view.
    pub fn index(view: Utf8View, i: usize) ?[]const u8 {
        if (i >= view.len) {
            return null;
        }
        var y: usize = 0;
        var it = view.iterator();
        var rune: ?[]const u8 = null;
        while (y < i + 1) : (y += 1) if (it.nextCodepointSlice()) |r| {
            rune = r;
        };
        if (rune) |nrune|
            _ = std.unicode.utf8Decode(nrune) catch unreachable;
        return rune;
    }

    pub fn slice(view: Utf8View, start: usize, end: usize) Utf8View {
        var len: usize = 0;
        var i: usize = 0;
        var it = view.iterator();
        while (i < start) : (i += 1)
            len += @boolToInt(it.nextCodepointSlice() != null);

        const start_i = it.i;
        while (i < end) : (i += 1)
            len += @boolToInt(it.nextCodepointSlice() != null);

        return .{
            .bytes = view.bytes[start_i..it.i],
            .len = len,
        };
    }

    pub fn iterator(view: Utf8View) std.unicode.Utf8Iterator {
        return std.unicode.Utf8View.initUnchecked(view.bytes).iterator();
    }
};

/// Given a string of words, this function will split the string into lines where
/// a maximum of `max_line_len` characters can occure on each line.
pub fn splitIntoLines(allocator: *mem.Allocator, max_line_len: usize, string: Utf8View) !Utf8View {
    var res = std.ArrayList(u8).init(allocator);
    errdefer res.deinit();

    // A decent estimate that will most likely ensure that we only do one allocation.
    try res.ensureCapacity(string.len + (string.len / max_line_len) + 1);

    var curr_line_len: usize = 0;
    var it = mem.tokenize(string.bytes, " \n");
    while (it.next()) |word_bytes| {
        const word = Utf8View.init(word_bytes) catch unreachable;
        const next_line_len = word.len + curr_line_len + (1 * @boolToInt(curr_line_len != 0));
        if (next_line_len > max_line_len) {
            try res.appendSlice("\n");
            try res.appendSlice(word_bytes);
            curr_line_len = word.len;
        } else {
            if (curr_line_len != 0)
                try res.appendSlice(" ");
            try res.appendSlice(word_bytes);
            curr_line_len = next_line_len;
        }
    }

    return Utf8View.init(res.toOwnedSlice()) catch unreachable;
}

fn utf8Len(s: []const u8) !usize {
    var res: usize = 0;
    var i: usize = 0;
    while (i < s.len) : (res += 1) {
        if (std.unicode.utf8ByteSequenceLength(s[i])) |cp_len| {
            if (i + cp_len > s.len) {
                return error.InvalidUtf8;
            }

            if (std.unicode.utf8Decode(s[i .. i + cp_len])) |_| {} else |_| {
                return error.InvalidUtf8;
            }
            i += cp_len;
        } else |err| {
            return error.InvalidUtf8;
        }
    }
    return res;
}
