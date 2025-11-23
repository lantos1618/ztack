# Ztack Quick Start Guide

This guide shows you how to use the improved Ztack framework to build web applications in Zig.

## Building

```bash
# Build everything
zig build

# Run specific examples
zig build router      # Router-based server (basic example)
zig build improved    # Improved counter (showcase all features)
zig build demo        # Transpiler demo
```

## Basic Server with Router

Here's a minimal Zig server with the new router:

```zig
const std = @import("std");
const net = std.net;
const html = @import("html");
const router = @import("router");

fn handleIndex(method: router.HttpMethod, path: []const u8, req_body: []const u8) ![]const u8 {
    _ = method;
    _ = path;
    _ = req_body;
    return "<html><body><h1>Hello</h1></body></html>";
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create router
    var app = router.Router.init(allocator);
    defer app.deinit();

    // Register route
    try app.register(router.HttpMethod.GET, "/", &handleIndex);

    // Listen
    var addr = try net.Address.parseIp("0.0.0.0", 8080);
    var listener = try addr.listen(.{ .reuse_address = true });
    defer listener.deinit();

    std.debug.print("Server listening on http://localhost:8080\n", .{});

    while (listener.accept()) |conn| {
        defer conn.stream.close();
        // ... handle request with app.dispatch() ...
    } else |err| {
        std.debug.print("Error: {}\n", .{err});
    }
}
```

## Building HTML with Helpers

The new HTML builder functions make creating UI easy:

```zig
const head = &[_]html.Element{
    html.meta("utf-8"),
    html.title(&[_]html.Element{ html.text("My Page") }),
};

const body = &[_]html.Element{
    html.div("container", &[_]html.Element{
        html.h1("header", &[_]html.Element{
            html.text("Welcome"),
        }),
        html.button(
            "btn-primary",
            "handleClick()",
            &[_]html.Element{ html.text("Click Me") }
        ),
    }),
};

var doc = html.HtmlDocument.init(allocator);
const page = try doc.build(head, body);
```

## Event Delegation

Modern apps should use event delegation instead of inline `onclick`:

```zig
// Use button_data for event delegation
html.button_data(
    "btn-primary",
    "click:myHandler",  // Format: "event:functionName"
    &[_]html.Element{ html.text("Click Me") }
)
```

Then include the delegation script in your page:

```zig
html.script(html.EVENT_DELEGATION_SCRIPT, false)
```

And define your handler:

```html
<script>
function myHandler(event) {
    console.log("Clicked!", event);
}
</script>
```

## Common HTML Elements

```zig
// Text content
html.text("Hello")

// Containers
html.div(class, children)
html.h1(class, children)
html.h2(class, children)
html.p(class, children)
html.span(class, children)

// Forms
html.button(class, onclick, children)
html.button_data(class, data_on, children)  // Event delegation
html.input(type, id, class)
html.input_with_value(type, id, value)

// Navigation
html.anchor(href, class, children)

// Metadata
html.meta(charset)
html.title(children)
html.script(src_or_content, is_src)
```

## Routing

Routes are registered by HTTP method and path:

```zig
var router = router.Router.init(allocator);

// GET routes
try router.register(.GET, "/", &handleIndex);
try router.register(.GET, "/about", &handleAbout);

// POST routes
try router.register(.POST, "/api/data", &handlePostData);

// Dispatch a request
if (try router.dispatch(method, path, body)) |response| {
    const http = try router.htmlResponse(allocator, response);
    // Send http to client
}
```

## Example: Counter App

```zig
const std = @import("std");
const net = std.net;
const html = @import("html");
const router = @import("router");

var counter: i32 = 0;

fn handleGet(method: router.HttpMethod, path: []const u8, body: []const u8) ![]const u8 {
    _ = method;
    _ = path;
    _ = body;
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    
    var doc = html.HtmlDocument.init(alloc);
    const head = &[_]html.Element{
        html.meta("utf-8"),
        html.title(&[_]html.Element{ html.text("Counter") }),
    };
    
    const count_str = try std.fmt.allocPrint(alloc, "{d}", .{counter});
    const body_elems = &[_]html.Element{
        html.div(null, &[_]html.Element{
            html.h1(null, &[_]html.Element{ html.text("Counter") }),
            html.p(null, &[_]html.Element{ html.text(count_str) }),
            html.button_data(null, "click:increment", &[_]html.Element{
                html.text("Increment"),
            }),
        }),
        html.script(html.EVENT_DELEGATION_SCRIPT, false),
        html.script("function increment() { location.reload(); }", false),
    };
    
    return try doc.build(head, body_elems);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    
    var app = router.Router.init(alloc);
    defer app.deinit();
    
    try app.register(.GET, "/", &handleGet);
    
    var addr = try net.Address.parseIp("0.0.0.0", 8080);
    var listener = try addr.listen(.{ .reuse_address = true });
    defer listener.deinit();
    
    std.debug.print("Counter server on http://localhost:8080\n", .{});
    
    while (listener.accept()) |conn| {
        defer conn.stream.close();
        
        var buf: [4096]u8 = undefined;
        const bytes = conn.stream.read(&buf) catch continue;
        if (bytes == 0) continue;
        
        const req = buf[0..bytes];
        var lines = std.mem.splitSequence(u8, req, "\r\n");
        const line = lines.next() orelse continue;
        
        const parsed = router.Router.parseRequestLine(line) orelse continue;
        const method = parsed[0];
        const path = parsed[1];
        
        if (try app.dispatch(method, path, "")) |response| {
            const http_resp = try router.htmlResponse(alloc, response);
            defer alloc.free(http_resp);
            _ = try conn.stream.writeAll(http_resp);
        }
    } else |err| {
        std.debug.print("Error: {}\n", .{err});
    }
}
```

## Key Improvements

1. **Router**: Type-safe HTTP routing by method & path
2. **Streaming HTML**: Efficient rendering with no intermediate allocations
3. **Event Delegation**: Modern, CSP-compliant event handling
4. **Helpers**: Clean, readable UI code with `html.*` functions
5. **Validation**: Transpiler validates unsupported Zig constructs
6. **Const/Var**: Proper distinction in transpiled JavaScript

## Next Steps

- Check `IMPROVEMENTS.md` for detailed architecture documentation
- See `src/examples/improved_counter.zig` for complete working example
- Look at `src/examples/router_server.zig` for router usage
- Review `src/modules/html.zig` for all available builders

## Tips

- Use `html.*` helpers instead of struct literals
- Use `button_data()` instead of `button()` for modern apps
- Always include `html.EVENT_DELEGATION_SCRIPT` if using `data-on`
- Routes don't do path parameters yet - add that as needed
- Consider adding middleware for CORS, auth, logging

## Build Info

Current binaries in `zig-out/bin/`:
- `router_server` - Basic routing example
- `improved_counter` - Full-featured example
- `js_counter` - Original transpilation example
- `demo_transpiler` - AST transpilation demo
- `wasm_counter` - WebAssembly example

Happy building! 🚀
