const std = @import("std");

pub const Value = union(enum) {
    number: i32,
    string: []const u8,
    boolean: bool,
    null,
    undefined,
    method_call: struct {
        object: []const u8,
        method: []const u8,
        args: []const Value,
    },

    pub fn toString(self: Value) []const u8 {
        switch (self) {
            .number => |n| return std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{n}) catch unreachable,
            .string => |s| return std.fmt.allocPrint(std.heap.page_allocator, "\"{s}\"", .{s}) catch unreachable,
            .boolean => |b| return if (b) "true" else "false",
            .null => return "null",
            .undefined => return "undefined",
            .method_call => |m| {
                var list = std.ArrayList(u8).init(std.heap.page_allocator);
                defer list.deinit();

                list.writer().writeAll(m.object) catch unreachable;
                list.writer().writeAll(".") catch unreachable;
                list.writer().writeAll(m.method) catch unreachable;
                list.writer().writeAll("(") catch unreachable;
                for (m.args, 0..) |arg, i| {
                    if (i > 0) list.writer().writeAll(", ") catch unreachable;
                    list.writer().writeAll(arg.toString()) catch unreachable;
                }
                list.writer().writeAll(")") catch unreachable;

                return std.heap.page_allocator.dupe(u8, list.items) catch unreachable;
            },
        }
    }
};

pub const Statement = union(enum) {
    let: struct { name: []const u8, value: Value },
    assign: struct { target: []const u8, value: Value },
    increment: []const u8,
    if_stmt: struct { condition: Condition, body: []const Statement },
    call: struct { target: []const u8, args: []const Value },
    method_call: struct { object: []const u8, method: []const u8, args: []const Value },

    pub fn toString(self: Statement, writer: anytype) !void {
        switch (self) {
            .let => |l| {
                try writer.writeAll("let ");
                try writer.writeAll(l.name);
                try writer.writeAll(" = ");
                try writer.writeAll(l.value.toString());
                try writer.writeAll(";");
            },
            .assign => |a| {
                try writer.writeAll(a.target);
                try writer.writeAll(" = ");
                try writer.writeAll(a.value.toString());
                try writer.writeAll(";");
            },
            .increment => |i| {
                try writer.writeAll(i);
                try writer.writeAll("++;");
            },
            .if_stmt => |i| {
                try writer.writeAll("if (");
                try writer.writeAll(i.condition.toString());
                try writer.writeAll(") {\n");
                for (i.body) |stmt| {
                    try writer.writeAll("  ");
                    try stmt.toString(writer);
                    try writer.writeAll("\n");
                }
                try writer.writeAll("}");
            },
            .call => |c| {
                try writer.writeAll(c.target);
                try writer.writeAll("(");
                for (c.args, 0..) |arg, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try writer.writeAll(arg.toString());
                }
                try writer.writeAll(");");
            },
            .method_call => |m| {
                try writer.writeAll(m.object);
                try writer.writeAll(".");
                try writer.writeAll(m.method);
                try writer.writeAll("(");
                for (m.args, 0..) |arg, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try writer.writeAll(arg.toString());
                }
                try writer.writeAll(");");
            },
        }
    }
};

pub const Condition = union(enum) {
    equals: struct { left: Value, right: Value },

    pub fn toString(self: Condition) []const u8 {
        var list = std.ArrayList(u8).init(std.heap.page_allocator);
        defer list.deinit();

        switch (self) {
            .equals => |e| {
                list.writer().writeAll(e.left.toString()) catch unreachable;
                list.writer().writeAll(" === ") catch unreachable;
                list.writer().writeAll(e.right.toString()) catch unreachable;
            },
        }

        return std.heap.page_allocator.dupe(u8, list.items) catch unreachable;
    }
};

pub fn parseInt(target: []const u8) Value {
    return .{ .method_call = .{
        .object = "parseInt",
        .method = "call",
        .args = &[_]Value{ .{ .undefined = {} }, .{ .string = target } },
    } };
}

pub fn querySelector(selector: []const u8) []const u8 {
    return std.fmt.allocPrint(std.heap.page_allocator, "document.querySelector('{s}')", .{selector}) catch unreachable;
}

pub fn getInnerText(element: []const u8) Value {
    return .{ .method_call = .{
        .object = element,
        .method = "innerText",
        .args = &[_]Value{},
    } };
}

pub fn setInnerText(element: []const u8, value: Value) Statement {
    return .{ .method_call = .{
        .object = element,
        .method = "innerText",
        .args = &[_]Value{value},
    } };
}

pub fn alert(message: []const u8) Statement {
    return .{ .call = .{
        .target = "alert",
        .args = &[_]Value{.{ .string = message }},
    } };
}

pub fn addEventListener(element: []const u8, event: []const u8, handler: []const u8) Statement {
    return .{ .method_call = .{
        .object = element,
        .method = "addEventListener",
        .args = &[_]Value{ .{ .string = event }, .{ .string = handler } },
    } };
}
