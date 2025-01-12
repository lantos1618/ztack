const std = @import("std");
const HtmlDocument = @import("html.zig").HtmlDocument;
const html = @import("html.zig").Element;
const JsFunction = @import("html.zig").JsFunction;

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

    const js_functions = [_]JsFunction{
        .{
            .name = "handleClick",
            .args = &[_][]const u8{"event"},
            .body = "alert('Hello from Zig-generated JavaScript!');",
        },
        .{
            .name = "setupListeners",
            .args = &[_][]const u8{},
            .body =
            \\const h1 = document.querySelector('h1');
            \\h1.addEventListener('click', handleClick);
            \\console.log('Listeners set up!');
            ,
        },
    };

    const body_elements = [_]html{
        html.div(
            "container mx-auto p-4",
            &[_]html{
                html.h1(
                    "text-4xl font-bold mb-4 cursor-pointer",
                    &[_]html{html.text("Click me!")},
                ),
                html.div(
                    "bg-gray-100 p-4 rounded",
                    &[_]html{html.text("Welcome to my website!")},
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
