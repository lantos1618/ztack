const std = @import("std");
const js = @import("js");
const symbol_map = @import("symbol_map");

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
    arena: std.mem.Allocator,
    parent_allocator: std.mem.Allocator,
    tree: std.zig.Ast,
    source: [:0]const u8,
    validator: ScriptValidator,

    pub fn init(parent_allocator: std.mem.Allocator, source: [:0]const u8) !Transpiler {
        const tree = try std.zig.Ast.parse(parent_allocator, source, .zig);
        return .{
            .arena = parent_allocator,
            .parent_allocator = parent_allocator,
            .tree = tree,
            .source = source,
            .validator = ScriptValidator.init(parent_allocator),
        };
    }

    pub fn deinit(self: *Transpiler) void {
        self.tree.deinit(self.parent_allocator);
        self.validator.deinit();
    }

    /// Convert Zig AST to JavaScript statements
    pub fn transpile(self: *Transpiler) ![]const js.JsStatement {
        var statements = std.ArrayList(js.JsStatement).init(self.arena);
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

        // Extract function parameters
        var params = std.ArrayList([]const u8).init(self.arena);
        defer params.deinit();
        
        const fn_proto_data = self.tree.nodes.items(.data)[fn_proto_idx];
        const fn_proto_tag = node_tags[fn_proto_idx];
        
        if (fn_proto_tag == .fn_proto) {
            const proto_lhs = fn_proto_data.lhs;
            const proto_rhs = fn_proto_data.rhs;
            if (proto_rhs > proto_lhs) {
                // Has parameters - extract them
                // Parameters are stored in extra_data between proto_lhs and proto_rhs
                const param_indices = self.tree.extra_data[proto_lhs..proto_rhs];
                for (param_indices) |param_idx| {
                    // Most parameter nodes use identifier tokens directly
                    const param_main_token = main_tokens[param_idx];
                    // The parameter name is usually at param_main_token + 1 (after the type)
                    // But for simple params, we might need to check different positions
                    const param_name = self.tree.tokenSlice(param_main_token);
                    // Skip type tokens, look for identifier
                    if (!std.mem.eql(u8, param_name, "var") and 
                        !std.mem.eql(u8, param_name, "const") and
                        param_name.len > 0) {
                        try params.append(param_name);
                    }
                }
            }
        }

        // Get function body statements
        var body_statements = std.ArrayList(js.JsStatement).init(self.arena);
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
        const params_slice = try params.toOwnedSlice();
        return js.JsStatement{
            .function_decl = .{
                .name = fn_name,
                .params = params_slice,
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
            .for_simple => {
                return self.transpileForSimple(stmt_idx) catch null;
            },
            // TODO: Implement switch statement support
            // .switch => {
            //     return self.transpileSwitch(stmt_idx) catch null;
            // },
            .call_one, .call => {
                // Expression statement (like a function call)
                if (self.transpileExpr(stmt_idx)) |expr| {
                    return js.JsStatement{ .expression = expr };
                }
                return null;
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
        const token_tag = self.tree.tokens.items(.tag)[main_token];
        
        // Determine if const or var
        const is_const = switch (token_tag) {
            .keyword_const => true,
            .keyword_var => false,
            else => false,
        };

        const name_token = main_token + 1;
        const name = self.tree.tokenSlice(name_token);

        const init_idx = node_data[decl_idx].rhs;
        const value = self.transpileExpr(init_idx) orelse js.JsExpression{ .value = .{ .undefined = {} } };

        // Use const_decl for Zig const, let_decl for Zig var
        if (is_const) {
            return js.JsStatement{
                .const_decl = .{
                    .name = name,
                    .value = value,
                },
            };
        } else {
            return js.JsStatement{
                .let_decl = .{
                    .name = name,
                    .value = value,
                },
            };
        }
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

        var body_statements = std.ArrayList(js.JsStatement).init(self.arena);
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

    fn transpileForSimple(self: *Transpiler, for_idx: u32) !?js.JsStatement {
        const node_data = self.tree.nodes.items(.data);
        const node_tags = self.tree.nodes.items(.tag);
        const main_tokens = self.tree.nodes.items(.main_token);

        // for_simple has: lhs = capture (range), rhs = body
        const capture_idx = node_data[for_idx].lhs;
        const body_idx = node_data[for_idx].rhs;

        // Get the iterator variable name
        const capture_main_token = main_tokens[capture_idx];
        const capture_name = self.tree.tokenSlice(capture_main_token);

        // Parse the range (0..10) from the for expression
        // The range is in the AST, we need to extract start and end
        const range_data = self.tree.nodes.items(.data)[capture_idx];
        const range_lhs = range_data.lhs;
        const range_rhs = range_data.rhs;

        const start_expr = self.transpileExpr(range_lhs) orelse js.JsExpression{ .value = .{ .number = 0 } };
        const end_expr = self.transpileExpr(range_rhs) orelse js.JsExpression{ .value = .{ .number = 0 } };

        // Build for body statements
        var body_statements = std.ArrayList(js.JsStatement).init(self.arena);
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

        // Create init statement: let i = start
        const init_stmt = try self.arena.create(js.JsStatement);
        init_stmt.* = .{
            .let_decl = .{
                .name = capture_name,
                .value = start_expr,
            },
        };

        // Create condition: i < end
        const condition_ptr_left = try self.arena.create(js.JsExpression);
        condition_ptr_left.* = .{ .identifier = capture_name };
        const condition_ptr_right = try self.arena.create(js.JsExpression);
        condition_ptr_right.* = end_expr;

        const condition = js.JsExpression{
            .binary_op = .{
                .left = condition_ptr_left,
                .operator = "<",
                .right = condition_ptr_right,
            },
        };

        // Create update: i++
        const update_operand = try self.arena.create(js.JsExpression);
        update_operand.* = .{ .identifier = capture_name };
        const update = js.JsExpression{
            .unary_op = .{
                .operator = "++",
                .operand = update_operand,
                .is_postfix = true,
            },
        };

        return js.JsStatement{
            .for_stmt = .{
                .init = init_stmt,
                .condition = condition,
                .update = update,
                .body = body,
            },
        };
    }

    fn transpileSwitch(self: *Transpiler, switch_idx: u32) !?js.JsStatement {
        const node_data = self.tree.nodes.items(.data);
        const node_tags = self.tree.nodes.items(.tag);
        
        const condition_idx = node_data[switch_idx].lhs;
        const body_idx = node_data[switch_idx].rhs;
        
        const condition = self.transpileExpr(condition_idx) orelse js.JsExpression{ .value = .{ .undefined = {} } };
        
        // Parse switch cases - for now, convert to if-else-if chain
        var body_statements = std.ArrayList(js.JsStatement).init(self.arena);
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
        
        // For now, we'll just return an if statement as a placeholder
        // A full switch statement implementation would be more complex
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

        // Check for unsupported constructs
        switch (tag) {
            .ptr_type => {
                const warning = std.fmt.allocPrint(self.arena, "Pointers are not supported in Zig Script", .{}) catch return null;
                self.validator.warn(warning) catch self.arena.free(warning);
                return null;
            },
            .builtin_call => {
                const warning = std.fmt.allocPrint(self.arena, "Builtin calls are not supported in Zig Script", .{}) catch return null;
                self.validator.warn(warning) catch self.arena.free(warning);
                return null;
            },
            else => {},
        }

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
                // Trim surrounding quotes from Zig token
                const trimmed = if (slice.len >= 2 and slice[0] == '"' and slice[slice.len - 1] == '"')
                    slice[1 .. slice.len - 1]
                else
                    slice;
                return js.JsExpression{ .value = .{ .string = trimmed } };
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
            .call_one, .call => {
                return self.transpileCall(expr_idx);
            },
            else => {
                const warning = std.fmt.allocPrint(self.arena, "Unsupported expression tag: {}", .{tag}) catch return null;
                self.validator.warn(warning) catch {
                    self.arena.free(warning);
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
        const left_ptr = self.arena.create(js.JsExpression) catch return null;
        const right_ptr = self.arena.create(js.JsExpression) catch return null;
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

    fn transpileCall(self: *Transpiler, expr_idx: u32) ?js.JsExpression {
        const node_data = self.tree.nodes.items(.data);
        const node_tags = self.tree.nodes.items(.tag);

        // Get the function being called
        const fn_idx = node_data[expr_idx].lhs;
        var fn_expr = self.transpileExpr(fn_idx) orelse return null;

        // Get argument indices
        var args = std.ArrayList(js.JsExpression).init(self.arena);
        defer args.deinit();

        const tag = node_tags[expr_idx];
        if (tag == .call_one) {
            // Single argument call
            const arg_idx = node_data[expr_idx].rhs;
            if (self.transpileExpr(arg_idx)) |arg| {
                args.append(arg) catch return null;
            }
        } else if (tag == .call) {
            // Multiple arguments - For now, warn and skip
            // (Call parsing requires more complex AST traversal)
            const warning = std.fmt.allocPrint(self.arena, "Multi-argument function calls not yet fully supported", .{}) catch return null;
            self.validator.warn(warning) catch {
                self.arena.free(warning);
            };
        }

        // Apply symbol mapping for dom -> document
        fn_expr = self.mapSymbols(fn_expr);

        const fn_ptr = self.arena.create(js.JsExpression) catch return null;
        fn_ptr.* = fn_expr;

        const args_slice = args.toOwnedSlice() catch return null;

        return js.JsExpression{
            .function_call = .{
                .function = fn_ptr,
                .args = args_slice,
            },
        };
    }

    /// Map Zig symbols to JavaScript equivalents using symbol_map module
    fn mapSymbols(self: *Transpiler, expr: js.JsExpression) js.JsExpression {
        switch (expr) {
            .property_access => |p| {
                if (p.object.* == .identifier) {
                    const obj_name = p.object.*.identifier;
                    if (symbol_map.findPropertyMapping(obj_name, p.property)) |mapping| {
                        const mapped_obj = self.arena.create(js.JsExpression) catch return expr;
                        mapped_obj.* = .{ .value = .{ .object = mapping.js_object } };
                        return .{
                            .property_access = .{
                                .object = mapped_obj,
                                .property = mapping.js_property,
                            },
                        };
                    }
                }
                return expr;
            },
            .method_call => |m| {
                if (m.object.* == .identifier) {
                    const obj_name = m.object.*.identifier;
                    if (symbol_map.findMethodMapping(obj_name, m.method)) |mapping| {
                        const mapped_obj = self.arena.create(js.JsExpression) catch return expr;
                        mapped_obj.* = .{ .value = .{ .object = mapping.js_object } };
                        return .{
                            .method_call = .{
                                .object = mapped_obj,
                                .method = mapping.js_method,
                                .args = m.args,
                            },
                        };
                    }
                }
                return expr;
            },
            .function_call => |f| {
                // Check if calling a mapped property access
                const mapped_fn = self.mapSymbols(f.function.*);
                const fn_ptr = self.arena.create(js.JsExpression) catch return expr;
                fn_ptr.* = mapped_fn;
                return .{
                    .function_call = .{
                        .function = fn_ptr,
                        .args = f.args,
                    },
                };
            },
            else => return expr,
        }
    }
};
