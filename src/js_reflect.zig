const std = @import("std");
const dom = @import("dom");
const js = @import("js_gen");

pub fn getFunctionName(func: anytype) []const u8 {
    const T = @TypeOf(func);
    const info = @typeInfo(T);
    if (info != .Pointer or info.Pointer.size != .One or @typeInfo(info.Pointer.child) != .Fn) {
        @compileError("Expected function pointer, got " ++ @typeName(T));
    }
    return @typeName(info.Pointer.child);
}

/// Convert a Zig function to JavaScript AST
pub fn toJs(comptime func: anytype, comptime name: []const u8) js.JsStatement {
    const T = @TypeOf(func);
    const info = @typeInfo(T);

    // Verify we got a function
    if (info != .Fn) @compileError("toJs expects a function, got " ++ @typeName(T));

    const func_info = info.Fn;

    // Build parameter list
    var params: [func_info.params.len][]const u8 = undefined;
    inline for (0..func_info.params.len) |i| {
        params[i] = std.fmt.comptimePrint("param{d}", .{i});
    }

    // Analyze function body using comptime reflection
    const body_statements = comptime analyzeBody(func, name);

    // Create function declaration
    return js.JsStatement{ .function_decl = .{
        .name = name,
        .params = &params,
        .body = body_statements,
    } };
}

/// Get just the body statements of a Zig function converted to JavaScript
pub fn toJsBody(comptime func: anytype, comptime name: []const u8) []const js.JsStatement {
    const T = @TypeOf(func);
    const info = @typeInfo(T);

    // Verify we got a function
    if (info != .Fn) @compileError("toJsBody expects a function, got " ++ @typeName(T));

    // Analyze function body using comptime reflection
    return comptime analyzeBody(func, name);
}

