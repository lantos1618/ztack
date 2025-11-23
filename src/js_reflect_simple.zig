const std = @import("std");

/// Simple transpiler that directly generates JavaScript strings from Zig AST
/// This avoids the complexity of union types and pointers at comptime
pub fn transpiledFunction(comptime func_name: []const u8) [:0]const u8 {
    const source = @embedFile("handlers.zig");
    
    var buffer: [1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    
    var tree = std.zig.Ast.parse(allocator, source, .zig) catch {
        return "";
    };
    defer tree.deinit(allocator);
    
    const root_decls = tree.rootDecls();
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    
    for (root_decls) |decl_idx| {
        if (node_tags[decl_idx] == .fn_decl) {
            const fn_proto_idx = node_data[decl_idx].lhs;
            const fn_body_idx = node_data[decl_idx].rhs;
            
            const fn_proto_main_token = main_tokens[fn_proto_idx];
            const fn_name_token = fn_proto_main_token + 1;
            const fn_name_slice = tree.tokenSlice(fn_name_token);
            
            if (std.mem.eql(u8, fn_name_slice, func_name)) {
                return statementListToJs(&tree, fn_body_idx);
            }
        }
    }
    
    return "";
}

fn statementListToJs(tree: *const std.zig.Ast, block_idx: std.zig.Ast.Node.Index) [:0]const u8 {
    @setEvalBranchQuota(20000);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    
    var output: [4096]u8 = undefined;
    var out_idx: usize = 0;
    
    const tag = node_tags[block_idx];
    var stmt_indices: [256]std.zig.Ast.Node.Index = undefined;
    var stmt_count: usize = 0;
    
    if (tag == .block or tag == .block_semicolon) {
        const block_stmts = tree.extra_data[node_data[block_idx].lhs..node_data[block_idx].rhs];
        for (block_stmts) |stmt_idx| {
            if (stmt_count >= 256) break;
            stmt_indices[stmt_count] = stmt_idx;
            stmt_count += 1;
        }
    } else if (tag == .block_two or tag == .block_two_semicolon) {
        if (node_data[block_idx].lhs != 0) {
            stmt_indices[stmt_count] = node_data[block_idx].lhs;
            stmt_count += 1;
        }
        if (node_data[block_idx].rhs != 0) {
            stmt_indices[stmt_count] = node_data[block_idx].rhs;
            stmt_count += 1;
        }
    }
    
    for (stmt_indices[0..stmt_count]) |stmt_idx| {
        const js_line = statementToJs(tree, stmt_idx);
        if (js_line.len > 0) {
            if (out_idx + js_line.len + 1 < output.len) {
                @memcpy(output[out_idx..][0..js_line.len], js_line);
                out_idx += js_line.len;
                output[out_idx] = '\n';
                out_idx += 1;
            }
        }
    }
    
    // Null-terminate
    output[out_idx] = 0;
    return output[0..out_idx :0];
}

fn statementToJs(tree: *const std.zig.Ast, node_idx: std.zig.Ast.Node.Index) []const u8 {
    @setEvalBranchQuota(20000);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    
    const tag = node_tags[node_idx];
    var output: [1024]u8 = undefined;
    
    switch (tag) {
        .simple_var_decl, .local_var_decl, .global_var_decl => {
            const var_name = tree.tokenSlice(main_tokens[node_idx]);
            const init_expr = expressionToJs(tree, node_data[node_idx].rhs);
            const len = std.fmt.bufPrint(&output, "const {s} = {s};", .{var_name, init_expr}) catch 0;
            return output[0..len];
        },
        .call, .call_one => {
            const func_expr_idx = node_data[node_idx].lhs;
            const func_name = tree.tokenSlice(main_tokens[func_expr_idx]);
            
            if (std.mem.eql(u8, func_name, "setInnerText")) {
                // Handle setInnerText specially as assignment
                var args: [2][]const u8 = undefined;
                var arg_count: usize = 0;
                
                if (tag == .call) {
                    const args_idx = node_data[node_idx].rhs;
                    if (args_idx != 0) {
                        const args_list = tree.extra_data[node_data[args_idx].lhs..node_data[args_idx].rhs];
                        for (args_list) |arg_idx| {
                            if (arg_count >= 2) break;
                            args[arg_count] = expressionToJs(tree, arg_idx);
                            arg_count += 1;
                        }
                    }
                }
                
                if (arg_count >= 2) {
                    const len = std.fmt.bufPrint(&output, "{s}.innerText = {s};", .{args[0], args[1]}) catch 0;
                    return output[0..len];
                }
            }
            
            // Regular call
            const expr = expressionToJs(tree, node_idx);
            const len = std.fmt.bufPrint(&output, "{s};", .{expr}) catch 0;
            return output[0..len];
        },
        .@"if" => {
            const cond = expressionToJs(tree, node_data[node_idx].lhs);
            const len = std.fmt.bufPrint(&output, "if ({s}) {{ }}", .{cond}) catch 0;
            return output[0..len];
        },
        else => return "",
    }
}

fn expressionToJs(tree: *const std.zig.Ast, node_idx: std.zig.Ast.Node.Index) []const u8 {
    @setEvalBranchQuota(20000);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    
    var output: [512]u8 = undefined;
    const tag = node_tags[node_idx];
    
    switch (tag) {
        .identifier => {
            const name = tree.tokenSlice(main_tokens[node_idx]);
            return name;
        },
        .number_literal => {
            const num_str = tree.tokenSlice(main_tokens[node_idx]);
            return num_str;
        },
        .string_literal => {
            const str = tree.tokenSlice(main_tokens[node_idx]);
            return str;
        },
        .add => {
            const left = expressionToJs(tree, node_data[node_idx].lhs);
            const right = expressionToJs(tree, node_data[node_idx].rhs);
            const len = std.fmt.bufPrint(&output, "{s} + {s}", .{left, right}) catch 0;
            return output[0..len];
        },
        .sub => {
            const left = expressionToJs(tree, node_data[node_idx].lhs);
            const right = expressionToJs(tree, node_data[node_idx].rhs);
            const len = std.fmt.bufPrint(&output, "{s} - {s}", .{left, right}) catch 0;
            return output[0..len];
        },
        .call, .call_one => {
            const func_expr_idx = node_data[node_idx].lhs;
            const func_name = tree.tokenSlice(main_tokens[func_expr_idx]);
            
            // Get arguments
            var args: [4][]const u8 = undefined;
            var arg_count: usize = 0;
            
            if (tag == .call) {
                const args_idx = node_data[node_idx].rhs;
                if (args_idx != 0) {
                    const args_list = tree.extra_data[node_data[args_idx].lhs..node_data[args_idx].rhs];
                    for (args_list) |arg_idx| {
                        if (arg_count >= 4) break;
                        args[arg_count] = expressionToJs(tree, arg_idx);
                        arg_count += 1;
                    }
                }
            } else if (tag == .call_one) {
                if (node_data[node_idx].rhs != 0) {
                    args[0] = expressionToJs(tree, node_data[node_idx].rhs);
                    arg_count = 1;
                }
            }
            
            // Map Zig calls to JS calls
            if (std.mem.eql(u8, func_name, "querySelector")) {
                if (arg_count > 0) {
                    const len = std.fmt.bufPrint(&output, "document.querySelector({s})", .{args[0]}) catch 0;
                    return output[0..len];
                }
            } else if (std.mem.eql(u8, func_name, "getInnerText")) {
                if (arg_count > 0) {
                    const len = std.fmt.bufPrint(&output, "{s}.innerText", .{args[0]}) catch 0;
                    return output[0..len];
                }
            } else if (std.mem.eql(u8, func_name, "parseInt")) {
                if (arg_count > 0) {
                    const len = std.fmt.bufPrint(&output, "parseInt({s})", .{args[0]}) catch 0;
                    return output[0..len];
                }
            } else if (std.mem.eql(u8, func_name, "alert")) {
                if (arg_count > 0) {
                    const len = std.fmt.bufPrint(&output, "window.alert({s})", .{args[0]}) catch 0;
                    return output[0..len];
                }
            } else if (std.mem.eql(u8, func_name, "addEventListener")) {
                if (arg_count > 2) {
                    const len = std.fmt.bufPrint(&output, "{s}.addEventListener({s}, {s})", .{args[0], args[1], args[2]}) catch 0;
                    return output[0..len];
                }
            }
            
            // Generic function call
            if (arg_count > 0) {
                const len = std.fmt.bufPrint(&output, "{s}({s})", .{func_name, args[0]}) catch 0;
                return output[0..len];
            }
            
            const len = std.fmt.bufPrint(&output, "{s}()", .{func_name}) catch 0;
            return output[0..len];
        },
        else => return "",
    }
}
