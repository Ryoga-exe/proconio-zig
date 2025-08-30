const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const File = std.fs.File;
const sc = @import("scanner.zig");
pub const marker = @import("marker.zig");

const stdin = File.stdin();

pub fn init(allocator: Allocator) !Proconio {
    return Proconio.init(allocator, stdin);
}

pub fn initInteractive(allocator: Allocator) !ProconioInteractive {
    return ProconioInteractive.init(allocator, stdin);
}

fn initAny(allocator: Allocator, source: anytype, comptime interactive: bool) !ProconioAny(@TypeOf(source), interactive) {
    return ProconioAny(@TypeOf(source), interactive).init(allocator, source);
}

const Proconio = ProconioAny(File, @import("builtin").mode == .Debug);
const ProconioInteractive = ProconioAny(File, true);
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

        pub fn deinit(self: *Self) void {
            self.scanner.deinit();
            self.arena.deinit();
        }

        pub fn input(self: *Self, comptime T: type) !Parse(T) {
            var result: Parse(T) = undefined;
            switch (@typeInfo(T)) {
                .@"struct" => |info| {
                    if (@hasField(T, "__proconio_marker")) {
                        result = try T.input(self);
                    } else {
                        inline for (info.fields) |field| {
                            @field(result, field.name) = try self.input(field.type);
                        }
                    }
                },
                .void => {
                    _ = try self.scanner.readNextTokenSlice();
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
                        // if something went wrong, try enumFromInt
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
                .optional => |info| {
                    result = self.input(info.child) catch null;
                },
                .vector => |info| {
                    inline for (0..info.len) |i| {
                        result[i] = try self.input(info.child);
                    }
                },
                else => {
                    // TODO: support other types
                    @compileError(std.fmt.comptimePrint("invalid type ({s}) given to Scanner", .{@typeName(T)}));
                },
            }
            return result;
        }

        fn Parse(comptime T: type) type {
            switch (@typeInfo(T)) {
                .@"struct" => |info| {
                    if (@hasField(T, "__proconio_marker")) {
                        return T.Type;
                    } else {
                        var fields: [info.fields.len]std.builtin.Type.StructField = undefined;
                        inline for (info.fields, 0..) |field, i| {
                            const FieldType = Self.Parse(field.type);
                            fields[i] = .{
                                .name = field.name,
                                .type = FieldType,
                                .default_value_ptr = field.default_value_ptr,
                                .is_comptime = field.is_comptime,
                                .alignment = @alignOf(FieldType),
                            };
                        }

                        return @Type(.{
                            .@"struct" = .{
                                .layout = info.layout,
                                .backing_integer = info.backing_integer,
                                .fields = &fields,
                                .decls = info.decls,
                                .is_tuple = info.is_tuple,
                            },
                        });
                    }
                },
                else => return T,
            }
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
        "1234 5678 3.14 true false test\n 100 100 200 300",
        false,
    );
    defer proconio.deinit();

    const in = try proconio.input(struct {
        n: u32,
        m: i64,
        f: f32,
        b1: bool,
        b2: bool,
        s: marker.Bytes,
        arr: marker.Slice(struct { usize, usize }, 2),
    });

    try testing.expectEqual(@as(u32, 1234), in.n);
    try testing.expectEqual(@as(i64, 5678), in.m);
    try testing.expectEqual(@as(f32, 3.14), in.f);
    try testing.expectEqual(true, in.b1);
    try testing.expectEqual(false, in.b2);
    try testing.expectEqualSlices(u8, "test", in.s);

    try testing.expectEqualSlices(struct { usize, usize }, &[_]struct { usize, usize }{ .{ 100, 100 }, .{ 200, 300 } }, in.arr);
}