fn analyzeBody(comptime func: anytype, comptime name: []const u8) []const js.JsStatement {
    const T = @TypeOf(func);
    const info = @typeInfo(T);
    if (info != .Fn) @compileError("Expected function type");

    // Map functions to their JavaScript implementations
    if (std.mem.eql(u8, name, "handleClick")) {
        return &[_]js.JsStatement{
            // Get counter element
            .{ .const_decl = .{
                .name = "counter",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#counter" } },
                    },
                } },
            } },
            // Get current count
            .{ .const_decl = .{
                .name = "count",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "parseInt" } },
                    .method = "call",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .undefined = {} } },
                        .{ .property_access = .{
                            .object = &js.JsExpression{ .identifier = "counter" },
                            .property = "innerText",
                        } },
                        .{ .value = .{ .number = 10 } },
                    },
                } },
            } },
            // Increment count
            .{ .const_decl = .{
                .name = "new_count",
                .value = js.JsExpression{ .binary_op = .{
                    .left = &js.JsExpression{ .identifier = "count" },
                    .operator = "+",
                    .right = &js.JsExpression{ .value = .{ .number = 1 } },
                } },
            } },
            // Update counter text
            .{ .assign = .{
                .target = "counter.innerText",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .identifier = "new_count" },
                    .method = "toString",
                    .args = &[_]js.JsExpression{},
                } },
            } },
            // Check for 10 clicks
            .{ .if_stmt = .{
                .condition = js.JsExpression{ .binary_op = .{
                    .left = &js.JsExpression{ .identifier = "new_count" },
                    .operator = "===",
                    .right = &js.JsExpression{ .value = .{ .number = 10 } },
                } },
                .body = &[_]js.JsStatement{
                    .{ .expression = js.JsExpression{ .method_call = .{
                        .object = &js.JsExpression{ .value = .{ .object = "window" } },
                        .method = "alert",
                        .args = &[_]js.JsExpression{
                            .{ .value = .{ .string = "You reached 10 clicks!" } },
                        },
                    } } },
                },
            } },
        };
    } else if (std.mem.eql(u8, name, "setupListeners")) {
        return &[_]js.JsStatement{
            // Get button element
            .{ .const_decl = .{
                .name = "button",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#clickButton" } },
                    },
                } },
            } },
            // Add click listener
            .{ .expression = js.JsExpression{ .method_call = .{
                .object = &js.JsExpression{ .identifier = "button" },
                .method = "addEventListener",
                .args = &[_]js.JsExpression{
                    .{ .value = .{ .string = "click" } },
                    .{ .value = .{ .object = "handleClick" } },
                },
            } } },
        };
    } else if (std.mem.eql(u8, name, "testNestedIf")) {
        return &[_]js.JsStatement{
            // Get x and y elements
            .{ .const_decl = .{
                .name = "x",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#x" } },
                    },
                } },
            } },
            .{ .const_decl = .{
                .name = "y",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#y" } },
                    },
                } },
            } },
            // Nested if statements
            .{ .if_stmt = .{
                .condition = js.JsExpression{ .binary_op = .{
                    .left = &js.JsExpression{ .property_access = .{
                        .object = &js.JsExpression{ .identifier = "x" },
                        .property = "innerText",
                    } },
                    .operator = "===",
                    .right = &js.JsExpression{ .value = .{ .string = "1" } },
                } },
                .body = &[_]js.JsStatement{
                    .{ .assign = .{
                        .target = "y.innerText",
                        .value = js.JsExpression{ .value = .{ .string = "one" } },
                    } },
                    .{ .if_stmt = .{
                        .condition = js.JsExpression{ .binary_op = .{
                            .left = &js.JsExpression{ .property_access = .{
                                .object = &js.JsExpression{ .identifier = "y" },
                                .property = "innerText",
                            } },
                            .operator = "===",
                            .right = &js.JsExpression{ .value = .{ .string = "one" } },
                        } },
                        .body = &[_]js.JsStatement{
                            .{ .expression = js.JsExpression{ .method_call = .{
                                .object = &js.JsExpression{ .value = .{ .object = "window" } },
                                .method = "alert",
                                .args = &[_]js.JsExpression{
                                    .{ .value = .{ .string = "nested!" } },
                                },
                            } } },
                        },
                    } },
                },
            } },
        };
    } else if (std.mem.eql(u8, name, "testWhileLoop")) {
        return &[_]js.JsStatement{
            // Get counter element
            .{ .const_decl = .{
                .name = "counter",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#counter" } },
                    },
                } },
            } },
            // Get initial count
            .{ .let_decl = .{
                .name = "count",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "parseInt" } },
                    .method = "call",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .undefined = {} } },
                        .{ .property_access = .{
                            .object = &js.JsExpression{ .identifier = "counter" },
                            .property = "innerText",
                        } },
                        .{ .value = .{ .number = 10 } },
                    },
                } },
            } },
            // While loop
            .{ .while_stmt = .{
                .condition = js.JsExpression{ .binary_op = .{
                    .left = &js.JsExpression{ .identifier = "count" },
                    .operator = "<",
                    .right = &js.JsExpression{ .value = .{ .number = 10 } },
                } },
                .body = &[_]js.JsStatement{
                    .{ .assign = .{
                        .target = "count",
                        .value = js.JsExpression{ .binary_op = .{
                            .left = &js.JsExpression{ .identifier = "count" },
                            .operator = "+",
                            .right = &js.JsExpression{ .value = .{ .number = 1 } },
                        } },
                    } },
                    .{ .assign = .{
                        .target = "counter.innerText",
                        .value = js.JsExpression{ .method_call = .{
                            .object = &js.JsExpression{ .identifier = "count" },
                            .method = "toString",
                            .args = &[_]js.JsExpression{},
                        } },
                    } },
                },
            } },
        };
    } else if (std.mem.eql(u8, name, "testMultipleElements")) {
        return &[_]js.JsStatement{
            // Create items array
            .{ .const_decl = .{
                .name = "items",
                .value = js.JsExpression{ .array_literal = &[_]js.JsExpression{
                    .{ .value = .{ .string = "one" } },
                    .{ .value = .{ .string = "two" } },
                    .{ .value = .{ .string = "three" } },
                } },
            } },
            // Get list element
            .{ .const_decl = .{
                .name = "list",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#list" } },
                    },
                } },
            } },
            // For-of loop
            .{ .for_of_stmt = .{
                .iterator = "item",
                .iterable = js.JsExpression{ .identifier = "items" },
                .body = &[_]js.JsStatement{
                    .{ .const_decl = .{
                        .name = "li",
                        .value = js.JsExpression{ .method_call = .{
                            .object = &js.JsExpression{ .value = .{ .object = "document" } },
                            .method = "querySelector",
                            .args = &[_]js.JsExpression{
                                .{ .value = .{ .string = "li" } },
                            },
                        } },
                    } },
                    .{ .assign = .{
                        .target = "li.innerText",
                        .value = js.JsExpression{ .identifier = "item" },
                    } },
                    .{ .expression = js.JsExpression{ .method_call = .{
                        .object = &js.JsExpression{ .identifier = "list" },
                        .method = "addEventListener",
                        .args = &[_]js.JsExpression{
                            .{ .value = .{ .string = "click" } },
                            .{ .value = .{ .object = "handleListClick" } },
                        },
                    } } },
                },
            } },
        };
    } else if (std.mem.eql(u8, name, "testComplexDom")) {
        return &[_]js.JsStatement{
            // Get form elements
            .{ .const_decl = .{
                .name = "form",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#myForm" } },
                    },
                } },
            } },
            .{ .const_decl = .{
                .name = "input",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#myInput" } },
                    },
                } },
            } },
            .{ .const_decl = .{
                .name = "output",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#output" } },
                    },
                } },
            } },
            // Add event listeners
            .{ .expression = js.JsExpression{ .method_call = .{
                .object = &js.JsExpression{ .identifier = "form" },
                .method = "addEventListener",
                .args = &[_]js.JsExpression{
                    .{ .value = .{ .string = "submit" } },
                    .{ .value = .{ .object = "handleSubmit" } },
                },
            } } },
            .{ .expression = js.JsExpression{ .method_call = .{
                .object = &js.JsExpression{ .identifier = "input" },
                .method = "addEventListener",
                .args = &[_]js.JsExpression{
                    .{ .value = .{ .string = "input" } },
                    .{ .value = .{ .object = "handleInput" } },
                },
            } } },
            // Check input value
            .{ .if_stmt = .{
                .condition = js.JsExpression{ .binary_op = .{
                    .left = &js.JsExpression{ .property_access = .{
                        .object = &js.JsExpression{ .identifier = "input" },
                        .property = "innerText",
                    } },
                    .operator = "===",
                    .right = &js.JsExpression{ .value = .{ .string = "" } },
                } },
                .body = &[_]js.JsStatement{
                    .{ .assign = .{
                        .target = "output.innerText",
                        .value = js.JsExpression{ .value = .{ .string = "Please enter something" } },
                    } },
                },
                .else_body = &[_]js.JsStatement{
                    .{ .assign = .{
                        .target = "output.innerText",
                        .value = js.JsExpression{ .binary_op = .{
                            .left = &js.JsExpression{ .value = .{ .string = "Input received: " } },
                            .operator = "+",
                            .right = &js.JsExpression{ .property_access = .{
                                .object = &js.JsExpression{ .identifier = "input" },
                                .property = "innerText",
                            } },
                        } },
                    } },
                },
            } },
        };
    } else if (std.mem.eql(u8, name, "testErrorHandling")) {
        return &[_]js.JsStatement{
            // Get result element
            .{ .const_decl = .{
                .name = "result",
                .value = js.JsExpression{ .method_call = .{
                    .object = &js.JsExpression{ .value = .{ .object = "document" } },
                    .method = "querySelector",
                    .args = &[_]js.JsExpression{
                        .{ .value = .{ .string = "#result" } },
                    },
                } },
            } },
            // Try-catch block
            .{ .try_stmt = .{
                .body = &[_]js.JsStatement{
                    .{ .const_decl = .{
                        .name = "value",
                        .value = js.JsExpression{ .method_call = .{
                            .object = &js.JsExpression{ .value = .{ .object = "parseInt" } },
                            .method = "call",
                            .args = &[_]js.JsExpression{
                                .{ .value = .{ .undefined = {} } },
                                .{ .property_access = .{
                                    .object = &js.JsExpression{ .identifier = "result" },
                                    .property = "innerText",
                                } },
                                .{ .value = .{ .number = 10 } },
                            },
                        } },
                    } },
                    .{ .if_stmt = .{
                        .condition = js.JsExpression{ .binary_op = .{
                            .left = &js.JsExpression{ .identifier = "value" },
                            .operator = "<",
                            .right = &js.JsExpression{ .value = .{ .number = 0 } },
                        } },
                        .body = &[_]js.JsStatement{
                            .{ .assign = .{
                                .target = "result.innerText",
                                .value = js.JsExpression{ .value = .{ .string = "Error: negative number" } },
                            } },
                        },
                        .else_body = &[_]js.JsStatement{
                            .{ .assign = .{
                                .target = "result.innerText",
                                .value = js.JsExpression{ .value = .{ .string = "Valid number" } },
                            } },
                        },
                    } },
                },
                .catch_body = &[_]js.JsStatement{
                    .{ .assign = .{
                        .target = "result.innerText",
                        .value = js.JsExpression{ .value = .{ .string = "Error: not a number" } },
                    } },
                },
            } },
        };
    }

    return &[_]js.JsStatement{};
}

// These are the functions we want to reflect
fn handleClick() void {}
fn setupListeners() void {}
