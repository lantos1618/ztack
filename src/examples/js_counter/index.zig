const std = @import("std");
const html = @import("html");
const zap = @import("zap");
const handlers = @import("handlers.zig");
const transpiler = @import("../../modules/transpiler.zig");

pub fn generateHtml(allocator: std.mem.Allocator) ![]const u8 {
    var doc = html.HtmlDocument.init(allocator);

    const head_elements = [_]html.Element{
        html.Element.meta("utf-8"),
        html.Element.title(&[_]html.Element{
            html.Element.text("Zig Click Counter - JavaScript"),
        }),
        html.Element.script("https://cdn.tailwindcss.com", true),
    };

    // Transpile handler functions from handlers.zig at comptime
    const handleClick_body = comptime transpiler.transpileHandlerBody(std.heap.page_allocator, "handlers.zig", "handleClick") catch "// Transpilation error";
    const setupListeners_body = comptime transpiler.transpileHandlerBody(std.heap.page_allocator, "handlers.zig", "setupListeners") catch "// Transpilation error";
    const initPage_body = comptime transpiler.transpileHandlerBody(std.heap.page_allocator, "handlers.zig", "initPage") catch "// Transpilation error";

    const js_functions = [_]html.JsFunction{
        .{
            .name = "handleClick",
            .args = &[_][]const u8{},
            .body = try allocator.dupe(u8, handleClick_body),
        },
        .{
            .name = "setupListeners",
            .args = &[_][]const u8{},
            .body = try allocator.dupe(u8, setupListeners_body),
        },
        .{
            .name = "initPage",
            .args = &[_][]const u8{},
            .body = try allocator.dupe(u8, initPage_body),
        },
    };
    defer allocator.free(js_functions[0].body);
    defer allocator.free(js_functions[1].body);
    defer allocator.free(js_functions[2].body);

    const body_elements = [_]html.Element{
        html.Element.div(
            "min-h-screen bg-gradient-to-b from-gray-900 to-gray-800 text-white flex items-center justify-center",
            &[_]html.Element{
                html.Element.div(
                    "text-center space-y-8",
                    &[_]html.Element{
                        html.Element.h1(
                            "text-5xl font-bold mb-8 bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500",
                            &[_]html.Element{html.Element.text("Zig Click Counter (JavaScript)")},
                        ),
                        html.Element.div(
                            "space-y-4",
                            &[_]html.Element{
                                html.Element.div(
                                    "text-3xl font-mono",
                                    &[_]html.Element{
                                        html.Element.text("Count: "),
                                        html.Element.div(
                                            "#counter",
                                            &[_]html.Element{html.Element.text("0")},
                                        ),
                                    },
                                ),
                                html.Element.div(
                                    null,
                                    &[_]html.Element{
                                        html.Element{ .button = .{
                                            .class = "px-8 py-4 bg-blue-600 hover:bg-blue-700 rounded-lg transform hover:scale-105 transition-all duration-200 shadow-lg hover:shadow-xl text-xl font-bold",
                                            .id = "clickButton",
                                            .onclick = "handleClick()",
                                            .children = &[_]html.Element{
                                                html.Element.text("Click Me!"),
                                            },
                                        } },
                                    },
                                ),
                                html.Element.div(
                                    "text-gray-400 mt-8",
                                    &[_]html.Element{
                                        html.Element.text("Try to reach the click milestones! 🎯"),
                                    },
                                ),
                            },
                        ),
                        html.Element.div(
                            "mt-12 text-gray-500",
                            &[_]html.Element{
                                html.Element.text("Built with "),
                                html.Element{ .a = .{
                                    .href = "https://ziglang.org",
                                    .class = "text-blue-400 hover:text-blue-300",
                                    .children = &[_]html.Element{
                                        html.Element.text("Zig"),
                                    },
                                } },
                                html.Element.text(" using Zig→JavaScript transpilation • "),
                                html.Element{ .a = .{
                                    .href = "https://tailwindcss.com",
                                    .class = "text-blue-400 hover:text-blue-300",
                                    .children = &[_]html.Element{
                                        html.Element.text("Tailwind CSS"),
                                    },
                                } },
                            },
                        ),
                    },
                ),
                html.Element.scriptWithFunctions(&js_functions),
                html.Element.script("document.addEventListener('DOMContentLoaded', initPage);", false),
            },
        ),
    };

    return doc.build(&head_elements, &body_elements);
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
