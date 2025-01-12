const std = @import("std");
const zap = @import("zap");
const HtmlDocument = @import("html.zig").HtmlDocument;
const html = @import("html.zig").Element;
const JsFunction = @import("html.zig").JsFunction;
const dom = @import("dom.zig");
const js = @import("js_gen.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpa_allocator = gpa.allocator();

pub fn generateHtml(alloc: std.mem.Allocator) ![]const u8 {
    var doc = HtmlDocument.init(alloc);

    const head_elements = [_]html{
        html.meta("utf-8"),
        html.title(&[_]html{html.text("My Page")}),
        html.script("https://cdn.tailwindcss.com", true),
    };

    // Create click handler in Zig
    var click_handler = dom.DomFunction.init(alloc, "handleClick");
    defer click_handler.deinit();

    // Get counter element
    const counter_element = "document.querySelector('#counter')";

    // Get current count and increment
    const window_count = js.JsExpression{ .property_access = .{
        .object = &js.JsExpression{ .value = .{ .object = "window" } },
        .property = "count",
    } };

    const inc_stmt = js.JsStatement{
        .assign = .{
            .target = "window.count",
            .value = js.JsExpression{ .binary_op = .{
                .left = &window_count,
                .operator = "+",
                .right = &js.JsExpression{ .value = .{ .number = 1 } },
            } },
        },
    };
    try click_handler.addStatement(inc_stmt.toString());

    // Set innerText statement
    const set_stmt = js.JsStatement{
        .assign = .{
            .target = std.fmt.allocPrint(alloc, "{s}.innerText", .{counter_element}) catch unreachable,
            .value = js.JsExpression{ .method_call = .{
                .object = &window_count,
                .method = "toString",
                .args = &[_]js.JsExpression{},
            } },
        },
    };
    try click_handler.addStatement(set_stmt.toString());

    // If statement
    const if_stmt = js.JsStatement{
        .if_stmt = .{
            .condition = js.JsExpression{ .binary_op = .{
                .left = &window_count,
                .operator = "===",
                .right = &js.JsExpression{ .value = .{ .number = 10 } },
            } },
            .body = &[_]js.JsStatement{
                js.JsStatement{
                    .assign = .{
                        .target = "alert",
                        .value = js.JsExpression{ .value = .{ .string = "You reached 10 clicks!" } },
                    },
                },
            },
        },
    };
    try click_handler.addStatement(if_stmt.toString());

    // Create setup function in Zig
    var setup_function = dom.DomFunction.init(alloc, "setupListeners");
    defer setup_function.deinit();

    // Initialize count variable
    const init_count_stmt = js.JsStatement{
        .assign = .{
            .target = "window.count",
            .value = js.JsExpression{ .value = .{ .number = 0 } },
        },
    };
    try setup_function.addStatement(init_count_stmt.toString());

    // Add event listener statement
    const add_listener_stmt = js.JsStatement{
        .assign = .{
            .target = "document.querySelector('h1').addEventListener",
            .value = js.JsExpression{ .method_call = .{
                .object = &js.JsExpression{ .value = .{ .object = "document.querySelector('h1')" } },
                .method = "addEventListener",
                .args = &[_]js.JsExpression{
                    js.JsExpression{ .value = .{ .string = "click" } },
                    js.JsExpression{ .value = .{ .object = "handleClick" } },
                },
            } },
        },
    };
    try setup_function.addStatement(add_listener_stmt.toString());

    const js_functions = [_]JsFunction{
        click_handler.toJs(),
        setup_function.toJs(),
    };
    defer {
        alloc.free(js_functions[0].body);
        alloc.free(js_functions[1].body);
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
                            "#counter",
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

    return doc.build(&head_elements, &body_elements);
}

fn on_request(r: zap.Request) void {
    const path = r.path orelse "/";
    if (path.len == 0 or std.mem.eql(u8, path, "/")) {
        if (generateHtml(gpa_allocator)) |html_content| {
            r.setHeader("Content-Type", "text/html") catch |err| {
                std.debug.print("Error setting header: {}\n", .{err});
                r.setStatus(.internal_server_error);
                r.sendBody("Internal Server Error") catch return;
                return;
            };
            r.sendBody(html_content) catch |err| {
                std.debug.print("Error sending body: {}\n", .{err});
                return;
            };
        } else |err| {
            std.debug.print("Error generating HTML: {}\n", .{err});
            r.setStatus(.internal_server_error);
            r.sendBody("Internal Server Error") catch return;
        }
    } else {
        r.setStatus(.not_found);
        r.sendBody("Not Found") catch return;
    }
}

pub fn main() !void {
    defer _ = gpa.deinit();

    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .on_request = on_request,
        .log = true,
        .public_folder = ".",
    });
    try listener.listen();

    std.debug.print("Server listening on http://127.0.0.1:8080\n", .{});
    zap.start(.{
        .threads = 2,
        .workers = 2,
    });
}
