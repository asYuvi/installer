const std = @import("std");
const platform = @import("platform.zig");
const manifest_mod = @import("manifest.zig");
const installer_mod = @import("installer.zig");

pub const UpdateInfo = struct {
    has_update: bool,
    current_version: []const u8,
    latest_version: []const u8,
};

pub const Orchestrator = struct {
    allocator: std.mem.Allocator,
    platform: platform.Platform,
    manifest: ?manifest_mod.Manifest,

    pub fn init(allocator: std.mem.Allocator, plat: platform.Platform) !*Orchestrator {
        const self = try allocator.create(Orchestrator);
        self.* = .{
            .allocator = allocator,
            .platform = plat,
            .manifest = null,
        };
        return self;
    }

    pub fn deinit(self: *Orchestrator) void {
        if (self.manifest) |*m| {
            m.deinit();
        }
        self.allocator.destroy(self);
    }

    pub fn runInstall(self: *Orchestrator) !void {
        std.debug.print("\n╔══════════════════════════════════════╗\n", .{});
        std.debug.print("║   asYuvi 安装器 v2.0.0              ║\n", .{});
        std.debug.print("╚══════════════════════════════════════╝\n\n", .{});

        // 1. 加载 manifest
        std.debug.print("━━━ 步骤 1/5: 加载安装配置 ━━━\n", .{});
        self.manifest = try manifest_mod.Manifest.loadEmbedded(self.allocator);
        try self.manifest.?.parse();
        const data = try self.manifest.?.getData();
        std.debug.print("✓ Manifest 版本: {s}\n", .{data.version});
        std.debug.print("✓ asYuvi 版本: {s}\n", .{data.asyuvi.version});

        // 2. 创建安装上下文
        std.debug.print("\n━━━ 步骤 2/5: 初始化安装环境 ━━━\n", .{});
        var install_ctx = try installer_mod.InstallContext.init(self.allocator, self.platform);
        defer install_ctx.deinit();
        std.debug.print("✓ 平台: {s} {s}\n", .{ @tagName(self.platform.os), @tagName(self.platform.arch) });
        std.debug.print("✓ 临时目录: {s}\n", .{install_ctx.temp_dir});

        var installer = installer_mod.Installer.init(&install_ctx);

        // 3. 安装依赖
        std.debug.print("\n━━━ 步骤 3/5: 安装依赖 ━━━\n", .{});

        // 3.1 安装 Lima (macOS only)
        if (self.platform.os == .darwin) {
            try installer.installLima("2.0.3");
        }

        // 3.2 安装 Alpine VM
        try installer.installAlpineVM("3.23.2");

        // 4. 安装 asYuvi
        std.debug.print("\n━━━ 步骤 4/5: 安装 asYuvi ━━━\n", .{});
        try installer.installAsYuvi(data.asyuvi.version);

        // 5. 启动 VM
        std.debug.print("\n━━━ 步骤 5/5: 配置和启动 ━━━\n", .{});
        try installer.startLimaVM();

        // 完成
        std.debug.print("\n╔══════════════════════════════════════╗\n", .{});
        std.debug.print("║   ✓ 安装成功完成！                 ║\n", .{});
        std.debug.print("╚══════════════════════════════════════╝\n", .{});
        std.debug.print("\n后续步骤:\n", .{});
        if (self.platform.os == .darwin) {
            std.debug.print("  1. 添加 Lima 到 PATH: export PATH=\"$HOME/.lima/bin:$PATH\"\n", .{});
            std.debug.print("  2. 启动 VM: limactl start ~/.asyuvi/vm/asYuvi.yaml\n", .{});
            std.debug.print("  3. 运行 asYuvi: asyuvi\n", .{});
        } else {
            std.debug.print("  1. 配置 Podman\n", .{});
            std.debug.print("  2. 运行 asYuvi: asyuvi\n", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn runUpgrade(self: *Orchestrator) !void {
        std.debug.print("━━━ 升级功能 ━━━\n", .{});
        std.debug.print("功能开发中...\n", .{});
        std.debug.print("\n计划功能:\n", .{});
        std.debug.print("  • 检查远程 manifest 更新\n", .{});
        std.debug.print("  • 比较版本号\n", .{});
        std.debug.print("  • 下载新版本\n", .{});
        std.debug.print("  • 备份旧版本\n", .{});
        std.debug.print("  • 原地升级\n", .{});
        std.debug.print("  • 验证升级\n", .{});
        _ = self;
    }

    pub fn runDiagnose(self: *Orchestrator) !void {
        std.debug.print("\n╔══════════════════════════════════════╗\n", .{});
        std.debug.print("║   系统诊断                          ║\n", .{});
        std.debug.print("╚══════════════════════════════════════╝\n\n", .{});

        // 平台信息
        std.debug.print("━━━ 平台信息 ━━━\n", .{});
        std.debug.print("操作系统: {s}\n", .{@tagName(self.platform.os)});
        std.debug.print("架构: {s}\n", .{@tagName(self.platform.arch)});
        std.debug.print("平台标识: {s}\n", .{self.platform.getIdentifier()});

        // 检查安装
        std.debug.print("\n━━━ 安装检查 ━━━\n", .{});
        const home = std.posix.getenv("HOME") orelse {
            std.debug.print("✗ 无法获取 HOME 环境变量\n", .{});
            return;
        };

        // 检查 Lima
        var lima_exists = false;
        if (self.platform.os == .darwin) {
            const lima_path = try std.fmt.allocPrint(self.allocator, "{s}/.lima/bin/limactl", .{home});
            defer self.allocator.free(lima_path);
            lima_exists = fileExists(lima_path);
            std.debug.print("Lima: {s}\n", .{if (lima_exists) "✓ 已安装" else "✗ 未安装"});
        }

        // 检查 VM
        const vm_path = try std.fmt.allocPrint(self.allocator, "{s}/.asyuvi/vm", .{home});
        defer self.allocator.free(vm_path);
        const vm_exists = fileExists(vm_path);
        std.debug.print("Alpine VM: {s}\n", .{if (vm_exists) "✓ 已安装" else "✗ 未安装"});

        // 检查 asYuvi
        const asyuvi_path = try std.fmt.allocPrint(self.allocator, "{s}/.asyuvi", .{home});
        defer self.allocator.free(asyuvi_path);
        const asyuvi_exists = fileExists(asyuvi_path);
        std.debug.print("asYuvi: {s}\n", .{if (asyuvi_exists) "✓ 已安装" else "✗ 未安装"});

        std.debug.print("\n━━━ 建议 ━━━\n", .{});
        if (self.platform.os == .darwin and !lima_exists) {
            std.debug.print("• 运行 'asyuvi-installer install' 安装 Lima\n", .{});
        }
        if (!vm_exists) {
            std.debug.print("• 运行 'asyuvi-installer install' 安装 Alpine VM\n", .{});
        }
        if (!asyuvi_exists) {
            std.debug.print("• 运行 'asyuvi-installer install' 安装 asYuvi\n", .{});
        }
        if (lima_exists and vm_exists and asyuvi_exists) {
            std.debug.print("• 所有组件已安装，系统就绪！\n", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn checkForUpdates(self: *Orchestrator) !UpdateInfo {
        _ = self;
        // TODO: 实现远程版本检查
        return UpdateInfo{
            .has_update = false,
            .current_version = "0.12.1",
            .latest_version = "0.12.1",
        };
    }
};

fn fileExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}
