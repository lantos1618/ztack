const std = @import("std");

/// Simple comptime Zig parser to extract function bodies
pub const ZigParser = struct {
    source: []const u8,

    pub fn init(comptime source: []const u8) ZigParser {
        return .{ .source = source };
    }

    /// Find a function by name and return its body content as a string
    pub fn getFunctionBody(comptime self: ZigParser, comptime func_name: []const u8) []const u8 {
        const source = self.source;
        
        // Find "fn funcname()" pattern
        const fn_pattern = "fn " ++ func_name ++ "(";
        const fn_start = std.mem.indexOf(u8, source, fn_pattern) orelse return "";
        
        // Move to the opening brace
        var pos = fn_start + fn_pattern.len;
        
        // Skip to closing paren
        while (pos < source.len and source[pos] != ')') : (pos += 1) {}
        pos += 1; // skip )
        
        // Skip whitespace and find opening brace
        while (pos < source.len and (source[pos] == ' ' or source[pos] == '\n' or source[pos] == '\t')) : (pos += 1) {}
        
        if (pos >= source.len or source[pos] != '{') return "";
        
        pos += 1; // skip {
        const body_start = pos;
        
        // Find matching closing brace
        var brace_depth: i32 = 1;
        while (pos < source.len and brace_depth > 0) : (pos += 1) {
            if (source[pos] == '{') {
                brace_depth += 1;
            } else if (source[pos] == '}') {
                brace_depth -= 1;
            }
        }
        
        const body_end = pos - 1; // -1 to exclude the closing brace
        return source[body_start..body_end];
    }

    /// Extract a line of code from function body
    pub fn parseLine(comptime line: []const u8) ParsedLine {
        var trimmed = std.mem.trim(u8, line, " \t\n\r");
        
        // Remove trailing semicolon
        if (std.mem.endsWith(u8, trimmed, ";")) {
            trimmed = trimmed[0 .. trimmed.len - 1];
        }

        // const x = value;
        if (std.mem.startsWith(u8, trimmed, "const ")) {
            return parseConstDecl(trimmed);
        }
        
        // var x = value;
        if (std.mem.startsWith(u8, trimmed, "var ")) {
            return parseVarDecl(trimmed);
        }
        
        // x = value;
        if (std.mem.indexOf(u8, trimmed, " = ")) |_| {
            return parseAssignment(trimmed);
        }

        return .{ .unknown = trimmed };
    }
};

pub const ParsedLine = union(enum) {
    const_decl: struct {
        name: []const u8,
        value: []const u8,
    },
    var_decl: struct {
        name: []const u8,
        value: []const u8,
    },
    assignment: struct {
        target: []const u8,
        value: []const u8,
    },
    unknown: []const u8,
};

fn parseConstDecl(comptime line: []const u8) ParsedLine {
    // "const x = value"
    var rest = line[6..]; // skip "const "
    
    if (std.mem.indexOf(u8, rest, " = ")) |eq_idx| {
        const eq_pos = eq_idx;
        const name = std.mem.trim(u8, rest[0..eq_pos], " \t");
        const value = std.mem.trim(u8, rest[eq_pos + 3 ..], " \t");
        return .{ .const_decl = .{ .name = name, .value = value } };
    }
    
    return .{ .unknown = line };
}

fn parseVarDecl(comptime line: []const u8) ParsedLine {
    // "var x = value"
    var rest = line[4..]; // skip "var "
    
    if (std.mem.indexOf(u8, rest, " = ")) |eq_idx| {
        const eq_pos = eq_idx;
        const name = std.mem.trim(u8, rest[0..eq_pos], " \t");
        const value = std.mem.trim(u8, rest[eq_pos + 3 ..], " \t");
        return .{ .var_decl = .{ .name = name, .value = value } };
    }
    
    return .{ .unknown = line };
}

fn parseAssignment(comptime line: []const u8) ParsedLine {
    if (std.mem.indexOf(u8, line, " = ")) |eq_idx| {
        const eq_pos = eq_idx;
        const target = std.mem.trim(u8, line[0..eq_pos], " \t");
        const value = std.mem.trim(u8, line[eq_pos + 3 ..], " \t");
        return .{ .assignment = .{ .target = target, .value = value } };
    }
    
    return .{ .unknown = line };
}

pub fn splitLines(comptime text: []const u8) [100][]const u8 {
    var lines: [100][]const u8 = undefined;
    var line_count = 0;
    var current_start: usize = 0;

    for (0..text.len) |i| {
        if (text[i] == '\n' or i == text.len - 1) {
            const end = if (i == text.len - 1 and text[i] != '\n') i + 1 else i;
            if (end > current_start) {
                lines[line_count] = text[current_start..end];
                line_count += 1;
            }
            current_start = i + 1;
        }
    }

    // Fill rest with empty strings
    for (line_count..100) |i| {
        lines[i] = "";
    }

    return lines;
}
