const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const math = std.math;
const process = std.process;
const md = @import("md/markdown.zig").Markdown;
const log = @import("md/log.zig");
const webview = @import("webview/webview.zig");

var DEBUG = false;
var LOG_LEVEL = log.logger.Level.Error;
var LOG_DATESTAMP = true;

const Cmd = enum {
    view,
};

/// Translates markdown input_files into html, returns a slice. Caller ows the memory.
fn translate(allocator: *mem.Allocator, input_files: *std.ArrayList([]const u8)) ![]const u8 {
    var str = std.ArrayList(u8).init(allocator);
    defer str.deinit();
    const cwd = fs.cwd();
    for (input_files.items) |input_file| {
        const source = try cwd.readFileAlloc(allocator, input_file, math.maxInt(usize));
        // try stdout.print("File: {}\nSource:\n````\n{}````\n", .{ input_file, source });
        try md.renderToHtml(
            allocator,
            source,
            str.outStream(),
        );
    }
    return str.toOwnedSlice();
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args = try process.argsAlloc(allocator);
    var arg_i: usize = 1;
    var maybe_cmd: ?Cmd = null;

    var input_files = std.ArrayList([]const u8).init(allocator);

    log.config(LOG_LEVEL, LOG_DATESTAMP);

    while (arg_i < args.len) : (arg_i += 1) {
        const full_arg = args[arg_i];
        if (mem.startsWith(u8, full_arg, "--")) {
            const arg = full_arg[2..];
            if (mem.eql(u8, arg, "help")) {
                try dumpUsage(std.io.getStdOut());
                return;
            } else if (mem.eql(u8, arg, "debug")) {
                DEBUG = true;
                LOG_LEVEL = log.logger.Level.Debug;
                log.config(LOG_LEVEL, LOG_DATESTAMP);
            } else {
                log.Errorf("Invalid parameter: {}\n", .{full_arg});
                dumpStdErrUsageAndExit();
            }
        } else if (mem.startsWith(u8, full_arg, "-")) {
            const arg = full_arg[1..];
            if (mem.eql(u8, arg, "h")) {
                try dumpUsage(std.io.getStdOut());
                return;
            }
        } else {
            inline for (std.meta.fields(Cmd)) |field| {
                log.Debugf("full_arg: {} field: {}\n", .{ full_arg, field });
                if (mem.eql(u8, full_arg, field.name)) {
                    maybe_cmd = @field(Cmd, field.name);
                    log.Infof("Have command: {}\n", .{field.name});
                    break;
                    // } else {
                    //     std.debug.warn("Invalid command: {}\n", .{full_arg});
                    //     dumpStdErrUsageAndExit();
                    // }
                } else {
                    _ = try input_files.append(full_arg);
                }
            }
        }
    }

    if (args.len <= 1) {
        log.Error("No arguments given!\n");
        dumpStdErrUsageAndExit();
    }

    if (input_files.items.len == 0) {
        log.Error("No input files were given!\n");
        dumpStdErrUsageAndExit();
    }

    var html = try std.ArrayListSentineled(u8, 0).init(allocator, "");
    defer html.deinit();

    const translated: []const u8 = try translate(allocator, &input_files);
    defer allocator.free(translated);

    const yava_script =
        \\ window.onload = function() {
        \\ };
    ;

    try std.fmt.format(html.writer(),
        \\ data:text/html,
        \\ <!doctype html>
        \\ <html>
        \\ <body>
        \\ {}
        \\ </body>
        \\ <script>
        \\ {}
        \\ </script>
        \\ </html>
    , .{ translated, yava_script });

    const final_doc = mem.span(@ptrCast([*c]const u8, html.span()));
    log.Debugf("final_doc: {} type: {}\n", .{ final_doc, @typeInfo(@TypeOf(final_doc)) });

    if (maybe_cmd) |cmd| {
        switch (cmd) {
            .view => {
                var handle = webview.webview_create(1, null);
                webview.webview_set_size(handle, 1240, 1400, webview.WEBVIEW_HINT_MIN);
                webview.webview_set_title(handle, "Zig Markdown Viewer");
                webview.webview_navigate(handle, final_doc);
                webview.webview_run(handle);
                return;
            },
            else => {},
        }
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
        \\If no commands are specified, the html translated markdown is dumped to stdout.
        \\
        \\Commands:
        \\  view                  Show the translated markdown in webview.
        \\
        \\Options:
        \\  -h, --help            Dump this help text to stdout.
        \\  --debug               Show debug output.
        \\
    );
}
