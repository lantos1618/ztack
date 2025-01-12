const std = @import("std");
const JsFunction = @import("html.zig").JsFunction;

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

pub const QuerySelector = struct {
    selector: []const u8,

    pub fn toString(self: QuerySelector) []const u8 {
        return self.selector;
    }

    pub fn byId(id: []const u8) QuerySelector {
        return .{ .selector = std.fmt.allocPrint(std.heap.page_allocator, "#{s}", .{id}) catch unreachable };
    }

    pub fn byClass(class: []const u8) QuerySelector {
        return .{ .selector = std.fmt.allocPrint(std.heap.page_allocator, ".{s}", .{class}) catch unreachable };
    }
};

pub const Element = struct {
    selector: QuerySelector,

    pub fn addEventListener(self: Element, event: Event.Type, handler: []const u8) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "document.querySelector('{s}').addEventListener('{s}', {s})",
            .{ self.selector.toString(), Event.toString(event), handler },
        ) catch unreachable;
    }

    pub fn setValue(self: Element, value: []const u8) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "document.querySelector('{s}').value = {s}",
            .{ self.selector.toString(), value },
        ) catch unreachable;
    }

    pub fn setInnerHtml(self: Element, html: []const u8) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "document.querySelector('{s}').innerHTML = {s}",
            .{ self.selector.toString(), html },
        ) catch unreachable;
    }

    pub fn setInnerText(self: Element, text: []const u8) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "document.querySelector('{s}').innerText = {s}",
            .{ self.selector.toString(), text },
        ) catch unreachable;
    }

    pub fn getInnerText(self: Element) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "document.querySelector('{s}').innerText",
            .{self.selector.toString()},
        ) catch unreachable;
    }
};

pub const Document = struct {
    pub fn querySelector(selector: []const u8) Element {
        return .{ .selector = .{ .selector = selector } };
    }

    pub fn getElementById(id: []const u8) Element {
        return .{ .selector = QuerySelector.byId(id) };
    }

    pub fn getElementByClass(class: []const u8) Element {
        return .{ .selector = QuerySelector.byClass(class) };
    }
};

pub const DomFunction = struct {
    name: []const u8,
    statements: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) DomFunction {
        return .{
            .name = name,
            .statements = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DomFunction) void {
        for (self.statements.items) |statement| {
            self.allocator.free(statement);
        }
        self.statements.deinit();
    }

    pub fn addStatement(self: *DomFunction, statement: []const u8) !void {
        const owned_statement = try self.allocator.dupe(u8, statement);
        errdefer self.allocator.free(owned_statement);
        try self.statements.append(owned_statement);
    }

    pub fn toJs(self: DomFunction) JsFunction {
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        for (self.statements.items) |statement| {
            body.writer().print("{s}\n", .{statement}) catch unreachable;
        }

        return .{
            .name = self.name,
            .args = &[_][]const u8{},
            .body = self.allocator.dupe(u8, body.items) catch unreachable,
        };
    }
};
