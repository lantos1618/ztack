const std = @import("std");

/// HTTP method enumeration
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,

    pub fn fromString(method_str: []const u8) ?HttpMethod {
        return std.meta.stringToEnum(HttpMethod, method_str);
    }

    pub fn toString(self: HttpMethod) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };
    }
};

/// Route handler function signature
pub const RouteHandler = *const fn (method: HttpMethod, path: []const u8, req_body: []const u8) anyerror![]const u8;

/// A single route entry
pub const Route = struct {
    method: HttpMethod,
    path: []const u8,
    handler: RouteHandler,
};

/// Router manages HTTP routes and dispatches requests
pub const Router = struct {
    allocator: std.mem.Allocator,
    routes: std.ArrayList(Route),

    pub fn init(allocator: std.mem.Allocator) Router {
        return .{
            .allocator = allocator,
            .routes = std.ArrayList(Route).init(allocator),
        };
    }

    pub fn deinit(self: *Router) void {
        self.routes.deinit();
    }

    /// Register a route with the router
    pub fn register(self: *Router, method: HttpMethod, path: []const u8, handler: RouteHandler) !void {
        try self.routes.append(.{
            .method = method,
            .path = path,
            .handler = handler,
        });
    }

    /// Find a route matching method and path
    pub fn findRoute(self: Router, method: HttpMethod, path: []const u8) ?Route {
        for (self.routes.items) |route| {
            if (route.method == method and std.mem.eql(u8, route.path, path)) {
                return route;
            }
        }
        return null;
    }

    /// Dispatch a request to the matching route
    pub fn dispatch(self: Router, method: HttpMethod, path: []const u8, req_body: []const u8) !?[]const u8 {
        if (self.findRoute(method, path)) |route| {
            return try route.handler(method, path, req_body);
        }
        return null;
    }

    /// Parse HTTP request line to extract method and path
    pub fn parseRequestLine(request_line: []const u8) ?struct { HttpMethod, []const u8 } {
        var iter = std.mem.splitSequence(u8, request_line, " ");

        const method_str = iter.next() orelse return null;
        const path = iter.next() orelse return null;

        const method = HttpMethod.fromString(method_str) orelse return null;

        return .{ method, path };
    }
};

/// Helper to create a simple 404 response
pub fn notFoundResponse(allocator: std.mem.Allocator) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 9\r\n\r\nNot Found",
        .{},
    );
}

/// Helper to create a simple 200 response with HTML
pub fn htmlResponse(allocator: std.mem.Allocator, html: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {}\r\n\r\n{s}",
        .{ html.len, html },
    );
}

/// Helper to create a simple 200 response with JSON
pub fn jsonResponse(allocator: std.mem.Allocator, json: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(allocator,
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\r\n{s}",
        .{ json.len, json },
    );
}
