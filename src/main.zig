const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const math = std.math;
const process = std.process;
const debug = @import("debug.zig");
const Tokenizer = @import("md/token.zig").Tokenizer;

const Cmd = enum {
    dump,
    tokenize,
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var debug_errors = false;
    const args = try process.argsAlloc(allocator);
    var arg_i: usize = 1;
    var maybe_cmd: ?Cmd = null;

    var input_files = std.ArrayList([]const u8).init(allocator);

    while (arg_i < args.len) : (arg_i += 1) {
        const full_arg = args[arg_i];
        if (mem.startsWith(u8, full_arg, "--")) {
            const arg = full_arg[2..];
            if (mem.eql(u8, arg, "help")) {
                try dumpUsage(std.io.getStdOut());
                return;
            } else if (mem.eql(u8, arg, "debug-errors")) {
                debug_errors = true;
            } else {
                std.debug.warn("Invalid parameter: {}\n", .{full_arg});
                dumpStdErrUsageAndExit();
            }
        } else if (maybe_cmd == null) {
            inline for (std.meta.fields(Cmd)) |field| {
                if (mem.eql(u8, full_arg, field.name)) {
                    maybe_cmd = @field(Cmd, field.name);
                    std.debug.warn("Have command: {}\n", .{field.name});
                    break;
                }
            } else {
                std.debug.warn("Invalid command: {}\n", .{full_arg});
                dumpStdErrUsageAndExit();
            }
        } else {
            _ = try input_files.append(full_arg);
        }
    }

    const cmd = maybe_cmd orelse {
        std.debug.warn("Expected a command parameter\n", .{});
        dumpStdErrUsageAndExit();
    };

    switch (cmd) {
        .dump => {
            _ = try std.io.getStdOut().write(
                \\foo
                \\
            );
            return;
        },
        .tokenize => {
            const stdout = &std.io.getStdOut().outStream();
            const cwd = fs.cwd();
            for (input_files.toSliceConst()) |input_file| {
                const source = try cwd.readFileAlloc(allocator, input_file, math.maxInt(usize));
                try stdout.print("File: {}\nSource:\n````\n{}````\n", .{input_file, source});
                var tokenizer = Tokenizer.init(source);
                while (true) {
                    const token = tokenizer.next();
                    if (token.id == .eof) break;
                    try stdout.print("{}: {}\n", .{@tagName(token.id), source[token.start..token.end]});
                }
            }
            return;
        },
    }
}

fn dumpStdErrUsageAndExit() noreturn {
    dumpUsage(std.io.getStdErr()) catch {};
    process.exit(1);
}

fn dumpUsage(file: fs.File) !void {
    _ = try file.write(
        \\Usage: mdcf [command] [options] <input>
        \\
        \\Commands:
        \\  dump                 Dump translated output to stdout
        \\  tokenize             (debug) tokenize the input files
        \\
        \\Options:
        \\  --help                dump this help text to stdout
        \\  --debug-errors        show stack trace on error
        \\
    );
}
