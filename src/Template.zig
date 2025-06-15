const std = @import("std");

name: [:0]const u8,
source: [:0]const u8,

const Node = union(enum) {
    text: []const u8,
    code_expression: []const u8,
    code_snippet: []const u8,
};

pub fn init(name: [:0]const u8, source: [:0]const u8) @This() {
    return .{ .name = name, .source = source };
}

pub fn writeZigSource(self: *const @This(), writer: std.io.AnyWriter) !void {
    try writer.print("pub fn @\"{s}\"(comptime Props: type, writer: std.io.AnyWriter, props: Props) !void {{\n", .{self.name});

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
    while (index < self.source.len) {
        const remaining_source = self.source[index..];
        switch (state) {
            .text => if (std.mem.startsWith(u8, remaining_source, start_code_expression_token)) {
                try writeTextNodeToZigSource(writer, self.source[state_start_index..index]);
                index += start_code_expression_token.len;
                state_start_index = index;
                state = .code_expression_start_of_line;
            } else if (std.mem.startsWith(u8, remaining_source, start_code_snippet_token)) {
                try writeTextNodeToZigSource(writer, self.source[state_start_index..index]);
                index += start_code_snippet_token.len;
                state_start_index = index;
                state = .code_snippet_start_of_line;
            } else {
                index += 1;
            },
            .code_expression_start_of_line => if (std.mem.startsWith(u8, remaining_source, end_code_token)) {
                try writeCodeExpressionNodeToZigSource(writer, self.source[state_start_index..index]);
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
                try writeCodeExpressionNodeToZigSource(writer, self.source[state_start_index..index]);
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
                try writeCodeSnippetNodeToZigSource(writer, self.source[state_start_index..index]);
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
                try writeCodeSnippetNodeToZigSource(writer, self.source[state_start_index..index]);
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
            try writeTextNodeToZigSource(writer, self.source[state_start_index..]);
        } else {
            unreachable;
        }
    }

    try writer.writeAll("}\n");
}

fn writeTextNodeToZigSource(writer: std.io.AnyWriter, text_node: []const u8) !void {
    try writer.writeAll("try writer.writeAll(\"");
    for (text_node) |character| {
        switch (character) {
            '\n' => try writer.writeAll("\\n"),
            '\\' => try writer.writeAll("\\\\"),
            '"' => try writer.writeAll("\\\""),
            else => try writer.writeByte(character),
        }
    }
    try writer.writeAll("\");\n");
}

fn writeCodeExpressionNodeToZigSource(writer: std.io.AnyWriter, code_expression: []const u8) !void {
    try writer.print("try writer.print(\"{{s}}\", .{{ {s} }});\n", .{code_expression});
}

fn writeCodeSnippetNodeToZigSource(writer: std.io.AnyWriter, code_snippet: []const u8) !void {
    try writer.writeAll(code_snippet);
    try writer.writeByte('\n');
}
