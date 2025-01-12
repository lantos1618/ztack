const std = @import("std");
const testing = std.testing;
const js = @import("js_gen.zig");

test "basic value generation" {
    const num_val = js.JsValue{ .number = 42 };
    try testing.expectEqualStrings("42", num_val.toString());

    const str_val = js.JsValue{ .string = "hello" };
    try testing.expectEqualStrings("\"hello\"", str_val.toString());

    const bool_val = js.JsValue{ .boolean = true };
    try testing.expectEqualStrings("true", bool_val.toString());
}

test "binary operation" {
    const left = js.JsExpression{ .value = .{ .number = 1 } };
    const right = js.JsExpression{ .value = .{ .number = 2 } };
    const add = js.JsExpression{ .binary_op = .{
        .left = &left,
        .operator = "+",
        .right = &right,
    } };
    try testing.expectEqualStrings("1 + 2", add.toString());
}

test "property access" {
    const obj = js.JsExpression{ .value = .{ .object = "window" } };
    const prop = js.JsExpression{ .property_access = .{
        .object = &obj,
        .property = "count",
    } };
    try testing.expectEqualStrings("window.count", prop.toString());
}

test "method call" {
    const obj = js.JsExpression{ .value = .{ .object = "Math" } };
    const args = [_]js.JsExpression{
        .{ .value = .{ .number = 42 } },
    };
    const call = js.JsExpression{ .method_call = .{
        .object = &obj,
        .method = "floor",
        .args = &args,
    } };
    try testing.expectEqualStrings("Math.floor(42)", call.toString());
}

test "let statement" {
    const value = js.JsExpression{ .value = .{ .number = 42 } };
    const stmt = js.JsStatement{ .let = .{
        .name = "x",
        .value = value,
    } };
    try testing.expectEqualStrings("let x = 42;", stmt.toString());
}

test "assignment statement" {
    const value = js.JsExpression{ .value = .{ .number = 42 } };
    const stmt = js.JsStatement{ .assign = .{
        .target = "x",
        .value = value,
    } };
    try testing.expectEqualStrings("x = 42;", stmt.toString());
}

test "if statement" {
    const cond = js.JsExpression{ .value = .{ .boolean = true } };
    const body = [_]js.JsStatement{
        .{ .assign = .{
            .target = "x",
            .value = .{ .value = .{ .number = 42 } },
        } },
    };
    const stmt = js.JsStatement{ .if_stmt = .{
        .condition = cond,
        .body = &body,
    } };
    try testing.expectEqualStrings("if (true) {\n  x = 42;\n}", stmt.toString());
}
