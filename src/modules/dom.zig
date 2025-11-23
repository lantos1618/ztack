const std = @import("std");
const js = @import("js");

/// DOM API functions that map to JavaScript
pub fn alert(msg: []const u8) js.JsExpression {
    return .{ .method_call = .{
        .object = &js.JsExpression{ .value = .{ .object = "window" } },
        .method = "alert",
        .args = &[_]js.JsExpression{
            .{ .value = .{ .string = msg } },
        },
    } };
}

pub fn querySelector(selector: []const u8) js.JsExpression {
    return .{ .method_call = .{
        .object = &js.JsExpression{ .value = .{ .object = "document" } },
        .method = "querySelector",
        .args = &[_]js.JsExpression{
            .{ .value = .{ .string = selector } },
        },
    } };
}

pub fn getElementById(allocator: std.mem.Allocator, id: []const u8) js.JsExpression {
    return querySelector(std.fmt.allocPrint(allocator, "#{s}", .{id}) catch unreachable);
}

pub fn getElementsByClassName(allocator: std.mem.Allocator, class: []const u8) js.JsExpression {
    return querySelector(std.fmt.allocPrint(allocator, ".{s}", .{class}) catch unreachable);
}

pub fn setInnerText(allocator: std.mem.Allocator, element: js.JsExpression, text: []const u8) js.JsExpression {
    return .{ .assign = .{
        .target = std.fmt.allocPrint(allocator, "{s}.innerText", .{element.toString(allocator)}) catch unreachable,
        .value = .{ .value = .{ .string = text } },
    } };
}

pub fn getInnerText(element: js.JsExpression) js.JsExpression {
    return .{ .property_access = .{
        .object = &element,
        .property = "innerText",
    } };
}

pub fn setInnerHtml(allocator: std.mem.Allocator, element: js.JsExpression, html: []const u8) js.JsExpression {
    return .{ .assign = .{
        .target = std.fmt.allocPrint(allocator, "{s}.innerHTML", .{element.toString(allocator)}) catch unreachable,
        .value = .{ .value = .{ .string = html } },
    } };
}

pub fn addEventListener(element: js.JsExpression, event: []const u8, handler: []const u8) js.JsExpression {
    return .{ .method_call = .{
        .object = &element,
        .method = "addEventListener",
        .args = &[_]js.JsExpression{
            .{ .value = .{ .string = event } },
            .{ .value = .{ .object = handler } },
        },
    } };
}

pub const EventType = enum {
    click,
    DOMContentLoaded,
    submit,
    input,
    change,

    pub fn toString(self: EventType) []const u8 {
        return switch (self) {
            .click => "click",
            .DOMContentLoaded => "DOMContentLoaded",
            .submit => "submit",
            .input => "input",
            .change => "change",
        };
    }
};

pub fn parseInt(str: []const u8, radix: u8) js.JsExpression {
    return .{ .method_call = .{
        .object = &js.JsExpression{ .value = .{ .object = "parseInt" } },
        .method = "call",
        .args = &[_]js.JsExpression{
            .{ .value = .{ .undefined = {} } },
            .{ .value = .{ .string = str } },
            .{ .value = .{ .number = radix } },
        },
    } };
}
