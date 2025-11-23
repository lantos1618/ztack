const std = @import("std");
const html = @import("html");
const js = @import("js");
const dom = @import("dom");
const zap = @import("zap");

fn generateHeadElements() []const html.Element {
    return &[_]html.Element{
        html.Element{ .meta = .{ .charset = "utf-8" } },
        html.Element{ .title = .{
            .children = &[_]html.Element{
                html.Element.text("Zig Wasm Demo"),
            },
        } },
        html.Element{ .script = .{ .src = "https://cdn.tailwindcss.com" } },
    };
}

fn generateBodyElements() []const html.Element {
    return &[_]html.Element{
        html.Element{ .div = .{
            .class = "container mx-auto p-4",
            .children = &[_]html.Element{
                html.Element{ .h1 = .{
                    .class = "text-4xl font-bold mb-8",
                    .children = &[_]html.Element{
                        html.Element.text("Zig WebAssembly Demo"),
                    },
                } },
                html.Element{ .div = .{
                    .class = "bg-white rounded-lg shadow-md p-6 mb-6",
                    .children = &[_]html.Element{
                        html.Element{ .h2 = .{
                            .class = "text-2xl font-bold mb-4",
                            .children = &[_]html.Element{
                                html.Element.text("Add Numbers"),
                            },
                        } },
                        html.Element{ .div = .{
                            .class = "flex gap-4 items-center",
                            .children = &[_]html.Element{
                                html.Element{ .input = .{
                                    .type = "number",
                                    .id = "num1",
                                    .value = "5",
                                    .class = "border p-2 rounded",
                                } },
                                html.Element{ .input = .{
                                    .type = "number",
                                    .id = "num2",
                                    .value = "3",
                                    .class = "border p-2 rounded",
                                } },
                                html.Element{ .button = .{
                                    .class = "bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600",
                                    .onclick = "calculateAdd()",
                                    .children = &[_]html.Element{
                                        html.Element.text("Add"),
                                    },
                                } },
                                html.Element{ .p = .{
                                    .class = "ml-4",
                                    .children = &[_]html.Element{
                                        html.Element.text("Result: "),
                                        html.Element{ .span = .{
                                            .id = "addResult",
                                            .class = "font-bold",
                                            .children = &[_]html.Element{
                                                html.Element.text("-"),
                                            },
                                        } },
                                    },
                                } },
                            },
                        } },
                    },
                } },
                html.Element{ .div = .{
                    .class = "bg-white rounded-lg shadow-md p-6",
                    .children = &[_]html.Element{
                        html.Element{ .h2 = .{
                            .class = "text-2xl font-bold mb-4",
                            .children = &[_]html.Element{
                                html.Element.text("Fibonacci"),
                            },
                        } },
                        html.Element{ .div = .{
                            .class = "flex gap-4 items-center",
                            .children = &[_]html.Element{
                                html.Element{ .input = .{
                                    .type = "number",
                                    .id = "fibN",
                                    .value = "10",
                                    .class = "border p-2 rounded",
                                } },
                                html.Element{ .button = .{
                                    .class = "bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600",
                                    .onclick = "calculateFib()",
                                    .children = &[_]html.Element{
                                        html.Element.text("Calculate"),
                                    },
                                } },
                                html.Element{ .p = .{
                                    .class = "ml-4",
                                    .children = &[_]html.Element{
                                        html.Element.text("Result: "),
                                        html.Element{ .span = .{
                                            .id = "fibResult",
                                            .class = "font-bold",
                                            .children = &[_]html.Element{
                                                html.Element.text("-"),
                                            },
                                        } },
                                    },
                                } },
                            },
                        } },
                    },
                } },
                html.Element{ .script = .{ .content = 
                \\let wasmInstance = null;
                \\
                \\async function loadWasm() {
                \\  try {
                \\    const response = await fetch('/wasm_main.wasm');
                \\    const bytes = await response.arrayBuffer();
                \\    const results = await WebAssembly.instantiate(bytes);
                \\    wasmInstance = results.instance;
                \\    console.log("Wasm module loaded successfully!");
                \\  } catch (error) {
                \\    console.error("Error loading wasm:", error);
                \\  }
                \\}
                \\
                \\function calculateAdd() {
                \\  if (!wasmInstance) {
                \\    console.error("Wasm not loaded yet");
                \\    return;
                \\  }
                \\  const num1 = parseInt(document.getElementById("num1").value);
                \\  const num2 = parseInt(document.getElementById("num2").value);
                \\  const result = wasmInstance.exports.add(num1, num2);
                \\  document.getElementById('addResult').textContent = result;
                \\}
                \\
                \\function calculateFib() {
                \\  if (!wasmInstance) {
                \\    console.error("Wasm not loaded yet");
                \\    return;
                \\  }
                \\  const n = parseInt(document.getElementById("fibN").value);
                \\  const result = wasmInstance.exports.fibonacci(n);
                \\  document.getElementById('fibResult').textContent = result;
                \\}
                \\
                \\// Load wasm when page loads
                \\document.addEventListener('DOMContentLoaded', loadWasm);
                } },
            },
        } },
    };
}

pub fn handle(r: zap.Request) void {
    var doc = html.HtmlDocument.init(std.heap.page_allocator);
    const head_elements = generateHeadElements();
    const body_elements = generateBodyElements();

    if (doc.build(head_elements, body_elements)) |html_str| {
        defer std.heap.page_allocator.free(html_str);

        if (r.setHeader("Content-Type", "text/html")) |_| {
            if (r.sendBody(html_str)) |_| {
                return;
            } else |err| {
                std.debug.print("Error sending body: {}\n", .{err});
                r.setStatus(.internal_server_error);
            }
        } else |err| {
            std.debug.print("Error setting header: {}\n", .{err});
            r.setStatus(.internal_server_error);
        }
    } else |err| {
        std.debug.print("Error generating HTML: {}\n", .{err});
        r.setStatus(.internal_server_error);
        _ = r.sendBody("Internal Server Error") catch |send_err| {
            std.debug.print("Error sending error response: {}\n", .{send_err});
        };
    }
}
