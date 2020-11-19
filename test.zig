comptime {
    _ = @import("src/unicode/unicode.zig");
    _ = @import("src/md/lexer.zig");
    _ = @import("test/section_tabs.zig");
    _ = @import("test/section_atx_headings.zig");
}
