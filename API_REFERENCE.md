# Ztack API Reference

Quick reference for the improved Ztack framework APIs.

## Router Module (`router.zig`)

### HttpMethod Enum
```zig
pub const HttpMethod = enum {
    GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
};

// Convert string to enum
HttpMethod.fromString("GET")  // → .GET
```

### Router Struct
```zig
var router = Router.init(allocator);
defer router.deinit();

// Register a route
try router.register(.GET, "/", &handleIndex);
try router.register(.POST, "/api/data", &handleData);

// Dispatch a request
if (try router.dispatch(.GET, "/", "")) |response| {
    // Handle response
}

// Find a route
if (router.findRoute(.GET, "/")) |route| {
    // Route found
}

// Parse HTTP request line
if (Router.parseRequestLine("GET / HTTP/1.1")) |parsed| {
    const method = parsed[0];
    const path = parsed[1];
}
```

### Response Builders
```zig
// HTML response
const http_response = try router.htmlResponse(allocator, html_content);

// JSON response
const json_response = try router.jsonResponse(allocator, json_content);

// 404 not found
const not_found = try router.notFoundResponse(allocator);
```

---

## HTML Module (`html.zig`)

### Text Elements
```zig
html.text("Hello World")
```

### Container Elements
```zig
// Divs with optional class/id
html.div(null, children)
html.div("container", children)
html.div("#my-id", children)

// Headers
html.h1("title", children)
html.h2("subtitle", children)

// Other containers
html.p("description", children)
html.span("inline", children)
```

### Interactive Elements
```zig
// Button with onclick handler
html.button("btn-primary", "handleClick()", children)

// Button with event delegation
html.button_data("btn-primary", "click:handleClick", children)

// Input fields
html.input("text", "username", "form-input")
html.input_with_value("password", "pwd", "secret")

// Links
html.anchor("/about", "link-class", children)
```

### Meta Elements
```zig
html.meta("utf-8")
html.title(&[_]html.Element{ html.text("Page Title") })
html.script("src.js", true)  // External script
html.script("var x = 1;", false)  // Inline script
```

### Event Delegation
```zig
// Use button_data() for event delegation
html.button_data("btn", "click:myHandler", children)

// Include this in your page
html.script(html.EVENT_DELEGATION_SCRIPT, false)

// Then define handlers in JavaScript
// <script>
//   function myHandler(event) { ... }
// </script>
```

### Document Building
```zig
var doc = html.HtmlDocument.init(allocator);

const head = &[_]html.Element{ ... };
const body = &[_]html.Element{ ... };

// Build HTML string
const html_string = try doc.build(head, body);

// Or render directly to a writer
try doc.renderToWriter(socket_writer, head, body);
```

---

## Transpiler Module (`transpiler.zig`)

### Transpile Zig to JavaScript
```zig
const transpiler_code = @embedFile("handlers.zig");
var transpiler = try Transpiler.init(allocator, transpiler_code);
defer transpiler.deinit();

const js_statements = try transpiler.transpile();

// Get warnings about unsupported constructs
transpiler.validator.printWarnings();
```

### Supported Zig Script Features
- Function declarations: `pub fn name() void { ... }`
- Variable declarations: `var x = 10;` or `const y = 20;`
- Variable assignment: `x = 20;`
- Arithmetic: `+`, `-`, `*`, `/`, `%`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Control flow: `if`, `for` loops
- Function calls: `dom.querySelector("#id")`

### Unsupported Features
- Pointers
- Complex types
- Allocators
- Advanced control flow

---

## JavaScript Module (`js.zig`)

### Building JavaScript Expressions
```zig
// Values
js.JsValue{ .number = 42 }
js.JsValue{ .string = "hello" }
js.JsValue{ .boolean = true }

// Identifiers
js.JsExpression{ .identifier = "myVar" }

// Binary operations
js.JsExpression{
    .binary_op = .{
        .left = left_expr,
        .operator = "+",
        .right = right_expr,
    }
}

// Function calls
js.JsExpression{
    .function_call = .{
        .function = func_expr,
        .args = args_slice,
    }
}
```

### Building JavaScript Statements
```zig
// Variable declaration
js.JsStatement{
    .let_decl = .{ .name = "x", .value = expr }
}

// Constant declaration
js.JsStatement{
    .const_decl = .{ .name = "x", .value = expr }
}

// Assignment
js.JsStatement{
    .assign = .{ .target = "x", .value = expr }
}

// If statement
js.JsStatement{
    .if_stmt = .{
        .condition = cond_expr,
        .body = body_stmts,
    }
}

// Function declaration
js.JsStatement{
    .function_decl = .{
        .name = "myFunc",
        .params = &[_][]const u8{ "arg1", "arg2" },
        .body = body_stmts,
    }
}
```

