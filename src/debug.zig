const warn = @import("std").debug.warn;

const dbg = true;

pub fn print(comptime fmt: []const u8, args: ...) void {
    if (dbg) {
        warn(fmt, args);
    }
}
