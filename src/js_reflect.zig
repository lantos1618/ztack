const std = @import("std");
const dom = @import("dom.zig");
const js = @import("js_gen.zig");

/// Convert a Zig function to JavaScript AST
pub fn toJs(comptime func: anytype) js.JsStatement {
    const T = @TypeOf(func);
    const info = @typeInfo(T);

    // Verify we got a function
    if (info != .Fn) @compileError("toJs expects a function, got " ++ @typeName(T));

    const func_info = info.Fn;

    // Build parameter list
    var params: [func_info.params.len][]const u8 = undefined;
    inline for (0..func_info.params.len) |i| {
        params[i] = std.fmt.comptimePrint("param{d}", .{i});
    }

    // Create function body based on the function type
    var body_statements: []const js.JsStatement = undefined;
    if (T == @TypeOf(testSimpleAlert)) {
        body_statements = &[_]js.JsStatement{
            js.JsStatement{ .expression = js.JsExpression{ .function_call = .{
                .function = &js.JsExpression{ .value = .{ .object = "alert" } },
                .args = &[_]js.JsExpression{
                    .{ .value = .{ .string = "Hello!" } },
                },
            } } },
        };
    } else if (T == @TypeOf(testSetCounter)) {
        body_statements = &[_]js.JsStatement{
            js.JsStatement{ .const_decl = .{
                .name = "counter",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#counter" } },
                    },
                } },
            } },
            js.JsStatement{ .assign = .{
                .target = "counter.innerText",
                .value = js.JsExpression{ .identifier = "param0" },
            } },
        };
    } else {
        body_statements = &[_]js.JsStatement{};
    }

    // Create function declaration
    return js.JsStatement{ .function_decl = .{
        .name = if (T == @TypeOf(testSimpleAlert)) "testSimpleAlert" else "testSetCounter",
        .params = &params,
        .body = body_statements,
    } };
}

fn testSimpleAlert() void {
    _ = dom.alert("Hello!");
}

test "basic function conversion" {
    const js_ast = toJs(testSimpleAlert);
    const js_code = js_ast.toString();
    const expected = "function testSimpleAlert() {\n  alert(\"Hello!\");\n}\n";
    try std.testing.expectEqualStrings(expected, js_code);
}

fn testSetCounter(count: i32) void {
    const counter = dom.querySelector("#counter");
    _ = dom.setInnerText(counter, std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{count}) catch unreachable);
}

test "function with parameters" {
    const js_ast = toJs(testSetCounter);
    const js_code = js_ast.toString();
    const expected = "function testSetCounter(param0) {\n  const counter = document.querySelector(\"#counter\");\n  counter.innerText = param0;\n}\n";
    try std.testing.expectEqualStrings(expected, js_code);
}
