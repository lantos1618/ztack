const std = @import("std");
const testing = std.testing;
const main = @import("main.zig");
const HtmlDocument = @import("html.zig").HtmlDocument;
const html = @import("html.zig").Element;

test "generateHtml returns valid HTML" {
    // Initialize allocator for testing
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Generate HTML
    const html_content = try main.generateHtml(allocator);
    defer allocator.free(html_content);

    // Basic checks
    try testing.expect(std.mem.indexOf(u8, html_content, "<!DOCTYPE html>") != null);
    try testing.expect(std.mem.indexOf(u8, html_content, "<title>My Page</title>") != null);
    try testing.expect(std.mem.indexOf(u8, html_content, "Click me to count!") != null);
    try testing.expect(std.mem.indexOf(u8, html_content, "id=\"counter\"") != null);
}

test "counter initialization" {
    // Initialize allocator for testing
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Generate HTML
    const html_content = try main.generateHtml(allocator);
    defer allocator.free(html_content);

    // Check counter initialization
    try testing.expect(std.mem.indexOf(u8, html_content, "window.count = 0") != null);
}

test "click handler functionality" {
    // Initialize allocator for testing
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Generate HTML
    const html_content = try main.generateHtml(allocator);
    defer allocator.free(html_content);

    // Check click handler
    try testing.expect(std.mem.indexOf(u8, html_content, "function handleClick") != null);
    try testing.expect(std.mem.indexOf(u8, html_content, "Number(window.count) + 1") != null);
    try testing.expect(std.mem.indexOf(u8, html_content, "You reached 10 clicks!") != null);
}
