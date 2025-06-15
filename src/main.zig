const std = @import("std");
const Template = @import("./Template.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) fatal("wrong number of arguments. 3 required, got {}", .{args.len});

    const output_file_path = args[1];
    const templates_path = args[2];

    var templates_dir = try std.fs.cwd().openDir(templates_path, .{ .iterate = true, .no_follow = true });
    defer templates_dir.close();

    var templates_walker = try templates_dir.walk(allocator);
    defer templates_walker.deinit();

    const output_file = try std.fs.cwd().createFile(output_file_path, .{});
    defer output_file.close();

    const output_file_writer = output_file.writer().any();
    try output_file_writer.writeAll("const std = @import(\"std\");\n");

    const ezig_extension = ".ezig";
    while (try templates_walker.next()) |template_entry| {
        if (template_entry.kind == .file and std.mem.endsWith(u8, template_entry.path, ezig_extension)) {
            const stat = try templates_dir.statFile(template_entry.path);
            const template_data = try templates_dir.readFileAllocOptions(allocator, template_entry.path, @intCast(stat.size), null, @alignOf(u8), 0);

            const template_name = try allocator.dupeZ(u8, template_entry.path[0 .. template_entry.path.len - ezig_extension.len]);
            defer allocator.free(template_name);

            const template = Template.init(template_name, template_data);

            try output_file_writer.writeAll("\n");
            try template.writeZigSource(output_file_writer);
        }
    }
    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
