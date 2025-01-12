const std = @import("std");
const dom = @import("dom");
const js = @import("js_gen");

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

    const func_info = info.Fn;
    const ReturnType = func_info.return_type.?;

    // Get function body AST at compile time
    const decls = @typeInfo(ReturnType).Struct.decls;
    var statements = std.ArrayList(js.JsStatement).init(std.heap.page_allocator);
    defer statements.deinit();

    // Analyze each statement in the function body
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
                    .condition = analyzeExpression(i.cond),
                    .body = analyzeBody(i.then_body),
                    .else_body = if (i.else_body) |eb| analyzeBody(eb) else null,
                },
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
        .Call => .{
            .method_call = .{
                .object = analyzeExpression(expr.callee),
                .method = expr.name,
                .args = analyzeExpressions(expr.args),
            },
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
        else => .{
            .value = .undefined,
        },
    };
}

fn analyzeExpressions(comptime exprs: anytype) []const js.JsExpression {
    const T = @TypeOf(exprs);
    if (@typeInfo(T) != .Array) @compileError("Expected array type");

    var result: [exprs.len]js.JsExpression = undefined;
    inline for (exprs, 0..) |expr, i| {
        result[i] = analyzeExpression(expr);
    }
    return &result;
}
