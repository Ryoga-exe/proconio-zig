pub const Bytes = struct {
    __proconio_marker: void,
    pub const Type = []const u8;

    pub fn input(io: anytype) !Type {
        return io.scanner.readNextTokenSlice();
    }
};
