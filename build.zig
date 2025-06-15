const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ezig",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const examples_mod = b.createModule(.{
        .root_source_file = b.path("examples/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const examples_ezig_exe = b.addExecutable(.{ .name = "examples_ezig", .root_source_file = b.path("src/main.zig"), .target = b.graph.host });
    const examples_ezig_step = b.addRunArtifact(examples_ezig_exe);
    const examples_ezig_output = examples_ezig_step.addOutputFileArg("ezig_templates.zig");
    examples_ezig_step.addDirectoryArg(b.path("examples/templates"));

    examples_mod.addAnonymousImport("ezig_templates", .{
        .root_source_file = examples_ezig_output,
    });

    const examples_tests = b.addTest(.{
        .root_module = examples_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const run_examples_tests = b.addRunArtifact(examples_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_examples_tests.step);
}
