const std = @import("std");

const LookaheadIterator = @import("./LookaheadIterator.zig");

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

pub fn writeZigSource(self: *const @This(), writer: std.io.AnyWriter) !void {
    var template_file = try self.dir.openFileZ(self.path, .{});
    defer template_file.close();

    var buffered_reader = std.io.bufferedReader(template_file.reader());
    var lookahead_iterator = LookaheadIterator.init(buffered_reader.reader().any());

    try writer.print("pub fn @\"{s}\"(comptime Props: type, writer: std.io.AnyWriter, props: Props) !void {{\n", .{self.name()});

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
            if (lookahead_iterator.consume(start_code_expression_format_token)) {
                try writeTextNodeEndToZigSource(writer);
                try writeCodeExpressionFormatNodeStartToZigSource(writer);
                continue :state .code_expression_format;
            } else if (lookahead_iterator.consume(start_code_expression_token)) {
                try writeTextNodeEndToZigSource(writer);
                try writeCodeExpressionNodeStartToZigSource(writer);
                continue :state .code_expression;
            } else if (lookahead_iterator.consume(start_code_snippet_token)) {
                try writeTextNodeEndToZigSource(writer);
                try writeCodeSnippetNodeStartToZigSource(writer);
                continue :state .code_snippet;
            } else if (lookahead_iterator.consume(newline_token)) {
                try writer.writeAll("\\n");
                continue :state .text;
            } else if (lookahead_iterator.consume(quote_token)) {
                try writer.writeAll("\\\"");
                continue :state .text;
            } else if (lookahead_iterator.consume(escape_token)) {
                try writer.writeByte('\\');
                continue :state .text;
            } else {
                if (lookahead_iterator.next()) |next_character| {
                    try writer.writeByte(next_character);
                    continue :state .text;
                } else {
                    try writeTextNodeEndToZigSource(writer);
                    break :state;
                }
            }
        },
        .code_expression_format => {
            if (lookahead_iterator.consume(end_code_expression_format_token)) {
                try writeCodeExpressionFormatNodeEndToZigSource(writer);
                continue :state .code_expression;
            } else {
                try writer.writeByte(lookahead_iterator.next().?);
                continue :state .code_expression_format;
            }
        },
        .code_expression => {
            if (lookahead_iterator.consume(end_code_token)) {
                try writeCodeExpressionNodeEndToZigSource(writer);
                try writeTextNodeStartToZigSource(writer);
                continue :state .text;
            } else if (lookahead_iterator.consume(start_multiline_string_literal_token)) {
                try writer.writeAll(start_multiline_string_literal_token);
                continue :state .code_expression_multiline_string_literal;
            } else if (lookahead_iterator.consume(start_comment_token)) {
                continue :state .code_expression_comment;
            } else if (lookahead_iterator.consume(start_string_literal_token)) {
                try writer.writeAll(start_string_literal_token);
                continue :state .code_expression_string_literal;
            } else if (lookahead_iterator.consume(newline_token)) {
                try writer.writeAll(newline_token);
                continue :state .code_expression;
            } else {
                try writer.writeByte(lookahead_iterator.next().?);
                continue :state .code_expression;
            }
        },
        .code_expression_string_literal => {
            if (lookahead_iterator.consume(escaped_backslash_token)) {
                try writer.writeAll(escaped_backslash_token);
                continue :state .code_expression_string_literal;
            } else if (lookahead_iterator.consume(escaped_quote_token)) {
                try writer.writeAll(escaped_quote_token);
                continue :state .code_expression_string_literal;
            } else if (lookahead_iterator.consume(quote_token)) {
                try writer.writeAll(quote_token);
                continue :state .code_expression;
            } else {
                try writer.writeByte(lookahead_iterator.next().?);
                continue :state .code_expression_string_literal;
            }
        },
        .code_expression_multiline_string_literal => {
            if (lookahead_iterator.consume(newline_token)) {
                try writer.writeAll(newline_token);
                continue :state .code_expression;
            } else {
                try writer.writeByte(lookahead_iterator.next().?);
                continue :state .code_expression_multiline_string_literal;
            }
        },
        .code_expression_comment => {
            if (lookahead_iterator.consume(end_code_token)) {
                try writeCodeSnippetNodeEndToZigSource(writer);
                try writeTextNodeStartToZigSource(writer);
                continue :state .text;
            } else if (lookahead_iterator.consume(newline_token)) {
                continue :state .code_expression;
            } else {
                lookahead_iterator.skip(1);
                continue :state .code_expression_comment;
            }
        },
        .code_snippet => {
            if (lookahead_iterator.consume(end_code_token)) {
                try writeCodeSnippetNodeEndToZigSource(writer);
                try writeTextNodeStartToZigSource(writer);
                continue :state .text;
            } else if (lookahead_iterator.consume(start_multiline_string_literal_token)) {
                try writer.writeAll(start_multiline_string_literal_token);
                continue :state .code_snippet_multiline_string_literal;
            } else if (lookahead_iterator.consume(start_comment_token)) {
                continue :state .code_snippet_comment;
            } else if (lookahead_iterator.consume(start_string_literal_token)) {
                try writer.writeAll(start_string_literal_token);
                continue :state .code_snippet_string_literal;
            } else if (lookahead_iterator.consume(newline_token)) {
                try writer.writeAll(newline_token);
                continue :state .code_snippet;
            } else {
                try writer.writeByte(lookahead_iterator.next().?);
                continue :state .code_snippet;
            }
        },
        .code_snippet_string_literal => {
            if (lookahead_iterator.consume(escaped_backslash_token)) {
                try writer.writeAll(escaped_backslash_token);
                continue :state .code_snippet_string_literal;
            } else if (lookahead_iterator.consume(escaped_quote_token)) {
                try writer.writeAll(escaped_quote_token);
                continue :state .code_snippet_string_literal;
            } else if (lookahead_iterator.consume(quote_token)) {
                try writer.writeAll(quote_token);
                continue :state .code_snippet;
            } else {
                try writer.writeByte(lookahead_iterator.next().?);
                continue :state .code_snippet_string_literal;
            }
        },
        .code_snippet_multiline_string_literal => {
            if (lookahead_iterator.consume(newline_token)) {
                try writer.writeAll(newline_token);
                continue :state .code_snippet;
            } else {
                try writer.writeByte(lookahead_iterator.next().?);
                continue :state .code_snippet_multiline_string_literal;
            }
        },
        .code_snippet_comment => {
            if (lookahead_iterator.consume(end_code_token)) {
                try writeCodeSnippetNodeEndToZigSource(writer);
                try writeTextNodeStartToZigSource(writer);
                continue :state .text;
            } else if (lookahead_iterator.consume(newline_token)) {
                continue :state .code_snippet;
            } else {
                lookahead_iterator.skip(1);
                continue :state .code_snippet_comment;
            }
        },
    }

    try writer.print("}}\n", .{});
}

fn writeTextNodeStartToZigSource(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll("try writer.writeAll(\"");
}

fn writeTextNodeEndToZigSource(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll("\");\n");
}

fn writeCodeExpressionNodeStartToZigSource(writer: anytype) @TypeOf(writer).Error!void {
    try writeCodeExpressionFormatNodeStartToZigSource(writer);
    try writer.writeAll("s");
    try writeCodeExpressionFormatNodeEndToZigSource(writer);
}

fn writeCodeExpressionFormatNodeStartToZigSource(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll("try writer.print(\"{");
}

fn writeCodeExpressionFormatNodeEndToZigSource(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll("}\", .{");
}

fn writeCodeExpressionNodeEndToZigSource(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeAll("});\n");
}

fn writeCodeSnippetNodeStartToZigSource(writer: anytype) @TypeOf(writer).Error!void {}

fn writeCodeSnippetNodeEndToZigSource(writer: anytype) @TypeOf(writer).Error!void {
    try writer.writeByte('\n');
}
