const std = @import("std");
const Template = @import("./Template.zig");

const ezig_extension = ".ezig";

allocator: std.mem.Allocator,
dir: std.fs.Dir,
walker: std.fs.Dir.Walker,
opt_last_template: ?Template = null,

pub fn init(allocator: std.mem.Allocator, path: []const u8) !@This() {
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
            self.opt_last_template = Template.init(self.dir, walker_entry.path);
            return self.opt_last_template;
        }
    }
    return null;
}
