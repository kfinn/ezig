const std = @import("std");
const Template = @import("./Template.zig");

const ezig_extension = ".ezig";

pub const TemplatesWalker = struct {
    allocator: std.mem.Allocator,
    dir: std.fs.Dir,
    walker: std.fs.Dir.Walker,
    opt_last_template: ?Template = null,

    pub fn init(allocator: std.mem.Allocator, path: [:0]const u8) !@This() {
        var dir = try std.fs.cwd().openDir(path, .{ .iterate = true, .no_follow = true });
        return .{
            .allocator = allocator,
            .dir = dir,
            .walker = try dir.walk(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.opt_last_template) |*last_template| {
            last_template.deinit();
        }
        self.walker.deinit();
        self.dir.close();
        self.* = undefined;
    }

    pub fn next(self: *@This()) !?Template {
        if (self.opt_last_template) |*last_template| {
            last_template.deinit();
            self.opt_last_template = null;
        }

        while (try self.walker.next()) |walker_entry| {
            if (walker_entry.kind == .file and Template.isTemplatePath(walker_entry.path)) {
                self.opt_last_template = try Template.init(self.allocator, self.dir, walker_entry.path, walker_entry.basename);
                return self.opt_last_template;
            }
        }
        return null;
    }
};

pub const EzigTemplatesImportOptions = struct {
    path: []const u8,
    import_name: []const u8 = "ezig_templates",
};

pub fn addEzigTemplatesImport(module: *std.Build.Module, options: EzigTemplatesImportOptions) void {
    var b = module.owner;

    const ezig_depepdency = b.dependency("ezig", .{});
    const ezig_exe = b.addExecutable(.{
        .name = "ezig",
        .root_source_file = ezig_depepdency.path("src/main.zig"),
        .target = b.graph.host,
    });
    ezig_exe.root_module.addImport("ezig_lib", ezig_depepdency.module("ezig_lib"));
    const ezig_step = b.addRunArtifact(ezig_exe);
    const ezig_output = ezig_step.addOutputFileArg("ezig_templates.zig");
    ezig_step.addDirectoryArg(b.path(options.path));

    var templates_walker = TemplatesWalker.init(b.allocator, options.path) catch @panic("could not walk templates");
    defer templates_walker.deinit();

    while (templates_walker.next() catch @panic("could not walk examples templates dir")) |template| {
        ezig_step.addFileInput(b.path(b.pathJoin(&.{ options.path, template.path })));
    }

    module.addAnonymousImport(options.import_name, .{
        .root_source_file = ezig_output,
    });
}
