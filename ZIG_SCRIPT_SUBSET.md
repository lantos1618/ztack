# Zig Script Subset - Supported Frontend Code

This document defines the **Zig Script subset**, which is the set of Zig language features supported for transpilation to JavaScript. If you use features outside this subset, the transpiler will either ignore them (return `null`) or fail with an error.

## Purpose

The transpiler doesn't aim to support all of Zig. Instead, it defines a minimal "Zig Script" subset that is sufficient for writing browser handlers and event listeners.

## Supported Features

### 1. Function Declarations
- **Syntax:** `pub fn name() void { ... }`
- **Restrictions:**
  - No parameters (parameters are ignored and emit a warning)
  - Return type must be `void`
  - Function body can contain statements (see below)

```zig
pub fn handleClick() void {
    // body
}
```

### 2. Variable Declarations
- **Syntax:** `var name = value;`
- **Supported values:**
  - Number literals: `42`, `0`, `-5`
  - String literals: `"hello"` (quotes preserved in JS)
  - Boolean literals: `true`, `false`
  - Identifiers: `myVar`

```zig
var count = 0;
var message = "Hello";
var active = true;
```

### 3. Variable Assignment
- **Syntax:** `target = value;`
- **Same value types as variable declarations**

```zig
count = count + 1;
name = "Updated";
```

### 4. Simple If Statements
- **Syntax:** `if (condition) { ... }`
- **Restrictions:**
  - No `else` support yet
  - Condition must be a simple expression (identifier or literal)
  - Cannot nest complex logic

```zig
if (count == 10) {
    dom.alert("Milestone!");
}
```

### 5. Function Calls (Coming Soon)
- Currently **NOT supported** — will be added
- Planned syntax: `functionName(arg1, arg2);`

### 6. DOM API Calls (Planned)
- The `dom.zig` module provides abstraction layer
- Calls to `dom.*` functions will be transpiled to `document.*` calls
- Example: `dom.querySelector("#id")` → `document.querySelector("#id")`

## Unsupported Features

The following Zig features will NOT work in Zig Script:

- **Loops** (`for`, `while`) — not yet implemented
- **Structs and Types** — too complex for browser code
- **Error handling** (`try`, `catch` in Zig sense) — not applicable to JS
- **Pointers** — not applicable to JS
- **Memory allocation** (`allocator`) — not applicable to JS
- **Function parameters** — currently ignored
- **Generics** — not applicable
- **Async/await** — not yet implemented
- **Complex expressions** — only literals and identifiers are safe
- **Module imports** — only the `dom` module is recognized

## Transpiler Behavior

When the transpiler encounters unsupported code:

1. **Graceful Ignore (returns null):**
   - Statements that cannot be transpiled are skipped
   - Avoids panics and allows partial transpilation

2. **Function Call Handling:**
   - Calls to unknown functions are currently ignored
   - In the future, will validate against a whitelist of `dom.*` functions

3. **Error Reporting:**
   - If enabled, emit warnings about unsupported constructs
   - (To be implemented in a logging system)

## Examples

### ✅ Valid Zig Script
```zig
pub fn handleClick() void {
    var count = 0;
    count = count + 1;
    if (count == 10) {
        // some action
    }
}

pub fn setupListeners() void {
    var element = dom.querySelector("#button");
}
```

### ❌ Invalid Zig Script (will be ignored or error)
```zig
// Parameters not supported
pub fn process(x: i32) void { }

// Loops not supported
pub fn loop() void {
    for (0..10) |i| { }
}

// Complex expressions not supported
pub fn math() void {
    var result = add(a, b);  // function calls not yet supported
}

// Error handling not supported
pub fn risky() void {
    var x = try something();  // 'try' not supported
}
```

## Future Improvements

1. Function calls with argument transpilation
2. Loop support (`for` loops, `while` loops)
3. Else clause in if statements
4. Method chaining (e.g., `dom.querySelector("x").addEventListener(...)`)
5. Object literals for event handler config
6. String interpolation
7. Better error messages and diagnostics

## Transpilation Output

All valid Zig Script code produces **standalone, valid JavaScript** that:
- Uses standard DOM APIs (`document.querySelector`, `addEventListener`, etc.)
- Does not reference Zig runtime
- Can run in any modern browser

Example transpilation:
```zig
// Zig Script
pub fn handleClick() void {
    var count = 0;
    count = count + 1;
    if (count == 10) {
        dom.alert("Done!");
    }
}

// Transpiles to:
// function handleClick() {
//   var count = 0;
//   count = count + 1;
//   if (count == 10) {
//     alert("Done!");
//   }
// }
```
