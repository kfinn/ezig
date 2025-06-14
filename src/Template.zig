const std = @import("std");

allocator: std.mem.Allocator,
name: [:0]const u8,
nodes: []Node,

pub const Node = union(enum) {
    text: []const u8,
    code_expression: []const u8,
    code_snippet: []const u8,
};

pub fn parse(allocator: std.mem.Allocator, name: [:0]const u8, source: [:0]const u8) std.mem.Allocator.Error!@This() {
    var nodes_builder = std.ArrayList(Node).init(allocator);

    const State = union(enum) {
        text,
        code_expression_start_of_line,
        code_expression_middle_of_line,
        code_expression_string_literal,
        code_expression_multiline_string_literal,
        code_expression_comment,
        code_snippet_start_of_line,
        code_snippet_middle_of_line,
        code_snippet_string_literal,
        code_snippet_multiline_string_literal,
        code_snippet_comment,
    };
    const start_code_expression_token = "<%=";
    const start_code_snippet_token = "<%";
    const end_code_token = "%>";
    const start_multiline_string_literal_token = "\\\\";
    const escaped_quote_token = "\\\"";
    const start_comment_token = "//";

    var state: State = .text;
    var index: usize = 0;
    var state_start_index: usize = 0;
    while (index < source.len) {
        const remaining_source = source[index..];
        switch (state) {
            .text => if (std.mem.startsWith(u8, remaining_source, start_code_expression_token)) {
                try nodes_builder.append(.{ .text = source[state_start_index..index] });
                index += start_code_expression_token.len;
                state_start_index = index;
                state = .code_expression_start_of_line;
            } else if (std.mem.startsWith(u8, remaining_source, start_code_snippet_token)) {
                try nodes_builder.append(.{ .text = source[state_start_index..index] });
                index += start_code_snippet_token.len;
                state_start_index = index;
                state = .code_snippet_start_of_line;
            } else {
                index += 1;
            },
            .code_expression_start_of_line => if (std.mem.startsWith(u8, remaining_source, end_code_token)) {
                try nodes_builder.append(.{ .code_expression = source[state_start_index..index] });
                index += end_code_token.len;
                state_start_index = index;
                state = .text;
            } else if (std.mem.startsWith(u8, remaining_source, start_multiline_string_literal_token)) {
                index += start_multiline_string_literal_token.len;
                state = .code_expression_multiline_string_literal;
            } else if (std.mem.startsWith(u8, remaining_source, start_comment_token)) {
                index += start_comment_token.len;
                state = .code_expression_comment;
            } else if (remaining_source[0] == '"') {
                index += 1;
                state = .code_expression_string_literal;
            } else if (std.ascii.isWhitespace(remaining_source[0])) {
                index += 1;
            } else {
                state = .code_expression_middle_of_line;
                index += 1;
            },
            .code_expression_middle_of_line => if (std.mem.startsWith(u8, remaining_source, end_code_token)) {
                try nodes_builder.append(.{ .code_expression = source[state_start_index..index] });
                index += end_code_token.len;
                state_start_index = index;
                state = .text;
            } else if (std.mem.startsWith(u8, remaining_source, start_comment_token)) {
                index += 1;
                state = .code_expression_comment;
            } else if (remaining_source[0] == '"') {
                index += 1;
                state = .code_expression_string_literal;
            } else if (remaining_source[0] == '\n') {
                index += 1;
                state = .code_expression_start_of_line;
            } else {
                index += 1;
            },
            .code_expression_multiline_string_literal => if (remaining_source[0] == '\n') {
                index += 1;
                state = .code_expression_start_of_line;
            } else {
                index += 1;
            },
            .code_expression_string_literal => if (std.mem.startsWith(u8, remaining_source, escaped_quote_token)) {
                index += escaped_quote_token.len;
            } else if (remaining_source[0] == '"') {
                index += 1;
                state = .code_expression_middle_of_line;
            } else {
                index += 1;
            },
            .code_expression_comment => if (remaining_source[0] == '\n') {
                index += 1;
                state = .code_expression_start_of_line;
            } else {
                index += 1;
            },
            .code_snippet_start_of_line => if (std.mem.startsWith(u8, remaining_source, end_code_token)) {
                try nodes_builder.append(.{ .code_snippet = source[state_start_index..index] });
                index += end_code_token.len;
                state_start_index = index;
                state = .text;
            } else if (std.mem.startsWith(u8, remaining_source, start_multiline_string_literal_token)) {
                index += start_multiline_string_literal_token.len;
                state = .code_snippet_multiline_string_literal;
            } else if (std.mem.startsWith(u8, remaining_source, start_comment_token)) {
                index += start_comment_token.len;
                state = .code_snippet_comment;
            } else if (remaining_source[0] == '"') {
                index += 1;
                state = .code_snippet_string_literal;
            } else if (std.ascii.isWhitespace(remaining_source[0])) {
                index += 1;
            } else {
                state = .code_snippet_middle_of_line;
                index += 1;
            },
            .code_snippet_middle_of_line => if (std.mem.startsWith(u8, remaining_source, end_code_token)) {
                try nodes_builder.append(.{ .code_snippet = source[state_start_index..index] });
                index += end_code_token.len;
                state_start_index = index;
                state = .text;
            } else if (std.mem.startsWith(u8, remaining_source, start_comment_token)) {
                index += start_comment_token.len;
                state = .code_snippet_comment;
            } else if (remaining_source[0] == '"') {
                index += 1;
                state = .code_snippet_string_literal;
            } else if (remaining_source[0] == '\n') {
                index += 1;
                state = .code_snippet_start_of_line;
            } else {
                index += 1;
            },
            .code_snippet_multiline_string_literal => if (remaining_source[0] == '\n') {
                index += 1;
                state = .code_snippet_start_of_line;
            } else {
                index += 1;
            },
            .code_snippet_string_literal => if (std.mem.startsWith(u8, remaining_source, escaped_quote_token)) {
                index += escaped_quote_token.len;
            } else if (remaining_source[0] == '"') {
                index += 1;
                state = .code_snippet_middle_of_line;
            } else {
                index += 1;
            },
            .code_snippet_comment => if (remaining_source[0] == '\n') {
                state = .code_snippet_start_of_line;
                index += 1;
            } else {
                index += 1;
            },
        }
    }
    if (index != state_start_index) {
        if (state == .text) {
            try nodes_builder.append(.{ .text = source[state_start_index..] });
        } else {
            unreachable;
        }
    }
    return .{ .allocator = allocator, .name = name, .nodes = try nodes_builder.toOwnedSlice() };
}

