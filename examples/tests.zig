const std = @import("std");
const ezig_templates = @import("ezig_templates");

test "hello world" {
    const Props = struct { name: [:0]const u8 };
    const props = Props{ .name = "World" };

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();

    try ezig_templates.@"hello_world.html"(Props, writer, props);

    const actual = try buf.toOwnedSliceSentinel(0);
    defer std.testing.allocator.free(actual);
    const squished_actual = try squish(std.testing.allocator, actual);
    defer std.testing.allocator.free(squished_actual);
    try std.testing.expectEqualStrings("<h1>Hello, World!</h1>", squished_actual);
}

test "list" {
    const Props = struct { items: []const [:0]const u8 };
    const items = [_][:0]const u8{ "first thing", "second thing" };
    const props: Props = .{ .items = &items };
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();

    try ezig_templates.@"list.html"(Props, writer, props);

    const actual = try buf.toOwnedSliceSentinel(0);
    defer std.testing.allocator.free(actual);
    const squished_actual = try squish(std.testing.allocator, actual);
    defer std.testing.allocator.free(squished_actual);
    try std.testing.expectEqualStrings("<ul> <li>first thing</li> <li>second thing</li> </ul>", squished_actual);
}

fn squish(allocator: std.mem.Allocator, original: [:0]const u8) ![:0]u8 {
    const State = enum { squishing, writing };
    var state: State = .squishing;
    var buf = std.ArrayList(u8).init(allocator);
    for (original) |character| {
        switch (state) {
            .squishing => {
                if (!std.ascii.isWhitespace(character)) {
                    try buf.append(character);
                    state = .writing;
                }
            },
            .writing => {
                if (std.ascii.isWhitespace(character)) {
                    try buf.append(' ');
                    state = .squishing;
                } else {
                    try buf.append(character);
                }
            },
        }
    }
    while (buf.getLastOrNull()) |last| {
        if (std.ascii.isWhitespace(last) or last == 0) {
            _ = buf.pop();
        } else {
            break;
        }
    }
    return buf.toOwnedSliceSentinel(0);
}
