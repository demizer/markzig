const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const math = std.math;
const json = std.json;
const ChildProcess = std.ChildProcess;

const log = @import("../src/md/log.zig");
const translate = @import("../src/md/translate.zig");
const Node = @import("../src/md/parse.zig").Node;

const TestError = error{
    TestNotFound,
    CouldNotCreateTempDirectory,
    DockerRunFailed,
};

pub const TestKey = enum {
    markdown,
    html,
};

const ValidationOutStream = struct {
    const Self = @This();

    expected_remaining: []const u8,

    pub const OutStream = std.io.OutStream(*Self, Error, write);
    pub const Error = error{DifferentData};

    fn init(exp: []const u8) Self {
        return .{
            .expected_remaining = exp,
        };
    }

    pub fn outStream(self: *Self) OutStream {
        return .{ .context = self };
    }

    fn write(self: *Self, bytes: []const u8) Error!usize {
        if (self.expected_remaining.len < bytes.len) {
            std.debug.warn(
                \\====== expected this output: =========
                \\{}
                \\======== instead found this: =========
                \\{}
                \\======================================\n
            , .{
                self.expected_remaining,
                bytes,
            });
            return error.DifferentData;
        }
        if (!mem.eql(u8, self.expected_remaining[0..bytes.len], bytes)) {
            std.debug.warn(
                \\====== expected this output: =========
                \\{}
                \\======== instead found this: =========
                \\{}
                \\======================================\n
            , .{
                self.expected_remaining[0..bytes.len],
                bytes,
            });
            return error.DifferentData;
        }
        self.expected_remaining = self.expected_remaining[bytes.len..];
        return bytes.len;
    }
};

/// Caller owns returned memory
pub fn getTest(allocator: *mem.Allocator, number: i32, key: TestKey) ![]const u8 {
    const cwd = fs.cwd();
    // path is relative to test.zig in the project root
    const source = try cwd.readFileAlloc(allocator, "test/spec/commonmark_spec_0.29.json", math.maxInt(usize));
    defer allocator.free(source);
    var json_parser = std.json.Parser.init(allocator, true);
    defer json_parser.deinit();
    var json_tree = try json_parser.parse(source);
    defer json_tree.deinit();
    const stdout = &std.io.getStdOut().outStream();
    for (json_tree.root.Array.items) |value, i| {
        var example_num = value.Object.get("example").?.Integer;
        if (example_num == number) {
            return try allocator.dupe(u8, value.Object.get(@tagName(key)).?.String);
        }
    }
    return TestError.TestNotFound;
}

pub fn mktmp(allocator: *mem.Allocator) ![]const u8 {
    const cwd = try fs.path.resolve(allocator, &[_][]const u8{"."});
    defer allocator.free(cwd);
    var out = try exec(allocator, cwd, true, &[_][]const u8{ "mktemp", "-d" });
    defer allocator.free(out.stdout);
    defer allocator.free(out.stderr);
    // defer allocator.free(out);
    log.Debugf("mktemp return: {}\n", .{out});
    return allocator.dupe(u8, std.mem.trim(u8, out.stdout, &std.ascii.spaces));
}

pub fn writeFile(allocator: *mem.Allocator, absoluteDirectory: []const u8, fileName: []const u8, contents: []const u8) ![]const u8 {
    var filePath = try fs.path.join(allocator, &[_][]const u8{ absoluteDirectory, fileName });
    log.Debugf("writeFile path: {}\n", .{filePath});
    const file = try std.fs.createFileAbsolute(filePath, .{});
    defer file.close();
    try file.writeAll(contents);
    return filePath;
}

pub fn writeJson(allocator: *mem.Allocator, tempDir: []const u8, name: []const u8, value: anytype) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try json.stringify(value, json.StringifyOptions{
        .whitespace = .{
            .indent = .{ .Space = 4 },
            .separator = true,
        },
    }, buf.outStream());
    return writeFile(allocator, tempDir, name, buf.items);
}

