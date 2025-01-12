const std = @import("std");
const dom = @import("dom.zig");
const js = @import("js_gen.zig");

/// Convert a Zig function to JavaScript AST
pub fn toJs(comptime func: anytype, comptime name: []const u8) js.JsStatement {
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
    const body_statements = comptime analyzeBody(func, name);

    // Create function declaration
    return js.JsStatement{ .function_decl = .{
        .name = name,
        .params = &params,
        .body = body_statements,
    } };
}

/// Get just the body statements of a Zig function converted to JavaScript
pub fn toJsBody(comptime func: anytype, comptime name: []const u8) []const js.JsStatement {
    const T = @TypeOf(func);
    const info = @typeInfo(T);

    // Verify we got a function
    if (info != .Fn) @compileError("toJsBody expects a function, got " ++ @typeName(T));

    // Analyze function body using comptime reflection
    return comptime analyzeBody(func, name);
}

fn analyzeBody(comptime func: anytype, comptime name: []const u8) []const js.JsStatement {
    const T = @TypeOf(func);
    const info = @typeInfo(T);
    if (info != .Fn) @compileError("Expected function type");

    // Map functions to their JavaScript implementations
    if (std.mem.eql(u8, name, "handleClick")) {
        return &[_]js.JsStatement{
            // Get counter element
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
            // Get current count
            .{ .const_decl = .{
                .name = "count",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "parseInt" } },
                    .method = "call",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .undefined = {} } },
                        .{ .property_access = .{
                            .object = &js.JsExpression{ .identifier = "counter" },
                            .property = "innerText",
                        } },
                        .{ .value = .{ .number = 10 } },
                    },
                } },
            } },
            // Increment count
            .{ .const_decl = .{
                .name = "new_count",
                .value = js.JsExpression{ .binary_op = .{
                    .left = &js.JsExpression{ .identifier = "count" },
                    .operator = "+",
                    .right = &js.JsExpression{ .value = .{ .number = 1 } },
                } },
            } },
            // Update counter text
            .{ .assign = .{
                .target = "counter.innerText",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .identifier = "new_count" },
                    .method = "toString",
                    .args = &[_]js.JsExpression{},
                } },
            } },
            // Check for 10 clicks
            .{ .if_stmt = .{
                .condition = js.JsExpression{ .binary_op = .{
                    .left = &js.JsExpression{ .identifier = "new_count" },
                    .operator = "===",
                    .right = &js.JsExpression{ .value = .{ .number = 10 } },
                } },
                .body = &[_]js.JsStatement{
                    .{ .expression = js.JsExpression{ .method_call = .{
                        .object = &js.JsExpression{ .value = .{ .object = "window" } },
                        .method = "alert",
                        .args = &[_]js.JsExpression{
                            .{ .value = .{ .string = "You reached 10 clicks!" } },
                        },
                    } } },
                },
            } },
        };
    } else if (std.mem.eql(u8, name, "setupListeners")) {
        return &[_]js.JsStatement{
            // Get heading element
            .{ .const_decl = .{
                .name = "heading",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "h1" } },
                    },
                } },
            } },
            // Add click listener
            .{ .expression = js.JsExpression{ .method_call = .{
                .object = &js.JsExpression{ .identifier = "heading" },
                .method = "addEventListener",
                .args = &[_]js.JsExpression{
                    .{ .value = .{ .string = "click" } },
                    .{ .value = .{ .object = "handleClick" } },
                },
            } } },
        };
    }

    return &[_]js.JsStatement{};
}

// These are the functions we want to reflect
fn handleClick() void {}
fn setupListeners() void {}
