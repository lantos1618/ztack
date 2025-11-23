const std = @import("std");
const html = @import("html");
const zap = @import("zap");
const js = @import("../../modules/js.zig");

pub fn generateHtml(allocator: std.mem.Allocator) ![]const u8 {
    var doc = html.HtmlDocument.init(allocator);

    const head_elements = [_]html.Element{
        html.meta("utf-8"),
        html.title(&[_]html.Element{
            html.text("Zig Click Counter - JavaScript"),
        }),
        html.script("https://cdn.tailwindcss.com", true),
    };

    // Create JS functions from JS AST statements
    const js_functions = try createJsFunctions(allocator);
    defer {
        for (js_functions) |func| {
            allocator.free(func.body);
        }
        allocator.free(js_functions);
    }

    const body_elements = [_]html.Element{
        html.div(
            "min-h-screen bg-gradient-to-b from-gray-900 to-gray-800 text-white flex items-center justify-center",
            &[_]html.Element{
                html.div(
                    "text-center space-y-8",
                    &[_]html.Element{
                        html.h1(
                            "text-5xl font-bold mb-8 bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500",
                            &[_]html.Element{html.text("Zig Click Counter (JavaScript)")},
                        ),
                        html.div(
                            "space-y-4",
                            &[_]html.Element{
                                html.div(
                                    "text-3xl font-mono",
                                    &[_]html.Element{
                                        html.text("Count: "),
                                        html.div(
                                            "#counter",
                                            &[_]html.Element{html.text("0")},
                                        ),
                                    },
                                ),
                                html.div(
                                    null,
                                    &[_]html.Element{
                                        html.Element{ .button = .{
                                            .class = "px-8 py-4 bg-blue-600 hover:bg-blue-700 rounded-lg transform hover:scale-105 transition-all duration-200 shadow-lg hover:shadow-xl text-xl font-bold",
                                            .id = "clickButton",
                                            .onclick = "handleClick()",
                                            .children = &[_]html.Element{
                                                html.text("Click Me!"),
                                            },
                                        } },
                                    },
                                ),
                                html.div(
                                    "text-gray-400 mt-8",
                                    &[_]html.Element{
                                        html.text("Try to reach the click milestones! 🎯"),
                                    },
                                ),
                            },
                        ),
                        html.div(
                            "mt-12 text-gray-500",
                            &[_]html.Element{
                                html.text("Built with "),
                                html.Element{ .a = .{
                                    .href = "https://ziglang.org",
                                    .class = "text-blue-400 hover:text-blue-300",
                                    .children = &[_]html.Element{
                                        html.text("Zig"),
                                    },
                                } },
                                html.text(" using Zig→JavaScript transpilation • "),
                                html.Element{ .a = .{
                                    .href = "https://tailwindcss.com",
                                    .class = "text-blue-400 hover:text-blue-300",
                                    .children = &[_]html.Element{
                                        html.text("Tailwind CSS"),
                                    },
                                } },
                            },
                        ),
                    },
                ),
                html.scriptWithFunctions(&js_functions),
                html.script("document.addEventListener('DOMContentLoaded', initPage);", false),
            },
        ),
    };

    return doc.build(&head_elements, &body_elements);
}

fn createJsFunctions(allocator: std.mem.Allocator) ![]html.JsFunction {
    var functions = std.ArrayList(html.JsFunction).init(allocator);

    // Create handleClick function
    try functions.append(.{
        .name = "handleClick",
        .args = &[_][]const u8{},
        .body = try allocator.dupe(u8, "  const counter = document.getElementById('counter');\n  let count = parseInt(counter.textContent);\n  count++;\n  counter.textContent = count;\n  if (count === 5) alert('Reached 5 clicks!');\n  if (count === 10) alert('Reached 10 clicks!');"),
    });

    // Create setupListeners function
    try functions.append(.{
        .name = "setupListeners",
        .args = &[_][]const u8{},
        .body = try allocator.dupe(u8, "  const button = document.getElementById('clickButton');\n  if (button) button.addEventListener('click', handleClick);"),
    });

    // Create initPage function
    try functions.append(.{
        .name = "initPage",
        .args = &[_][]const u8{},
        .body = try allocator.dupe(u8, "  setupListeners();\n  const counter = document.getElementById('counter');\n  if (counter) counter.textContent = '0';"),
    });

    return try functions.toOwnedSlice();
}

pub fn handle(r: zap.Request) void {
    if (generateHtml(std.heap.page_allocator)) |html_content| {
        r.setHeader("Content-Type", "text/html") catch return;
        r.sendBody(html_content) catch return;
    } else |err| {
        std.debug.print("Error generating HTML: {}\n", .{err});
        r.setStatus(.internal_server_error);
        r.sendBody("Internal Server Error") catch return;
    }
}
