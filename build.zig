const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 嵌入 manifest 的选项
    const options = b.addOptions();
    const manifest_path = b.path("embed/manifest.json");
    const manifest_file = b.build_root.handle.openFile(manifest_path.getPath(b), .{}) catch |err| {
        std.debug.print("Warning: Cannot open manifest file: {}\n", .{err});
        options.addOption([]const u8, "embedded_manifest", "{}");
        return;
    };
    defer manifest_file.close();

    const manifest_content = manifest_file.readToEndAlloc(b.allocator, 10 * 1024 * 1024) catch |err| {
        std.debug.print("Warning: Cannot read manifest file: {}\n", .{err});
        options.addOption([]const u8, "embedded_manifest", "{}");
        return;
    };
    options.addOption([]const u8, "embedded_manifest", manifest_content);

    const exe = b.addExecutable(.{
        .name = "asyuvi-installer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // 静态链接（macOS 不支持完全静态链接 libc，后续优化）
    // exe.linkage = .static;

    // Release 模式下去除调试符号
    if (optimize != .Debug) {
        exe.root_module.strip = true;
    }

    // 添加 build options 模块
    exe.root_module.addImport("build_options", options.createModule());

    b.installArtifact(exe);

    // Run step
    const run_step = b.step("run", "Run the installer");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_step.dependOn(&run_cmd.step);

    // Test step
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("build_options", options.createModule());

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
