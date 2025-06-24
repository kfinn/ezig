const std = @import("std");

const lookahead_buffer_capacity = 4;

reader: std.io.AnyReader,
lookahead_buffer: [lookahead_buffer_capacity]u8 = undefined,
lookahead_buffer_start_index: usize = 0,
lookahead_buffer_size: usize = 0,

pub fn init(reader: std.io.AnyReader) @This() {
    return .{ .reader = reader };
}

pub fn next(self: *@This()) ?u8 {
    if (self.lookahead_buffer_size > 0) {
        const result = self.lookahead_buffer[self.lookahead_buffer_start_index];
        self.lookahead_buffer_start_index = (self.lookahead_buffer_start_index + 1) % lookahead_buffer_capacity;
        self.lookahead_buffer_size -= 1;
        return result;
    }
    return self.readOptByte();
}

pub fn skip(self: *@This(), count: usize) void {
    for (0..count) |_| {
        _ = self.next();
    }
}

pub fn consume(self: *@This(), prefix: []const u8) bool {
    if (self.startsWith(prefix)) {
        self.skip(prefix.len);
        return true;
    }
    return false;
}

pub fn startsWith(self: *@This(), needle: []const u8) bool {
    std.debug.assert(needle.len <= lookahead_buffer_capacity);

    for (0..needle.len) |index| {
        const needle_value = needle[index];
        const lookahead_buffer_index = (self.lookahead_buffer_start_index + index) % lookahead_buffer_capacity;
        if (index == self.lookahead_buffer_size) {
            if (self.readOptByte()) |underlying_next| {
                self.lookahead_buffer[lookahead_buffer_index] = underlying_next;
                self.lookahead_buffer_size += 1;
                if (underlying_next != needle_value) {
                    return false;
                }
            } else {
                return false;
            }
        } else if (index < self.lookahead_buffer_size) {
            if (self.lookahead_buffer[lookahead_buffer_index] != needle_value) {
                return false;
            }
        } else {
            unreachable;
        }
    }

    return true;
}

fn readOptByte(self: *@This()) ?u8 {
    return self.reader.readByte() catch null;
}
