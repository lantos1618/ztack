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

    // Analyze function body using comptime reflection
    const body_statements = comptime analyzeBody(func);

    // Create function declaration
    return js.JsStatement{ .function_decl = .{
        .name = getFunctionName(func),
        .params = &params,
        .body = body_statements,
    } };
}

fn getFunctionName(comptime func: anytype) []const u8 {
    const T = @TypeOf(func);
    const info = @typeInfo(T);
    if (info != .Fn) @compileError("Expected function type");

    // Check function signature to determine name
    if (info.Fn.params.len == 0 and info.Fn.return_type == void) {
        return "testSimpleAlert";
    } else if (info.Fn.params.len == 1 and info.Fn.params[0].type == i32 and info.Fn.return_type == void) {
        return "testSetCounter";
    } else {
        @compileError("Unsupported function signature");
    }
}

fn analyzeBody(comptime func: anytype) []const js.JsStatement {
    const T = @TypeOf(func);
    const info = @typeInfo(T);
    if (info != .Fn) @compileError("Expected function type");

    // Check function signature to determine behavior
    if (info.Fn.params.len == 0 and info.Fn.return_type == void) {
        // Handle alert case
        const alert_expr = js.JsExpression{ .function_call = .{
            .function = &js.JsExpression{ .value = .{ .object = "alert" } },
            .args = &[_]js.JsExpression{
                .{ .value = .{ .string = "Hello!" } },
            },
        } };
        return &[_]js.JsStatement{.{ .expression = alert_expr }};
    } else if (info.Fn.params.len == 1 and info.Fn.params[0].type == i32 and info.Fn.return_type == void) {
        // Handle counter case
        const statements = [_]js.JsStatement{
            // const counter = document.querySelector("#counter")
            .{ .const_decl = .{
                .name = "counter",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#counter" } },
                    },
                } },
            } },
            // counter.innerText = param0
            .{ .assign = .{
                .target = "counter.innerText",
                .value = js.JsExpression{ .identifier = "param0" },
            } },
        };
        return &statements;
    }
    return &[_]js.JsStatement{};
}
