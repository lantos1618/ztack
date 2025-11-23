const std = @import("std");

const BUF_SIZE = 512;

/// Simple transpiler that directly generates JavaScript strings from Zig AST
pub fn transpiledFunction(comptime func_name: []const u8) []const u8 {
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
                var output: [4096]u8 = undefined;
                var ctx = Context{ .output = &output, .output_idx = 0 };
                generateFunctionBody(&tree, fn_body_idx, &ctx);
                return ctx.output[0..ctx.output_idx];
            }
        }
    }
    
    return "";
}

const Context = struct {
    output: *[4096]u8,
    output_idx: usize,
};

fn generateFunctionBody(tree: *const std.zig.Ast, block_idx: std.zig.Ast.Node.Index, ctx: *Context) void {
    @setEvalBranchQuota(20000);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    
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
        statementToJs(tree, stmt_idx, ctx);
        if (ctx.output_idx < ctx.output.len) {
            ctx.output[ctx.output_idx] = '\n';
            ctx.output_idx += 1;
        }
    }
}

fn statementToJs(tree: *const std.zig.Ast, node_idx: std.zig.Ast.Node.Index, ctx: *Context) void {
    @setEvalBranchQuota(20000);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    
    const tag = node_tags[node_idx];
    
    switch (tag) {
        .simple_var_decl, .local_var_decl, .global_var_decl => {
            const var_name = tree.tokenSlice(main_tokens[node_idx]);
            var expr_buf: [BUF_SIZE]u8 = undefined;
            const init_expr = expressionToJs(tree, node_data[node_idx].rhs, &expr_buf);
            const result = std.fmt.bufPrint(ctx.output[ctx.output_idx..], "const {s} = {s};", .{var_name, init_expr}) catch return;
            ctx.output_idx += result.len;
        },
        .call, .call_one => {
            const func_expr_idx = node_data[node_idx].lhs;
            const func_name = tree.tokenSlice(main_tokens[func_expr_idx]);
            
            if (std.mem.eql(u8, func_name, "setInnerText")) {
                // Handle setInnerText specially as assignment
                var arg0_buf: [BUF_SIZE]u8 = undefined;
                var arg1_buf: [BUF_SIZE]u8 = undefined;
                
                if (tag == .call) {
                    const args_idx = node_data[node_idx].rhs;
                    if (args_idx != 0) {
                        const args_list = tree.extra_data[node_data[args_idx].lhs..node_data[args_idx].rhs];
                        if (args_list.len >= 2) {
                            const arg0 = expressionToJs(tree, args_list[0], &arg0_buf);
                            const arg1 = expressionToJs(tree, args_list[1], &arg1_buf);
                            const result = std.fmt.bufPrint(ctx.output[ctx.output_idx..], "{s}.innerText = {s};", .{arg0, arg1}) catch return;
                            ctx.output_idx += result.len;
                            return;
                        }
                    }
                }
            }
            
            // Regular call
            var expr_buf: [BUF_SIZE]u8 = undefined;
            const expr = expressionToJs(tree, node_idx, &expr_buf);
            const result = std.fmt.bufPrint(ctx.output[ctx.output_idx..], "{s};", .{expr}) catch return;
            ctx.output_idx += result.len;
        },
        .@"if" => {
            var cond_buf: [BUF_SIZE]u8 = undefined;
            const cond = expressionToJs(tree, node_data[node_idx].lhs, &cond_buf);
            const result = std.fmt.bufPrint(ctx.output[ctx.output_idx..], "if ({s}) {{ }}", .{cond}) catch return;
            ctx.output_idx += result.len;
        },
        else => {},
    }
}

