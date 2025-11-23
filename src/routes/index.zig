const std = @import("std");
const html = @import("html");
const js_gen = @import("js_gen");
const js_reflect = @import("js_reflect");
const dom = @import("dom");
const zap = @import("zap");

// Function that will be reflected to JavaScript
fn handleClick() void {
    // Get current count and increment
    const counter = dom.querySelector("#counter");
    const count_str = dom.getInnerText(counter).toString();
    const count = std.fmt.parseInt(i32, count_str, 10) catch 0;
    const new_count = count + 1;

    // Update counter text
    _ = dom.setInnerText(counter, std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{new_count}) catch unreachable);

    // Check for milestone
    if (new_count == 10) {
        _ = dom.alert("You've clicked 10 times! Keep going!");
    } else if (new_count == 50) {
        _ = dom.alert("Wow! 50 clicks! You're dedicated!");
    } else if (new_count == 100) {
        _ = dom.alert("100 CLICKS! You're officially a click master! 🏆");
    }
}

// Function that will be reflected to JavaScript
fn setupListeners() void {
    const button = dom.querySelector("#clickButton");
    _ = dom.addEventListener(button, dom.EventType.click.toString(), "handleClick");
}

// Function that will be reflected to JavaScript
fn initPage() void {
    _ = setupListeners();
}

pub fn generateHtml(allocator: std.mem.Allocator) ![]const u8 {
    var doc = html.HtmlDocument.init(allocator);

    const head_elements = [_]html.Element{
        html.Element.meta("utf-8"),
        html.Element.title(&[_]html.Element{
            html.Element.text("Zig Click Counter"),
        }),
        html.Element.script("https://cdn.tailwindcss.com", true),
    };

    // Manually construct JavaScript function bodies
    // (Zig doesn't support AST reflection on function bodies, so we build the JS AST manually)
    
    // handleClick function body
    const click_handler_stmts = [_]js_gen.JsStatement{
        .{ .const_decl = .{
            .name = "counter",
            .value = .{ .method_call = .{
                .object = &js_gen.JsExpression{ .identifier = "document" },
                .method = "querySelector",
                .args = &[_]js_gen.JsExpression{
                    .{ .value = .{ .string = "#counter" } },
                },
            } },
        } },
        .{ .const_decl = .{
            .name = "count_str",
            .value = .{ .property_access = .{
                .object = &js_gen.JsExpression{ .identifier = "counter" },
                .property = "innerText",
            } },
        } },
        .{ .const_decl = .{
            .name = "count",
            .value = .{ .function_call = .{
                .function = &js_gen.JsExpression{ .identifier = "parseInt" },
                .args = &[_]js_gen.JsExpression{
                    .{ .identifier = "count_str" },
                    .{ .value = .{ .number = 10 } },
                },
            } },
        } },
        .{ .const_decl = .{
            .name = "new_count",
            .value = .{ .binary_op = .{
                .left = &js_gen.JsExpression{ .identifier = "count" },
                .operator = "+",
                .right = &js_gen.JsExpression{ .value = .{ .number = 1 } },
            } },
        } },
        .{ .assign = .{
            .target = "counter.innerText",
            .value = .{ .identifier = "new_count" },
        } },
        .{ .if_stmt = .{
            .condition = .{ .binary_op = .{
                .left = &js_gen.JsExpression{ .identifier = "new_count" },
                .operator = "==",
                .right = &js_gen.JsExpression{ .value = .{ .number = 10 } },
            } },
            .body = &[_]js_gen.JsStatement{
                .{ .expression = .{ .method_call = .{
                    .object = &js_gen.JsExpression{ .identifier = "window" },
                    .method = "alert",
                    .args = &[_]js_gen.JsExpression{
                        .{ .value = .{ .string = "You've clicked 10 times! Keep going!" } },
                    },
                } } },
            },
            .else_body = null,
        } },
    };
    
    var click_handler_str = std.ArrayList(u8).init(allocator);
    defer click_handler_str.deinit();
    for (click_handler_stmts) |stmt| {
        try click_handler_str.writer().print("{s}\n", .{stmt.toString()});
    }

    // setupListeners function body
    const setup_stmts = [_]js_gen.JsStatement{
        .{ .const_decl = .{
            .name = "button",
            .value = .{ .method_call = .{
                .object = &js_gen.JsExpression{ .identifier = "document" },
                .method = "querySelector",
                .args = &[_]js_gen.JsExpression{
                    .{ .value = .{ .string = "#clickButton" } },
                },
            } },
        } },
        .{ .expression = .{ .method_call = .{
            .object = &js_gen.JsExpression{ .identifier = "button" },
            .method = "addEventListener",
            .args = &[_]js_gen.JsExpression{
                .{ .value = .{ .string = "click" } },
                .{ .identifier = "handleClick" },
            },
        } } },
    };
    
    var setup_str = std.ArrayList(u8).init(allocator);
    defer setup_str.deinit();
    for (setup_stmts) |stmt| {
        try setup_str.writer().print("{s}\n", .{stmt.toString()});
    }

    // initPage function body
    const init_stmts = [_]js_gen.JsStatement{
        .{ .expression = .{ .function_call = .{
            .function = &js_gen.JsExpression{ .identifier = "setupListeners" },
            .args = &[_]js_gen.JsExpression{},
        } } },
    };
    
    var init_str = std.ArrayList(u8).init(allocator);
    defer init_str.deinit();
    for (init_stmts) |stmt| {
        try init_str.writer().print("{s}\n", .{stmt.toString()});
    }

    const js_functions = [_]html.JsFunction{
        .{
            .name = "handleClick",
            .args = &[_][]const u8{},
            .body = try allocator.dupe(u8, click_handler_str.items),
        },
        .{
            .name = "setupListeners",
            .args = &[_][]const u8{},
            .body = try allocator.dupe(u8, setup_str.items),
        },
        .{
            .name = "initPage",
            .args = &[_][]const u8{},
            .body = try allocator.dupe(u8, init_str.items),
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
                            &[_]html.Element{html.Element.text("Zig Click Counter")},
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
                                html.Element.text(" and "),
                                html.Element{ .a = .{
                                    .href = "https://tailwindcss.com",
                                    .class = "text-blue-400 hover:text-blue-300",
                                    .children = &[_]html.Element{
                                        html.Element.text("Tailwind CSS"),
                                    },
                                } },
                                html.Element.text(" • "),
                                html.Element{ .a = .{
                                    .href = "/wasm",
                                    .class = "text-blue-400 hover:text-blue-300",
                                    .children = &[_]html.Element{
                                        html.Element.text("Try WASM Demo"),
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
