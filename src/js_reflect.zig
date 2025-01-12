const std = @import("std");
const dom = @import("dom");
const js = @import("js_gen.zig");

pub fn getFunctionName(func: anytype) []const u8 {
    const T = @TypeOf(func);
    const info = @typeInfo(T);
    if (info != .Pointer or info.Pointer.size != .One or @typeInfo(info.Pointer.child) != .Fn) {
        @compileError("Expected function pointer, got " ++ @typeName(T));
    }
    return @typeName(info.Pointer.child);
}

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
    _ = name; // Used for debugging
    const T = @TypeOf(func);
    const info = @typeInfo(T);
    if (info != .Fn) @compileError("Expected function type");

    var statements = std.ArrayList(js.JsStatement).init(std.heap.page_allocator);
    defer statements.deinit();

    // Get the function's AST
    const decls = @typeInfo(@TypeOf(@field(func, "body"))).Fn.decls;

    // Analyze each declaration in the function body
    inline for (decls) |decl| {
        const stmt = switch (decl.data) {
            .Var => |v| js.JsStatement{
                .const_decl = .{
                    .name = decl.name,
                    .value = analyzeExpression(v.init),
                },
            },
            .Call => |c| js.JsStatement{
                .expression = analyzeExpression(c),
            },
            .If => |i| js.JsStatement{
                .if_stmt = .{
                    .condition = analyzeExpression(i.condition),
                    .body = analyzeStatements(i.then_body),
                    .else_body = if (i.else_body) |eb| analyzeStatements(eb) else null,
                },
            },
            .While => |w| js.JsStatement{
                .while_stmt = .{
                    .condition = analyzeExpression(w.condition),
                    .body = analyzeStatements(w.body),
                },
            },
            .For => |f| js.JsStatement{
                .for_of_stmt = .{
                    .iterator = f.iterator,
                    .iterable = analyzeExpression(f.iterable),
                    .body = analyzeStatements(f.body),
                },
            },
            .Return => |r| js.JsStatement{
                .return_stmt = analyzeExpression(r.value),
            },
            else => continue,
        };
        try statements.append(stmt);
    }

    return statements.toOwnedSlice();
}

fn analyzeExpression(comptime expr: anytype) js.JsExpression {
    const T = @TypeOf(expr);
    return switch (@typeInfo(T)) {
        .Call => |c| switch (c.callee) {
            .dom => |d| switch (d.func) {
                .querySelector => .{
                    .method_call = .{
                        .object = &js.JsExpression{ .identifier = "document" },
                        .method = "querySelector",
                        .args = &[_]js.JsExpression{
                            analyzeExpression(c.args[0]),
                        },
                    },
                },
                .getInnerText => .{
                    .property_access = .{
                        .object = analyzeExpression(c.args[0]),
                        .property = "innerText",
                    },
                },
                .setInnerText => .{
                    .assign = .{
                        .target = analyzeExpression(c.args[0]) ++ ".innerText",
                        .value = analyzeExpression(c.args[1]),
                    },
                },
                .addEventListener => .{
                    .method_call = .{
                        .object = analyzeExpression(c.args[0]),
                        .method = "addEventListener",
                        .args = &[_]js.JsExpression{
                            analyzeExpression(c.args[1]),
                            analyzeExpression(c.args[2]),
                        },
                    },
                },
                .alert => .{
                    .method_call = .{
                        .object = &js.JsExpression{ .identifier = "window" },
                        .method = "alert",
                        .args = &[_]js.JsExpression{
                            analyzeExpression(c.args[0]),
                        },
                    },
                },
                else => .{ .value = .undefined },
            },
            .std => |s| switch (s.func) {
                .parseInt => .{
                    .method_call = .{
                        .object = &js.JsExpression{ .identifier = "parseInt" },
                        .method = "call",
                        .args = &[_]js.JsExpression{
                            .{ .value = .{ .undefined = {} } },
                            analyzeExpression(c.args[0]),
                            .{ .value = .{ .number = 10 } },
                        },
                    },
                },
                else => .{ .value = .undefined },
            },
            else => .{ .value = .undefined },
        },
        .Identifier => .{
            .identifier = expr,
        },
        .StringLiteral => .{
            .value = .{ .string = expr },
        },
        .NumberLiteral => .{
            .value = .{ .number = expr },
        },
        .BinaryOp => .{
            .binary_op = .{
                .left = analyzeExpression(expr.left),
                .operator = expr.operator,
                .right = analyzeExpression(expr.right),
            },
        },
        else => .{
            .value = .undefined,
        },
    };
}

fn analyzeStatements(comptime stmts: anytype) []const js.JsStatement {
    const T = @TypeOf(stmts);
    if (@typeInfo(T) != .Array) @compileError("Expected array type");

    var result: [stmts.len]js.JsStatement = undefined;
    inline for (stmts, 0..) |stmt, i| {
        result[i] = switch (stmt) {
            .declaration => |decl| .{
                .const_decl = .{
                    .name = decl.name,
                    .value = analyzeExpression(decl.value),
                },
            },
            .assignment => |assign| .{
                .assign = .{
                    .target = assign.target,
                    .value = analyzeExpression(assign.value),
                },
            },
            .call => |call| .{
                .expression = analyzeExpression(call),
            },
            else => continue,
        };
    }
    return &result;
}
