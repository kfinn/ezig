const std = @import("std");
const ezig_lib = @import("ezig_lib");
const Template = ezig_lib.Template;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) fatal("wrong number of arguments. 3 required, got {}", .{args.len});

    const output_file_path = args[1];
    const templates_path = args[2];

    var templates_walker = try ezig_lib.TemplatesWalker.init(allocator, templates_path);
    defer templates_walker.deinit();

    const output_file = try std.fs.cwd().createFile(output_file_path, .{});
    defer output_file.close();

    const output_file_writer = output_file.writer().any();
    try output_file_writer.writeAll("const std = @import(\"std\");\n");

    while (try templates_walker.next()) |template| {
        try output_file_writer.writeByte('\n');
        try template.writeZigSource(output_file_writer);
    }
    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
