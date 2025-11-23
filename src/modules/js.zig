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
        is_postfix: bool = false,
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
                if (u.is_postfix) {
                    try u.operand.write(writer);
                    try writer.writeAll(u.operator);
                } else {
                    try writer.writeAll(u.operator);
                    try u.operand.write(writer);
                }
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
                    try init.write(writer, 0);
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
};
