const std = @import("std");
const Allocator = std.mem.Allocator;
const TokenIterator = std.mem.TokenIterator(u8, .any);
const tokenize = std.mem.tokenizeAny;
const delimiters = " \t\r\n";

pub inline fn scanner(allocator: Allocator, source: anytype, comptime interactive: bool) !Scanner(@TypeOf(source), interactive) {
    return Scanner(@TypeOf(source), interactive).init(allocator, source);
}

pub inline fn Scanner(comptime S: type, comptime interactive: bool) type {
    return if (interactive) ScannerInteractive(S) else ScannerAllAlloc(S);
}

fn ScannerAllAlloc(comptime S: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        buffer: []u8,
        token_iter: TokenIterator,

        fn init(allocator: Allocator, source: S) !Self {
            const buffer = blk: {
                switch (@typeInfo(S)) {
                    .pointer => |ptr_info| {
                        switch (ptr_info.size) {
                            .slice, .one => {
                                // TODO: check ptr_info.child
                                break :blk try allocator.dupe(u8, source);
                            },
                            else => @compileError("invalid type given to Scanner"),
                        }
                    },
                    else => {
                        if (std.meta.hasMethod(S, "reader")) {
                            const reader = source.reader();
                            break :blk try reader.readAllAlloc(allocator, std.math.maxInt(usize));
                        } else {
                            @compileError("invalid type given to Scanner");
                        }
                    },
                }
            };
            return Self{
                .allocator = allocator,
                .buffer = buffer,
                .token_iter = tokenize(u8, buffer, delimiters),
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.buffer);
        }

        pub fn readNextTokenSlice(self: *Self) ![]const u8 {
            return self.token_iter.next().?;
        }
    };
}

fn ScannerInteractive(comptime S: type) type {
    if (S != std.fs.File) {
        // TODO: supports other types
        @compileError("ScannerInteractive mode only supports std.fs.File.");
    }
    return struct {
        const Self = @This();

        allocator: Allocator,
        buffer: std.ArrayList(u8),
        buffered_reader: @TypeOf(std.io.bufferedReader(std.io.getStdIn().reader())),

        fn init(allocator: Allocator, source: S) !Self {
            return Self{
                .allocator = allocator,
                .buffer = try std.ArrayList(u8).initCapacity(allocator, 4096),
                .buffered_reader = std.io.bufferedReader(source.reader()),
            };
        }

        pub fn deinit(self: Self) void {
            self.buffer.deinit();
        }

        pub fn readNextTokenSlice(self: *Self) ![]const u8 {
            const start = self.buffer.items.len;
            const reader = self.buffered_reader.reader();
            const writer = self.buffer.writer();
            while (true) {
                const byte = try reader.readByte();
                if (std.ascii.isWhitespace(byte)) {
                    break;
                }
                try writer.writeByte(byte);
            }
            return self.buffer.items[start..];
        }
    };
}

const testing = std.testing;
test scanner {
    const allocator = testing.allocator;
    var sc = try scanner(allocator, "hello world\nfoobar", false);
    defer sc.deinit();
    try testing.expectEqualSlices(u8, "hello", try sc.readNextTokenSlice());
    try testing.expectEqualSlices(u8, "world", try sc.readNextTokenSlice());
    try testing.expectEqualSlices(u8, "foobar", try sc.readNextTokenSlice());
}
