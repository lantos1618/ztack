const std = @import("std");
const zap = @import("zap");
const wasm_handler = @import("routes/wasm_example/wasm_handler.zig");
const index_handler = @import("routes/index.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpa_allocator = gpa.allocator();

fn on_request(r: zap.Request) void {
    const path = r.path orelse "/";

    if (std.mem.eql(u8, path, "/wasm")) {
        wasm_handler.handle(r);
        return;
    }

    if (path.len == 0 or std.mem.eql(u8, path, "/")) {
        index_handler.handle(r);
        return;
    }

    r.setStatus(.not_found);
    r.sendBody("Not Found") catch return;
}

pub fn main() !void {
    defer _ = gpa.deinit();

    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .on_request = on_request,
        .log = true,
        .public_folder = "public",
    });
    try listener.listen();

    std.debug.print("Server listening on http://127.0.0.1:8080\n", .{});
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
