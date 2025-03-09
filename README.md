# proconio-zig

proconio for the Zig programming language. useful and easy IO library for programming contests.

## usage

```zig
const std = @import("std");
const proconio = @import("proconio");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var io = try proconio.init(allocator);
    defer io.deinit();

    const in = try io.input(struct {
        n: u8,
        m: u32,
        l: i32,
    });
    std.debug.print("{}, {}, {}\n", .{in.n, in.m, in.l});
}
```
