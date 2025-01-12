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
    binary_op: struct {
        left: *const JsExpression,
        operator: []const u8,
        right: *const JsExpression,
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

    pub fn toString(self: JsExpression) []const u8 {
        switch (self) {
            .value => |v| return v.toString(),
            .binary_op => |b| {
                const left = b.left.toString();
                const right = b.right.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "{s} {s} {s}", .{ left, b.operator, right }) catch unreachable;
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
        }
    }
};

pub const JsStatement = union(enum) {
    let: struct {
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
    },

    pub fn toString(self: JsStatement) []const u8 {
        switch (self) {
            .let => |l| {
                const value = l.value.toString();
                return std.fmt.allocPrint(std.heap.page_allocator, "let {s} = {s};", .{ l.name, value }) catch unreachable;
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
                return std.fmt.allocPrint(std.heap.page_allocator, "if ({s}) {{\n{s}}}", .{ cond, body_str.items }) catch unreachable;
            },
        }
    }
};
