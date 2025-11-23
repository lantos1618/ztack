const std = @import("std");
const Transpiler = @import("transpiler").Transpiler;
const js = @import("js");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = @embedFile("js_counter/handlers.zig");

    std.debug.print("\n╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         Zig to JavaScript Transpiler Demo             ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

    std.debug.print("📄 Source file: handlers.zig ({} bytes)\n\n", .{source.len});

    var trans = try Transpiler.init(allocator, source);
    defer trans.deinit();

    const statements = try trans.transpile();
    defer allocator.free(statements);

    std.debug.print("✅ Successfully transpiled {} functions:\n\n", .{statements.len});

    for (statements, 0..) |stmt, i| {
        std.debug.print("─────────────────────────────────────────────────────────\n", .{});
        std.debug.print("Function {}: \n", .{i});
        std.debug.print("─────────────────────────────────────────────────────────\n", .{});
        std.debug.print("{s}\n\n", .{stmt.toString()});
    }

    std.debug.print("✨ Transpilation complete!\n\n", .{});
}
