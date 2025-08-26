const std = @import("std");

const TemplatesWalker = @import("TemplatesWalker.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    std.debug.assert(args.skip());
    const command = args.next() orelse fatal("Requires a command. Expected list or generate.", .{});
    if (std.mem.eql(u8, command, "list")) {
        try list(allocator, &args);
    } else if (std.mem.eql(u8, command, "generate")) {
        try generate(allocator, &args);
    } else {
        fatal("Unkonwn command: {s}. Expected list or generate.\n", .{command});
    }

    return std.process.cleanExit();
}

fn list(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !void {
    const output_file_path = args.next() orelse fatal("Missing output file argument.", .{});
    const templates_path = args.next() orelse fatal("Missing templates argument.", .{});

    const output_file = try std.fs.cwd().createFile(output_file_path, .{});
    defer output_file.close();

    var output_file_buffer: [1024]u8 = undefined;
    var output_file_writer = output_file.writer(&output_file_buffer);
    const output_writer = &output_file_writer.interface;

    var templates_walker = try TemplatesWalker.init(allocator, templates_path);
    defer templates_walker.deinit();

    while (try templates_walker.next()) |template| {
        try output_writer.print("{s}\n", .{template.path});
    }
    try output_writer.flush();
}

fn generate(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !void {
    const output_file_path = args.next() orelse fatal("Missing output file argument.", .{});
    const templates_path = args.next() orelse fatal("Missing templates argument.", .{});
    const dependencies_file_path = args.next() orelse fatal("Missing dependencies argument", .{});

    const output_file = try std.fs.cwd().createFile(output_file_path, .{});
    defer output_file.close();

    var output_file_buffer: [1024]u8 = undefined;
    var output_file_writer = output_file.writer(&output_file_buffer);
    const output_writer = &output_file_writer.interface;

    var templates_walker = try TemplatesWalker.init(allocator, templates_path);
    defer templates_walker.deinit();

    const dependencies_file = try std.fs.cwd().createFile(dependencies_file_path, .{});
    defer dependencies_file.close();

    var dependencies_file_buffer: [1024]u8 = undefined;
    var dependencies_file_writer = dependencies_file.writer(&dependencies_file_buffer);
    const dependencies_writer = &dependencies_file_writer.interface;

    try output_writer.writeAll("const std = @import(\"std\");\n\n");
    try dependencies_writer.writeAll("ezig_templates:");

    while (try templates_walker.next()) |template| {
        try template.writeZigSource(output_writer);
        try output_writer.writeByte('\n');

        try dependencies_writer.print(" {s}/{s}", .{ templates_path, template.path });
    }

    try dependencies_writer.flush();
    try output_writer.flush();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
