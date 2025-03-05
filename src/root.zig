const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const sc = @import("scanner.zig");

const stdin = std.io.getStdIn();

pub fn init(allocator: Allocator) !Proconio {
    return Proconio.init(allocator, stdin);
}

pub fn initInteractive(allocator: Allocator) !ProconioInteractive {
    return ProconioInteractive.init(allocator, stdin);
}

fn initAny(allocator: Allocator, source: anytype, comptime interactive: bool) !ProconioAny(@TypeOf(source), interactive) {
    return ProconioAny(@TypeOf(source), interactive).init(allocator, source);
}

const Proconio = ProconioAny(@TypeOf(stdin), @import("builtin").mode == .Debug);
const ProconioInteractive = ProconioAny(@TypeOf(stdin), true);
fn ProconioAny(comptime S: type, comptime interactive: bool) type {
    return struct {
        const Self = @This();

        arena: ArenaAllocator,
        scanner: sc.Scanner(S, interactive),
        parse_bool: *const fn ([]const u8) bool,

        fn init(allocator: Allocator, source: anytype) !Self {
            return Self{
                .arena = ArenaAllocator.init(allocator),
                .scanner = try sc.scanner(allocator, source, interactive),
                .parse_bool = parseBoolDefault,
            };
        }

        pub fn deinit(self: Self) void {
            self.scanner.deinit();
            self.arena.deinit();
        }

        pub fn input(self: *Self, comptime T: type) !Parse(T) {
            var result: Parse(T) = undefined;
            switch (@typeInfo(T)) {
                .@"struct" => |info| {
                    inline for (info.fields) |field| {
                        @field(result, field.name) = try self.input(field.type);
                    }
                },
                .int => {
                    // TODO: currently, we can't get single character as u8... Need to implement 'Char' struct like original proconio
                    const buf = try self.scanner.readNextTokenSlice();
                    result = try std.fmt.parseInt(T, buf, 0);
                },
                .float => {
                    const buf = try self.scanner.readNextTokenSlice();
                    result = try std.fmt.parseFloat(T, buf);
                },
                .bool => {
                    const buf = try self.scanner.readNextTokenSlice();
                    result = self.parse_bool(buf);
                },
                .@"enum" => {
                    const buf = try self.scanner.readNextTokenSlice();
                    result = std.meta.stringToEnum(T, buf) orelse blk: {
                        const num = std.fmt.parseInt(usize, buf, 0) catch {
                            return error.ParseError;
                        };
                        break :blk @enumFromInt(num);
                    };
                },
                .array => |info| {
                    inline for (0..info.len) |i| {
                        result[i] = try self.input(info.child);
                    }
                },
                .vector => |info| {
                    inline for (0..info.len) |i| {
                        result[i] = try self.input(info.child);
                    }
                },
                else => {
                    // TODO: support other types
                    @compileError("");
                },
            }
            return result;
        }

        fn Parse(comptime T: type) type {
            return T;
        }
    };
}

fn parseBoolDefault(buf: []const u8) bool {
    return !(std.mem.eql(u8, buf, "false") or std.mem.eql(u8, buf, "0"));
}

const testing = std.testing;
test {
    const allocator = testing.allocator;
    var proconio = try initAny(
        allocator,
        "1234 5678 3.14 true false",
        false,
    );
    defer proconio.deinit();

    const in = try proconio.input(struct {
        n: u32,
        m: i64,
        f: f32,
        b1: bool,
        b2: bool,
    });

    try testing.expectEqual(@as(u32, 1234), in.n);
    try testing.expectEqual(@as(i64, 5678), in.m);
    try testing.expectEqual(@as(f32, 3.14), in.f);
    try testing.expectEqual(true, in.b1);
    try testing.expectEqual(false, in.b2);
}