fn expressionToJs(tree: *const std.zig.Ast, node_idx: std.zig.Ast.Node.Index, buf: *[BUF_SIZE]u8) []const u8 {
    @setEvalBranchQuota(20000);
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    
    const tag = node_tags[node_idx];
    
    switch (tag) {
        .identifier => {
            return tree.tokenSlice(main_tokens[node_idx]);
        },
        .number_literal => {
            return tree.tokenSlice(main_tokens[node_idx]);
        },
        .string_literal => {
            return tree.tokenSlice(main_tokens[node_idx]);
        },
        .add => {
            var left_buf: [BUF_SIZE]u8 = undefined;
            var right_buf: [BUF_SIZE]u8 = undefined;
            const left = expressionToJs(tree, node_data[node_idx].lhs, &left_buf);
            const right = expressionToJs(tree, node_data[node_idx].rhs, &right_buf);
            const result = std.fmt.bufPrint(buf, "{s} + {s}", .{left, right}) catch return "";
            return buf[0..result.len];
        },
        .sub => {
            var left_buf: [BUF_SIZE]u8 = undefined;
            var right_buf: [BUF_SIZE]u8 = undefined;
            const left = expressionToJs(tree, node_data[node_idx].lhs, &left_buf);
            const right = expressionToJs(tree, node_data[node_idx].rhs, &right_buf);
            const result = std.fmt.bufPrint(buf, "{s} - {s}", .{left, right}) catch return "";
            return buf[0..result.len];
        },
        .call, .call_one => {
            const func_expr_idx = node_data[node_idx].lhs;
            const func_name = tree.tokenSlice(main_tokens[func_expr_idx]);
            
            // Get arguments
            var arg0_buf: [BUF_SIZE]u8 = undefined;
            var arg1_buf: [BUF_SIZE]u8 = undefined;
            var arg2_buf: [BUF_SIZE]u8 = undefined;
            var arg0: []const u8 = "";
            var arg1: []const u8 = "";
            var arg2: []const u8 = "";
            var arg_count: usize = 0;
            
            if (tag == .call) {
                const args_idx = node_data[node_idx].rhs;
                if (args_idx != 0) {
                    const args_list = tree.extra_data[node_data[args_idx].lhs..node_data[args_idx].rhs];
                    if (args_list.len > 0) {
                        arg0 = expressionToJs(tree, args_list[0], &arg0_buf);
                        arg_count = 1;
                    }
                    if (args_list.len > 1) {
                        arg1 = expressionToJs(tree, args_list[1], &arg1_buf);
                        arg_count = 2;
                    }
                    if (args_list.len > 2) {
                        arg2 = expressionToJs(tree, args_list[2], &arg2_buf);
                        arg_count = 3;
                    }
                }
            } else if (tag == .call_one) {
                if (node_data[node_idx].rhs != 0) {
                    arg0 = expressionToJs(tree, node_data[node_idx].rhs, &arg0_buf);
                    arg_count = 1;
                }
            }
            
            // Map Zig calls to JS calls
            if (std.mem.eql(u8, func_name, "querySelector")) {
                if (arg_count > 0) {
                    const result = std.fmt.bufPrint(buf, "document.querySelector({s})", .{arg0}) catch return "";
                    return buf[0..result.len];
                }
            } else if (std.mem.eql(u8, func_name, "getInnerText")) {
                if (arg_count > 0) {
                    const result = std.fmt.bufPrint(buf, "{s}.innerText", .{arg0}) catch return "";
                    return buf[0..result.len];
                }
            } else if (std.mem.eql(u8, func_name, "parseInt")) {
                if (arg_count > 0) {
                    const result = std.fmt.bufPrint(buf, "parseInt({s})", .{arg0}) catch return "";
                    return buf[0..result.len];
                }
            } else if (std.mem.eql(u8, func_name, "alert")) {
                if (arg_count > 0) {
                    const result = std.fmt.bufPrint(buf, "window.alert({s})", .{arg0}) catch return "";
                    return buf[0..result.len];
                }
            } else if (std.mem.eql(u8, func_name, "addEventListener")) {
                if (arg_count > 2) {
                    const result = std.fmt.bufPrint(buf, "{s}.addEventListener({s}, {s})", .{arg0, arg1, arg2}) catch return "";
                    return buf[0..result.len];
                }
            }
            
            // Generic function call
            if (arg_count > 0) {
                const result = std.fmt.bufPrint(buf, "{s}({s})", .{func_name, arg0}) catch return "";
                return buf[0..result.len];
            }
            
            const result = std.fmt.bufPrint(buf, "{s}()", .{func_name}) catch return "";
            return buf[0..result.len];
        },
        else => return "",
    }
}
