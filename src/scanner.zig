const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Reader = std.Io.Reader;
const TokenIterator = std.mem.TokenIterator(u8, .any);
const tokenize = std.mem.tokenizeAny;
const delimiters = std.ascii.whitespace;

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
                switch (S) {
                    File => {
                        var file_buffer: [1024]u8 = undefined;
                        var file_reader = source.reader(&file_buffer);
                        const reader = &file_reader.interface;
                        break :blk try reader.allocRemaining(allocator, .unlimited);
                    },
                    Reader => {
                        break :blk try source.allocRemaining(allocator, .unlimited);
                    },
                    else => switch (@typeInfo(S)) {
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
                            @compileError("invalid type given to Scanner");
                        },
                    },
                }
            };

            return Self{
                .allocator = allocator,
                .buffer = buffer,
                .token_iter = tokenize(u8, buffer, &delimiters),
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
    if (S != File) {
        // TODO: supports other types
        @compileError("ScannerInteractive mode only supports std.fs.File.");
    }
    return struct {
        const Self = @This();

        var reader_buffer: [1024]u8 = undefined;

        allocator: Allocator,
        buffer: std.ArrayList(u8),
        reader: File.Reader,

        fn init(allocator: Allocator, source: S) !Self {
            return Self{
                .allocator = allocator,
                .buffer = try std.ArrayList(u8).initCapacity(allocator, 1024),
                .reader = source.reader(&reader_buffer),
            };
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit(self.allocator);
        }

        pub fn readNextTokenSlice(self: *Self) ![]const u8 {
            // NOTE: consider `start=0`
            // this scanner is only used by proconio and outer proconio call this with `dupe` for Bytes
            const start = self.buffer.items.len;
            const writer = self.buffer.writer(self.allocator);
            const reader = &self.reader.interface;
            while (true) {
                const byte = try reader.takeByte();
                if (!std.ascii.isWhitespace(byte)) {
                    try writer.writeByte(byte);
                    break;
                }
            }
            while (true) {
                const byte = try reader.takeByte();
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
