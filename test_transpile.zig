const std = @import("std");
const js_reflect = @import("js_reflect");

pub fn main() void {
    // Test the transpilation
    const result = comptime js_reflect.toJsBody(handleClick, "handleClick");
    
    // Print the result
    for (result) |stmt| {
        std.debug.print("{s}\n", .{stmt.toString()});
    }
}

fn handleClick() void {
    const x = 5;
}
