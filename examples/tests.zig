const std = @import("std");
const ezig_templates = @import("ezig_templates");

test "hello world" {
    const Props = struct { name: [:0]const u8 };
    const props = Props{ .name = "World" };

    try testTemplate("hello_world.html", props, "<h1>Hello, World!</h1>");
}

test "quotes" {
    try testTemplate("quotes.html", .{}, "<span style=\"font-family: monospace\">\"Text\"</span>");
}

test "formatting" {
    try testTemplate("formatting.html", .{ .number = 0xf0 }, "<div>F0#</div>");
}

test "escaping" {
    try testTemplate("escaping.html", .{}, "<div>%>\"%>\\%>\"%>\\</div> <div> hello this is a long string %> </div>");
}

test "list" {
    const Props = struct { items: []const [:0]const u8 };
    const items = [_][:0]const u8{ "first thing", "second thing" };
    const props: Props = .{ .items = &items };
    try testTemplate("list.html", props, "<ul> <li>first thing</li> <li>second thing</li> </ul>");
}

test "table with partials" {
    const Row = struct {
        name: [:0]const u8,
        description: [:0]const u8,
    };
    const Props = struct { rows: []const Row };
    const rows = [_]Row{ .{ .name = "Charlie", .description = "Black and white shih tzu mix" }, .{ .name = "Tony", .description = "Tan sapsali mix" } };
    const props = Props{ .rows = &rows };

    try testTemplate(
        "table_with_partials.html",
        props,
        "<table> <tbody> <tr> <td>Charlie</td> <td>Black and white shih tzu mix</td> </tr> <tr> <td>Tony</td> <td>Tan sapsali mix</td> </tr> </tbody> </table>",
    );
}

test "layouts" {
    const Props = struct {
        title: [:0]const u8,

        pub fn writeTitle(self: *const @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.writeAll(self.title);
        }

        pub fn writeBody(self: *const @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
            const BodyProps = struct { text: [:0]const u8 };
            const body_props = BodyProps{ .text = self.title };
            try ezig_templates.@"layouts/body.html"(writer, body_props);
        }
    };
    const props: Props = .{ .title = "Ezig Templates" };

    try testTemplate(
        "layouts/layout.html",
        props,
        "<html> <head> <title> Ezig Templates </title> </head> <body> <h1>Layout Example</h1> <div>Ezig Templates</div> </body> </html>",
    );
}

pub fn writeLinkTo(writer: *std.Io.Writer, href: [:0]const u8, body: [:0]const u8) std.Io.Writer.Error!void {
    try writer.print("<a href=\"{s}\">{s}</a>", .{ href, body });
}

test "view helpers" {
    try testTemplate(
        "view_helper.html",
        .{},
        "<a href=\"https://www.ziglang.org\">Zig</a>",
    );
}

fn testTemplate(comptime template_name: []const u8, props: anytype, expected: []const u8) !void {
    var actual_writer: std.Io.Writer.Allocating = .init(std.testing.allocator);
    var squishing_transform: SquishingTransform = .init(&actual_writer.writer);

    try @field(ezig_templates, template_name)(&squishing_transform.writer, props);

    var actual = actual_writer.toArrayList();
    defer actual.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(expected, actual.items);
}

const SquishingTransform = struct {
    sink: *std.Io.Writer,
    writer: std.Io.Writer,
    state: enum { init, whitespace, writing } = .init,

    const vtable: std.Io.Writer.VTable = .{
        .drain = drain,
    };

    fn init(sink: *std.Io.Writer) @This() {
        return .{
            .sink = sink,
            .writer = .{
                .buffer = &[_]u8{},
                .vtable = &vtable,
            },
        };
    }

    pub fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *@This() = @alignCast(@fieldParentPtr("writer", w));
        var count: usize = 0;
        for (data[0 .. data.len - 1]) |datum| {
            for (datum) |c| {
                try self.drainCharacter(c);
                count += 1;
            }
        }
        for (0..splat) |_| {
            for (data[data.len - 1]) |c| {
                try self.drainCharacter(c);
                count += 1;
            }
        }
        return count;
    }

    fn drainCharacter(self: *@This(), c: u8) std.Io.Writer.Error!void {
        switch (self.state) {
            .init => {
                if (!std.ascii.isWhitespace(c)) {
                    try self.sink.writeByte(c);
                    self.state = .writing;
                }
            },
            .whitespace => {
                if (!std.ascii.isWhitespace(c)) {
                    try self.sink.writeByte(' ');
                    try self.sink.writeByte(c);
                    self.state = .writing;
                }
            },
            .writing => {
                if (std.ascii.isWhitespace(c)) {
                    self.state = .whitespace;
                } else {
                    try self.sink.writeByte(c);
                }
            },
        }
    }
};
