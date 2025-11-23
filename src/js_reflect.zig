const std = @import("std");
const dom = @import("dom");
const js = @import("js_gen");
const zig_parser = @import("zig_parser");

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
/// This uses std.zig.Ast.parse() to parse the source code at comptime.
pub fn toJsBody(comptime func: anytype, comptime name: []const u8) []const js.JsStatement {
    _ = func;
    // Analyze function body using Zig's AST parser
    return analyzeBodyViaAst(name);
}

fn analyzeBodyViaAst(comptime func_name: []const u8) []const js.JsStatement {
    // Use Zig's built-in AST parser to parse the current file
    const source = @embedFile("routes/index.zig");
    
    var tree = std.zig.Ast.parse(std.heap.page_allocator, source, .zig) catch |err| {
        @compileError("Failed to parse AST: " ++ @errorName(err));
    };
    defer tree.deinit(std.heap.page_allocator);

    // Get root declarations from the AST
    const root_decls = tree.rootDecls();
    
    // Search for the function with the given name
    var fn_body_node: std.zig.Ast.Node.Index = 0;
    var found = false;
    
    for (root_decls) |decl_idx| {
        const node_tags = tree.nodes.items(.tag);
        const node_data = tree.nodes.items(.data);
        
        // Check if this is a function declaration
        if (node_tags[decl_idx] == .fn_decl) {
            // Get the fn_proto (left side of fn_decl)
            const fn_proto_idx = node_data[decl_idx].lhs;
            const fn_body_idx = node_data[decl_idx].rhs;
            
            // Get the function name from the main_token of fn_proto
            const main_tokens = tree.nodes.items(.main_token);
            const fn_proto_main_token = main_tokens[fn_proto_idx];
            // The main_token IS the function name, not 'fn' keyword
            const fn_name_slice = tree.tokenSlice(fn_proto_main_token);
            
            if (std.mem.eql(u8, fn_name_slice, func_name)) {
                fn_body_node = fn_body_idx;
                found = true;
                break;
            }
        }
    }
    
    if (!found) {
        @compileError("Function not found: " ++ func_name);
    }
    
    // Extract statements from the function body block
    return analyzeBlockNode(&tree, fn_body_node);
}

fn buildStatementArray(comptime stmts: anytype) []const js.JsStatement {
    return &stmts;
}

fn analyzeBlockNode(comptime tree: *const std.zig.Ast, comptime block_idx: std.zig.Ast.Node.Index) []const js.JsStatement {
    @setEvalBranchQuota(10000);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    
    const tag = node_tags[block_idx];
    
    if (tag == .block or tag == .block_semicolon) {
        const block_stmts = tree.extra_data[node_data[block_idx].lhs..node_data[block_idx].rhs];
        
        // For blocks, we need to iterate and collect statements
        var statements: [256]js.JsStatement = undefined;
        var stmt_count: usize = 0;
        
        for (block_stmts) |stmt_idx| {
            if (stmt_count >= 256) break;
            if (analyzeStatementNode(tree, stmt_idx)) |stmt| {
                statements[stmt_count] = stmt;
                stmt_count += 1;
            } else |_| {}
        }
        
        // Create an array literal based on count
        switch (stmt_count) {
            0 => return &[_]js.JsStatement{},
            1 => return &[_]js.JsStatement{statements[0]},
            2 => return &[_]js.JsStatement{statements[0], statements[1]},
            3 => return &[_]js.JsStatement{statements[0], statements[1], statements[2]},
            4 => return &[_]js.JsStatement{statements[0], statements[1], statements[2], statements[3]},
            5 => return &[_]js.JsStatement{statements[0], statements[1], statements[2], statements[3], statements[4]},
            6 => return &[_]js.JsStatement{statements[0], statements[1], statements[2], statements[3], statements[4], statements[5]},
            7 => return &[_]js.JsStatement{statements[0], statements[1], statements[2], statements[3], statements[4], statements[5], statements[6]},
            8 => return &[_]js.JsStatement{statements[0], statements[1], statements[2], statements[3], statements[4], statements[5], statements[6], statements[7]},
            9 => return &[_]js.JsStatement{statements[0], statements[1], statements[2], statements[3], statements[4], statements[5], statements[6], statements[7], statements[8]},
            10 => return &[_]js.JsStatement{statements[0], statements[1], statements[2], statements[3], statements[4], statements[5], statements[6], statements[7], statements[8], statements[9]},
            else => {
                // For more than 10 statements, we can extend this
                return &[_]js.JsStatement{};
            }
        }
    } else if (tag == .block_two or tag == .block_two_semicolon) {
        // Block with 0-2 statements
        if (node_data[block_idx].lhs == 0 and node_data[block_idx].rhs == 0) {
            return &[_]js.JsStatement{};
        }
        
        if (node_data[block_idx].rhs == 0) {
            if (analyzeStatementNode(tree, node_data[block_idx].lhs)) |stmt| {
                return &[_]js.JsStatement{stmt};
            }
            return &[_]js.JsStatement{};
        }
        
        if (analyzeStatementNode(tree, node_data[block_idx].lhs)) |stmt1| {
            if (analyzeStatementNode(tree, node_data[block_idx].rhs)) |stmt2| {
                return &[_]js.JsStatement{stmt1, stmt2};
            }
            return &[_]js.JsStatement{stmt1};
        }
        return &[_]js.JsStatement{};
    }
    
    return &[_]js.JsStatement{};
}

