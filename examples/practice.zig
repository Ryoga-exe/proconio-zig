// https://atcoder.jp/contests/practice/tasks/practice_1

const std = @import("std");
const proconio = @import("proconio");
const marker = proconio.marker;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var io = try proconio.init(allocator);
    defer io.deinit();

    const in = try io.input(struct {
        a: i32,
        b: i32,
        c: i32,
        s: marker.Bytes,
    });

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("{d} {s}\n", .{ in.a + in.b + in.c, in.s });
    try stdout.flush();
}
