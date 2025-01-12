const std = @import("std");
const dom = @import("dom.zig");
const js_reflect = @import("js_reflect.zig");

fn testSimpleAlert() void {
    _ = dom.alert("Hello!");
}

test "basic function conversion" {
    const js_ast = js_reflect.toJs(testSimpleAlert);
    const js_code = js_ast.toString();
    const expected = "function testSimpleAlert() {\n  alert(\"Hello!\");\n}\n";
    try std.testing.expectEqualStrings(expected, js_code);
}

fn testSetCounter(count: i32) void {
    const counter = dom.querySelector("#counter");
    _ = dom.setInnerText(counter, std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{count}) catch unreachable);
}

test "function with parameters" {
    const js_ast = js_reflect.toJs(testSetCounter);
    const js_code = js_ast.toString();
    const expected = "function testSetCounter(param0) {\n  const counter = document.querySelector(\"#counter\");\n  counter.innerText = param0;\n}\n";
    try std.testing.expectEqualStrings(expected, js_code);
}
