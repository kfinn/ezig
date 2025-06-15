const std = @import("std");

pub fn @"hello_world.html.ezig"(comptime Props: type, writer: std.io.AnyWriter, props: Props) !void {
writer.writeAll("<h1>Hello, ");
writer.print("{s}", .{  props.name  });
writer.writeAll("!</h1>\n");
}
