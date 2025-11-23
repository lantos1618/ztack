# Transpiler Fixes Summary

## What Was Fixed

### 1. ✅ DOM Namespace Mapping (Critical)
**Status:** IMPLEMENTED
- Added `mapSymbols()` function in transpiler that converts `dom.*` calls to `document.*`
- Maps:
  - `dom.querySelector()` → `document.querySelector()`
  - `dom.getElementById()` → `document.getElementById()`
  - `dom.alert()` → `window.alert()`
- Works for both property access chains and method calls
- Handles nested function calls (recursively maps function pointers)

**Example:**
```zig
// Input Zig
const el = dom.querySelector("#test");
dom.alert("Hello");

// Output JavaScript
const el = document.querySelector("#test");
window.alert("Hello");
```

### 2. ✅ Variable Declaration Type (let/const instead of var)
**Status:** IMPLEMENTED
- Changed `var_decl` transpilation to output `let_decl` statements
- JavaScript output now uses `let` for Zig `var` declarations (mutable)
- Structure supports future use of `const_decl` for Zig `const`

**Example:**
```zig
// Input Zig
var x = 5;

// Output JavaScript (BEFORE)
var x = 5;

// Output JavaScript (AFTER)
let x = 5;
```

### 3. ✅ For Loop Support
**Status:** IMPLEMENTED
- Added `transpileForSimple()` function for Zig range-based for loops
- Supports `for (start..end) |i| { ... }` syntax
- Generates standard JavaScript C-style for loops: `for (let i = start; i < end; i++)`
- Properly handles:
  - Iterator variable declaration with `let`
  - Condition expression with postfix `++`
  - Block body statements

**Example:**
```zig
// Input Zig
for (0..10) |i| {
  // loop body
}

// Output JavaScript
for (let i = 0; i < 10; i++) {
  // loop body
}
```

### 4. ✅ Unary Operator Postfix Support
**Status:** IMPLEMENTED
- Enhanced `unary_op` to support postfix operators (like `i++` vs `++i`)
- Added `is_postfix` boolean field to `JsExpression.unary_op`
- Properly outputs `i++` in for loop increments instead of `++i`

**Example:**
```zig
// For loop update expression
i++  // outputs as: i++  (not ++i)
```

### 5. ✅ Expression Statements
**Status:** IMPLEMENTED
- Added support for expression statements (standalone function calls)
- Transpiler now handles `.call_one` and `.call` tags at statement level
- Enables transpilation of standalone calls like `dom.alert("msg")`

**Example:**
```zig
// Input Zig
dom.alert("Hello");
setupListeners();

// Output JavaScript
document.alert("Hello");
setupListeners();
```

### 6. ✅ Eliminate toString Allocations
**Status:** PARTIAL (Architecture improvement in dom.zig)
- Refactored `dom.zig` functions to remove `toString()` allocations
- `setInnerText()` and `setInnerHtml()` now return expressions instead of pre-formatted strings
- Deferred string generation until final output
- Reduces memory fragmentation from excessive allocations

## Architecture Notes

### DOM Mapping vs DOM.zig Functions
**Important:** There's a semantic difference between:
1. **Transpiler symbol mapping** - Maps identifier `dom` to `document` during JS generation
2. **dom.zig module functions** - These are Zig functions that return `JsExpression` values

The transpiler works by parsing Zig source text, not by executing Zig code. When you write:
```zig
const counter = dom.querySelector("#counter");
```

The transpiler sees this as: call the identifier `dom.querySelector` (a method call). It doesn't execute the dom.zig function; instead, it maps the symbol based on patterns.

### Writer Pattern for Future Optimization
The codebase already has a `write()` method for streaming output. Future refactoring should:
1. Remove all `toString()` calls
2. Use `write()` methods throughout
3. Stream directly to HTTP responses
4. Eliminate intermediate string allocations

## Testing

Run the transpiler tests:
```bash
zig build test
```

Run the demo:
```bash
zig build demo
```

## Performance Impact

- **Memory:** Reduced allocations from DOM string building
- **Speed:** Symbol mapping is O(1) string comparisons
- **Output Size:** No change (same JavaScript generated)

## Known Limitations

1. **Parameters:** Function parameters are not yet transpiled (warning issued)
2. **Multi-argument calls:** Partially supported, some complex cases need work
3. **Async/Await:** Not yet implemented
4. **Generics:** Not applicable to JavaScript target