pub fn toZigSource(self: *const @This()) ![:0]const u8 {
    var result_builder = std.ArrayList(u8).init(self.allocator);
    const writer = result_builder.writer();

    try writer.print("pub fn @\"{s}\"(comptime Props: type, allocator: std.mem.Allocator, writer: std.io.AnyWriter, props: Props) !void {{\n", .{self.name});

    for (self.nodes) |node| {
        switch (node) {
            .text => |text| {
                try writer.writeAll("writer.writeAll(\"");
                for (text) |character| {
                    switch (character) {
                        '\n' => try writer.writeAll("\\n"),
                        '\\' => try writer.writeAll("\\\\"),
                        '"' => try writer.writeAll("\\\""),
                        else => try writer.writeByte(character),
                    }
                }
                try writer.writeAll("\");\n");
            },
            .code_expression => |code_expression| {
                try writer.print("writer.print(\"{{s}}\", .{{ {s} }});\n", .{code_expression});
            },
            .code_snippet => |code_snippet| {
                try writer.writeAll(code_snippet);
                try writer.writeByte('\n');
            },
        }
    }

    try writer.writeAll("}\n");

    return result_builder.toOwnedSliceSentinel(0);
}

pub fn deinit(self: *@This()) void {
    self.allocator.free(self.nodes);
    self.* = undefined;
}
