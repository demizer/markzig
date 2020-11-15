const std = @import("std");
const time = @import("zig-time");
pub const logger = @import("zig-log");

var log = logger.Logger.init(std.io.getStdOut(), LogFormatPrefix, logger.LoggerOptions{
    .color = true,
    .fileName = true,
    .lineNumber = true,
    .timestamp = true,
    .doubleSpacing = true,
});

// This is NOT the Zig way..
//
// This code has multiple workarounds due to pending proposals and compiler bugs
//
// "ambiguity of forced comptime types" https://github.com/ziglang/zig/issues/5672
// "access to root source file for testing" https://github.com/ziglang/zig/issues/6621
pub fn LogFormatPrefix(
    // writer: anytype,
    // config: LoggerOptions,
    logr: *logger.Logger,
    scopelevel: logger.Level,
) void {
    // TODO: check windows support
    if (logr.options.timestamp) {
        var local = time.Location.getLocal();
        var now = time.now(&local);
        now.formatBuffer(logr.writer, time.RFC3339) catch return;
        logr.writer.writeByte(' ') catch return;
    }
    if (logr.options.color) {
        logr.writer.print("{}", .{logger.TTY.Code(.Reset)}) catch return;
        logr.writer.writeAll(scopelevel.color().Code()) catch return;
        logr.writer.print("[{}]", .{scopelevel.toString()}) catch return;
        logr.writer.writeAll(logger.TTY.Reset.Code()) catch return;
        logr.writer.print(" ", .{}) catch return;
    } else {
        logr.writer.print("[{s}]: ", .{scopelevel.toString()}) catch return;
    }

    // TODO use better method to get the filename and line number
    // https://github.com/ziglang/zig/issues/7106

    // TODO: allow independt fileName and lineNumber
    if (!logr.options.fileName and !logr.options.lineNumber) {
        return;
    }
    var dbconfig: std.debug.TTY.Config = .no_color;
    var lineBuf: logger.DebugInfoWriter() = .{};

    const debug_info = std.debug.getSelfDebugInfo() catch return;
    var it = std.debug.StackIterator.init(@returnAddress(), null);
    var count: u8 = 0;
    var address: usize = 0;
    while (it.next()) |return_address| {
        if (count == 3) {
            address = return_address;
            break;
        }
        count += 1;
    }
    std.debug.printSourceAtAddress(debug_info, lineBuf.writer(), address - 1, dbconfig) catch return;
    const colPos = std.mem.indexOf(u8, lineBuf.items[0..], ": ");

    if (logr.options.color) {
        logr.writer.print("{}[{}]: ", .{ logger.TTY.Code(.Reset), lineBuf.items[0..colPos.?] }) catch return;
    } else {
        logr.writer.print("[{}]: ", .{lineBuf.items[0..colPos.?]}) catch return;
    }
}

pub fn Debug(comptime str: []const u8) void {
    log.Debug("{}\n", .{str});
}

pub fn Debugf(comptime fmt: []const u8, args: anytype) void {
    log.Debug(fmt, args);
}

pub fn Info(comptime str: []const u8) void {
    log.Info("{}\n", .{str});
}

pub fn Infof(comptime fmt: []const u8, args: anytype) void {
    log.Info(fmt, args);
}

pub fn Error(comptime str: []const u8) void {
    log.Error("{}\n", .{str});
}

pub fn Errorf(comptime fmt: []const u8, args: anytype) void {
    log.Error(fmt, args);
}

pub fn Fatal(comptime str: []const u8) void {
    log.Fatal("{}\n", .{str});
    std.os.exit(1);
}

pub fn Fatalf(comptime fmt: []const u8, args: anytype) void {
    log.Fatal(fmt, args);
    std.os.exit(1);
}
