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

    addEzigTemplatesImport(examples_mod, .{ .path = "examples/templates" });

    const examples_tests = b.addTest(.{
        .root_module = examples_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const run_examples_tests = b.addRunArtifact(examples_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_examples_tests.step);
}

pub const EzigTemplatesImportOptions = struct {
    path: []const u8,
    import_name: []const u8 = "ezig_templates",
};

pub fn addEzigTemplatesImport(module: *std.Build.Module, options: EzigTemplatesImportOptions) void {
    const b = module.owner;

    const ezig_exe = b.addExecutable(.{
        .name = "examples_ezig",
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
    });

    const ezig_list_only_step = b.addRunArtifact(ezig_exe);
    ezig_list_only_step.has_side_effects = true;
    ezig_list_only_step.addArg("list");
    const ezig_list_only_output = ezig_list_only_step.addOutputFileArg("ezig_templates.txt");
    ezig_list_only_step.addDirectoryArg(b.path(options.path));

    const ezig_generate_step = b.addRunArtifact(ezig_exe);
    ezig_generate_step.addArg("generate");
    const ezig_output = ezig_generate_step.addOutputFileArg("ezig_templates.zig");
    ezig_generate_step.addDirectoryArg(b.path(options.path));
    _ = ezig_generate_step.addDepFileOutputArg("generated_templates.d");
    ezig_generate_step.addFileInput(ezig_list_only_output);

    module.addAnonymousImport(options.import_name, .{
        .root_source_file = ezig_output,
    });
}