### Writing JavaScript
```zig
var js_code = std.ArrayList(u8).init(allocator);
try stmt.write(js_code.writer(), 0);  // indent=0
```

---

## DOM Module (`dom.zig`)

Abstract DOM API for transpilation.

```zig
// Planned functions:
dom.querySelector(selector)
dom.getElementById(id)
dom.addEventListener(target, event, handler)
dom.fetch(url, options)
dom.localStorage()
dom.alert(message)
```

---

## Complete Example

```zig
const std = @import("std");
const html = @import("html");
const router = @import("router");

fn handleIndex(method: router.HttpMethod, path: []const u8, body: []const u8) ![]const u8 {
    _ = method; _ = path; _ = body;
    
    var doc = html.HtmlDocument.init(allocator);
    const head = &[_]html.Element{
        html.meta("utf-8"),
        html.title(&[_]html.Element{ html.text("My App") }),
    };
    
    const page = &[_]html.Element{
        html.div("container", &[_]html.Element{
            html.h1("title", &[_]html.Element{
                html.text("Welcome"),
            }),
            html.button_data("btn-primary", "click:handleClick", &[_]html.Element{
                html.text("Click Me"),
            }),
        }),
        html.script(html.EVENT_DELEGATION_SCRIPT, false),
        html.script("function handleClick() { alert('Clicked!'); }", false),
    };
    
    return try doc.build(head, page);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = router.Router.init(allocator);
    defer app.deinit();

    try app.register(.GET, "/", &handleIndex);

    // ... Listen and dispatch ...
}
```

---

## Common Patterns

### Simple Counter
```zig
const body = &[_]html.Element{
    html.div(null, &[_]html.Element{
        html.p(null, &[_]html.Element{
            html.text("Count: 0"),
        }),
        html.button_data(null, "click:increment", &[_]html.Element{
            html.text("Increment"),
        }),
    }),
};
```

### Form with Inputs
```zig
const form = &[_]html.Element{
    html.div("form-group", &[_]html.Element{
        html.input("text", "username", "form-input"),
        html.input("password", "password", "form-input"),
        html.button_data("btn-submit", "click:handleSubmit", &[_]html.Element{
            html.text("Submit"),
        }),
    }),
};
```

### Navigation
```zig
const nav = &[_]html.Element{
    html.div("navbar", &[_]html.Element{
        html.anchor("/", "brand", &[_]html.Element{ html.text("Home") }),
        html.anchor("/about", "link", &[_]html.Element{ html.text("About") }),
        html.anchor("/contact", "link", &[_]html.Element{ html.text("Contact") }),
    }),
};
```

---

## Type Signatures

### Router Handler
```zig
fn handler(method: router.HttpMethod, path: []const u8, body: []const u8) ![]const u8
```

### HTML Writer
```zig
try element.toString(writer, indent);
try doc.renderToWriter(writer, head, body);
```

### Transpiler
```zig
var transpiler = try Transpiler.init(allocator, source);
const statements = try transpiler.transpile();
transpiler.validator.printWarnings();
```

---

## Error Handling

```zig
// Router dispatch
if (try app.dispatch(method, path, body)) |response| {
    // Success
} else {
    // Not found
}

// HTML building
const html = try doc.build(head, body) catch {
    std.debug.print("HTML building failed\n", .{});
    return error.HTMLBuildFailed;
};

// Transpiler
var transpiler = try Transpiler.init(allocator, source) catch {
    std.debug.print("Parsing failed\n", .{});
    return error.ParseFailed;
};
```

---

## Memory Management

All Ztack APIs require an allocator:

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

// Use allocator with all APIs
var router = Router.init(allocator);
var doc = html.HtmlDocument.init(allocator);
var transpiler = try Transpiler.init(allocator, code);
```

Ownership model:
- Router owns route list
- Document owns HTML tree (shared references)
- Transpiler owns AST and generated code
- Response strings must be freed by caller

---

## Tips & Tricks

1. **Event Delegation**: Always include `html.EVENT_DELEGATION_SCRIPT` if using `button_data()`
2. **Streaming**: Use `renderToWriter()` for large pages to avoid allocations
3. **Type Safety**: The router validates methods at compile-time (enums)
4. **Helpers**: Use `html.*()` functions instead of direct struct literals
5. **Performance**: Each element in streaming mode uses O(1) intermediate memory

---

**Full Documentation:** See IMPROVEMENTS.md and QUICK_START.md
**Examples:** See src/examples/improved_counter.zig
**Tests:** Run `zig build test`
