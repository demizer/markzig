const std = @import("std");
const time = @import("zig-time");
// pub const logger = @import("zig-log");

// var log = logger.Logger.new(std.io.getStdOut(), true);

// pub fn config(level: logger.Level, dates: bool) void {
//     log.setLevel(level);
//     if (dates) {
//         log.prefixHandler(log_rfc3330_date_handler);
//     }
// }

pub const log_level: std.log.Level = .debug;

const markzig = std.log.scoped(.markzig);

// pub fn PrefixFormat(
//     // l: *logger.Logger,
//     comptime level: std.log.Level,
//     comptime scope: @TypeOf(.EnumLiteral),
//     comptime format: []const u8,
//     args: anytype,
// ) void {
//     var local = time.Location.getLocal();
//     var now = time.now(&local);
//     var buf = std.ArrayList(u8).init(std.testing.allocator);
//     defer buf.deinit();
//     now.formatBuffer(&buf, time.RFC3339) catch unreachable;
//     l.file_stream.print("{} ", .{buf.items}) catch unreachable;
// }

// Define root.log to override the std implementation
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ switch (scope) {
        .markzig => @tagName(scope),
        else => if (@enumToInt(level) <= @enumToInt(std.log.Level.crit))
            @tagName(scope)
        else
            return,
    } ++ "): ";

    // const prefix = "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    // TODO use better method to get the filename and line number
    var config: std.debug.TTY.Config = .no_color;
    var buf = std.ArrayList(u8).init(allocator);
    const debug_info = std.debug.getSelfDebugInfo() catch return;
    var it = std.debug.StackIterator.init(@returnAddress(), null);
    var count: u8 = 0;
    var address: usize = 0;
    while (it.next()) |return_address| {
        if (count == 2) {
            address = return_address;
            break;
        }
        count += 1;
    }
    std.debug.printSourceAtAddress(debug_info, buf.outStream(), address - 1, config) catch return;

    const colPos = std.mem.indexOf(u8, buf.items[0..], ": ");
    var bufPrefix: [400]u8 = undefined;
    const prefix = std.fmt.bufPrint(bufPrefix[0..], "[{}] {} [{}]: ", .{ @tagName(level), scope_prefix, buf.items[0..colPos.?] }) catch return;
    var bufOut: [400]u8 = undefined;
    const out = std.fmt.bufPrint(bufOut[0..], format, args) catch unreachable;
    const final = std.mem.concat(allocator, u8, &[_][]const u8{ prefix, out, "\n" }) catch return;

    // Print the message to stderr, silently ignoring any errors
    const held = std.debug.getStderrMutex().acquire();
    defer held.release();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.writeAll(final) catch return;
}

pub fn Debug(comptime str: []const u8) void {
    markzig.debug("{}\n", .{str});
}

pub fn Debugf(comptime fmt: []const u8, args: anytype) void {
    markzig.debug(fmt, args);
}

pub fn Info(comptime str: []const u8) void {
    markzig.info("{}\n", .{str});
}

pub fn Infof(comptime fmt: []const u8, args: anytype) void {
    markzig.info(fmt, args);
}

pub fn Error(comptime str: []const u8) void {
    markzig.err("{}\n", .{str});
}

pub fn Errorf(comptime fmt: []const u8, args: anytype) void {
    markzig.err(fmt, args);
}

pub fn Fatal(comptime str: []const u8) void {
    markzig.crit("{}\n", .{str});
    std.os.exit(1);
}

pub fn Fatalf(comptime fmt: []const u8, args: anytype) void {
    markzig.crit(fmt, args);
    std.os.exit(1);
}
