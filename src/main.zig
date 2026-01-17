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
        \\asYuvi Installer - 本地化 AI Agent 执行平台安装器
        \\
        \\用法:
        \\  asyuvi-installer <command> [options]
        \\
        \\命令:
        \\  install          执行全新安装
        \\  upgrade          升级现有安装
        \\  diagnose         诊断系统状态
        \\  version-check    检查是否有更新
        \\  --version, -v    显示版本信息
        \\  --help, -h       显示此帮助信息
        \\
        \\示例:
        \\  asyuvi-installer install          # 全新安装 asYuvi
        \\  asyuvi-installer upgrade          # 升级到最新版本
        \\  asyuvi-installer diagnose         # 诊断安装状态
        \\
    , .{});
}

fn runInstall(allocator: std.mem.Allocator) !void {
    std.debug.print("开始安装 asYuvi...\n\n", .{});

    // 检测平台
    const plat = try platform.Platform.detect();
    std.debug.print("检测到平台: {s} {s}\n", .{ @tagName(plat.os), @tagName(plat.arch) });

    if (!plat.isSupported()) {
        std.debug.print("错误: 不支持的平台\n", .{});
        std.process.exit(1);
    }

    // 创建并运行编排器
    var orch = try orchestrator.Orchestrator.init(allocator, plat);
    defer orch.deinit();

    try orch.runInstall();
}

fn runUpgrade(allocator: std.mem.Allocator) !void {
    std.debug.print("检查更新...\n\n", .{});

    const plat = try platform.Platform.detect();
    var orch = try orchestrator.Orchestrator.init(allocator, plat);
    defer orch.deinit();

    try orch.runUpgrade();
}

fn runDiagnose(allocator: std.mem.Allocator) !void {
    std.debug.print("诊断系统状态...\n\n", .{});

    const plat = try platform.Platform.detect();
    var orch = try orchestrator.Orchestrator.init(allocator, plat);
    defer orch.deinit();

    try orch.runDiagnose();
}

fn runVersionCheck(allocator: std.mem.Allocator) !void {
    std.debug.print("检查版本更新...\n\n", .{});

    const plat = try platform.Platform.detect();
    var orch = try orchestrator.Orchestrator.init(allocator, plat);
    defer orch.deinit();

    const update_info = try orch.checkForUpdates();
    if (update_info.has_update) {
        std.debug.print("发现新版本: {s} (当前: {s})\n", .{ update_info.latest_version, update_info.current_version });
    } else {
        std.debug.print("已是最新版本\n", .{});
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
