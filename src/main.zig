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

test "parsing a simple template" {
    var template = try Template.parse(std.testing.allocator, "test template", "<h1><%= page.title %></h1>");
    defer template.deinit();

    try std.testing.expect(template.nodes.len == 3);
    try std.testing.expect(std.mem.eql(u8, template.nodes[0].text, "<h1>"));
    try std.testing.expect(std.mem.eql(u8, template.nodes[1].code_expression, " page.title "));
    try std.testing.expect(std.mem.eql(u8, template.nodes[2].text, "</h1>"));

    const templateZigSource = try template.toZigSource();
    defer std.testing.allocator.free(templateZigSource);

    std.debug.print("source: \n{s}", .{templateZigSource});
}
