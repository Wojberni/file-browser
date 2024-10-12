const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Vaxis dependency for GUI
    const vaxis_dep = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });
    // file browser module imported in later steps
    const file_browser_mod = b.addModule("file-browser", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // zig build demo
    const demo = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("examples/demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo.root_module.addImport("file-browser", file_browser_mod);

    const demo_run = b.addRunArtifact(demo);
    demo_run.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        demo_run.addArgs(args);
    }
    const demo_step = b.step("demo", "Run demo");
    demo_step.dependOn(&demo_run.step);

    // zig build test
    const tests = b.addTest(.{
        .root_source_file = b.path("tests/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("file-browser", file_browser_mod);

    const test_run = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_run.step);

    // zig build gui
    const gui = b.addExecutable(.{
        .name = "gui",
        .root_source_file = b.path("gui/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    gui.root_module.addImport("vaxis", vaxis_dep.module("vaxis"));
    gui.root_module.addImport("file-browser", file_browser_mod);

    const gui_run = b.addRunArtifact(gui);
    gui_run.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        gui_run.addArgs(args);
    }
    const gui_step = b.step("gui", "Run GUI");
    gui_step.dependOn(&gui_run.step);
    
    // zig build gui-artifact
    const gui_artifact = b.addInstallArtifact(gui, .{});
    gui_artifact.step.dependOn(b.getInstallStep());
    const gui_artifact_step = b.step("gui-artifact", "Generate GUI artifact");
    gui_artifact_step.dependOn(&gui_artifact.step);
}
