const std = @import("std");
const Transpiler = @import("transpiler").Transpiler;
const js = @import("js");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = @embedFile("sample_handlers.zig");

    std.debug.print("=== Transpiling Zig to JavaScript ===\n", .{});
    std.debug.print("Source length: {} bytes\n\n", .{source.len});

    var trans = try Transpiler.init(allocator, source);
    defer trans.deinit();

    const statements = try trans.transpile();
    defer allocator.free(statements);

    std.debug.print("Generated {} statements:\n\n", .{statements.len});

    var stdout = std.io.getStdOut().writer();
    for (statements, 0..) |stmt, i| {
        std.debug.print("Statement {}:\n", .{i});
        try stmt.write(stdout, 1);
        try stdout.writeAll("\n\n");
    }
}