fn analyzeStatementNode(comptime tree: *const std.zig.Ast, comptime node_idx: std.zig.Ast.Node.Index) !js.JsStatement {
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    
    const tag = node_tags[node_idx];
    
    return switch (tag) {
        .var_simple, .local_var_decl => blk: {
            // Get variable name from main token
            const var_name = tree.tokenSlice(main_tokens[node_idx]);
            
            // Get the initializer (rhs)
            const init_expr = analyzeExpressionNode(tree, node_data[node_idx].rhs) catch .{ .value = .undefined };
            
            break :blk .{
                .var_decl = .{
                    .name = var_name,
                    .value = init_expr,
                },
            };
        },
        .const_simple, .local_const_decl => blk: {
            // Get const name from main token
            const const_name = tree.tokenSlice(main_tokens[node_idx]);
            
            // Get the initializer (rhs)
            const init_expr = analyzeExpressionNode(tree, node_data[node_idx].rhs) catch .{ .value = .undefined };
            
            break :blk .{
                .const_decl = .{
                    .name = const_name,
                    .value = init_expr,
                },
            };
        },
        .assign => blk: {
            // Assignment: lhs is the target, rhs is the value
            const target = tree.tokenSlice(main_tokens[node_data[node_idx].lhs]);
            const value = analyzeExpressionNode(tree, node_data[node_idx].rhs) catch .{ .value = .undefined };
            
            break :blk .{
                .assign = .{
                    .target = target,
                    .value = value,
                },
            };
        },
        .@"if", .if_simple => blk: {
            const cond = analyzeExpressionNode(tree, node_data[node_idx].lhs) catch .{ .value = .undefined };
            const then_stmt = analyzeBlockNode(tree, node_data[node_idx].rhs);
            
            break :blk .{
                .if_stmt = .{
                    .condition = cond,
                    .body = then_stmt,
                    .else_body = null,
                },
            };
        },
        .@"while", .while_simple => blk: {
            const cond = analyzeExpressionNode(tree, node_data[node_idx].lhs) catch .{ .value = .undefined };
            const body = analyzeBlockNode(tree, node_data[node_idx].rhs);
            
            break :blk .{
                .while_stmt = .{
                    .condition = cond,
                    .body = body,
                },
            };
        },
        .call, .call_one, .async_call, .async_call_one => blk: {
            const expr = analyzeExpressionNode(tree, node_idx) catch .{ .value = .undefined };
            break :blk .{ .expression = expr };
        },
        .@"return" => blk: {
            if (node_data[node_idx].lhs != 0) {
                const return_expr = analyzeExpressionNode(tree, node_data[node_idx].lhs) catch .{ .value = .undefined };
                break :blk .{ .return_stmt = return_expr };
            } else {
                break :blk .{ .return_stmt = null };
            }
        },
        else => .{ .empty = {} },
    };
}

fn getSourceText(comptime tree: *const std.zig.Ast, comptime start_idx: std.zig.Ast.Node.Index, comptime end_idx: std.zig.Ast.Node.Index) []const u8 {
    const main_tokens = tree.nodes.items(.main_token);
    const token_starts = tree.tokens.items(.start);
    
    const start_token = main_tokens[start_idx];
    const end_token = main_tokens[end_idx];
    
    const start_offset = token_starts[start_token];
    const end_slice = tree.tokenSlice(end_token);
    const end_offset = token_starts[end_token] + end_slice.len;
    
    return tree.source[start_offset..end_offset];
}

