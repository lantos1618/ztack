const std = @import("std");
const zap = @import("zap");
const HtmlDocument = @import("html.zig").HtmlDocument;
const html = @import("html.zig").Element;
const JsFunction = @import("html.zig").JsFunction;
const dom = @import("dom.zig");
const js = @import("js_gen.zig");
const js_reflect = @import("js_reflect.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpa_allocator = gpa.allocator();

// Function that will be reflected to JavaScript
fn handleClick() void {
    // Get current count and increment
    const counter = dom.querySelector("#counter");
    const count_str = dom.getInnerText(counter).toString();
    const count = std.fmt.parseInt(i32, count_str, 10) catch 0;
    const new_count = count + 1;

    // Update counter text
    _ = dom.setInnerText(counter, std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{new_count}) catch unreachable);

    // Check for 10 clicks
    if (new_count == 10) {
        _ = dom.alert("You reached 10 clicks!");
    }
}

// Function that will be reflected to JavaScript
fn setupListeners() void {
    const heading = dom.querySelector("h1");
    _ = dom.addEventListener(heading, dom.EventType.click.toString(), "handleClick");
}

pub fn generateHtml(alloc: std.mem.Allocator) ![]const u8 {
    var doc = HtmlDocument.init(alloc);

    const head_elements = [_]html{
        html.meta("utf-8"),
        html.title(&[_]html{html.text("My Page")}),
        html.script("https://cdn.tailwindcss.com", true),
    };

    // Convert Zig functions to JavaScript
    const click_handler_body = js_reflect.toJsBody(handleClick, "handleClick");
    const setup_body = js_reflect.toJsBody(setupListeners, "setupListeners");

    // Create JavaScript function strings
    var click_handler_str = std.ArrayList(u8).init(alloc);
    defer click_handler_str.deinit();
    for (click_handler_body) |stmt| {
        try click_handler_str.writer().print("{s}\n", .{stmt.toString()});
    }

    var setup_str = std.ArrayList(u8).init(alloc);
    defer setup_str.deinit();
    for (setup_body) |stmt| {
        try setup_str.writer().print("{s}\n", .{stmt.toString()});
    }

    const js_functions = [_]JsFunction{
        .{
            .name = "handleClick",
            .args = &[_][]const u8{},
            .body = try alloc.dupe(u8, click_handler_str.items),
        },
        .{
            .name = "setupListeners",
            .args = &[_][]const u8{},
            .body = try alloc.dupe(u8, setup_str.items),
        },
    };
    defer alloc.free(js_functions[0].body);
    defer alloc.free(js_functions[1].body);

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
