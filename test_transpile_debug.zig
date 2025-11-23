const std = @import("std");
const js_reflect = @import("src/js_reflect.zig");
const js_gen = @import("src/js_gen.zig");

pub fn main() !void {
    const stmts = js_reflect.transpiledFunction("handleClick");
    std.debug.print("Number of statements: {}\n", .{stmts.len});
    
    for (stmts, 0..) |stmt, i| {
        std.debug.print("Statement {}: {s}\n", .{i, stmt.toString()});
    }
}