fn analyzeExpressionNode(comptime tree: *const std.zig.Ast, comptime node_idx: std.zig.Ast.Node.Index) !js.JsExpression {
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    
    const tag = node_tags[node_idx];
    
    return switch (tag) {
        .identifier => .{
            .identifier = tree.tokenSlice(main_tokens[node_idx]),
        },
        .number_literal => blk: {
            const num_str = tree.tokenSlice(main_tokens[node_idx]);
            const num = std.fmt.parseInt(i32, num_str, 10) catch 0;
            break :blk .{ .value = .{ .number = num } };
        },
        .string_literal => blk: {
            const str = tree.tokenSlice(main_tokens[node_idx]);
            // Remove quotes from string literal
            if (str.len >= 2 and str[0] == '"' and str[str.len - 1] == '"') {
                break :blk .{ .value = .{ .string = str[1 .. str.len - 1] } };
            }
            break :blk .{ .value = .{ .string = str } };
        },
        .add, .sub, .mul, .div => blk: {
            const src = getSourceText(tree, node_data[node_idx].lhs, node_data[node_idx].rhs);
            
            // For simplicity, store the whole expression as identifier for now
            break :blk .{
                .identifier = src,
            };
        },
        .call, .call_one => blk: {
            // Get function name from lhs
            const func_name = tree.tokenSlice(main_tokens[node_data[node_idx].lhs]);
            break :blk .{
                .identifier = func_name,
            };
        },
        else => .{ .value = .undefined },
    };
}

fn analyzeBody(comptime func: anytype, comptime name: []const u8) []const js.JsStatement {
    _ = func;
    _ = name;
    
    // Zig's @typeInfo() doesn't provide access to function body AST.
    // Use analyzeBodyViaAst() instead which leverages std.zig.Ast.parse()
    return &[_]js.JsStatement{};
}

fn analyzeExpression(comptime expr: anytype) js.JsExpression {
    const T = @TypeOf(expr);
    return switch (@typeInfo(T)) {
        .Call => |c| switch (c.callee) {
            .dom => |d| switch (d.func) {
                .querySelector => .{
                    .method_call = .{
                        .object = &js.JsExpression{ .identifier = "document" },
                        .method = "querySelector",
                        .args = &[_]js.JsExpression{
                            analyzeExpression(c.args[0]),
                        },
                    },
                },
                .getInnerText => .{
                    .property_access = .{
                        .object = analyzeExpression(c.args[0]),
                        .property = "innerText",
                    },
                },
                .setInnerText => .{
                    .assign = .{
                        .target = analyzeExpression(c.args[0]) ++ ".innerText",
                        .value = analyzeExpression(c.args[1]),
                    },
                },
                .addEventListener => .{
                    .method_call = .{
                        .object = analyzeExpression(c.args[0]),
                        .method = "addEventListener",
                        .args = &[_]js.JsExpression{
                            analyzeExpression(c.args[1]),
                            analyzeExpression(c.args[2]),
                        },
                    },
                },
                .alert => .{
                    .method_call = .{
                        .object = &js.JsExpression{ .identifier = "window" },
                        .method = "alert",
                        .args = &[_]js.JsExpression{
                            analyzeExpression(c.args[0]),
                        },
                    },
                },
                else => .{ .value = .undefined },
            },
            .std => |s| switch (s.func) {
                .parseInt => .{
                    .method_call = .{
                        .object = &js.JsExpression{ .identifier = "parseInt" },
                        .method = "call",
                        .args = &[_]js.JsExpression{
                            .{ .value = .{ .undefined = {} } },
                            analyzeExpression(c.args[0]),
                            .{ .value = .{ .number = 10 } },
                        },
                    },
                },
                else => .{ .value = .undefined },
            },
            else => .{ .value = .undefined },
        },
        .Identifier => .{
            .identifier = expr,
        },
        .StringLiteral => .{
            .value = .{ .string = expr },
        },
        .NumberLiteral => .{
            .value = .{ .number = expr },
        },
        .BinaryOp => .{
            .binary_op = .{
                .left = analyzeExpression(expr.left),
                .operator = expr.operator,
                .right = analyzeExpression(expr.right),
            },
        },
        else => .{
            .value = .undefined,
        },
    };
}

fn analyzeStatements(comptime stmts: anytype) []const js.JsStatement {
    const T = @TypeOf(stmts);
    if (@typeInfo(T) != .Array) @compileError("Expected array type");

    var result: [stmts.len]js.JsStatement = undefined;
    inline for (stmts, 0..) |stmt, i| {
        result[i] = switch (stmt) {
            .declaration => |decl| .{
                .const_decl = .{
                    .name = decl.name,
                    .value = analyzeExpression(decl.value),
                },
            },
            .assignment => |assign| .{
                .assign = .{
                    .target = assign.target,
                    .value = analyzeExpression(assign.value),
                },
            },
            .call => |call| .{
                .expression = analyzeExpression(call),
            },
            else => continue,
        };
    }
    return &result;
}
