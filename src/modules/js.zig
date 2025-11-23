const std = @import("std");

pub const Value = union(enum) {
    number: i32,
    string: []const u8,
    boolean: bool,
    null,
    undefined,
    function_ref: []const u8,
    property_get: struct {
        object: []const u8,
        property: []const u8,
    },
    property_set: struct {
        object: []const u8,
        property: []const u8,
        value: *const Value,
    },
    method_call: struct {
        object: []const u8,
        method: []const u8,
        args: []const Value,
    },

    pub fn toString(self: Value, allocator: std.mem.Allocator) ![]const u8 {
        switch (self) {
            .number => |n| return try std.fmt.allocPrint(allocator, "{d}", .{n}),
            .string => |s| return try std.fmt.allocPrint(allocator, "\"{s}\"", .{s}),
            .boolean => |b| return try allocator.dupe(u8, if (b) "true" else "false"),
            .null => return try allocator.dupe(u8, "null"),
            .undefined => return try allocator.dupe(u8, "undefined"),
            .function_ref => |f| return try allocator.dupe(u8, f),
            .property_get => |p| {
                var list = std.ArrayList(u8).init(allocator);
                errdefer list.deinit();

                try list.writer().writeAll(p.object);
                try list.writer().writeAll(".");
                try list.writer().writeAll(p.property);

                return try allocator.dupe(u8, list.items);
            },
            .property_set => |p| {
                var list = std.ArrayList(u8).init(allocator);
                errdefer list.deinit();

                try list.writer().writeAll(p.object);
                try list.writer().writeAll(".");
                try list.writer().writeAll(p.property);
                try list.writer().writeAll(" = ");
                const value_str = try p.value.toString(allocator);
                defer allocator.free(value_str);
                try list.writer().writeAll(value_str);

                return try allocator.dupe(u8, list.items);
            },
            .method_call => |m| {
                var list = std.ArrayList(u8).init(allocator);
                errdefer list.deinit();

                try list.writer().writeAll(m.object);
                try list.writer().writeAll(".");
                try list.writer().writeAll(m.method);
                try list.writer().writeAll("(");
                for (m.args, 0..) |arg, i| {
                    if (i > 0) try list.writer().writeAll(", ");
                    const arg_str = try arg.toString(allocator);
                    defer allocator.free(arg_str);
                    try list.writer().writeAll(arg_str);
                }
                try list.writer().writeAll(")");

                return try allocator.dupe(u8, list.items);
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

    pub fn toString(self: Statement, allocator: std.mem.Allocator) ![]const u8 {
        var list = std.ArrayList(u8).init(allocator);
        errdefer list.deinit();

        switch (self) {
            .let => |l| {
                try list.writer().writeAll("let ");
                try list.writer().writeAll(l.name);
                try list.writer().writeAll(" = ");
                const value_str = try l.value.toString(allocator);
                defer allocator.free(value_str);
                try list.writer().writeAll(value_str);
                try list.writer().writeAll(";");
            },
            .assign => |a| {
                try list.writer().writeAll(a.target);
                try list.writer().writeAll(" = ");
                const value_str = try a.value.toString(allocator);
                defer allocator.free(value_str);
                try list.writer().writeAll(value_str);
                try list.writer().writeAll(";");
            },
            .increment => |i| {
                try list.writer().writeAll(i);
                try list.writer().writeAll("++;");
            },
            .if_stmt => |i| {
                try list.writer().writeAll("if (");
                const cond_str = try i.condition.toString(allocator);
                defer allocator.free(cond_str);
                try list.writer().writeAll(cond_str);
                try list.writer().writeAll(") {\n");
                for (i.body) |stmt| {
                    try list.writer().writeAll("  ");
                    const stmt_str = try stmt.toString(allocator);
                    defer allocator.free(stmt_str);
                    try list.writer().writeAll(stmt_str);
                    try list.writer().writeAll("\n");
                }
                try list.writer().writeAll("}");
            },
            .call => |c| {
                try list.writer().writeAll(c.target);
                try list.writer().writeAll("(");
                for (c.args, 0..) |arg, i| {
                    if (i > 0) try list.writer().writeAll(", ");
                    const arg_str = try arg.toString(allocator);
                    defer allocator.free(arg_str);
                    try list.writer().writeAll(arg_str);
                }
                try list.writer().writeAll(");");
            },
            .method_call => |m| {
                try list.writer().writeAll(m.object);
                try list.writer().writeAll(".");
                try list.writer().writeAll(m.method);
                try list.writer().writeAll("(");
                for (m.args, 0..) |arg, i| {
                    if (i > 0) try list.writer().writeAll(", ");
                    const arg_str = try arg.toString(allocator);
                    defer allocator.free(arg_str);
                    try list.writer().writeAll(arg_str);
                }
                try list.writer().writeAll(");");
            },
        }

        return try allocator.dupe(u8, list.items);
    }
};

pub const Condition = union(enum) {
    equals: struct { left: Value, right: Value },

    pub fn toString(self: Condition, allocator: std.mem.Allocator) ![]const u8 {
        var list = std.ArrayList(u8).init(allocator);
        errdefer list.deinit();

        switch (self) {
            .equals => |e| {
                const left_str = try e.left.toString(allocator);
                defer allocator.free(left_str);
                try list.writer().writeAll(left_str);
                try list.writer().writeAll(" === ");
                const right_str = try e.right.toString(allocator);
                defer allocator.free(right_str);
                try list.writer().writeAll(right_str);
            },
        }

        return try allocator.dupe(u8, list.items);
    }
};

// Helper functions
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
    return .{ .property_get = .{
        .object = element,
        .property = "innerText",
    } };
}

pub fn setInnerText(element: []const u8, value: Value) Statement {
    return .{ .assign = .{
        .target = std.fmt.allocPrint(std.heap.page_allocator, "{s}.innerText", .{element}) catch unreachable,
        .value = value,
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
