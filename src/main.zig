const std = @import("std");

/// Will check the structural equality of two structs, pointers, and unions.
pub fn StructEql(comptime T: type, a: T, b: T) bool {
    if (@sizeOf(T) == 0) return true;
    var areEql = true;
    switch (@typeInfo(T)) {
        .Struct => |structInfo| {
            inline for (structInfo.fields) |structField| {
                switch (@typeInfo(structField.type)) {
                    .Struct, .Union => {
                        areEql = StructEql(structField.type, @field(a, structField.name), @field(b, structField.name));
                        if (areEql == false) {
                            break;
                        }
                    },
                    inline else => {
                        if (@field(a, structField.name) != @field(b, structField.name)) {
                            areEql = false;
                            break;
                        }
                    },
                }
            }
        },
        .Union => |unionInfo| {
            inline for (unionInfo.fields) |unionField| {
                // Need to make sure that we are working with the activeTag before we iterate through that tag's underlying field type.
                if (std.mem.eql(u8, unionField.name, @tagName(std.meta.activeTag(a))) and std.mem.eql(u8, unionField.name, @tagName(std.meta.activeTag(b)))) {
                    switch (@typeInfo(unionField.type)) {
                        .Struct, .Union => {
                            areEql = StructEql(unionField.type, @field(a, unionField.name), @field(b, unionField.name));
                            if (areEql == false) {
                                break;
                            }
                        },
                        inline else => {
                            if (@field(a, unionField.name) != @field(b, unionField.name)) {
                                areEql = false;
                                break;
                            }
                        },
                    }
                }
            }
        },
        .Pointer => |_| {
            if (a == b) {
                return StructEql(@TypeOf(a.*), a.*, b.*);
            }
        },
        else => {
            std.io.getStdErr().writer().print("Unsupported type '{any}'", .{@typeInfo(T)}) catch {};
            return false;
        },
    }
    return areEql;
}

test "Primitive == Primitive" {
    try std.testing.expect(StructEql(comptime_int, 10, 10) == true);
}

test "Struct <-> Struct" {
    const Point = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    const p0 = Point{};
    const p1 = Point{};

    try std.testing.expect(StructEql(Point, p0, p1) == true);
}

test "Struct With Nested Struct <-> Struct With Nested Struct" {
    const Point = struct {
        x: f32 = 0,
        y: f32 = 0,
    };
    const Transform = struct {
        pos: Point = .{ .x = 0, .y = 0 },
        rot: Point = .{ .x = 0, .y = 0 },
        scale: Point = .{ .x = 0, .y = 0 },
    };

    const Circle = struct {
        transform: Transform,
        radius: f32,
    };

    const t0 = Transform{ .pos = .{ .x = 0, .y = 0 } };
    const t1 = Transform{};
    const c0 = Circle{ .transform = t0, .radius = 0 };
    const c1 = Circle{ .transform = t1, .radius = 0 };

    try std.testing.expect(StructEql(Circle, c0, c1) == true);
}

test "Tagged Union with nested Struct <-> Tagged Union with nested Structs" {
    const Point = struct {
        x: f32 = 0,
        y: f32 = 0,
    };
    const Transform = struct {
        pos: Point = .{ .x = 0, .y = 0 },
        rot: Point = .{ .x = 0, .y = 0 },
        scale: Point = .{ .x = 0, .y = 0 },
    };

    const Circle = struct {
        transform: Transform,
        radius: f32,
    };

    const Rectangle = struct {
        transform: Transform,
        width: f32,
        height: f32,
    };

    const Collider = union(enum) {
        Circle: Circle,
        Rectangle: Rectangle,
    };

    const t0 = Transform{};
    const t1 = Transform{};
    const c0 = Circle{ .transform = t0, .radius = 0 };
    const c1 = Circle{ .transform = t1, .radius = 0 };
    const col0 = Collider{ .Circle = c0 };
    const col1 = Collider{ .Circle = c1 };

    try std.testing.expect(StructEql(Collider, col0, col1) == true);
}

test "Pointer == Pointer (Both pointers point to the same address, and the data at that address is structurally equal)" {
    const Point = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    var x: Point = .{ .x = 0, .y = 10 };

    var p0 = &x;
    var p1 = &x;

    const p2 = &x;
    const p3 = &x;

    // Getting around unused variable error -_-...
    p0.x = 0;
    p1.x = 0;

    try std.testing.expect(StructEql(*Point, p0, p1));
    try std.testing.expect(StructEql(*const Point, p2, p3));
}

test "Big Mamba == Big Mamba (Two structs with a relatively complex struct hierarchy)" {
    const Point = struct {
        x: f32 = 0,
        y: f32 = 0,
    };

    const Transform = struct {
        pos: Point = .{ .x = 0, .y = 0 },
        rot: Point = .{ .x = 0, .y = 0 },
        scale: Point = .{ .x = 0, .y = 0 },
    };

    const Circle = struct {
        transform: Transform,
        radius: f32,
    };

    const Rectangle = struct {
        transform: Transform,
        width: f32,
        height: f32,
    };

    const Collider = union(enum) {
        Circle: Circle,
        Rectangle: Rectangle,
    };

    const Entity = struct {
        transform: Transform,
        collider: Collider,
    };

    const e0 = Entity{
        .transform = Transform{},
        .collider = Collider{ .Circle = Circle{
            .transform = Transform{},
            .radius = 1,
        } },
    };
    const e1 = Entity{
        .transform = Transform{},
        .collider = Collider{ .Circle = Circle{
            .transform = Transform{},
            .radius = 1,
        } },
    };

    try std.testing.expect(StructEql(Entity, e0, e1));
}
