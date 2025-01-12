const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    });

    // Create modules
    const html_module = b.addModule("html", .{
        .root_source_file = b.path("src/html.zig"),
    });

    const js_gen_module = b.addModule("js_gen", .{
        .root_source_file = b.path("src/js_gen.zig"),
    });

    const js_reflect_module = b.addModule("js_reflect", .{
        .root_source_file = b.path("src/js_reflect.zig"),
    });
    js_reflect_module.addImport("js_gen", js_gen_module);

    const dom_module = b.addModule("dom", .{
        .root_source_file = b.path("src/dom.zig"),
    });
    dom_module.addImport("js_gen", js_gen_module);

    // Add wasm target
    const wasm_target = .{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    };

    // Create wasm module
    const wasm = b.addExecutable(.{
        .name = "wasm_main",
        .root_source_file = b.path("src/routes/wasm_example/wasm_main.zig"),
        .target = b.resolveTargetQuery(wasm_target),
        .optimize = optimize,
    });
    wasm.entry = .disabled;

    // Install wasm file to public folder
    const wasm_install = b.addInstallArtifact(wasm, .{
        .dest_dir = .{ .override = .{ .custom = "public" } },
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "zig_test",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add module dependencies
    exe.root_module.addImport("zap", zap.module("zap"));
    exe.root_module.addImport("html", html_module);
    exe.root_module.addImport("js_gen", js_gen_module);
    exe.root_module.addImport("js_reflect", js_reflect_module);
    exe.root_module.addImport("dom", dom_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.step.dependOn(&wasm_install.step); // Make sure wasm is built before running server

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
