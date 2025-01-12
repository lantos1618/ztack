const std = @import("std");
const js = @import("js_gen.zig");

test "JsValue string conversion" {
    const cases = [_]struct {
        value: js.JsValue,
        expected: []const u8,
    }{
        .{ .value = js.JsValue{ .number = 42 }, .expected = "42" },
        .{ .value = js.JsValue{ .string = "hello" }, .expected = "\"hello\"" },
        .{ .value = js.JsValue{ .boolean = true }, .expected = "true" },
        .{ .value = js.JsValue{ .boolean = false }, .expected = "false" },
        .{ .value = js.JsValue{ .null = {} }, .expected = "null" },
        .{ .value = js.JsValue{ .undefined = {} }, .expected = "undefined" },
        .{ .value = js.JsValue{ .object = "document" }, .expected = "document" },
    };

    for (cases) |case| {
        try std.testing.expectEqualStrings(case.expected, case.value.toString());
    }
}

test "JsExpression binary operations" {
    const left = js.JsExpression{ .value = js.JsValue{ .number = 1 } };
    const right = js.JsExpression{ .value = js.JsValue{ .number = 2 } };

    const binary_op = js.JsExpression{ .binary_op = .{
        .left = &left,
        .operator = "+",
        .right = &right,
    } };

    try std.testing.expectEqualStrings("1 + 2", binary_op.toString());
}

test "JsExpression method calls" {
    const obj = js.JsExpression{ .value = js.JsValue{ .object = "document" } };
    const method_call = js.JsExpression{ .method_call = .{
        .object = &obj,
        .method = "querySelector",
        .args = &[_]js.JsExpression{
            .{ .value = js.JsValue{ .string = "#test" } },
        },
    } };

    try std.testing.expectEqualStrings("document.querySelector(\"#test\")", method_call.toString());
}

test "JsExpression property access" {
    const obj = js.JsExpression{ .identifier = "element" };
    const prop_access = js.JsExpression{ .property_access = .{
        .object = &obj,
        .property = "innerText",
    } };

    try std.testing.expectEqualStrings("element.innerText", prop_access.toString());
}

test "JsExpression array literals" {
    const array = js.JsExpression{ .array_literal = &[_]js.JsExpression{
        .{ .value = js.JsValue{ .number = 1 } },
        .{ .value = js.JsValue{ .number = 2 } },
        .{ .value = js.JsValue{ .number = 3 } },
    } };

    try std.testing.expectEqualStrings("[1, 2, 3]", array.toString());
}

test "JsStatement variable declarations" {
    const value = js.JsExpression{ .value = js.JsValue{ .number = 42 } };

    const var_decl = js.JsStatement{ .var_decl = .{
        .name = "x",
        .value = value,
    } };

    const let_decl = js.JsStatement{ .let_decl = .{
        .name = "y",
        .value = value,
    } };

    const const_decl = js.JsStatement{ .const_decl = .{
        .name = "z",
        .value = value,
    } };

    try std.testing.expectEqualStrings("var x = 42;", var_decl.toString());
    try std.testing.expectEqualStrings("let y = 42;", let_decl.toString());
    try std.testing.expectEqualStrings("const z = 42;", const_decl.toString());
}

test "JsStatement if statement" {
    const condition = js.JsExpression{ .binary_op = .{
        .left = &js.JsExpression{ .identifier = "x" },
        .operator = ">",
        .right = &js.JsExpression{ .value = js.JsValue{ .number = 0 } },
    } };

    const if_stmt = js.JsStatement{ .if_stmt = .{
        .condition = condition,
        .body = &[_]js.JsStatement{
            .{ .expression = js.JsExpression{ .method_call = .{
                .object = &js.JsExpression{ .value = js.JsValue{ .object = "console" } },
                .method = "log",
                .args = &[_]js.JsExpression{
                    .{ .value = js.JsValue{ .string = "positive" } },
                },
            } } },
        },
    } };

    const expected =
        \\if (x > 0) {
        \\  console.log("positive");
        \\}
    ;

    try std.testing.expectEqualStrings(expected, if_stmt.toString());
}

test "JsStatement while loop" {
    const condition = js.JsExpression{ .binary_op = .{
        .left = &js.JsExpression{ .identifier = "count" },
        .operator = "<",
        .right = &js.JsExpression{ .value = js.JsValue{ .number = 10 } },
    } };

    const while_stmt = js.JsStatement{ .while_stmt = .{
        .condition = condition,
        .body = &[_]js.JsStatement{
            .{ .assign = .{
                .target = "count",
                .value = js.JsExpression{ .binary_op = .{
                    .left = &js.JsExpression{ .identifier = "count" },
                    .operator = "+",
                    .right = &js.JsExpression{ .value = js.JsValue{ .number = 1 } },
                } },
            } },
        },
    } };

    const expected =
        \\while (count < 10) {
        \\  count = count + 1;
        \\}
    ;

    try std.testing.expectEqualStrings(expected, while_stmt.toString());
}

test "JsStatement for-of loop" {
    const for_of = js.JsStatement{ .for_of_stmt = .{
        .iterator = "item",
        .iterable = js.JsExpression{ .identifier = "items" },
        .body = &[_]js.JsStatement{
            .{ .expression = js.JsExpression{ .method_call = .{
                .object = &js.JsExpression{ .value = js.JsValue{ .object = "console" } },
                .method = "log",
                .args = &[_]js.JsExpression{
                    .{ .identifier = "item" },
                },
            } } },
        },
    } };

    const expected =
        \\for (const item of items) {
        \\  console.log(item);
        \\}
    ;

    try std.testing.expectEqualStrings(expected, for_of.toString());
}

test "JsStatement try-catch" {
    const try_stmt = js.JsStatement{ .try_stmt = .{
        .body = &[_]js.JsStatement{
            .{ .const_decl = .{
                .name = "x",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = js.JsValue{ .object = "JSON" } },
                    .method = "parse",
                    .args = &[_]js.JsExpression{
                        .{ .value = js.JsValue{ .string = "{}" } },
                    },
                } },
            } },
        },
        .catch_body = &[_]js.JsStatement{
            .{ .expression = js.JsExpression{ .method_call = .{
                .object = &js.JsExpression{ .value = js.JsValue{ .object = "console" } },
                .method = "error",
                .args = &[_]js.JsExpression{
                    .{ .value = js.JsValue{ .string = "Failed to parse" } },
                },
            } } },
        },
    } };

    const expected =
        \\try {
        \\  const x = JSON.parse("{}");
        \\} catch (error) {
        \\  console.error("Failed to parse");
        \\}
    ;

    try std.testing.expectEqualStrings(expected, try_stmt.toString());
}

test "JsStatement function declaration" {
    const func_decl = js.JsStatement{ .function_decl = .{
        .name = "greet",
        .params = &[_][]const u8{"name"},
        .body = &[_]js.JsStatement{
            .{ .return_stmt = js.JsExpression{ .binary_op = .{
                .left = &js.JsExpression{ .value = js.JsValue{ .string = "Hello, " } },
                .operator = "+",
                .right = &js.JsExpression{ .identifier = "name" },
            } } },
        },
    } };

    const expected =
        \\function greet(name) {
        \\  return "Hello, " + name;
        \\}
        \\
    ;

    try std.testing.expectEqualStrings(expected, func_decl.toString());
}
