const std = @import("std");
const mem = std.mem;
const io = std.io;
const parser = @import("parse.zig");
const translate = @import("translate.zig");

pub const Markdown = struct {
    pub fn renderToHtml(allocator: *mem.Allocator, input: []const u8, out: var) !void {
        var p = parser.Parser.init(allocator);
        defer p.deinit();
        try p.parse(input);
        try translate.markdownToHtml(
            allocator,
            p,
            out,
        );
    }
};
