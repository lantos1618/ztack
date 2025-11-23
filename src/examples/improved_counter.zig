const std = @import("std");
const net = std.net;
const html = @import("html");
const router = @import("router");
const Transpiler = @import("transpiler");
const js = @import("js");

/// Example handler using new HTML builder helpers
fn handleCounterPage(allocator: std.mem.Allocator) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var doc = html.HtmlDocument.init(allocator);
    
    // Build head elements using helpers
    const head = &[_]html.Element{
        html.meta("utf-8"),
        html.title(&[_]html.Element{html.text("Counter with Event Delegation")}),
        html.script("https://cdn.tailwindcss.com", true),
    };

    // Build body with new helpers
    const body = &[_]html.Element{
        html.div("min-h-screen bg-gradient-to-b from-slate-900 to-slate-800 text-white flex items-center justify-center", &[_]html.Element{
            html.div("text-center space-y-8", &[_]html.Element{
                html.h1("text-5xl font-bold mb-4 bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500", &[_]html.Element{
                    html.text("Zig Counter"),
                }),
                html.h2("text-gray-400 text-lg", &[_]html.Element{
                    html.text("Click counter using event delegation"),
                }),
                html.div("space-y-4 mt-8", &[_]html.Element{
                    html.div("text-4xl font-mono tracking-wider", &[_]html.Element{
                        html.span(null, &[_]html.Element{
                            html.text("Count: "),
                        }),
                        html.span("font-bold text-blue-400", &[_]html.Element{
                            html.text("0"),
                        }),
                    }),
                    // Using event delegation with data-on attribute
                    html.button_data("px-8 py-4 bg-blue-600 hover:bg-blue-700 rounded-lg transform hover:scale-105 transition-all shadow-lg text-xl font-bold", "click:increment", &[_]html.Element{
                        html.text("Increment"),
                    }),
                    html.button_data("px-8 py-4 bg-red-600 hover:bg-red-700 rounded-lg transform hover:scale-105 transition-all shadow-lg text-xl font-bold", "click:reset", &[_]html.Element{
                        html.text("Reset"),
                    }),
                }),
                html.p("text-gray-500 text-sm mt-8", &[_]html.Element{
                    html.text("This uses event delegation (data-on attributes) instead of inline onclick"),
                }),
            }),
        }),
        html.script(html.EVENT_DELEGATION_SCRIPT, false),
        html.script(
            \\<script>
            \\  let count = 0;
            \\  function increment() {
            \\    count++;
            \\    document.querySelector('span.text-blue-400').textContent = count;
            \\  }
            \\  function reset() {
            \\    count = 0;
            \\    document.querySelector('span.text-blue-400').textContent = count;
            \\  }
            \\</script>
        , false),
    };

    try doc.renderToWriter(result.writer(), head, body);
    return result.toOwnedSlice();
}

fn handleIndex(method: router.HttpMethod, path: []const u8, req_body: []const u8) ![]const u8 {
    _ = method;
    _ = path;
    _ = req_body;
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    return try handleCounterPage(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app_router = router.Router.init(allocator);
    defer app_router.deinit();

    try app_router.register(router.HttpMethod.GET, "/", &handleIndex);

    var address = try net.Address.parseIp("0.0.0.0", 8080);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    std.debug.print("\n🚀 Improved Counter Server listening on http://0.0.0.0:8080\n", .{});
    std.debug.print("📋 Features:\n", .{});
    std.debug.print("   ✓ Streaming HTML rendering (no allocPrint overhead)\n", .{});
    std.debug.print("   ✓ Event delegation with data-on attributes\n", .{});
    std.debug.print("   ✓ Router-based architecture\n", .{});
    std.debug.print("   ✓ Clean HTML builder helper functions\n", .{});
    std.debug.print("Press Ctrl+C to stop\n\n", .{});

    while (listener.accept()) |connection| {
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch continue;

        if (bytes_read == 0) continue;

        const request = buffer[0..bytes_read];
        var lines = std.mem.splitSequence(u8, request, "\r\n");
        const request_line = lines.next() orelse continue;
        
        const parsed = router.Router.parseRequestLine(request_line) orelse continue;
        const method = parsed[0];
        const path = parsed[1];

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
