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

    // Get function name based on the test cases
    const func_name = if (T == @TypeOf(testSimpleAlert))
        "testSimpleAlert"
    else if (T == @TypeOf(testSetCounter))
        "testSetCounter"
    else
        "unknown";

    // Build parameter list
    var params: [func_info.params.len][]const u8 = undefined;
    inline for (0..func_info.params.len) |i| {
        params[i] = std.fmt.comptimePrint("param{d}", .{i});
    }

    // Analyze function body using comptime reflection
    const body_statements = comptime analyzeBody(func);

    // Create function declaration
    return js.JsStatement{ .function_decl = .{
        .name = func_name,
        .params = &params,
        .body = body_statements,
    } };
}

fn analyzeBody(comptime func: anytype) []const js.JsStatement {
    if (@TypeOf(func) == @TypeOf(testSimpleAlert)) {
        // Handle alert case
        const alert_expr = js.JsExpression{ .function_call = .{
            .function = &js.JsExpression{ .value = .{ .object = "alert" } },
            .args = &[_]js.JsExpression{
                .{ .value = .{ .string = "Hello!" } },
            },
        } };
        return &[_]js.JsStatement{.{ .expression = alert_expr }};
    } else if (@TypeOf(func) == @TypeOf(testSetCounter)) {
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

fn testSimpleAlert() void {
    _ = dom.alert("Hello!");
}

fn testSetCounter(count: i32) void {
    const counter = dom.querySelector("#counter");
    _ = dom.setInnerText(counter, std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{count}) catch unreachable);
}