fn exec(allocator: *mem.Allocator, cwd: []const u8, expect_0: bool, argv: []const []const u8) !ChildProcess.ExecResult {
    const max_output_size = 100 * 1024;
    const result = ChildProcess.exec(.{
        .allocator = allocator,
        .argv = argv,
        .cwd = cwd,
        .max_output_bytes = max_output_size,
    }) catch |err| {
        std.debug.warn("The following command failed:\n", .{});
        // printCmd(cwd, argv);
        return err;
    };
    // switch (result.term) {
    //     .Exited => |code| {
    //         if ((code != 0) == expect_0) {
    //             std.debug.warn("The following command exited with error code {}:\n", .{code});
    //             // printCmd(cwd, argv);
    //             std.debug.warn("stderr:\n{}\n", .{result.stderr});
    //             return error.CommandFailed;
    //         }
    //     },
    //     else => {
    //         std.debug.warn("The following command terminated unexpectedly:\n", .{});
    //         // printCmd(cwd, argv);
    //         std.debug.warn("stderr:\n{}\n", .{result.stderr});
    //         return error.CommandFailed;
    //     },
    // }
    return result;
}

pub fn debugPrintExecCommand(allocator: *mem.Allocator, arry: [][]const u8) !void {
    var cmd_buf = std.ArrayList(u8).init(allocator);
    defer cmd_buf.deinit();
    for (arry) |a| {
        try cmd_buf.appendSlice(a);
        try cmd_buf.append(' ');
    }
    log.Debugf("exec cmd: {}\n", .{cmd_buf.items});
}

pub fn dockerRunJsonDiff(allocator: *mem.Allocator, actualJson: []const u8, expectJson: []const u8) !void {
    const cwd = try fs.path.resolve(allocator, &[_][]const u8{"."});
    defer allocator.free(cwd);
    var filemount = try std.mem.concat(allocator, u8, &[_][]const u8{ actualJson, ":", actualJson });
    defer allocator.free(filemount);
    var file2mount = try std.mem.concat(allocator, u8, &[_][]const u8{ expectJson, ":", expectJson });
    defer allocator.free(file2mount);

    // The long way around until there is a better way to compare json in Zig
    var cmd = &[_][]const u8{ "docker", "run", "-t", "-v", filemount, "-v", file2mount, "-w", cwd, "--rm", "bwowk/json-diff", "-C", expectJson, actualJson };
    try debugPrintExecCommand(allocator, cmd);

    var diff = try exec(allocator, cwd, true, cmd);
    if (diff.term.Exited != 0) {
        log.Errorf("docker run failed:\n{}\n", .{diff.stdout});
        return error.DockerRunFailed;
    }
}

/// compareJsonExpect tests parser output against a json test file containing the expected output
/// - expected: The expected json output. Use @embedFile()!
/// - value: The value to test against the expected json. This will be marshaled to json.
/// - returns: An error or optional: null (on success) or "value" encoded as json on compare failure.
pub fn compareJsonExpect(allocator: *mem.Allocator, expected: []const u8, value: anytype) !?[]const u8 {
    // check with zig stream validator
    var dumpBuf = std.ArrayList(u8).init(allocator);
    defer dumpBuf.deinit();

    var stringyOpts = json.StringifyOptions{
        .whitespace = .{
            .indent = .{ .Space = 4 },
            .separator = true,
        },
    };

    // human readable diff
    var tempDir = try mktmp(allocator);
    defer allocator.free(tempDir);

    var expectJsonPath = try writeFile(allocator, tempDir, "expect.json", expected);
    defer allocator.free(expectJsonPath);

    var actualJsonPath = try writeJson(allocator, tempDir, "actual.json", value);
    defer allocator.free(actualJsonPath);

    // FIXME: replace with zig json diff
    dockerRunJsonDiff(allocator, actualJsonPath, expectJsonPath) catch |err2| {
        try json.stringify(value, stringyOpts, dumpBuf.outStream());
        return dumpBuf.toOwnedSlice();
    };
    return null;
}

/// compareHtmlExpect tests parser output against a json test file containing the expected output
/// - expected: The expected html output. Use @embedFile()!
/// - value: The translated parser output.
/// - dumpHtml: If true, only the json value of "value" will be dumped to stdout.
pub fn compareHtmlExpect(allocator: *std.mem.Allocator, expected: []const u8, value: *std.ArrayList(Node)) !?[]const u8 {
    var vos = ValidationOutStream.init(expected);
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try translate.markdownToHtml(value, buf.outStream());
    _ = vos.outStream().write(buf.items) catch |err| {
        return buf.items;
    };
    return null;
}

pub fn dumpTest(input: []const u8) void {
    std.debug.warn("{}", .{"\n"});
    log.Debugf("test:\n{}-- END OF TEST --\n", .{input});
}
