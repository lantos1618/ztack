const std = @import("std");

pub fn main() void {
    const source = @embedFile("handlers.zig");
    
    var buffer: [1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    
    var tree = std.zig.Ast.parse(allocator, source, .zig) catch {
        std.debug.print("Parse failed\n", .{});
        return;
    };
    defer tree.deinit(allocator);
    
    const root_decls = tree.rootDecls();
    std.debug.print("Root decls count: {}\n", .{root_decls.len});
    
    const node_tags = tree.nodes.items(.tag);
    const node_data = tree.nodes.items(.data);
    const main_tokens = tree.nodes.items(.main_token);
    
    for (root_decls, 0..) |decl_idx, i| {
        std.debug.print("Decl {}: tag={}\n", .{i, node_tags[decl_idx]});
        
        if (node_tags[decl_idx] == .fn_decl) {
            const fn_proto_idx = node_data[decl_idx].lhs;
            const fn_body_idx = node_data[decl_idx].rhs;
            
            const fn_proto_main_token = main_tokens[fn_proto_idx];
            const fn_proto_tag = node_tags[fn_proto_idx];
            std.debug.print("  fn_proto tag: {}\n", .{fn_proto_tag});
            std.debug.print("  fn_proto_main_token: {}\n", .{fn_proto_main_token});
            
            // Get the function name from the proto's data
            const fn_proto_data = node_data[fn_proto_idx];
            std.debug.print("  fn_proto data: lhs={}, rhs={}\n", .{fn_proto_data.lhs, fn_proto_data.rhs});
            
            // Token after "fn" keyword is the function name
            const tokens = tree.tokens.items(.tag);
            std.debug.print("  Token {}: {}\n", .{fn_proto_main_token, tokens[fn_proto_main_token]});
            std.debug.print("  Token {}: {}\n", .{fn_proto_main_token + 1, tokens[fn_proto_main_token + 1]});
            
            const fn_name_slice = tree.tokenSlice(fn_proto_main_token + 1);
            std.debug.print("  Function: {s}\n", .{fn_name_slice});
            std.debug.print("  Body idx: {}, tag: {}\n", .{fn_body_idx, node_tags[fn_body_idx]});
            
            const body_tag = node_tags[fn_body_idx];
            if (body_tag == .block or body_tag == .block_semicolon) {
                const lhs = node_data[fn_body_idx].lhs;
                const rhs = node_data[fn_body_idx].rhs;
                std.debug.print("    Block range: {} to {}\n", .{lhs, rhs});
                
                if (rhs > lhs) {
                    const block_stmts = tree.extra_data[lhs..rhs];
                    std.debug.print("    Statements: {}\n", .{block_stmts.len});
                    
                    for (block_stmts, 0..) |stmt_idx, j| {
                        std.debug.print("      Stmt {}: tag={}\n", .{j, node_tags[stmt_idx]});
                    }
                }
            } else if (body_tag == .block_two or body_tag == .block_two_semicolon) {
                std.debug.print("    Block two: lhs={}, rhs={}\n", .{node_data[fn_body_idx].lhs, node_data[fn_body_idx].rhs});
            }
        }
    }
}
