const std = @import("std");
const html = @import("html");
const js = @import("js_gen");
const dom = @import("dom");
const zap = @import("zap");

pub fn generateHtml() []const html.Element {
    return &[_]html.Element{
        .{ .meta = .{ .charset = "utf-8" } },
        .{ .title = .{ .children = &[_]html.Element{
            html.Element.text("Zig Wasm Demo"),
        } } },
        .{ .script = .{ .src = "https://cdn.tailwindcss.com" } },
        .{ .div = .{ .class = "container mx-auto p-4", .children = &[_]html.Element{
            .{ .h1 = .{ .class = "text-4xl font-bold mb-8", .children = &[_]html.Element{
                html.Element.text("Zig WebAssembly Demo"),
            } } },
            .{ .div = .{ .class = "bg-white rounded-lg shadow-md p-6 mb-6", .children = &[_]html.Element{
                .{ .h2 = .{ .class = "text-2xl font-bold mb-4", .children = &[_]html.Element{
                    html.Element.text("Add Numbers"),
                } } },
                .{ .div = .{ .class = "flex gap-4 items-center", .children = &[_]html.Element{
                    .{ .input = .{ .type = "number", .id = "num1", .value = "5", .class = "border p-2 rounded" } },
                    .{ .input = .{ .type = "number", .id = "num2", .value = "3", .class = "border p-2 rounded" } },
                    .{ .button = .{ .onclick = "calculateAdd()", .class = "bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600", .children = &[_]html.Element{
                        html.Element.text("Add"),
                    } } },
                    .{ .p = .{ .class = "ml-4", .children = &[_]html.Element{
                        html.Element.text("Result: "),
                        .{ .span = .{ .id = "addResult", .class = "font-bold", .children = &[_]html.Element{
                            html.Element.text("-"),
                        } } },
                    } } },
                } } },
            } } },
            .{ .div = .{ .class = "bg-white rounded-lg shadow-md p-6", .children = &[_]html.Element{
                .{ .h2 = .{ .class = "text-2xl font-bold mb-4", .children = &[_]html.Element{
                    html.Element.text("Fibonacci"),
                } } },
                .{ .div = .{ .class = "flex gap-4 items-center", .children = &[_]html.Element{
                    .{ .input = .{ .type = "number", .id = "fibN", .value = "10", .class = "border p-2 rounded" } },
                    .{ .button = .{ .onclick = "calculateFib()", .class = "bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600", .children = &[_]html.Element{
                        html.Element.text("Calculate"),
                    } } },
                    .{ .p = .{ .class = "ml-4", .children = &[_]html.Element{
                        html.Element.text("Result: "),
                        .{ .span = .{ .id = "fibResult", .class = "font-bold", .children = &[_]html.Element{
                            html.Element.text("-"),
                        } } },
                    } } },
                } } },
            } } },
            .{ .script = .{ .content = 
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
        } } },
    };
}

pub fn handle(r: zap.Request) void {
    var doc = html.HtmlDocument.init(std.heap.page_allocator);
    const head_elements = generateHtml();

    if (doc.build(head_elements, &[_]html.Element{})) |html_str| {
        r.setHeader("Content-Type", "text/html") catch return;
        r.sendBody(html_str) catch return;
    } else |_| {
        r.setStatus(.internal_server_error);
        r.sendBody("Error generating HTML") catch return;
    }
}
