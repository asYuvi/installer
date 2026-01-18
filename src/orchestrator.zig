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
        std.debug.print("║   asYuvi Installer v2.0.0           ║\n", .{});
        std.debug.print("╚══════════════════════════════════════╝\n\n", .{});

        // 1. 加载 manifest
        std.debug.print("━━━ Step 1/5: Load Configuration ━━━\n", .{});
        self.manifest = try manifest_mod.Manifest.loadEmbedded(self.allocator);
        try self.manifest.?.parse();
        const data = try self.manifest.?.getData();
        std.debug.print("✓ Manifest version: {s}\n", .{data.version});
        std.debug.print("✓ asYuvi version: {s}\n", .{data.asyuvi.version});

        // 2. 创建安装上下文
        std.debug.print("\n━━━ Step 2/5: Initialize Environment ━━━\n", .{});
        var install_ctx = try installer_mod.InstallContext.init(self.allocator, self.platform);
        defer install_ctx.deinit();
        std.debug.print("✓ Platform: {s} {s}\n", .{ @tagName(self.platform.os), @tagName(self.platform.arch) });
        std.debug.print("✓ Temp directory: {s}\n", .{install_ctx.temp_dir});

        var installer = installer_mod.Installer.init(&install_ctx);

        // 3. 安装依赖
        std.debug.print("\n━━━ Step 3/5: Install Dependencies ━━━\n", .{});

        // 3.1 安装 Lima (macOS only)
        if (self.platform.os == .darwin) {
            try installer.installLima("2.0.3");
        }

        // 3.2 安装 Alpine VM
        try installer.installAlpineVM("3.23.2");

        // 4. 安装 asYuvi
        std.debug.print("\n━━━ Step 4/5: Install asYuvi ━━━\n", .{});
        try installer.installAsYuvi(data.asyuvi.version);

        // 5. 启动 VM
        std.debug.print("\n━━━ Step 5/5: Configure and Start ━━━\n", .{});
        try installer.startLimaVM();

        // 完成
        std.debug.print("\n╔══════════════════════════════════════╗\n", .{});
        std.debug.print("║   ✓ Installation Complete!         ║\n", .{});
        std.debug.print("╚══════════════════════════════════════╝\n", .{});
        std.debug.print("\nNext steps:\n", .{});
        if (self.platform.os == .darwin) {
            std.debug.print("  1. Add Lima to PATH: export PATH=\"$HOME/.lima/bin:$PATH\"\n", .{});
            std.debug.print("  2. Start VM: limactl start ~/.asyuvi/vm/asYuvi.yaml\n", .{});
            std.debug.print("  3. Run asYuvi: asyuvi\n", .{});
        } else {
            std.debug.print("  1. Configure Podman\n", .{});
            std.debug.print("  2. Run asYuvi: asyuvi\n", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn runUpgrade(self: *Orchestrator) !void {
        std.debug.print("━━━ Upgrade Feature ━━━\n", .{});
        std.debug.print("Feature under development...\n", .{});
        std.debug.print("\nPlanned features:\n", .{});
        std.debug.print("  • Check remote manifest updates\n", .{});
        std.debug.print("  • Compare version numbers\n", .{});
        std.debug.print("  • Download new version\n", .{});
        std.debug.print("  • Backup old version\n", .{});
        std.debug.print("  • In-place upgrade\n", .{});
        std.debug.print("  • Verify upgrade\n", .{});
        _ = self;
    }

    pub fn runDiagnose(self: *Orchestrator) !void {
        std.debug.print("\n╔══════════════════════════════════════╗\n", .{});
        std.debug.print("║   System Diagnostics                ║\n", .{});
        std.debug.print("╚══════════════════════════════════════╝\n\n", .{});

        // 平台信息
        std.debug.print("━━━ Platform Info ━━━\n", .{});
        std.debug.print("OS: {s}\n", .{@tagName(self.platform.os)});
        std.debug.print("Architecture: {s}\n", .{@tagName(self.platform.arch)});
        std.debug.print("Platform ID: {s}\n", .{self.platform.getIdentifier()});

        // 检查安装
        std.debug.print("\n━━━ Installation Check ━━━\n", .{});
        const home = std.posix.getenv("HOME") orelse {
            std.debug.print("✗ Cannot get HOME environment variable\n", .{});
            return;
        };

        // 检查 Lima
        var lima_exists = false;
        if (self.platform.os == .darwin) {
            const lima_path = try std.fmt.allocPrint(self.allocator, "{s}/.lima/bin/limactl", .{home});
            defer self.allocator.free(lima_path);
            lima_exists = fileExists(lima_path);
            std.debug.print("Lima: {s}\n", .{if (lima_exists) "✓ Installed" else "✗ Not installed"});
        }

        // 检查 VM
        const vm_path = try std.fmt.allocPrint(self.allocator, "{s}/.asyuvi/vm", .{home});
        defer self.allocator.free(vm_path);
        const vm_exists = fileExists(vm_path);
        std.debug.print("Alpine VM: {s}\n", .{if (vm_exists) "✓ Installed" else "✗ Not installed"});

        // 检查 asYuvi
        const asyuvi_path = try std.fmt.allocPrint(self.allocator, "{s}/.asyuvi", .{home});
        defer self.allocator.free(asyuvi_path);
        const asyuvi_exists = fileExists(asyuvi_path);
        std.debug.print("asYuvi: {s}\n", .{if (asyuvi_exists) "✓ Installed" else "✗ Not installed"});

        std.debug.print("\n━━━ Recommendations ━━━\n", .{});
        if (self.platform.os == .darwin and !lima_exists) {
            std.debug.print("• Run 'asyuvi-installer install' to install Lima\n", .{});
        }
        if (!vm_exists) {
            std.debug.print("• Run 'asyuvi-installer install' to install Alpine VM\n", .{});
        }
        if (!asyuvi_exists) {
            std.debug.print("• Run 'asyuvi-installer install' to install asYuvi\n", .{});
        }
        if (lima_exists and vm_exists and asyuvi_exists) {
            std.debug.print("• All components installed, system ready!\n", .{});
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
