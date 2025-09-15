const Parse = @import("utils.zig").Parse;

pub const Bytes = struct {
    pub const Type = []const u8;
    __proconio_marker: void = {},

    pub fn input(io: anytype, _: ?Bytes) !Type {
        // NOTE: or
        // const allocator = io.arena.allocator();
        // return try allocator.dupe(u8, io.scanner.readNextTokenSlice());
        return try io.scanner.readNextTokenSlice();
    }
};

pub fn Slice(comptime T: type) type {
    return struct {
        const Self = @This();
        const InnerType = Parse(T);
        pub const Type = []InnerType;
        __proconio_marker: void = {},

        len: usize,

        pub fn input(io: anytype, context: ?Self) !Type {
            const allocator = io.arena.allocator();
            const len = context.?.len;
            var result = try allocator.alloc(InnerType, len);
            errdefer allocator.free(result);

            for (0..len) |i| {
                result[i] = try io.input(T);
            }

            return result;
        }

        pub fn init(len: usize) Self {
            return .{ .len = len };
        }
    };
}
