const std = @import("std");
const builtin = @import("builtin");

// Core modules
const platform = @import("platform.zig");
const orchestrator = @import("orchestrator.zig");

const VERSION = "2.0.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // 解析命令行参数
    if (args.len == 1) {
        try printHelp();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        try printVersion();
    } else if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printHelp();
    } else if (std.mem.eql(u8, command, "install")) {
        try runInstall(allocator);
    } else if (std.mem.eql(u8, command, "upgrade")) {
        try runUpgrade(allocator);
    } else if (std.mem.eql(u8, command, "diagnose")) {
        try runDiagnose(allocator);
    } else if (std.mem.eql(u8, command, "version-check")) {
        try runVersionCheck(allocator);
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printHelp();
        std.process.exit(1);
    }
}

fn printVersion() !void {
    std.debug.print("asYuvi Installer v{s}\n", .{VERSION});
    std.debug.print("Platform: {s}-{s}\n", .{ @tagName(builtin.os.tag), @tagName(builtin.cpu.arch) });
}

fn printHelp() !void {
    std.debug.print(
        \\asYuvi Installer - Local AI Agent Execution Platform Installer
        \\
        \\Usage:
        \\  asyuvi-installer <command> [options]
        \\
        \\Commands:
        \\  install          Perform fresh installation
        \\  upgrade          Upgrade existing installation
        \\  diagnose         Diagnose system status
        \\  version-check    Check for updates
        \\  --version, -v    Show version information
        \\  --help, -h       Show this help message
        \\
        \\Examples:
        \\  asyuvi-installer install          # Fresh install asYuvi
        \\  asyuvi-installer upgrade          # Upgrade to latest version
        \\  asyuvi-installer diagnose         # Diagnose installation status
        \\
    , .{});
}

fn runInstall(allocator: std.mem.Allocator) !void {
    std.debug.print("Starting asYuvi installation...\n\n", .{});

    // 检测平台
    const plat = try platform.Platform.detect();
    std.debug.print("Detected platform: {s} {s}\n", .{ @tagName(plat.os), @tagName(plat.arch) });

    if (!plat.isSupported()) {
        std.debug.print("Error: Unsupported platform\n", .{});
        std.process.exit(1);
    }

    // 创建并运行编排器
    var orch = try orchestrator.Orchestrator.init(allocator, plat);
    defer orch.deinit();

    try orch.runInstall();
}

fn runUpgrade(allocator: std.mem.Allocator) !void {
    std.debug.print("Checking for updates...\n\n", .{});

    const plat = try platform.Platform.detect();
    var orch = try orchestrator.Orchestrator.init(allocator, plat);
    defer orch.deinit();

    try orch.runUpgrade();
}

fn runDiagnose(allocator: std.mem.Allocator) !void {
    std.debug.print("Diagnosing system status...\n\n", .{});

    const plat = try platform.Platform.detect();
    var orch = try orchestrator.Orchestrator.init(allocator, plat);
    defer orch.deinit();

    try orch.runDiagnose();
}

fn runVersionCheck(allocator: std.mem.Allocator) !void {
    std.debug.print("Checking version updates...\n\n", .{});

    const plat = try platform.Platform.detect();
    var orch = try orchestrator.Orchestrator.init(allocator, plat);
    defer orch.deinit();

    const update_info = try orch.checkForUpdates();
    if (update_info.has_update) {
        std.debug.print("New version found: {s} (current: {s})\n", .{ update_info.latest_version, update_info.current_version });
    } else {
        std.debug.print("Already on latest version\n", .{});
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
