const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const t = b.addTest("src/md/token.zig");
    t.addPackagePath("zig-time", "lib/zig-time/src/time.zig");
    t.addPackagePath("zig-log", "lib/log.zig/src/index.zig");
    b.step("test", "Run all tests").dependOn(&t.step);

    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("mdcf", "src/main.zig");
    exe.setBuildMode(mode);
    exe.addPackagePath("zig-log", "lib/log.zig/src/index.zig");
    exe.addPackagePath("mylog", "src/log/log.zig");
    exe.addPackagePath("zig-time", "lib/zig-time/src/time.zig");
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
