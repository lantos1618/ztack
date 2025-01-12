const std = @import("std");

pub const JsValue = union(enum) {
    number: i32,
    string: []const u8,
    boolean: bool,
    null,
    undefined,
    object: []const u8,

    pub fn toString(self: JsValue) []const u8 {
        switch (self) {
            .number => |n| return std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{n}) catch unreachable,
            .string => |s| return std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\"", .{s}) catch unreachable,
            .boolean => |b| return if (b) "true" else "false",
            .null => return "null",
            .undefined => return "undefined",
            .object => |o| return o,
        }
    }
};

pub const JsExpression = union(enum) {
    value: JsValue,
    identifier: []const u8,
    binary_op: struct {
        left: *const JsExpression,
        operator: []const u8,
        right: *const JsExpression,
    },
    unary_op: struct {
        operator: []const u8,
        operand: *const JsExpression,
    },
    property_access: struct {
        object: *const JsExpression,
        property: []const u8,
    },
    method_call: struct {
        object: *const JsExpression,
        method: []const u8,
        args: []const JsExpression,
    },
    function_call: struct {
        function: *const JsExpression,
        args: []const JsExpression,
    },
    array_literal: []const JsExpression,
    object_literal: []struct {
        key: []const u8,
        value: JsExpression,
    },

    pub fn toString(self: JsExpression) []const u8 {
        switch (self) {
            .value => |v| return v.toString(),
            .identifier => |i| return i,
            .binary_op => |b| {
                const left = b.left.toString();
                const right = b.right.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "{s} {s} {s}", .{ left, b.operator, right }) catch unreachable;
            },
            .unary_op => |u| {
                const operand = u.operand.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}{s}", .{ u.operator, operand }) catch unreachable;
            },
            .property_access => |p| {
                const obj = p.object.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}.{s}", .{ obj, p.property }) catch unreachable;
            },
            .method_call => |m| {
                const obj = m.object.toString();
                var args_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer args_str.deinit();
                for (m.args, 0..) |arg, i| {
                    if (i > 0) args_str.writer().writeAll(", ") catch unreachable;
                    args_str.writer().writeAll(arg.toString()) catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}.{s}({s})", .{ obj, m.method, args_str.items }) catch unreachable;
            },
            .function_call => |f| {
                const func = f.function.toString();
                var args_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer args_str.deinit();
                for (f.args, 0..) |arg, i| {
                    if (i > 0) args_str.writer().writeAll(", ") catch unreachable;
                    args_str.writer().writeAll(arg.toString()) catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}({s})", .{ func, args_str.items }) catch unreachable;
            },
            .array_literal => |a| {
                var items_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer items_str.deinit();
                for (a, 0..) |item, i| {
                    if (i > 0) items_str.writer().writeAll(", ") catch unreachable;
                    items_str.writer().writeAll(item.toString()) catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "[{s}]", .{items_str.items}) catch unreachable;
            },
            .object_literal => |o| {
                var props_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer props_str.deinit();
                for (o, 0..) |prop, i| {
                    if (i > 0) props_str.writer().writeAll(", ") catch unreachable;
                    const value = prop.value.toString();
                    props_str.writer().print("\"{s}\": {s}", .{ prop.key, value }) catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "{{{s}}}", .{props_str.items}) catch unreachable;
            },
        }
    }
};

