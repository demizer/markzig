const std = @import("std");
const time = @import("zig-time");
pub const logger = @import("zig-log");

var log = logger.Logger.new(std.io.getStdOut(), true);

pub fn config(level: logger.Level, dates: bool) void {
    log.setLevel(level);
    if (dates) {
        log.set_date_handler(log_rfc3330_date_handler);
    }
}

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

pub fn Debug(comptime str: []const u8) void {
    log.Debug(str);
}

pub fn Debugf(comptime fmt: []const u8, args: anytype) void {
    log.Debugf(fmt, args);
}

pub fn Info(comptime str: []const u8) void {
    log.Info(str);
}

pub fn Infof(comptime fmt: []const u8, args: anytype) void {
    log.Infof(fmt, args);
}

pub fn Error(comptime str: []const u8) void {
    log.Error(str);
}

pub fn Errorf(comptime fmt: []const u8, args: anytype) void {
    log.Errorf(fmt, args);
}

pub fn Fatal(comptime str: []const u8) void {
    log.Fatal(str);
    std.os.exit(1);
}

pub fn Fatalf(comptime fmt: []const u8, args: anytype) void {
    log.Fatalf(fmt, args);
    std.os.exit(1);
}
