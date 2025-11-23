const std = @import("std");
const net = std.net;
const html = @import("html");
const router = @import("router");

/// Example handler for GET /
fn handleIndex(method: router.HttpMethod, path: []const u8, req_body: []const u8) ![]const u8 {
    _ = method;
    _ = path;
    _ = req_body;
    return "<!DOCTYPE html>\n<html>\n<head><title>Router Example</title></head>\n<body><h1>Hello from Router!</h1></body>\n</html>";
}

/// Example handler for POST /api/data
fn handlePostData(method: router.HttpMethod, path: []const u8, req_body: []const u8) ![]const u8 {
    _ = method;
    _ = path;
    std.debug.print("Received data: {s}\n", .{req_body});
    return "{\"status\":\"ok\"}";
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app_router = router.Router.init(allocator);
    defer app_router.deinit();

    // Register routes
    try app_router.register(router.HttpMethod.GET, "/", &handleIndex);
    try app_router.register(router.HttpMethod.POST, "/api/data", &handlePostData);

    var address = try net.Address.parseIp("0.0.0.0", 8080);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    std.debug.print("\n🚀 Router Server listening on http://0.0.0.0:8080\n", .{});
    std.debug.print("GET / → handleIndex\n", .{});
    std.debug.print("POST /api/data → handlePostData\n", .{});
    std.debug.print("Press Ctrl+C to stop\n\n", .{});

    while (listener.accept()) |connection| {
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch continue;

        if (bytes_read == 0) continue;

        const request = buffer[0..bytes_read];

        // Parse HTTP request
        var lines = std.mem.splitSequence(u8, request, "\r\n");
        const request_line = lines.next() orelse continue;
        
        // Extract method and path
        const parsed = router.Router.parseRequestLine(request_line) orelse continue;
        const method = parsed[0];
        const path = parsed[1];

        // Dispatch to router
        if (try app_router.dispatch(method, path, "")) |response| {
            const http_response = try router.htmlResponse(allocator, response);
            defer allocator.free(http_response);
            _ = try connection.stream.writeAll(http_response);
        } else {
            const not_found = try router.notFoundResponse(allocator);
            defer allocator.free(not_found);
            _ = try connection.stream.writeAll(not_found);
        }
    } else |err| {
        std.debug.print("Error accepting connection: {}\n", .{err});
    }
}
