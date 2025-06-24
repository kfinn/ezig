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

    var state: State = .text;
    try writeTextNodeStartToZigSource(writer);

    outer: while (true) {
        switch (state) {
            .text => {
                if (lookahead_iterator.consume(start_code_expression_token)) {
                    try writeTextNodeEndToZigSource(writer);
                    state = .code_expression;
                    try writeCodeExpressionNodeStartToZigSource(writer);
                } else if (lookahead_iterator.consume(start_code_snippet_token)) {
                    try writeTextNodeEndToZigSource(writer);
                    state = .code_snippet;
                    try writeCodeSnippetNodeStartToZigSource(writer);
                } else if (lookahead_iterator.consume(newline_token)) {
                    try writer.writeAll("\\n");
                } else if (lookahead_iterator.consume(quote_token)) {
                    try writer.writeAll("\\\\");
                } else if (lookahead_iterator.consume(escape_token)) {
                    try writer.writeByte('\\');
                } else {
                    if (lookahead_iterator.next()) |next_character| {
                        try writer.writeByte(next_character);
                    } else {
                        try writeTextNodeEndToZigSource(writer);
                        break :outer;
                    }
                }
            },
            .code_expression => {
                if (lookahead_iterator.consume(end_code_token)) {
                    try writeCodeExpressionNodeEndToZigSource(writer);
                    state = .text;
                    try writeTextNodeStartToZigSource(writer);
                } else if (lookahead_iterator.consume(start_multiline_string_literal_token)) {
                    try writer.writeAll(start_multiline_string_literal_token);
                    state = .code_expression_multiline_string_literal;
                } else if (lookahead_iterator.consume(start_comment_token)) {
                    state = .code_expression_comment;
                } else if (lookahead_iterator.consume(start_string_literal_token)) {
                    try writer.writeAll(start_string_literal_token);
                    state = .code_expression_string_literal;
                } else if (lookahead_iterator.consume(newline_token)) {
                    try writer.writeAll(newline_token);
                    state = .code_expression;
                } else {
                    try writer.writeByte(lookahead_iterator.next().?);
                }
            },
            .code_expression_string_literal => {
                if (lookahead_iterator.consume(escaped_backslash_token)) {
                    try writer.writeAll(escaped_backslash_token);
                } else if (lookahead_iterator.consume(escaped_quote_token)) {
                    try writer.writeAll(escaped_quote_token);
                } else if (lookahead_iterator.consume(quote_token)) {
                    try writer.writeAll(quote_token);
                    state = .code_expression;
                } else {
                    try writer.writeByte(lookahead_iterator.next().?);
                }
            },
            .code_expression_multiline_string_literal => {
                if (lookahead_iterator.consume(newline_token)) {
                    try writer.writeAll(newline_token);
                    state = .code_expression;
                } else {
                    try writer.writeByte(lookahead_iterator.next().?);
                }
            },
            .code_expression_comment => {
                if (lookahead_iterator.consume(end_code_token)) {
                    try writeCodeSnippetNodeEndToZigSource(writer);
                    state = .text;
                    try writeTextNodeStartToZigSource(writer);
                } else if (lookahead_iterator.consume(newline_token)) {
                    state = .code_expression;
                } else {
                    lookahead_iterator.skip(1);
                }
            },
            .code_snippet => {
                if (lookahead_iterator.consume(end_code_token)) {
                    try writeCodeSnippetNodeEndToZigSource(writer);
                    state = .text;
                    try writeTextNodeStartToZigSource(writer);
                } else if (lookahead_iterator.consume(start_multiline_string_literal_token)) {
                    try writer.writeAll(start_multiline_string_literal_token);
                    state = .code_snippet_multiline_string_literal;
                } else if (lookahead_iterator.consume(start_comment_token)) {
                    state = .code_snippet_comment;
                } else if (lookahead_iterator.consume(start_string_literal_token)) {
                    try writer.writeAll(start_string_literal_token);
                    state = .code_snippet_string_literal;
                } else if (lookahead_iterator.consume(newline_token)) {
                    try writer.writeAll(newline_token);
                    state = .code_snippet;
                } else {
                    try writer.writeByte(lookahead_iterator.next().?);
                }
            },
            .code_snippet_string_literal => {
                if (lookahead_iterator.consume(escaped_backslash_token)) {
                    try writer.writeAll(escaped_backslash_token);
                } else if (lookahead_iterator.consume(escaped_quote_token)) {
                    try writer.writeAll(escaped_quote_token);
                } else if (lookahead_iterator.consume(quote_token)) {
                    try writer.writeAll(quote_token);
                    state = .code_snippet;
                } else {
                    try writer.writeByte(lookahead_iterator.next().?);
                }
            },
            .code_snippet_multiline_string_literal => {
                if (lookahead_iterator.consume(newline_token)) {
                    try writer.writeAll(newline_token);
                    state = .code_snippet;
                } else {
                    try writer.writeByte(lookahead_iterator.next().?);
                }
            },
            .code_snippet_comment => {
                if (lookahead_iterator.consume(end_code_token)) {
                    try writeCodeSnippetNodeEndToZigSource(writer);
                    state = .text;
                    try writeTextNodeStartToZigSource(writer);
                } else if (lookahead_iterator.consume(newline_token)) {
                    state = .code_snippet;
                } else {
                    lookahead_iterator.skip(1);
                }
            },
        }
    }

    try writer.print("}}\n", .{});
}

fn writeTextNodeStartToZigSource(writer: std.io.AnyWriter) !void {
    try writer.writeAll("try writer.writeAll(\"");
}

fn writeTextNodeEndToZigSource(writer: std.io.AnyWriter) !void {
    try writer.writeAll("\");\n");
}

fn writeCodeExpressionNodeStartToZigSource(writer: std.io.AnyWriter) !void {
    try writer.writeAll("try writer.print(\"{s}\", .{");
}

fn writeCodeExpressionNodeEndToZigSource(writer: std.io.AnyWriter) !void {
    try writer.writeAll("});\n");
}

fn writeCodeSnippetNodeStartToZigSource(_: std.io.AnyWriter) !void {}

fn writeCodeSnippetNodeEndToZigSource(writer: std.io.AnyWriter) !void {
    try writer.writeByte('\n');
}
