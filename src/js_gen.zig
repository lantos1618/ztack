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
    for_of_stmt: struct {
        iterator: []const u8,
        iterable: JsExpression,
        body: []const JsStatement,
    },
    try_stmt: struct {
        body: []const JsStatement,
        catch_body: []const JsStatement,
    },
    return_stmt: ?JsExpression,
    block: []const JsStatement,
    function_decl: struct {
        name: []const u8,
        params: []const []const u8,
        body: []const JsStatement,
    },

    fn addIndent(writer: anytype, indent: usize) !void {
        var i: usize = 0;
        while (i < indent) : (i += 1) {
            try writer.writeAll("  ");
        }
    }

    fn toStringWithIndent(self: JsStatement, indent: usize) []const u8 {
        switch (self) {
            .empty => return "",
            .expression => |e| {
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll(e.toString()) catch unreachable;
                str.writer().writeAll(";") catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .var_decl => |v| {
                const value = v.value.toString();
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("var {s} = {s};", .{ v.name, value }) catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .let_decl => |l| {
                const value = l.value.toString();
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("let {s} = {s};", .{ l.name, value }) catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .const_decl => |c| {
                const value = c.value.toString();
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("const {s} = {s};", .{ c.name, value }) catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .assign => |a| {
                const value = a.value.toString();
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("{s} = {s};", .{ a.target, value }) catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .if_stmt => |i| {
                const cond = i.condition.toString();
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("if ({s}) {{\n", .{cond}) catch unreachable;
                for (i.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                if (i.else_body) |else_body| {
                    str.writer().writeAll(" else {\n") catch unreachable;
                    for (else_body) |stmt| {
                        const stmt_str = stmt.toStringWithIndent(indent + 1);
                        str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                    }
                    addIndent(&str.writer(), indent) catch unreachable;
                    str.writer().writeAll("}") catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .while_stmt => |w| {
                const cond = w.condition.toString();
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("while ({s}) {{\n", .{cond}) catch unreachable;
                for (w.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .for_stmt => |f| {
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("for (") catch unreachable;
                if (f.init) |init| {
                    str.writer().writeAll(init.toString()) catch unreachable;
                }
                str.writer().writeAll("; ") catch unreachable;
                if (f.condition) |cond| {
                    str.writer().writeAll(cond.toString()) catch unreachable;
                }
                str.writer().writeAll("; ") catch unreachable;
                if (f.update) |update| {
                    str.writer().writeAll(update.toString()) catch unreachable;
                }
                str.writer().writeAll(") {\n") catch unreachable;
                for (f.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .for_of_stmt => |f| {
                const iterable = f.iterable.toString();
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("for (const {s} of {s}) {{\n", .{ f.iterator, iterable }) catch unreachable;
                for (f.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .try_stmt => |t| {
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("try {\n") catch unreachable;
                for (t.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("} catch (error) {\n") catch unreachable;
                for (t.catch_body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .return_stmt => |r| {
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                if (r) |expr| {
                    const value = expr.toString();
                    str.writer().print("return {s};", .{value}) catch unreachable;
                } else {
                    str.writer().writeAll("return;") catch unreachable;
                }
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .block => |b| {
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("{\n") catch unreachable;
                for (b) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
            .function_decl => |f| {
                var str = std.ArrayList(u8).init(std.heap.page_allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("function {s}(", .{f.name}) catch unreachable;
                for (f.params, 0..) |param, i| {
                    if (i > 0) str.writer().writeAll(", ") catch unreachable;
                    str.writer().writeAll(param) catch unreachable;
                }
                str.writer().writeAll(") {\n") catch unreachable;
                for (f.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}\n") catch unreachable;
                return std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{str.items}) catch unreachable;
            },
        }
    }

    pub fn toString(self: JsStatement) []const u8 {
        return self.toStringWithIndent(0);
    }
};
