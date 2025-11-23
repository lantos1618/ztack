const std = @import("std");
const net = std.net;
const Transpiler = @import("transpiler").Transpiler;
const js = @import("js");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Transpile handlers
    const handlers_src = @embedFile("js_counter/handlers.zig");
    var transpiler = try Transpiler.init(allocator, handlers_src);
    defer transpiler.deinit();

    const js_statements = try transpiler.transpile();
    defer allocator.free(js_statements);

    // Build JavaScript from transpiled statements
    var js_code = std.ArrayList(u8).init(allocator);
    defer js_code.deinit();

    for (js_statements) |stmt| {
        try stmt.write(js_code.writer(), 2);
        try js_code.writer().writeByte('\n');
    }

    // Print warnings if any
    transpiler.validator.printWarnings();

    var address = try net.Address.parseIp("0.0.0.0", 8080);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    std.debug.print("\n🚀 Server listening on http://0.0.0.0:8080\n", .{});
    std.debug.print("📄 JS Counter Example (with transpiled handlers)\n", .{});
    std.debug.print("Press Ctrl+C to stop\n\n", .{});

    while (listener.accept()) |connection| {
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch continue;

        if (bytes_read == 0) continue;

        _ = buffer[0..bytes_read];

        const html = try std.fmt.allocPrint(allocator,
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\  <meta charset="utf-8">
            \\  <title>Zig Click Counter</title>
            \\  <script src="https://cdn.tailwindcss.com"></script>
            \\</head>
            \\<body class="min-h-screen bg-gradient-to-b from-gray-900 to-gray-800 text-white flex items-center justify-center">
            \\  <div class="text-center space-y-8">
            \\    <h1 class="text-5xl font-bold mb-8 bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500">
            \\      Zig Click Counter (Transpiled JavaScript)
            \\    </h1>
            \\    <div class="space-y-4">
            \\      <div class="text-3xl font-mono">
            \\        Count: <span id="counter" class="font-bold">0</span>
            \\      </div>
            \\      <button id="clickButton" onclick="handleClick()" class="px-8 py-4 bg-blue-600 hover:bg-blue-700 rounded-lg transform hover:scale-105 transition-all duration-200 shadow-lg hover:shadow-xl text-xl font-bold">
            \\        Click Me!
            \\      </button>
            \\    </div>
            \\    <div class="text-gray-400 mt-8">
            \\      <em>Function handlers are transpiled from Zig!</em>
            \\    </div>
            \\  </div>
            \\  
            \\  <script>
            \\{s}
            \\  </script>
            \\</body>
            \\</html>
        , .{js_code.items});
        defer allocator.free(html);

        const response = try std.fmt.allocPrint(allocator,
            "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {}\r\n\r\n{s}",
            .{ html.len, html },
        );
        defer allocator.free(response);

        _ = try connection.stream.writeAll(response);
    } else |err| {
        std.debug.print("Error accepting connection: {}\n", .{err});
    }
}
