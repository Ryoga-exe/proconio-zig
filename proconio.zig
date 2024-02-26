const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Input(comptime buffer_size: usize) type {
    return Scanner(buffer_size, std.io.getStdIn().reader());
}

fn Scanner(comptime buffer_size: usize, comptime reader: anytype) type {
    return struct {
        const Self = @This();
        var buffered_reader = std.io.bufferedReader(reader);
        var breader = buffered_reader.reader();

        buffer: [buffer_size]u8 = undefined,

        pub fn init() Self {
            return Self{};
        }
        pub fn next(self: *Self, allocator: Allocator) []const u8 {
            return allocator.dupe(u8, self.nextRaw()) catch unreachable;
        }
        pub fn nextRaw(self: *Self) []const u8 {
            var fbs = std.io.fixedBufferStream(&self.buffer);
            const writer = fbs.writer();
            for (0..fbs.buffer.len) |_| {
                const byte: u8 = breader.readByte() catch unreachable;
                if (std.ascii.isWhitespace(byte)) {
                    break;
                }
                writer.writeByte(byte) catch unreachable;
            }
            const output = fbs.getWritten();
            self.buffer[output.len] = ' ';
            return output;
        }
        pub fn nextLine(self: *Self, allocator: Allocator) []const u8 {
            return allocator.dupe(u8, self.nextLineRaw()) catch unreachable;
        }
        pub fn nextLineRaw(self: *Self) []const u8 {
            const line = breader.readUntilDelimiterOrEof(
                &self.buffer,
                '\n',
            ) orelse return "";
            if (@import("builtin").os.tag == .windows) {
                return std.mem.trimRight(u8, line.?, "\r");
            } else {
                return line.?;
            }
        }
        pub fn nextUsize(self: *Self) usize {
            return std.fmt.parseInt(usize, self.nextRaw(), 10) orelse 0;
        }
        pub fn nextInt(self: *Self, comptime T: type) T {
            return std.fmt.parseInt(T, self.nextRaw(), 10) orelse 0;
        }
        pub fn nextFloat(self: *Self, comptime T: type) T {
            return std.fmt.parseFloat(T, self.nextRaw()) orelse 0.0;
        }
        pub fn nextNumber(self: *Self, comptime T: type) T {
            switch (@typeInfo(T)) {
                .Int => return self.nextInt(T),
                .Float => return self.nextFloat(T),
                else => @compileError("Invalid type"),
            }
        }
        pub fn nextSlice(self: *Self, comptime T: type, allocator: Allocator, len: usize) []T {
            var slice = allocator.alloc(T, len) catch unreachable;
            for (0..len) |i| {
                slice[i] = self.nextNumber(T);
            }
            return slice;
        }
    };
}
