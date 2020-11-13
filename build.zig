const std = @import("std");
const Builder = @import("std").build.Builder;

fn addWebviewDeps(exe: *std.build.LibExeObjStep, webviewObjStep: *std.build.Step) void {
    exe.step.dependOn(webviewObjStep);
    exe.addIncludeDir("src/webview");
    exe.addLibPath("/usr/lib");
    exe.addObjectFile("src/webview/webview.o");
    exe.linkSystemLibrary("c++");
    exe.linkSystemLibrary("gtk+-3.0");
    exe.linkSystemLibrary("webkit2gtk-4.0");
}

pub fn build(b: *Builder) void {
    {
        // b.verbose_cc = true;
        const mode = b.standardReleaseOptions();
        const mdView = b.addExecutable("mdv", "src/main.zig");
        mdView.setBuildMode(mode);
        mdView.addPackagePath("zig-log", "lib/log.zig/src/index.zig");
        mdView.addPackagePath("mylog", "src/log/log.zig");
        mdView.addPackagePath("zig-time", "lib/zig-time/src/time.zig");
        mdView.c_std = Builder.CStd.C11;
        const webviewObjStep = WebviewLibraryStep.create(b);
        addWebviewDeps(mdView, &webviewObjStep.step);
        mdView.install();
        const run_cmd = mdView.run();
        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const mdTest = b.addTest("test.zig");
        mdTest.addPackagePath("zig-time", "lib/zig-time/src/time.zig");
        mdTest.addPackagePath("zig-log", "lib/log.zig/src/index.zig");
        b.step("test", "Run all tests").dependOn(&mdTest.step);
    }
}

const WebviewLibraryStep = struct {
    builder: *std.build.Builder,
    step: std.build.Step,

    fn create(builder: *std.build.Builder) *WebviewLibraryStep {
        const self = builder.allocator.create(WebviewLibraryStep) catch unreachable;
        self.* = init(builder);
        return self;
    }

    fn init(builder: *std.build.Builder) WebviewLibraryStep {
        return WebviewLibraryStep{
            .builder = builder,
            .step = std.build.Step.init(std.build.Step.Id.LibExeObj, "Webview Library Compile", builder.allocator, make),
        };
    }

    fn make(step: *std.build.Step) !void {
        const self = @fieldParentPtr(WebviewLibraryStep, "step", step);
        const libs = std.mem.trim(u8, try self.builder.exec(
            &[_][]const u8{ "pkg-config", "--cflags", "--libs", "gtk+-3.0", "webkit2gtk-4.0" },
        ), &std.ascii.spaces);

        var cmd = std.ArrayList([]const u8).init(self.builder.allocator);
        defer cmd.deinit();

        try cmd.append("zig");
        try cmd.append("c++");
        // try cmd.append("--version");
        // try cmd.append("-print-search-dirs");
        try cmd.append("-v");
        try cmd.append("-c");
        try cmd.append("src/webview/webview.cc");
        try cmd.append("-DWEBVIEW_GTK");
        try cmd.append("-std=c++11");
        var line_it = std.mem.tokenize(libs, " ");
        while (line_it.next()) |item| {
            try cmd.append(item);
        }
        try cmd.append("-o");
        try cmd.append("src/webview/webview.o");

        _ = std.mem.trim(u8, try self.builder.exec(cmd.items), &std.ascii.spaces);
    }
};
