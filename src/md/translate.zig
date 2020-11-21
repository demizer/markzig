const std = @import("std");
const parser = @import("parse.zig");
const Node = @import("parse.zig").Node;

pub fn markdownToHtml(nodeList: *std.ArrayList(Node), writer: anytype) !void {
    for (nodeList.items) |item| {
        try parser.Node.htmlStringify(
            item,
            parser.Node.StringifyOptions{
                .whitespace = .{
                    .indent = .{ .Space = 4 },
                    .separator = true,
                },
            },
            writer,
        );
    }
}