pub const JsStatement = union(enum) {
    empty,
    expression: JsExpression,
    var_decl: struct {
        name: []const u8,
        value: JsExpression,
    },
    let_decl: struct {
        name: []const u8,
        value: JsExpression,
    },
    const_decl: struct {
        name: []const u8,
        value: JsExpression,
    },
    assign: struct {
        target: []const u8,
        value: JsExpression,
    },
    if_stmt: struct {
        condition: JsExpression,
        body: []const JsStatement,
        else_body: ?[]const JsStatement = null,
    },
    while_stmt: struct {
        condition: JsExpression,
        body: []const JsStatement,
    },
    for_stmt: struct {
        init: ?*const JsStatement,
        condition: ?JsExpression,
        update: ?JsExpression,
        body: []const JsStatement,
    },
    return_stmt: ?JsExpression,
    block: []const JsStatement,
    function_decl: struct {
        name: []const u8,
        params: []const []const u8,
        body: []const JsStatement,
    },

    pub fn toString(self: JsStatement) []const u8 {
        switch (self) {
            .empty => return "",
            .expression => |e| return std.fmt.allocPrint(std.heap.page_allocator, "{s};", .{e.toString()}) catch unreachable,
            .var_decl => |v| {
                const value = v.value.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "var {s} = {s};", .{ v.name, value }) catch unreachable;
            },
            .let_decl => |l| {
                const value = l.value.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "let {s} = {s};", .{ l.name, value }) catch unreachable;
            },
            .const_decl => |c| {
                const value = c.value.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "const {s} = {s};", .{ c.name, value }) catch unreachable;
            },
            .assign => |a| {
                const value = a.value.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "{s} = {s};", .{ a.target, value }) catch unreachable;
            },
            .if_stmt => |i| {
                const cond = i.condition.toString();
                var body_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer body_str.deinit();
                for (i.body) |stmt| {
                    body_str.writer().writeAll("  ") catch unreachable;
                    body_str.writer().writeAll(stmt.toString()) catch unreachable;
                    body_str.writer().writeAll("\n") catch unreachable;
                }
                if (i.else_body) |else_body| {
                    var else_str = std.ArrayList(u8).init(std.heap.page_allocator);
                    defer else_str.deinit();
                    for (else_body) |stmt| {
                        else_str.writer().writeAll("  ") catch unreachable;
                        else_str.writer().writeAll(stmt.toString()) catch unreachable;
                        else_str.writer().writeAll("\n") catch unreachable;
                    }
                    return std.fmt.allocPrint(std.heap.page_allocator, "if ({s}) {{\n{s}}} else {{\n{s}}}\n", .{ cond, body_str.items, else_str.items }) catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "if ({s}) {{\n{s}}}\n", .{ cond, body_str.items }) catch unreachable;
            },
            .while_stmt => |w| {
                const cond = w.condition.toString();
                var body_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer body_str.deinit();
                for (w.body) |stmt| {
                    body_str.writer().writeAll("  ") catch unreachable;
                    body_str.writer().writeAll(stmt.toString()) catch unreachable;
                    body_str.writer().writeAll("\n") catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "while ({s}) {{\n{s}}}\n", .{ cond, body_str.items }) catch unreachable;
            },
            .for_stmt => |f| {
                var init_str: []const u8 = "";
                var cond_str: []const u8 = "";
                var update_str: []const u8 = "";
                if (f.init) |init| init_str = init.toString();
                if (f.condition) |cond| cond_str = cond.toString();
                if (f.update) |update| update_str = update.toString();

                var body_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer body_str.deinit();
                for (f.body) |stmt| {
                    body_str.writer().writeAll("  ") catch unreachable;
                    body_str.writer().writeAll(stmt.toString()) catch unreachable;
                    body_str.writer().writeAll("\n") catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "for ({s}; {s}; {s}) {{\n{s}}}\n", .{ init_str, cond_str, update_str, body_str.items }) catch unreachable;
            },
            .return_stmt => |r| {
                if (r) |expr| {
                    const value = expr.toString();
                    return std.fmt.allocPrint(std.heap.page_allocator, "return {s};\n", .{value}) catch unreachable;
                }
                return "return;\n";
            },
            .block => |b| {
                var body_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer body_str.deinit();
                for (b) |stmt| {
                    body_str.writer().writeAll("  ") catch unreachable;
                    body_str.writer().writeAll(stmt.toString()) catch unreachable;
                    body_str.writer().writeAll("\n") catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "{{\n{s}}}\n", .{body_str.items}) catch unreachable;
            },
            .function_decl => |f| {
                var params_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer params_str.deinit();
                for (f.params, 0..) |param, i| {
                    if (i > 0) params_str.writer().writeAll(", ") catch unreachable;
                    params_str.writer().writeAll(param) catch unreachable;
                }

                var body_str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer body_str.deinit();
                for (f.body) |stmt| {
                    body_str.writer().writeAll("  ") catch unreachable;
                    body_str.writer().writeAll(stmt.toString()) catch unreachable;
                    body_str.writer().writeAll("\n") catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "function {s}({s}) {{\n{s}}}\n", .{ f.name, params_str.items, body_str.items }) catch unreachable;
            },
        }
    }
};
