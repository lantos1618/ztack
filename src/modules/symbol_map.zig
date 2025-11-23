const std = @import("std");
const js = @import("js");

/// Symbol mapping table for Zig to JavaScript equivalents
pub const SymbolMap = struct {
    allocator: std.mem.Allocator,
    mappings: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) SymbolMap {
        var mappings = std.StringHashMap([]const u8).init(allocator);
        
        // Global object mappings
        mappings.put("dom", "document") catch unreachable;
        mappings.put("window", "window") catch unreachable;
        mappings.put("console", "console") catch unreachable;
        
        return .{
            .allocator = allocator,
            .mappings = mappings,
        };
    }

    pub fn deinit(self: *SymbolMap) void {
        self.mappings.deinit();
    }

    pub fn get(self: SymbolMap, key: []const u8) ?[]const u8 {
        return self.mappings.get(key);
    }

    pub fn set(self: *SymbolMap, key: []const u8, value: []const u8) !void {
        try self.mappings.put(key, value);
    }
};

/// Method mappings: (object, method) -> (js_object, js_method)
pub const MethodMapping = struct {
    zig_object: []const u8,
    zig_method: []const u8,
    js_object: []const u8,
    js_method: []const u8,
};

pub const method_mappings = [_]MethodMapping{
    // DOM methods
    .{ .zig_object = "dom", .zig_method = "querySelector", .js_object = "document", .js_method = "querySelector" },
    .{ .zig_object = "dom", .zig_method = "querySelectorAll", .js_object = "document", .js_method = "querySelectorAll" },
    .{ .zig_object = "dom", .zig_method = "getElementById", .js_object = "document", .js_method = "getElementById" },
    .{ .zig_object = "dom", .zig_method = "getElementByClassName", .js_object = "document", .js_method = "getElementsByClassName" },
    .{ .zig_object = "dom", .zig_method = "alert", .js_object = "window", .js_method = "alert" },
    
    // Console methods (std.debug.print -> console.log)
    .{ .zig_object = "std.debug", .zig_method = "print", .js_object = "console", .js_method = "log" },
    .{ .zig_object = "console", .zig_method = "log", .js_object = "console", .js_method = "log" },
};

pub fn findMethodMapping(zig_object: []const u8, zig_method: []const u8) ?MethodMapping {
    for (method_mappings) |mapping| {
        if (std.mem.eql(u8, mapping.zig_object, zig_object) and
            std.mem.eql(u8, mapping.zig_method, zig_method)) {
            return mapping;
        }
    }
    return null;
}

/// Property mappings: (object, property) -> (js_object, js_property)
pub const PropertyMapping = struct {
    zig_object: []const u8,
    zig_property: []const u8,
    js_object: []const u8,
    js_property: []const u8,
};

pub const property_mappings = [_]PropertyMapping{
    // DOM properties
    .{ .zig_object = "dom", .zig_property = "querySelector", .js_object = "document", .js_property = "querySelector" },
    .{ .zig_object = "dom", .zig_property = "getElementById", .js_object = "document", .js_property = "getElementById" },
    .{ .zig_object = "dom", .zig_property = "querySelectorAll", .js_object = "document", .js_property = "querySelectorAll" },
};

pub fn findPropertyMapping(zig_object: []const u8, zig_property: []const u8) ?PropertyMapping {
    for (property_mappings) |mapping| {
        if (std.mem.eql(u8, mapping.zig_object, zig_object) and
            std.mem.eql(u8, mapping.zig_property, zig_property)) {
            return mapping;
        }
    }
    return null;
}
