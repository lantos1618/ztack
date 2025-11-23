const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // const zap = b.dependency("zap", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .openssl = false,
    // });

    // Create modules
    // const html_module = b.addModule("html", .{
    //     .root_source_file = b.path("src/modules/html.zig"),
    // });

    // const dom_module = b.addModule("dom", .{
    //     .root_source_file = b.path("src/modules/dom.zig"),
    // });

    const js_module = b.addModule("js", .{
        .root_source_file = b.path("src/modules/js.zig"),
    });

    const transpiler_module = b.addModule("transpiler", .{
        .root_source_file = b.path("src/modules/transpiler.zig"),
    });
    transpiler_module.addImport("js", js_module);

    // Add wasm target
    const wasm_target: std.Target.Query = .{
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
        .root_source_file = b.path("src/examples/js_counter/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add module dependencies
    // exe.root_module.addImport("zap", zap.module("zap"));
    // exe.root_module.addImport("html", html_module);
    // exe.root_module.addImport("dom", dom_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.step.dependOn(&wasm_install.step); // Make sure wasm is built before running server

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Transpiler test
    const transpiler_test = b.addExecutable(.{
        .name = "transpiler_test",
        .root_source_file = b.path("src/tests/transpiler_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    transpiler_test.root_module.addImport("transpiler", transpiler_module);
    transpiler_test.root_module.addImport("js", js_module);

    const run_transpiler_test = b.addRunArtifact(transpiler_test);

    // Test step
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests/test_ast.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_transpiler_test.step);
}
