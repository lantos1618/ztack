const std = @import("std");

pub const JsValue = union(enum) {
    number: i32,
    string: []const u8,
    boolean: bool,
    null,
    undefined,
    object: []const u8,

    pub fn write(self: JsValue, writer: anytype) !void {
        switch (self) {
            .number => |n| try writer.print("{d}", .{n}),
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .boolean => |b| try writer.writeAll(if (b) "true" else "false"),
            .null => try writer.writeAll("null"),
            .undefined => try writer.writeAll("undefined"),
            .object => |o| try writer.writeAll(o),
        }
    }

    pub fn toString(self: JsValue, allocator: std.mem.Allocator) []const u8 {
        switch (self) {
            .number => |n| return std.fmt.allocPrint(allocator, "{d}", .{n}) catch unreachable,
            .string => |s| return std.fmt.allocPrint(allocator, "\"{s}\"", .{s}) catch unreachable,
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

    pub fn write(self: JsExpression, writer: anytype) !void {
        switch (self) {
            .value => |v| try v.write(writer),
            .identifier => |i| try writer.writeAll(i),
            .binary_op => |b| {
                try b.left.write(writer);
                try writer.print(" {s} ", .{b.operator});
                try b.right.write(writer);
            },
            .unary_op => |u| {
                try writer.writeAll(u.operator);
                try u.operand.write(writer);
            },
            .property_access => |p| {
                try p.object.write(writer);
                try writer.print(".{s}", .{p.property});
            },
            .method_call => |m| {
                try m.object.write(writer);
                try writer.print(".{s}(", .{m.method});
                for (m.args, 0..) |arg, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try arg.write(writer);
                }
                try writer.writeAll(")");
            },
            .function_call => |f| {
                try f.function.write(writer);
                try writer.writeAll("(");
                for (f.args, 0..) |arg, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try arg.write(writer);
                }
                try writer.writeAll(")");
            },
            .array_literal => |a| {
                try writer.writeAll("[");
                for (a, 0..) |item, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try item.write(writer);
                }
                try writer.writeAll("]");
            },
            .object_literal => |o| {
                try writer.writeAll("{");
                for (o, 0..) |prop, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try writer.print("\"{s}\": ", .{prop.key});
                    try prop.value.write(writer);
                }
                try writer.writeAll("}");
            },
        }
    }

    pub fn toString(self: JsExpression, allocator: std.mem.Allocator) []const u8 {
        switch (self) {
            .value => |v| return v.toString(allocator),
            .identifier => |i| return i,
            .binary_op => |b| {
                const left = b.left.toString(allocator);
                const right = b.right.toString(allocator);
                return std.fmt.allocPrint(allocator, "{s} {s} {s}", .{ left, b.operator, right }) catch unreachable;
            },
            .unary_op => |u| {
                const operand = u.operand.toString(allocator);
                return std.fmt.allocPrint(allocator, "{s}{s}", .{ u.operator, operand }) catch unreachable;
            },
            .property_access => |p| {
                const obj = p.object.toString(allocator);
                return std.fmt.allocPrint(allocator, "{s}.{s}", .{ obj, p.property }) catch unreachable;
            },
            .method_call => |m| {
                const obj = m.object.toString(allocator);
                var args_str = std.ArrayList(u8).init(allocator);
                defer args_str.deinit();
                for (m.args, 0..) |arg, i| {
                    if (i > 0) args_str.writer().writeAll(", ") catch unreachable;
                    args_str.writer().writeAll(arg.toString(allocator)) catch unreachable;
                }
                return std.fmt.allocPrint(allocator, "{s}.{s}({s})", .{ obj, m.method, args_str.items }) catch unreachable;
            },
            .function_call => |f| {
                const func = f.function.toString(allocator);
                var args_str = std.ArrayList(u8).init(allocator);
                defer args_str.deinit();
                for (f.args, 0..) |arg, i| {
                    if (i > 0) args_str.writer().writeAll(", ") catch unreachable;
                    args_str.writer().writeAll(arg.toString(allocator)) catch unreachable;
                }
                return std.fmt.allocPrint(allocator, "{s}({s})", .{ func, args_str.items }) catch unreachable;
            },
            .array_literal => |a| {
                var items_str = std.ArrayList(u8).init(allocator);
                defer items_str.deinit();
                for (a, 0..) |item, i| {
                    if (i > 0) items_str.writer().writeAll(", ") catch unreachable;
                    items_str.writer().writeAll(item.toString(allocator)) catch unreachable;
                }
                return std.fmt.allocPrint(allocator, "[{s}]", .{items_str.items}) catch unreachable;
            },
            .object_literal => |o| {
                var props_str = std.ArrayList(u8).init(allocator);
                defer props_str.deinit();
                for (o, 0..) |prop, i| {
                    if (i > 0) props_str.writer().writeAll(", ") catch unreachable;
                    const value = prop.value.toString(allocator);
                    props_str.writer().print("\"{s}\": {s}", .{ prop.key, value }) catch unreachable;
                }
                return std.fmt.allocPrint(allocator, "{{{s}}}", .{props_str.items}) catch unreachable;
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

    fn toStringWithIndent(self: JsStatement, allocator: std.mem.Allocator, indent: usize) []const u8 {
        switch (self) {
            .empty => return "",
            .expression => |e| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                e.write(str.writer()) catch unreachable;
                str.writer().writeAll(";") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .var_decl => |v| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("var {s} = ", .{v.name}) catch unreachable;
                v.value.write(str.writer()) catch unreachable;
                str.writer().writeAll(";") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .let_decl => |l| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("let {s} = ", .{l.name}) catch unreachable;
                l.value.write(str.writer()) catch unreachable;
                str.writer().writeAll(";") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .const_decl => |c| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("const {s} = ", .{c.name}) catch unreachable;
                c.value.write(str.writer()) catch unreachable;
                str.writer().writeAll(";") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .assign => |a| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("{s} = ", .{a.target}) catch unreachable;
                a.value.write(str.writer()) catch unreachable;
                str.writer().writeAll(";") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .if_stmt => |i| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("if (") catch unreachable;
                i.condition.write(str.writer()) catch unreachable;
                str.writer().writeAll(") {\n") catch unreachable;
                for (i.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                if (i.else_body) |else_body| {
                    str.writer().writeAll(" else {\n") catch unreachable;
                    for (else_body) |stmt| {
                        const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                        str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                    }
                    addIndent(&str.writer(), indent) catch unreachable;
                    str.writer().writeAll("}") catch unreachable;
                }
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .while_stmt => |w| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("while (") catch unreachable;
                w.condition.write(str.writer()) catch unreachable;
                str.writer().writeAll(") {\n") catch unreachable;
                for (w.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .for_stmt => |f| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("for (") catch unreachable;
                if (f.init) |init| {
                    const init_str = init.toStringWithIndent(allocator, 0);
                    str.writer().writeAll(init_str) catch unreachable;
                }
                str.writer().writeAll("; ") catch unreachable;
                if (f.condition) |cond| {
                    const cond_str = cond.toString(allocator);
                    str.writer().writeAll(cond_str) catch unreachable;
                }
                str.writer().writeAll("; ") catch unreachable;
                if (f.update) |update| {
                    const upd_str = update.toString(allocator);
                    str.writer().writeAll(upd_str) catch unreachable;
                }
                str.writer().writeAll(") {\n") catch unreachable;
                for (f.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .for_of_stmt => |f| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("for (const {s} of ", .{f.iterator}) catch unreachable;
                f.iterable.write(str.writer()) catch unreachable;
                str.writer().writeAll(") {\n") catch unreachable;
                for (f.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .try_stmt => |t| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("try {\n") catch unreachable;
                for (t.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("} catch (error) {\n") catch unreachable;
                for (t.catch_body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .return_stmt => |r| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                if (r) |expr| {
                    str.writer().writeAll("return ") catch unreachable;
                    expr.write(str.writer()) catch unreachable;
                    str.writer().writeAll(";") catch unreachable;
                } else {
                    str.writer().writeAll("return;") catch unreachable;
                }
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .block => |b| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("{\n") catch unreachable;
                for (b) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
            .function_decl => |f| {
                var str = std.ArrayList(u8).init(allocator);
                defer str.deinit();
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().print("function {s}(", .{f.name}) catch unreachable;
                for (f.params, 0..) |param, i| {
                    if (i > 0) str.writer().writeAll(", ") catch unreachable;
                    str.writer().writeAll(param) catch unreachable;
                }
                str.writer().writeAll(") {\n") catch unreachable;
                for (f.body) |stmt| {
                    const stmt_str = stmt.toStringWithIndent(allocator, indent + 1);
                    str.writer().print("{s}\n", .{stmt_str}) catch unreachable;
                }
                addIndent(&str.writer(), indent) catch unreachable;
                str.writer().writeAll("}\n") catch unreachable;
                return std.fmt.allocPrint(allocator, "{s}", .{str.items}) catch unreachable;
            },
        }
    }

    pub fn write(self: JsStatement, writer: anytype, indent: usize) !void {
        switch (self) {
            .empty => {},
            .expression => |e| {
                try addIndent(writer, indent);
                try e.write(writer);
                try writer.writeAll(";");
            },
            .var_decl => |v| {
                try addIndent(writer, indent);
                try writer.print("var {s} = ", .{v.name});
                try v.value.write(writer);
                try writer.writeAll(";");
            },
            .let_decl => |l| {
                try addIndent(writer, indent);
                try writer.print("let {s} = ", .{l.name});
                try l.value.write(writer);
                try writer.writeAll(";");
            },
            .const_decl => |c| {
                try addIndent(writer, indent);
                try writer.print("const {s} = ", .{c.name});
                try c.value.write(writer);
                try writer.writeAll(";");
            },
            .assign => |a| {
                try addIndent(writer, indent);
                try writer.print("{s} = ", .{a.target});
                try a.value.write(writer);
                try writer.writeAll(";");
            },
            .if_stmt => |i| {
                try addIndent(writer, indent);
                try writer.writeAll("if (");
                try i.condition.write(writer);
                try writer.writeAll(") {\n");
                for (i.body) |stmt| {
                    try stmt.write(writer, indent + 1);
                    try writer.writeByte('\n');
                }
                try addIndent(writer, indent);
                try writer.writeAll("}");
                if (i.else_body) |else_body| {
                    try writer.writeAll(" else {\n");
                    for (else_body) |stmt| {
                        try stmt.write(writer, indent + 1);
                        try writer.writeByte('\n');
                    }
                    try addIndent(writer, indent);
                    try writer.writeAll("}");
                }
            },
            .while_stmt => |w| {
                try addIndent(writer, indent);
                try writer.writeAll("while (");
                try w.condition.write(writer);
                try writer.writeAll(") {\n");
                for (w.body) |stmt| {
                    try stmt.write(writer, indent + 1);
                    try writer.writeByte('\n');
                }
                try addIndent(writer, indent);
                try writer.writeAll("}");
            },
            .for_stmt => |f| {
                try addIndent(writer, indent);
                try writer.writeAll("for (");
                if (f.init) |init| {
                    const init_str = init.toStringWithIndent(std.heap.page_allocator, 0);
                    try writer.writeAll(init_str);
                }
                try writer.writeAll("; ");
                if (f.condition) |cond| {
                    try cond.write(writer);
                }
                try writer.writeAll("; ");
                if (f.update) |update| {
                    try update.write(writer);
                }
                try writer.writeAll(") {\n");
                for (f.body) |stmt| {
                    try stmt.write(writer, indent + 1);
                    try writer.writeByte('\n');
                }
                try addIndent(writer, indent);
                try writer.writeAll("}");
            },
            .for_of_stmt => |f| {
                try addIndent(writer, indent);
                try writer.print("for (const {s} of ", .{f.iterator});
                try f.iterable.write(writer);
                try writer.writeAll(") {\n");
                for (f.body) |stmt| {
                    try stmt.write(writer, indent + 1);
                    try writer.writeByte('\n');
                }
                try addIndent(writer, indent);
                try writer.writeAll("}");
            },
            .try_stmt => |t| {
                try addIndent(writer, indent);
                try writer.writeAll("try {\n");
                for (t.body) |stmt| {
                    try stmt.write(writer, indent + 1);
                    try writer.writeByte('\n');
                }
                try addIndent(writer, indent);
                try writer.writeAll("} catch (error) {\n");
                for (t.catch_body) |stmt| {
                    try stmt.write(writer, indent + 1);
                    try writer.writeByte('\n');
                }
                try addIndent(writer, indent);
                try writer.writeAll("}");
            },
            .return_stmt => |r| {
                try addIndent(writer, indent);
                if (r) |expr| {
                    try writer.writeAll("return ");
                    try expr.write(writer);
                    try writer.writeAll(";");
                } else {
                    try writer.writeAll("return;");
                }
            },
            .block => |b| {
                try addIndent(writer, indent);
                try writer.writeAll("{\n");
                for (b) |stmt| {
                    try stmt.write(writer, indent + 1);
                    try writer.writeByte('\n');
                }
                try addIndent(writer, indent);
                try writer.writeAll("}");
            },
            .function_decl => |f| {
                try addIndent(writer, indent);
                try writer.print("function {s}(", .{f.name});
                for (f.params, 0..) |param, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try writer.writeAll(param);
                }
                try writer.writeAll(") {\n");
                for (f.body) |stmt| {
                    try stmt.write(writer, indent + 1);
                    try writer.writeByte('\n');
                }
                try addIndent(writer, indent);
                try writer.writeAll("}\n");
            },
        }
    }

    pub fn toString(self: JsStatement, allocator: std.mem.Allocator) []const u8 {
        return self.toStringWithIndent(allocator, 0);
    }
};
