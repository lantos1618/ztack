const std = @import("std");
const net = std.net;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var address = try net.Address.parseIp("0.0.0.0", 8080);
    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    std.debug.print("\n🚀 Server listening on http://0.0.0.0:8080\n", .{});
    std.debug.print("📄 JS Counter Example\n", .{});
    std.debug.print("Press Ctrl+C to stop\n\n", .{});

    while (listener.accept()) |connection| {
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch continue;
        
        if (bytes_read == 0) continue;

        _ = buffer[0..bytes_read]; // ignore request for now
        
        // Simple HTTP response with the counter HTML
        const html = 
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
            \\      Zig Click Counter (JavaScript)
            \\    </h1>
            \\    <div class="space-y-4">
            \\      <div class="text-3xl font-mono">
            \\        Count: <span id="counter" class="font-bold">0</span>
            \\      </div>
            \\      <button onclick="handleClick()" class="px-8 py-4 bg-blue-600 hover:bg-blue-700 rounded-lg transform hover:scale-105 transition-all duration-200 shadow-lg hover:shadow-xl text-xl font-bold">
            \\        Click Me!
            \\      </button>
            \\    </div>
            \\    <div class="text-gray-400 mt-8">
            \\      Try to reach the click milestones! 🎯
            \\    </div>
            \\  </div>
            \\  
            \\  <script>
            \\  function handleClick() {
            \\    const counter = document.getElementById('counter');
            \\    let count = parseInt(counter.textContent);
            \\    count++;
            \\    counter.textContent = count;
            \\    
            \\    if (count === 5) alert('🎉 Reached 5 clicks!');
            \\    if (count === 10) alert('🎊 Reached 10 clicks!');
            \\    if (count === 20) alert('🚀 Reached 20 clicks!');
            \\  }
            \\  
            \\  window.addEventListener('DOMContentLoaded', function() {
            \\    const counter = document.getElementById('counter');
            \\    counter.textContent = '0';
            \\  });
            \\  </script>
            \\</body>
            \\</html>
        ;

        const response = try std.fmt.allocPrint(allocator, 
            "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {}\r\n\r\n{s}", 
            .{ html.len, html }
        );
        defer allocator.free(response);

        _ = try connection.stream.writeAll(response);
    } else |err| {
        std.debug.print("Error accepting connection: {}\n", .{err});
    }
}
