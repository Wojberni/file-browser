const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const file_browser_mod = b.addModule("file-browser", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const demo = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("examples/demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo.root_module.addImport("file-browser", file_browser_mod);

    const demo_run = b.addRunArtifact(demo);
    demo_run.step.dependOn(b.getInstallStep());
    const demo_step = b.step("demo", "Run demo");
    demo_step.dependOn(&demo_run.step);

    const tests = b.addTest(.{
        .root_source_file = b.path("tests/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("file-browser", file_browser_mod);

    const test_run = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_run.step);
}
