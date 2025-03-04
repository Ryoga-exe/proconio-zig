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

        fn init(allocator: Allocator, source: anytype) !Self {
            return Self{
                .arena = ArenaAllocator.init(allocator),
                .scanner = try sc.scanner(allocator, source, interactive),
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
                .int => |info| {
                    const buf = try self.scanner.readNextTokenSlice();
                    result = try std.fmt.parseInt(std.meta.Int(info.signedness, info.bits), buf, 0);
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

const testing = std.testing;
test {
    const allocator = testing.allocator;
    const proconio = try init(allocator);
    defer proconio.deinit();
}
