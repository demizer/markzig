const std = @import("std");
const debug = @import("std").debug.warn;
const md = @import("markdown.zig");

pub fn main() anyerror!void {
    debug("All your base are belong to us.\n");
    debug("hi: {}\n", @typeName(md.MdParser));
    const md1 =
        \\# Here is a title
        \\## Title 2
        \\
        \\Here is a paragraph,
        \\  followed on the same line
        \\
        \\and a new paragraph
        \\
        \\##### Following title
    ;

    var md2 = md.MdParser.init(std.debug.global_allocator);
    const nodes = md2.parse(md1);

    for (nodes.toSliceConst()) |node| {
        debug("{}\n", node);
        node.print();
    }
}
