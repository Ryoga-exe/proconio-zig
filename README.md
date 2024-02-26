# proconio-zig

proconio for the Zig programming language. useful and easy io library for programming contests.

## usage

```zig
const std = @import("std");
const Input = @import("proconio.zig").Input;

pub fn main() !void {
    const input = Input(1024).init();

    _ = input.nextUsize();
    _ = input.nextFloat(f64);

    const allocator = std.heap.page_allocator;
    const slice = input.nextSlice(usize, allocator, 10);
    defer allocator.free(slice);
}
```
