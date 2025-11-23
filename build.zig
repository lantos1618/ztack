const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define all modules
    const js_module = b.addModule("js", .{
        .root_source_file = b.path("src/modules/js.zig"),
    });

    const dom_module = b.addModule("dom", .{
        .root_source_file = b.path("src/modules/dom.zig"),
    });
    dom_module.addImport("js", js_module);

    const html_module = b.addModule("html", .{
        .root_source_file = b.path("src/modules/html.zig"),
    });

    const transpiler_module = b.addModule("transpiler", .{
        .root_source_file = b.path("src/modules/transpiler.zig"),
    });
    transpiler_module.addImport("js", js_module);

    // Demo transpiler executable
    const demo_exe = b.addExecutable(.{
        .name = "demo_transpiler",
        .root_source_file = b.path("src/examples/demo_transpiler.zig"),
        .target = target,
        .optimize = optimize,
    });
    demo_exe.root_module.addImport("js", js_module);
    demo_exe.root_module.addImport("transpiler", transpiler_module);
    b.installArtifact(demo_exe);

    const run_demo = b.addRunArtifact(demo_exe);
    const demo_step = b.step("demo", "Run the transpiler demo");
    demo_step.dependOn(&run_demo.step);

    // Simple server executable (Counter App)
    const server_exe = b.addExecutable(.{
        .name = "js_counter",
        .root_source_file = b.path("src/examples/simple_server.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_exe.root_module.addImport("html", html_module);
    server_exe.root_module.addImport("js", js_module);
    server_exe.root_module.addImport("transpiler", transpiler_module);
    b.installArtifact(server_exe);

    // WASM counter server executable
    const wasm_server_exe = b.addExecutable(.{
        .name = "wasm_counter",
        .root_source_file = b.path("src/examples/wasm_simple_server.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(wasm_server_exe);

    // Main run step
    const run_cmd = b.addRunArtifact(server_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the JS counter server");
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

    // Main test executable
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/tests/test_ast.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_transpiler_test.step);

    // WASM counter test
    const run_wasm_counter = b.addRunArtifact(wasm_server_exe);
    const test_wasm_step = b.step("test-wasm", "Run WASM counter server");
    test_wasm_step.dependOn(&run_wasm_counter.step);
}
