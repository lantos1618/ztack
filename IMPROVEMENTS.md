# Ztack Architecture Improvements

This document outlines the comprehensive improvements made to the Ztack project to enhance scalability, maintainability, and modern web development patterns.

## Overview of Changes

The project has been refactored from a monolithic server example to a modular, production-ready framework with proper architectural patterns. These improvements address the five critical areas identified in the code review.

---

## 1. Router Architecture (NEW: `router.zig`)

### Problem Addressed
The original `simple_server.zig` used hardcoded `if (path == "/")` for routing, which doesn't scale beyond a few routes.

### Solution
Created a dedicated `router.zig` module with:

**Key Components:**
- `HttpMethod` enum: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- `Route` struct: Associates HTTP method + path + handler
- `Router` struct: Manages routes and dispatches requests

**API:**
```zig
var app_router = router.Router.init(allocator);
try app_router.register(router.HttpMethod.GET, "/", &handleIndex);
try app_router.register(router.HttpMethod.POST, "/api/data", &handlePostData);

if (try app_router.dispatch(method, path, req_body)) |response| {
    // Handle response
}
```

**Helper Functions:**
- `notFoundResponse()`: 404 response
- `htmlResponse()`: HTML with proper headers
- `jsonResponse()`: JSON with proper headers
- `parseRequestLine()`: Extracts method & path from HTTP request

**Usage Example:**
See `src/examples/router_server.zig` for a complete working example.

---

## 2. HTML Rendering Optimization (Streaming Pattern)

### Problem Addressed
The original `html.zig` used `std.fmt.allocPrint()` recursively, allocating intermediate strings and putting pressure on the allocator. For high-traffic servers, this is inefficient.

### Solution
Added streaming writer pattern:

**Before:**
```zig
pub fn build(head: []const Element, body: []const Element) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    try result.appendSlice("<!DOCTYPE html>\n<html>\n");
    // ... more allocations ...
    return result.toOwnedSlice();
}
```

**After:**
```zig
pub fn build(head: []const Element, body: []const Element) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    try self.renderToWriter(result.writer(), head, body);
    return result.toOwnedSlice();
}

pub fn renderToWriter(writer: anytype, head: []const Element, body: []const Element) !void {
    try writer.writeAll("<!DOCTYPE html>\n<html>\n");
    // ... direct writes, no intermediate allocations ...
}
```

**Benefits:**
- Single allocation (the final ArrayList)
- Direct writes to output stream
- Compatible with TCP writers, file writers, etc.
- No string buffering between elements

---

## 3. Event Delegation (Modern DOM Patterns)

### Problem Addressed
Using inline `onclick="handleClick()"` violates modern Content Security Policies and is less maintainable. Global function scope pollution.

### Solution
Implemented event delegation with `data-on` attributes:

**HTML Generation:**
```zig
html.button_data(
    "px-8 py-4 bg-blue-600",
    "click:handleClick",
    &[_]html.Element{ html.text("Click Me") }
)
```

**Generates:**
```html
<button data-on="click:handleClick" class="px-8 py-4 bg-blue-600">
  Click Me
</button>
```

**JavaScript Glue (in `html.zig`):**
```javascript
// EVENT_DELEGATION_SCRIPT constant
document.body.addEventListener('click', function(e) {
  var target = e.target.closest('[data-on]');
  if (!target) return;
  var parts = target.dataset.on.split(':');
  var event = parts[0];
  var handler = parts[1];
  if (e.type === event && window[handler]) {
    window[handler](e);
  }
});
```

**Benefits:**
- CSP-compliant (no inline event handlers)
- Single listener for all delegated events
- Cleaner HTML output
- Easier to add/remove handlers dynamically

---

## 4. Transpiler Robustness Improvements

### Const vs Var Distinction
Previously, the transpiler treated all variable declarations as `let`. Now it properly distinguishes:

```zig
// Zig Code
const x = 10;  // Immutable
var y = 20;    // Mutable

// Transpiles to
const x = 10;
let y = 20;
```

**Implementation:**
Checks the token tag (`keyword_const` vs `keyword_var`) and generates the appropriate JS statement.

### Unsupported Construct Validation
Added explicit checks for unsupported Zig features:
- Pointers (`ptr_type`)
- Builtin calls (`builtin_call`)
- These emit warnings instead of silently failing

**Example:**
```
⚠️  Transpiler Warnings (1 unsupported constructs found):
  - Pointers are not supported in Zig Script
```

### Future Improvements
The validation framework is now in place to easily add:
- Slice validation
- Complex expression checks
- Advanced control flow detection

---

## 5. HTML Builder Helper Functions (Better DX)

### Problem Addressed
Creating UI required deeply nested struct literals, making code verbose and hard to read.

### Solution
Added convenience functions for common elements:

