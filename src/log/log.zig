const std = @import("std");
const logger = @import("zig-log");

pub var log = logger.Logger.new(std.io.getStdOut(), true);

pub fn log_rfc3330_date_handler(
    l: *logger.Logger,
) void {
    var local = time.Location.getLocal();
    var now = time.now(&local);
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    now.formatBuffer(&buf, time.RFC3339) catch unreachable;
    l.file_stream.print("{} ", .{buf.items}) catch unreachable;
}

pub fn use_rfc3339_date_handler() void {
    log.set_date_handler(log_rfc3330_date_handler);
}
