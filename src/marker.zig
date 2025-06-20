pub const Bytes = struct {
    __proconio_marker: void,
    pub const Type = []const u8;

    pub fn input(io: anytype) !Type {
        return io.scanner.readNextTokenSlice();
    }
};

pub fn Slice(comptime T: type, len: usize) type {
    return struct {
        __proconio_marker: void,
        pub const Type = []T;

        pub fn input(io: anytype) !Type {
            const allocator = io.arena.allocator();
            var result = try allocator.alloc(T, len);
            errdefer allocator.free(result);

            for (0..len) |i| {
                result[i] = try io.input(T);
            }

            return result;
        }
    };
}