```zig
// Instead of:
.button = .{
    .class = "btn-primary",
    .onclick = "handleClick()",
    .children = &[_]html.Element{ html.text("Click") }
}

// Use:
html.button("btn-primary", "handleClick()", &[_]html.Element{
    html.text("Click")
})
```

**Available Helpers:**
```zig
// Text
html.text(content)

// Containers
html.div(class_or_id, children)
html.h1(class, children)
html.h2(class, children)
html.p(class, children)
html.span(class, children)

// Interactive
html.button(class, onclick, children)
html.button_data(class, data_on, children)  // Event delegation
html.input(type, id, class)
html.input_with_value(type, id, value)
html.anchor(href, class, children)

// Meta
html.meta(charset)
html.title(children)
html.script(src_or_content, is_src)
```

**Real-World Example:**
```zig
const page = &[_]html.Element{
    html.div("container", &[_]html.Element{
        html.h1("title", &[_]html.Element{
            html.text("Welcome"),
        }),
        html.button_data("btn-primary", "click:handleSubmit", &[_]html.Element{
            html.text("Submit"),
        }),
    }),
};
```

---

## 6. Module Organization

### New Modules
- **`router.zig`** (NEW): HTTP routing with method/path matching
- **`html.zig`** (ENHANCED): Streaming rendering + event delegation + helpers
- **`transpiler.zig`** (IMPROVED): Better validation + const/var distinction
- **`js.zig`**: JavaScript AST (unchanged, robust)
- **`symbol_map.zig`**: Zig→JS symbol mapping (unchanged)
- **`dom.zig`**: DOM API abstraction (existing)

### Build Integration
All modules are properly integrated in `build.zig`:
```zig
const router_module = b.addModule("router", .{
    .root_source_file = b.path("src/modules/router.zig"),
});
```

---

## Examples

### 1. Router-Based Server (`router_server.zig`)
Demonstrates basic router usage with multiple endpoints.

**Run:**
```bash
zig build router
```

### 2. Improved Counter (`improved_counter.zig`)
Showcases all improvements together:
- Router-based architecture
- HTML builder helpers
- Event delegation with `data-on` attributes
- Streaming HTML rendering

**Run:**
```bash
zig build improved
```

---

## Performance Implications

### Memory Usage
- **Before**: O(n) intermediate allocations for HTML rendering
- **After**: O(1) intermediate allocation (final ArrayList)

### CPU Usage
- **Before**: Multiple allocation/deallocation cycles
- **After**: Single linear pass with direct writes

### Network
- Same output size, better generation performance

### Example (1000-element page):
- Old: ~1000 allocPrint calls
- New: 1 ArrayList write + direct stream writes

---

## Backward Compatibility

All changes are **backward compatible**:
- `html.build()` still returns `[]const u8`
- `HtmlDocument` API unchanged
- Old code using nested structs still works
- New helpers are additive

**Migration Path:**
Gradually replace verbose struct literals with helper functions:
```zig
// Old (still works)
.div = .{ .class = "container", .children = ... }

// New (recommended)
html.div("container", ...)
```

---

## Next Steps (Priority Order)

1. **WASM First**: The transpiler is cool, but Zig→WASM is where the real power lies. Consider:
   - Auto-generating JavaScript glue code for WASM exports
   - Binding DOM events to WASM functions
   - Memory safe DOM access from WASM

2. **DOM API Completeness**:
   - Add `fetch()` abstraction
   - Add `localStorage` abstraction
   - Add `console` abstraction
   - This enables real web apps

3. **Streaming Response Support**:
   - Instead of allocating full HTML, stream directly to TCP socket
   - Use `renderToWriter()` with the socket writer directly

4. **Database Integration**:
   - SQL builder
   - Connection pooling helpers
   - Migration framework

5. **Request/Response Middleware**:
   - CORS helpers
   - Authentication middleware
   - Logging/metrics

---

## Design Principles

These improvements follow these principles:

1. **Stream Everything**: Allocate once, write directly
2. **Type Safety**: Use Zig's type system, not stringly-typed routing
3. **No Magic**: Explicit over implicit, readers understand what happens
4. **Modern Patterns**: CSP-compliant, event delegation, proper HTTP semantics
5. **Opt-in Features**: Helpers are optional, core modules are minimal
6. **Progressive Enhancement**: Old patterns still work, new patterns available

---

## Testing

Build and verify:
```bash
zig build              # Build all (should complete with no errors)
zig build router       # Run router example
zig build improved     # Run improved counter
zig build test         # Run transpiler tests
```

---

## Summary

This architecture upgrade transforms Ztack from a proof-of-concept into a production-ready framework by:

✓ Adding proper routing with `router.zig`
✓ Optimizing HTML rendering with streaming writers
✓ Implementing modern event delegation patterns
✓ Improving transpiler robustness and validation
✓ Providing developer-friendly HTML builders
✓ Maintaining backward compatibility
✓ Following web standards and best practices

The foundation is now solid for building real web applications in Zig.
