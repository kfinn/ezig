const std = @import("std");

dir: std.fs.Dir,
path: [:0]const u8,

const Node = union(enum) {
    text: []const u8,
    code_expression: []const u8,
    code_snippet: []const u8,
};

pub const filename_extension = ".ezig";

pub fn isTemplatePath(pathname: [:0]const u8) bool {
    return std.mem.endsWith(u8, pathname, filename_extension);
}

pub fn init(dir: std.fs.Dir, path: [:0]const u8) @This() {
    return .{
        .dir = dir,
        .path = path,
    };
}

pub fn deinit(self: *@This()) void {
    self.* = undefined;
}

pub fn name(self: *const @This()) []const u8 {
    return self.path[0 .. self.path.len - filename_extension.len];
}

pub fn writeZigSource(self: *const @This(), writer: *std.Io.Writer) !void {
    var template_file = try self.dir.openFileZ(self.path, .{});
    defer template_file.close();

    var template_file_buffer: [1024]u8 = undefined;
    var template_file_reader = template_file.reader(&template_file_buffer);
    const template_reader = &template_file_reader.interface;

    try writer.print("pub fn @\"{s}\"(writer: *std.Io.Writer, props: anytype) std.Io.Writer.Error!void {{\n", .{self.name()});

    const State = union(enum) {
        text,
        code_expression_format,
        code_expression,
        code_expression_string_literal,
        code_expression_multiline_string_literal,
        code_expression_comment,
        code_snippet,
        code_snippet_string_literal,
        code_snippet_multiline_string_literal,
        code_snippet_comment,
    };
    const start_code_expression_token = "<%=";
    const start_code_expression_format_token = "<%{";
    const end_code_expression_format_token = "}=";
    const start_code_snippet_token = "<%";
    const end_code_token = "%>";
    const start_multiline_string_literal_token = "\\\\";
    const escaped_backslash_token = "\\\\";
    const escaped_quote_token = "\\\"";
    const start_comment_token = "//";
    const start_string_literal_token = "\"";
    const newline_token = "\n";
    const quote_token = "\"";
    const escape_token = "\\";

    try writeTextNodeStartToZigSource(writer);

    state: switch (State.text) {
        .text => {
            if (consume(template_reader, start_code_expression_format_token)) {
                try writeTextNodeEndToZigSource(writer);
                try writeCodeExpressionFormatNodeStartToZigSource(writer);
                continue :state .code_expression_format;
            } else if (consume(template_reader, start_code_expression_token)) {
                try writeTextNodeEndToZigSource(writer);
                try writeCodeExpressionNodeStartToZigSource(writer);
                continue :state .code_expression;
            } else if (consume(template_reader, start_code_snippet_token)) {
                try writeTextNodeEndToZigSource(writer);
                try writeCodeSnippetNodeStartToZigSource(writer);
                continue :state .code_snippet;
            } else if (consume(template_reader, newline_token)) {
                try writer.writeAll("\\n");
                continue :state .text;
            } else if (consume(template_reader, quote_token)) {
                try writer.writeAll("\\\"");
                continue :state .text;
            } else if (consume(template_reader, escape_token)) {
                try writer.writeByte('\\');
                continue :state .text;
            } else {
                template_reader.streamExact(writer, 1) catch {
                    try writeTextNodeEndToZigSource(writer);
                    break :state;
                };
                continue :state .text;
            }
        },
        .code_expression_format => {
            if (consume(template_reader, end_code_expression_format_token)) {
                try writeCodeExpressionFormatNodeEndToZigSource(writer);
                continue :state .code_expression;
            } else {
                try template_reader.streamExact(writer, 1);
                continue :state .code_expression_format;
            }
        },
        .code_expression => {
            if (consume(template_reader, end_code_token)) {
                try writeCodeExpressionNodeEndToZigSource(writer);
                try writeTextNodeStartToZigSource(writer);
                continue :state .text;
            } else if (consume(template_reader, start_multiline_string_literal_token)) {
                try writer.writeAll(start_multiline_string_literal_token);
                continue :state .code_expression_multiline_string_literal;
            } else if (consume(template_reader, start_comment_token)) {
                continue :state .code_expression_comment;
            } else if (consume(template_reader, start_string_literal_token)) {
                try writer.writeAll(start_string_literal_token);
                continue :state .code_expression_string_literal;
            } else if (consume(template_reader, newline_token)) {
                try writer.writeAll(newline_token);
                continue :state .code_expression;
            } else {
                try template_reader.streamExact(writer, 1);
                continue :state .code_expression;
            }
        },
        .code_expression_string_literal => {
            if (consume(template_reader, escaped_backslash_token)) {
                try writer.writeAll(escaped_backslash_token);
                continue :state .code_expression_string_literal;
            } else if (consume(template_reader, escaped_quote_token)) {
                try writer.writeAll(escaped_quote_token);
                continue :state .code_expression_string_literal;
            } else if (consume(template_reader, quote_token)) {
                try writer.writeAll(quote_token);
                continue :state .code_expression;
            } else {
                try template_reader.streamExact(writer, 1);
                continue :state .code_expression_string_literal;
            }
        },
        .code_expression_multiline_string_literal => {
            if (consume(template_reader, newline_token)) {
                try writer.writeAll(newline_token);
                continue :state .code_expression;
            } else {
                try template_reader.streamExact(writer, 1);
                continue :state .code_expression_multiline_string_literal;
            }
        },
        .code_expression_comment => {
            if (consume(template_reader, end_code_token)) {
                try writeCodeSnippetNodeEndToZigSource(writer);
                try writeTextNodeStartToZigSource(writer);
                continue :state .text;
            } else if (consume(template_reader, newline_token)) {
                continue :state .code_expression;
            } else {
                template_reader.toss(1);
                continue :state .code_expression_comment;
            }
        },
        .code_snippet => {
            if (consume(template_reader, end_code_token)) {
                try writeCodeSnippetNodeEndToZigSource(writer);
                try writeTextNodeStartToZigSource(writer);
                continue :state .text;
            } else if (consume(template_reader, start_multiline_string_literal_token)) {
                try writer.writeAll(start_multiline_string_literal_token);
                continue :state .code_snippet_multiline_string_literal;
            } else if (consume(template_reader, start_comment_token)) {
                continue :state .code_snippet_comment;
            } else if (consume(template_reader, start_string_literal_token)) {
                try writer.writeAll(start_string_literal_token);
                continue :state .code_snippet_string_literal;
            } else if (consume(template_reader, newline_token)) {
                try writer.writeAll(newline_token);
                continue :state .code_snippet;
            } else {
                try template_reader.streamExact(writer, 1);
                continue :state .code_snippet;
            }
        },
        .code_snippet_string_literal => {
            if (consume(template_reader, escaped_backslash_token)) {
                try writer.writeAll(escaped_backslash_token);
                continue :state .code_snippet_string_literal;
            } else if (consume(template_reader, escaped_quote_token)) {
                try writer.writeAll(escaped_quote_token);
                continue :state .code_snippet_string_literal;
            } else if (consume(template_reader, quote_token)) {
                try writer.writeAll(quote_token);
                continue :state .code_snippet;
            } else {
                try template_reader.streamExact(writer, 1);
                continue :state .code_snippet_string_literal;
            }
        },
        .code_snippet_multiline_string_literal => {
            if (consume(template_reader, newline_token)) {
                try writer.writeAll(newline_token);
                continue :state .code_snippet;
            } else {
                try template_reader.streamExact(writer, 1);
                continue :state .code_snippet_multiline_string_literal;
            }
        },
        .code_snippet_comment => {
            if (consume(template_reader, end_code_token)) {
                try writeCodeSnippetNodeEndToZigSource(writer);
                try writeTextNodeStartToZigSource(writer);
                continue :state .text;
            } else if (consume(template_reader, newline_token)) {
                continue :state .code_snippet;
            } else {
                template_reader.toss(1);
                continue :state .code_snippet_comment;
            }
        },
    }

    try writer.print("}}\n", .{});
}

fn consume(reader: *std.Io.Reader, needle: []const u8) bool {
    if (reader.peek(needle.len)) |peeked| {
        if (std.mem.eql(u8, peeked, needle)) {
            reader.toss(needle.len);
            return true;
        }
    } else |_| {}
    return false;
}

fn writeTextNodeStartToZigSource(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll("try writer.writeAll(\"");
}

fn writeTextNodeEndToZigSource(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll("\");\n");
}

fn writeCodeExpressionNodeStartToZigSource(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writeCodeExpressionFormatNodeStartToZigSource(writer);
    try writer.writeAll("s");
    try writeCodeExpressionFormatNodeEndToZigSource(writer);
}

fn writeCodeExpressionFormatNodeStartToZigSource(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll("try writer.print(\"{");
}

fn writeCodeExpressionFormatNodeEndToZigSource(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll("}\", .{");
}

fn writeCodeExpressionNodeEndToZigSource(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll("});\n");
}

fn writeCodeSnippetNodeStartToZigSource(_: *std.Io.Writer) std.Io.Writer.Error!void {}

fn writeCodeSnippetNodeEndToZigSource(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeByte('\n');
}
