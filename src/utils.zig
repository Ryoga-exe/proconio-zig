const std = @import("std");

pub fn Parse(comptime T: type) type {
    switch (@typeInfo(T)) {
        .@"struct" => |info| {
            if (@hasField(T, "__proconio_marker")) {
                return T.Type;
            } else {
                var fields: [info.fields.len]std.builtin.Type.StructField = undefined;
                inline for (info.fields, 0..) |field, i| {
                    const FieldType = Parse(field.type);
                    fields[i] = .{
                        .name = field.name,
                        .type = FieldType,
                        .default_value_ptr = null, // field.default_value_ptr,
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
