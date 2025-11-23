const std = @import("std");
const Transpiler = @import("transpiler").Transpiler;
const js = @import("js");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n╔════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║         Testing Transpiler Fixes                     ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════╝\n\n", .{});

    // Test 1: let/const instead of var
    std.debug.print("Test 1: Variable Declarations (var -> let)\n", .{});
    std.debug.print("─────────────────────────────────────────────────────────\n", .{});
    const test1_source = 
        \\pub fn test1() void {
        \\    var x = 5;
        \\    var y = 10;
        \\}
    ;
    var trans1 = try Transpiler.init(allocator, test1_source);
    defer trans1.deinit();
    const stmts1 = try trans1.transpile();
    defer allocator.free(stmts1);
    var stdout = std.io.getStdOut().writer();
    try stmts1[0].write(stdout, 0);
    try stdout.writeAll("\n\n");

    // Test 2: For loop transpilation
    std.debug.print("Test 2: For Loop Support (for range)\n", .{});
    std.debug.print("─────────────────────────────────────────────────────────\n", .{});
    const test2_source = 
        \\pub fn loopTest() void {
        \\    for (0..10) |i| {
        \\    }
        \\}
    ;
    var trans2 = try Transpiler.init(allocator, test2_source);
    defer trans2.deinit();
    const stmts2 = try trans2.transpile();
    defer allocator.free(stmts2);
    try stmts2[0].write(stdout, 0);
    try stdout.writeAll("\n\n");

    // Test 3: DOM mapping
    std.debug.print("Test 3: DOM Namespace Mapping (dom -> document)\n", .{});
    std.debug.print("─────────────────────────────────────────────────────────\n", .{});
    const test3_source = 
        \\pub fn domTest() void {
        \\    const el = dom.querySelector("#test");
        \\}
    ;
    var trans3 = try Transpiler.init(allocator, test3_source);
    defer trans3.deinit();
    const stmts3 = try trans3.transpile();
    defer allocator.free(stmts3);
    try stmts3[0].write(stdout, 0);
    try stdout.writeAll("\n\n");

    std.debug.print("\n✨ All tests completed!\n", .{});
}
