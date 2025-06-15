const std = @import("std");
const Template = @import("./Template.zig");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    for (args) |arg| {
        std.debug.print("arg: {s}\n", .{arg});
    }

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

            var template = try Template.parse(allocator, template_name, template_data);
            defer template.deinit();

            std.debug.print("writing template: {s}\n", .{template.name});
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

test "parsing a template" {
    var template = try Template.parse(std.testing.allocator, "someTemplate",
        \\  <h1>
        \\  <%= props.page.title %>
        \\  </h1>
        \\  <ul>
        \\  <% for (props.bullets) |bullet| { %>
        \\    <li><%= bullet %></li>
        \\  <% } %>
        \\  </ul>
    );
    defer template.deinit();

    try std.testing.expectEqualStrings(template.name, "someTemplate");
    try std.testing.expectEqual(template.nodes.len, 9);
    try std.testing.expectEqualSlices(u8, template.nodes[0].text, "  <h1>\n  ");
    try std.testing.expectEqualSlices(u8, template.nodes[1].code_expression, " props.page.title ");
    try std.testing.expectEqualSlices(u8, template.nodes[2].text, "\n  </h1>\n  <ul>\n  ");
    try std.testing.expectEqualSlices(u8, template.nodes[3].code_snippet, " for (props.bullets) |bullet| { ");
    try std.testing.expectEqualSlices(u8, template.nodes[4].text, "\n    <li>");
    try std.testing.expectEqualSlices(u8, template.nodes[5].code_expression, " bullet ");
    try std.testing.expectEqualSlices(u8, template.nodes[6].text, "</li>\n  ");
    try std.testing.expectEqualSlices(u8, template.nodes[7].code_snippet, " } ");
    try std.testing.expectEqualSlices(u8, template.nodes[8].text, "\n  </ul>");

    var zig_source_builder = std.ArrayList(u8).init(std.testing.allocator);
    const writer = zig_source_builder.writer().any();
    try template.writeZigSource(writer);
    const template_zig_source = try zig_source_builder.toOwnedSliceSentinel(0);
    defer std.testing.allocator.free(template_zig_source);
}
