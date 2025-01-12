const std = @import("std");

pub const JsFunction = struct {
    name: []const u8,
    args: []const []const u8,
    body: []const u8,
};

pub const Event = struct {
    pub const Type = enum {
        click,
        DOMContentLoaded,
        submit,
        input,
        change,
    };

    pub fn toString(event_type: Type) []const u8 {
        return switch (event_type) {
            .click => "click",
            .DOMContentLoaded => "DOMContentLoaded",
            .submit => "submit",
            .input => "input",
            .change => "change",
        };
    }
};

pub const Element = union(enum) {
    text: []const u8,
    div: Container,
    h1: Container,
    script: Script,
    meta: Meta,
    title: Container,

    pub const Container = struct {
        children: []const Element = &.{},
        class: ?[]const u8 = null,
        id: ?[]const u8 = null,
    };

    pub const Script = struct {
        src: ?[]const u8 = null,
        content: ?[]const u8 = null,
        functions: ?[]const JsFunction = null,
    };

    pub const Meta = struct {
        charset: []const u8,
    };

    // Helper functions
    pub fn text(content: []const u8) Element {
        return .{ .text = content };
    }

    pub fn div(class_or_id: ?[]const u8, children: []const Element) Element {
        if (class_or_id) |value| {
            if (std.mem.startsWith(u8, value, "#")) {
                return .{ .div = .{ .id = value[1..], .children = children } };
            } else {
                return .{ .div = .{ .class = value, .children = children } };
            }
        }
        return .{ .div = .{ .children = children } };
    }

    pub fn h1(class: ?[]const u8, children: []const Element) Element {
        return .{ .h1 = .{ .class = class, .children = children } };
    }

    pub fn script(src_or_content: []const u8, is_src: bool) Element {
        if (is_src) {
            return .{ .script = .{ .src = src_or_content } };
        } else {
            return .{ .script = .{ .content = src_or_content } };
        }
    }

    pub fn scriptWithFunctions(functions: []const JsFunction) Element {
        return .{ .script = .{ .functions = functions } };
    }

    pub fn meta(charset: []const u8) Element {
        return .{ .meta = .{ .charset = charset } };
    }

    pub fn title(children: []const Element) Element {
        return .{ .title = .{ .children = children } };
    }

    fn functionToJs(func: JsFunction, writer: anytype, indent: usize) !void {
        try writer.writeByteNTimes(' ', indent);
        try writer.print("function {s}(", .{func.name});

        for (func.args, 0..) |arg, i| {
            if (i > 0) try writer.writeAll(", ");
            try writer.writeAll(arg);
        }

        try writer.writeAll(") {\n");
        try writer.writeByteNTimes(' ', indent + 2);
        try writer.print("{s}\n", .{func.body});
        try writer.writeByteNTimes(' ', indent);
        try writer.writeAll("}");
    }

    pub fn toString(self: Element, writer: anytype, indent: usize) !void {
        switch (self) {
            .text => |t| try writer.writeAll(t),
            .div => |d| {
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll("<div");
                if (d.class) |class| {
                    try writer.print(" class=\"{s}\"", .{class});
                }
                if (d.id) |id| {
                    try writer.print(" id=\"{s}\"", .{id});
                }
                try writer.writeAll(">\n");
                for (d.children) |child| {
                    try child.toString(writer, indent + 2);
                    try writer.writeByte('\n');
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll("</div>");
            },
            .h1 => |h| {
                try writer.writeByteNTimes(' ', indent);
                if (h.class) |class| {
                    try writer.print("<h1 class=\"{s}\">\n", .{class});
                } else {
                    try writer.writeAll("<h1>\n");
                }
                for (h.children) |child| {
                    try child.toString(writer, indent + 2);
                    try writer.writeByte('\n');
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll("</h1>");
            },
            .script => |s| {
                try writer.writeByteNTimes(' ', indent);
                if (s.src) |src| {
                    try writer.print("<script src=\"{s}\"></script>", .{src});
                } else if (s.content) |content| {
                    try writer.writeAll("<script>\n");
                    try writer.writeByteNTimes(' ', indent + 2);
                    try writer.print("{s}\n", .{content});
                    try writer.writeByteNTimes(' ', indent);
                    try writer.writeAll("</script>");
                } else if (s.functions) |functions| {
                    try writer.writeAll("<script>\n");
                    for (functions, 0..) |func, i| {
                        try functionToJs(func, writer, indent + 2);
                        if (i < functions.len - 1) try writer.writeByte('\n');
                    }
                    try writer.writeByte('\n');
                    try writer.writeByteNTimes(' ', indent);
                    try writer.writeAll("</script>");
                }
            },
            .meta => |m| {
                try writer.writeByteNTimes(' ', indent);
                try writer.print("<meta charset=\"{s}\">", .{m.charset});
            },
            .title => |t| {
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll("<title>\n");
                for (t.children) |child| {
                    try child.toString(writer, indent + 2);
                    try writer.writeByte('\n');
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll("</title>");
            },
        }
    }
};

pub const HtmlDocument = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn build(self: *Self, head: []const Element, body: []const Element) ![]const u8 {
        var result = std.ArrayList(u8).init(self.allocator);
        errdefer result.deinit();

        try result.appendSlice("<!DOCTYPE html>\n<html>\n");

        // Head
        try result.appendSlice("<head>\n");
        for (head) |elem| {
            try elem.toString(result.writer(), 2);
            try result.appendSlice("\n");
        }
        try result.appendSlice("</head>\n");

        // Body
        try result.appendSlice("<body>\n");
        for (body) |elem| {
            try elem.toString(result.writer(), 2);
            try result.appendSlice("\n");
        }
        try result.appendSlice("</body>\n");

        try result.appendSlice("</html>");

        return result.toOwnedSlice();
    }
};
