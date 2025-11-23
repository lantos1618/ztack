const std = @import("std");
const js = @import("js");

/// Zig Script subset validator
/// Tracks unsupported constructs found during transpilation
pub const ScriptValidator = struct {
    allocator: std.mem.Allocator,
    warnings: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) ScriptValidator {
        return .{
            .allocator = allocator,
            .warnings = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ScriptValidator) void {
        for (self.warnings.items) |warning| {
            self.allocator.free(warning);
        }
        self.warnings.deinit();
    }

    pub fn warn(self: *ScriptValidator, message: []const u8) !void {
        const msg_copy = try self.allocator.dupe(u8, message);
        try self.warnings.append(msg_copy);
    }

    pub fn printWarnings(self: ScriptValidator) void {
        if (self.warnings.items.len == 0) {
            return;
        }
        std.debug.print("\n⚠️  Transpiler Warnings ({} unsupported constructs found):\n", .{self.warnings.items.len});
        for (self.warnings.items) |warning| {
            std.debug.print("  - {s}\n", .{warning});
        }
    }
};

pub const Transpiler = struct {
    allocator: std.mem.Allocator,
    tree: std.zig.Ast,
    source: [:0]const u8,
    validator: ScriptValidator,

    pub fn init(allocator: std.mem.Allocator, source: [:0]const u8) !Transpiler {
        const tree = try std.zig.Ast.parse(allocator, source, .zig);
        return .{
            .allocator = allocator,
            .tree = tree,
            .source = source,
            .validator = ScriptValidator.init(allocator),
        };
    }

    pub fn deinit(self: *Transpiler) void {
        self.tree.deinit(self.allocator);
        self.validator.deinit();
    }

    /// Convert Zig AST to JavaScript statements
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

        // Get function name from prototype
        const fn_proto_main_token = main_tokens[fn_proto_idx];
        const fn_name_token = fn_proto_main_token + 1;
        const fn_name = self.tree.tokenSlice(fn_name_token);

        // Check for function parameters (not yet supported)
        const fn_proto_data = self.tree.nodes.items(.data)[fn_proto_idx];
        const fn_proto_tag = node_tags[fn_proto_idx];
        
        // If this is a function proto with parameters, warn
        if (fn_proto_tag == .fn_proto) {
            const proto_lhs = fn_proto_data.lhs;
            const proto_rhs = fn_proto_data.rhs;
            if (proto_rhs > proto_lhs and proto_lhs != 0) {
                // Has parameters
                const warning = try std.fmt.allocPrint(self.allocator, "Function '{s}' has parameters, which are not yet supported and will be ignored", .{fn_name});
                try self.validator.warn(warning);
                self.allocator.free(warning);
            }
        }

        // Get function body statements
        var body_statements = std.ArrayList(js.JsStatement).init(self.allocator);
        defer body_statements.deinit();

        const body_tag = node_tags[fn_body_idx];
        if (body_tag == .block or body_tag == .block_semicolon) {
            const lhs = node_data[fn_body_idx].lhs;
            const rhs = node_data[fn_body_idx].rhs;

            if (rhs > lhs) {
                const block_stmts = self.tree.extra_data[lhs..rhs];
                for (block_stmts) |stmt_idx| {
                    if (self.transpileStmt(stmt_idx)) |stmt| {
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

    fn transpileStmt(self: *Transpiler, stmt_idx: u32) ?js.JsStatement {
        const node_tags = self.tree.nodes.items(.tag);

        const tag = node_tags[stmt_idx];

        switch (tag) {
            .simple_var_decl => {
                return self.transpileVarDecl(stmt_idx) catch null;
            },
            .assign => {
                return self.transpileAssign(stmt_idx) catch null;
            },
            .if_simple => {
                return self.transpileIf(stmt_idx) catch null;
            },
            else => {
                return null;
            },
        }
    }

    fn transpileVarDecl(self: *Transpiler, decl_idx: u32) !?js.JsStatement {
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

    fn transpileAssign(self: *Transpiler, assign_idx: u32) !?js.JsStatement {
        const node_data = self.tree.nodes.items(.data);
        const lhs_idx = node_data[assign_idx].lhs;
        const rhs_idx = node_data[assign_idx].rhs;

        const lhs = self.transpileExpr(lhs_idx) orelse return null;
        const rhs = self.transpileExpr(rhs_idx) orelse js.JsExpression{ .value = .{ .undefined = {} } };

        // Extract target name from expression
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

    fn transpileIf(self: *Transpiler, if_idx: u32) !?js.JsStatement {
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
                    if (self.transpileStmt(stmt_idx)) |stmt| {
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
        const node_data = self.tree.nodes.items(.data);
        const main_tokens = self.tree.nodes.items(.main_token);
        _ = node_data;

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
                
                // Check if this is a boolean literal (true/false as identifiers)
                if (std.mem.eql(u8, slice, "true")) {
                    return js.JsExpression{ .value = .{ .boolean = true } };
                } else if (std.mem.eql(u8, slice, "false")) {
                    return js.JsExpression{ .value = .{ .boolean = false } };
                }
                
                return js.JsExpression{ .identifier = slice };
            },
            .add => {
                return self.transpileBinaryOp(expr_idx, "+");
            },
            .sub => {
                return self.transpileBinaryOp(expr_idx, "-");
            },
            .mul => {
                return self.transpileBinaryOp(expr_idx, "*");
            },
            .div => {
                return self.transpileBinaryOp(expr_idx, "/");
            },
            .mod => {
                return self.transpileBinaryOp(expr_idx, "%");
            },
            .equal_equal => {
                return self.transpileBinaryOp(expr_idx, "==");
            },
            .bang_equal => {
                return self.transpileBinaryOp(expr_idx, "!=");
            },
            .less_than => {
                return self.transpileBinaryOp(expr_idx, "<");
            },
            .less_or_equal => {
                return self.transpileBinaryOp(expr_idx, "<=");
            },
            .greater_than => {
                return self.transpileBinaryOp(expr_idx, ">");
            },
            .greater_or_equal => {
                return self.transpileBinaryOp(expr_idx, ">=");
            },
            else => {
                const warning = std.fmt.allocPrint(self.allocator, "Unsupported expression tag: {}", .{tag}) catch return null;
                self.validator.warn(warning) catch {
                    self.allocator.free(warning);
                };
                return null;
            },
        }
    }

    fn transpileBinaryOp(self: *Transpiler, expr_idx: u32, op: []const u8) ?js.JsExpression {
        const node_data = self.tree.nodes.items(.data);
        const lhs_idx = node_data[expr_idx].lhs;
        const rhs_idx = node_data[expr_idx].rhs;

        const left = self.transpileExpr(lhs_idx) orelse return null;
        const right = self.transpileExpr(rhs_idx) orelse return null;

        // Allocate storage for binary op pointers
        const left_ptr = self.allocator.create(js.JsExpression) catch return null;
        const right_ptr = self.allocator.create(js.JsExpression) catch return null;
        left_ptr.* = left;
        right_ptr.* = right;

        return js.JsExpression{
            .binary_op = .{
                .left = left_ptr,
                .operator = op,
                .right = right_ptr,
            },
        };
    }
};
