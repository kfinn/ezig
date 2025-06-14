const std = @import("std");
const Template = @import("./Template.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{});
    const allocator = gpa.allocator();
    _ = Template.parse(allocator, "");

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!
}

test "parsing a template" {
    var template = try Template.parse(std.testing.allocator, "some_template",
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

    const templateZigSource = try template.toZigSource();
    defer std.testing.allocator.free(templateZigSource);

    std.debug.print("source: \n{s}", .{templateZigSource});
}
