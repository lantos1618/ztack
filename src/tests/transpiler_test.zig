const std = @import("std");
const js = @import("js");

pub const Transpiler = struct {
    allocator: std.mem.Allocator,
    tree: std.zig.Ast,
    source: []const u8,

    pub fn init(allocator: std.mem.Allocator, source: [:0]const u8) !Transpiler {
        const tree = try std.zig.Ast.parse(allocator, source, .zig);
        return .{
            .allocator = allocator,
            .tree = tree,
            .source = source,
        };
    }

    pub fn deinit(self: *Transpiler) void {
        self.tree.deinit(self.allocator);
    }

    pub fn transpile(self: *Transpiler) ![]const js.JsStatement {
        var statements = std.ArrayList(js.JsStatement).init(self.allocator);
        defer statements.deinit();

        const root_decls = self.tree.rootDecls();
        for (root_decls) |decl_idx| {
            if (try self.transpileDecl(decl_idx)) |stmt| {
                try statements.append(stmt);
            }
        }

        return try statements.toOwnedSlice();
    }

    fn transpileDecl(self: *Transpiler, decl_idx: u32) !?js.JsStatement {
        const node_tags = self.tree.nodes.items(.tag);
        const tag = node_tags[decl_idx];

        switch (tag) {
            .fn_decl => {
                return try self.transpileFnDecl(decl_idx);
            },
            else => {
                return null;
            },
        }
    }

    fn transpileFnDecl(self: *Transpiler, decl_idx: u32) !?js.JsStatement {
        const node_data = self.tree.nodes.items(.data);
        const node_tags = self.tree.nodes.items(.tag);
        const main_tokens = self.tree.nodes.items(.main_token);

        const fn_proto_idx = node_data[decl_idx].lhs;
        const fn_body_idx = node_data[decl_idx].rhs;

        const fn_proto_main_token = main_tokens[fn_proto_idx];
        const fn_name_token = fn_proto_main_token + 1;
        const fn_name = self.tree.tokenSlice(fn_name_token);

        var body_statements = std.ArrayList(js.JsStatement).init(self.allocator);
        defer body_statements.deinit();

        const body_tag = node_tags[fn_body_idx];
        if (body_tag == .block or body_tag == .block_semicolon) {
            const lhs = node_data[fn_body_idx].lhs;
            const rhs = node_data[fn_body_idx].rhs;

            if (rhs > lhs) {
                const block_stmts = self.tree.extra_data[lhs..rhs];
                for (block_stmts) |stmt_idx| {
                    if (try self.transpileStmt(stmt_idx)) |stmt| {
                        try body_statements.append(stmt);
                    }
                }
            }
        }

        const body = try body_statements.toOwnedSlice();
        return js.JsStatement{
            .function_decl = .{
                .name = fn_name,
                .params = &[_][]const u8{},
                .body = body,
            },
        };
    }

    fn transpileStmt(self: *Transpiler, stmt_idx: u32) std.mem.Allocator.Error!?js.JsStatement {
        const node_tags = self.tree.nodes.items(.tag);
        const tag = node_tags[stmt_idx];

        switch (tag) {
            .simple_var_decl => {
                return try self.transpileVarDecl(stmt_idx);
            },
            .assign => {
                return try self.transpileAssign(stmt_idx);
            },
            .if_simple => {
                return try self.transpileIf(stmt_idx);
            },
            else => {
                return null;
            },
        }
    }

    fn transpileVarDecl(self: *Transpiler, decl_idx: u32) std.mem.Allocator.Error!?js.JsStatement {
        const node_data = self.tree.nodes.items(.data);
        const main_tokens = self.tree.nodes.items(.main_token);

        const main_token = main_tokens[decl_idx];
        const name_token = main_token + 1;
        const name = self.tree.tokenSlice(name_token);

        const init_idx = node_data[decl_idx].rhs;
        const value = self.transpileExpr(init_idx) orelse js.JsExpression{ .value = .{ .undefined = {} } };

        return js.JsStatement{
            .var_decl = .{
                .name = name,
                .value = value,
            },
        };
    }

    fn transpileAssign(self: *Transpiler, assign_idx: u32) std.mem.Allocator.Error!?js.JsStatement {
        const node_data = self.tree.nodes.items(.data);
        const lhs_idx = node_data[assign_idx].lhs;
        const rhs_idx = node_data[assign_idx].rhs;

        const lhs = self.transpileExpr(lhs_idx) orelse return null;
        const rhs = self.transpileExpr(rhs_idx) orelse js.JsExpression{ .value = .{ .undefined = {} } };

        const target = switch (lhs) {
            .identifier => |id| id,
            else => "unknown",
        };

        return js.JsStatement{
            .assign = .{
                .target = target,
                .value = rhs,
            },
        };
    }

    fn transpileIf(self: *Transpiler, if_idx: u32) std.mem.Allocator.Error!?js.JsStatement {
        const node_data = self.tree.nodes.items(.data);
        const node_tags = self.tree.nodes.items(.tag);

        const condition_idx = node_data[if_idx].lhs;
        const body_idx = node_data[if_idx].rhs;

        const condition = self.transpileExpr(condition_idx) orelse js.JsExpression{ .value = .{ .boolean = false } };

        var body_statements = std.ArrayList(js.JsStatement).init(self.allocator);
        defer body_statements.deinit();

        const body_tag = node_tags[body_idx];
        if (body_tag == .block or body_tag == .block_semicolon) {
            const lhs = node_data[body_idx].lhs;
            const rhs = node_data[body_idx].rhs;

            if (rhs > lhs) {
                const block_stmts = self.tree.extra_data[lhs..rhs];
                for (block_stmts) |stmt_idx| {
                    if (try self.transpileStmt(stmt_idx)) |stmt| {
                        try body_statements.append(stmt);
                    }
                }
            }
        }

        const body = try body_statements.toOwnedSlice();
        return js.JsStatement{
            .if_stmt = .{
                .condition = condition,
                .body = body,
                .else_body = null,
            },
        };
    }

    fn transpileExpr(self: *Transpiler, expr_idx: u32) ?js.JsExpression {
        const node_tags = self.tree.nodes.items(.tag);
        const main_tokens = self.tree.nodes.items(.main_token);

        const tag = node_tags[expr_idx];

        switch (tag) {
            .number_literal => {
                const token = main_tokens[expr_idx];
                const slice = self.tree.tokenSlice(token);
                const num = std.fmt.parseInt(i32, slice, 10) catch 0;
                return js.JsExpression{ .value = .{ .number = num } };
            },
            .string_literal => {
                const token = main_tokens[expr_idx];
                const slice = self.tree.tokenSlice(token);
                return js.JsExpression{ .value = .{ .string = slice } };
            },
            .identifier => {
                const token = main_tokens[expr_idx];
                const slice = self.tree.tokenSlice(token);
                return js.JsExpression{ .identifier = slice };
            },

            else => {
                return null;
            },
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const source = @embedFile("sample_handlers.zig");

    std.debug.print("=== Transpiling Zig to JavaScript ===\n", .{});
    std.debug.print("Source length: {} bytes\n\n", .{source.len});

    var trans = try Transpiler.init(allocator, source);
    defer trans.deinit();

    const statements = try trans.transpile();
    defer allocator.free(statements);

    std.debug.print("Generated {} statements:\n\n", .{statements.len});

    for (statements, 0..) |stmt, i| {
        std.debug.print("Statement {}:\n", .{i});
        std.debug.print("  {s}\n\n", .{stmt.toString()});
    }
}
