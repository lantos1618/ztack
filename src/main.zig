const std = @import("std");
const HtmlDocument = @import("html.zig").HtmlDocument;
const html = @import("html.zig").Element;
const JsFunction = @import("html.zig").JsFunction;
const dom = @import("dom.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var doc = HtmlDocument.init(allocator);

    const head_elements = [_]html{
        html.meta("utf-8"),
        html.title(&[_]html{html.text("My Page")}),
        html.script("https://cdn.tailwindcss.com", true),
    };

    // Create type-safe DOM elements
    const title_element = dom.Document.querySelector("h1");
    const counter_element = dom.Document.getElementById("counter");

    // Create click handler in Zig
    var click_handler = dom.DomFunction.init(allocator, "handleClick");
    defer click_handler.deinit();

    try click_handler.addStatement("let count = parseInt(document.querySelector('#counter').innerText) || 0");
    try click_handler.addStatement("count++");
    try click_handler.addStatement(counter_element.setInnerText("count.toString()"));
    try click_handler.addStatement(
        \\if (count === 10) { alert('You reached 10 clicks!'); }
    );

    // Create setup function in Zig
    var setup_function = dom.DomFunction.init(allocator, "setupListeners");
    defer setup_function.deinit();
    try setup_function.addStatement(title_element.addEventListener(dom.Event.Type.click, "handleClick"));

    const js_functions = [_]JsFunction{
        click_handler.toJs(),
        setup_function.toJs(),
    };
    defer {
        allocator.free(js_functions[0].body);
        allocator.free(js_functions[1].body);
    }

    const body_elements = [_]html{
        html.div(
            "container mx-auto p-4",
            &[_]html{
                html.h1(
                    "text-4xl font-bold mb-4 cursor-pointer",
                    &[_]html{html.text("Click me to count!")},
                ),
                html.div(
                    "text-2xl font-bold mt-4",
                    &[_]html{
                        html.text("Count: "),
                        html.div(
                            null,
                            &[_]html{html.text("0")},
                        ),
                    },
                ),
                html.scriptWithFunctions(&js_functions),
                html.script(
                    \\document.addEventListener('DOMContentLoaded', () => {
                    \\  setupListeners();
                    \\});
                , false),
            },
        ),
    };

    const html_str = try doc.build(&head_elements, &body_elements);
    defer allocator.free(html_str);

    // Print the HTML to stdout
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{html_str});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
