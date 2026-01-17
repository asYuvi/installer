const std = @import("std");
const platform = @import("platform.zig");
const network = @import("network.zig");
const manifest = @import("manifest.zig");
const archive = @import("utils/archive.zig");

pub const InstallContext = struct {
    allocator: std.mem.Allocator,
    platform: platform.Platform,
    downloader: network.Downloader,
    temp_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, plat: platform.Platform) !InstallContext {
        const temp_dir = try std.fmt.allocPrint(allocator, "/tmp/asyuvi-installer-{d}", .{std.time.timestamp()});
        try archive.ensureDir(temp_dir);

        return InstallContext{
            .allocator = allocator,
            .platform = plat,
            .downloader = network.Downloader.init(allocator),
            .temp_dir = temp_dir,
        };
    }

    pub fn deinit(self: *InstallContext) void {
        archive.remove(self.temp_dir) catch {};
        self.allocator.free(self.temp_dir);
    }
};

pub const Installer = struct {
    ctx: *InstallContext,

    pub fn init(ctx: *InstallContext) Installer {
        return .{ .ctx = ctx };
    }

    /// 安装 Lima（仅 macOS）
    pub fn installLima(self: *Installer, version: []const u8) !void {
        if (self.ctx.platform.os != .darwin) {
            std.debug.print("跳过 Lima 安装（仅 macOS 需要）\n", .{});
            return;
        }

        std.debug.print("\n=== 安装 Lima v{s} ===\n", .{version});

        // 检查是否已安装
        if (self.checkLimaInstalled()) {
            std.debug.print("Lima 已安装，跳过\n", .{});
            return;
        }

        // 构建下载 URL
        const platform_id = self.ctx.platform.getIdentifier();
        const url = try std.fmt.allocPrint(
            self.ctx.allocator,
            "https://github.com/lima-vm/lima/releases/download/v{s}/lima-{s}-Darwin-{s}.tar.gz",
            .{ version, version, if (self.ctx.platform.arch == .arm64) "arm64" else "x86_64" },
        );
        defer self.ctx.allocator.free(url);

        const archive_path = try std.fmt.allocPrint(
            self.ctx.allocator,
            "{s}/lima.tar.gz",
            .{self.ctx.temp_dir},
        );
        defer self.ctx.allocator.free(archive_path);

        // 下载
        try self.ctx.downloader.download(.{
            .url = url,
            .dest_path = archive_path,
            .show_progress = true,
        });

        // 解压到 ~/.lima
        const home = std.posix.getenv("HOME") orelse return error.HomeNotSet;
        const lima_dir = try std.fmt.allocPrint(self.ctx.allocator, "{s}/.lima", .{home});
        defer self.ctx.allocator.free(lima_dir);

        try archive.extractTarGz(self.ctx.allocator, archive_path, lima_dir);

        // 添加到 PATH（提示用户）
        std.debug.print("\n✓ Lima 安装完成！\n", .{});
        std.debug.print("请将以下路径添加到 PATH:\n", .{});
        std.debug.print("  export PATH=\"{s}/bin:$PATH\"\n", .{lima_dir});

        _ = platform_id;
    }

    /// 安装 Alpine VM
    pub fn installAlpineVM(self: *Installer, version: []const u8) !void {
        std.debug.print("\n=== 安装 Alpine VM v{s} ===\n", .{version});

        // 构建下载 URL（使用中国镜像）
        const arch_str = if (self.ctx.platform.arch == .arm64) "arm64" else "x86_64";
        const url = try std.fmt.allocPrint(
            self.ctx.allocator,
            "https://mirrors.tuna.tsinghua.edu.cn/asyuvi/releases/v0.12.1/asyuvi-alpine-{s}-0.12.0-minimal-20260117.tar.gz",
            .{arch_str},
        );
        defer self.ctx.allocator.free(url);

        const archive_path = try std.fmt.allocPrint(
            self.ctx.allocator,
            "{s}/alpine-vm.tar.gz",
            .{self.ctx.temp_dir},
        );
        defer self.ctx.allocator.free(archive_path);

        // 下载
        std.debug.print("下载 Alpine VM 镜像...\n", .{});
        try self.ctx.downloader.download(.{
            .url = url,
            .dest_path = archive_path,
            .show_progress = true,
        });

        // 解压到 ~/.asyuvi/vm
        const home = std.posix.getenv("HOME") orelse return error.HomeNotSet;
        const vm_dir = try std.fmt.allocPrint(self.ctx.allocator, "{s}/.asyuvi/vm", .{home});
        defer self.ctx.allocator.free(vm_dir);

        try archive.extractTarGz(self.ctx.allocator, archive_path, vm_dir);

        std.debug.print("✓ Alpine VM 安装完成\n", .{});
    }

    /// 安装 asYuvi
    pub fn installAsYuvi(self: *Installer, version: []const u8) !void {
        std.debug.print("\n=== 安装 asYuvi v{s} ===\n", .{version});

        // 构建下载 URL
        const platform_id = self.ctx.platform.getIdentifier();
        const url = try std.fmt.allocPrint(
            self.ctx.allocator,
            "https://github.com/xbits/asYuvi/releases/download/v{s}/asYuvi-{s}-{s}.tar.gz",
            .{ version, version, platform_id },
        );
        defer self.ctx.allocator.free(url);

        const archive_path = try std.fmt.allocPrint(
            self.ctx.allocator,
            "{s}/asyuvi.tar.gz",
            .{self.ctx.temp_dir},
        );
        defer self.ctx.allocator.free(archive_path);

        // 下载
        std.debug.print("下载 asYuvi...\n", .{});
        std.debug.print("注意: 这是模拟下载，实际 URL 可能需要调整\n", .{});

        // TODO: 实际下载（现在跳过因为 URL 可能不存在）
        std.debug.print("跳过下载（演示模式）\n", .{});

        // 以下代码在实际下载成功后执行
        // const home = std.posix.getenv("HOME") orelse return error.HomeNotSet;
        // const asyuvi_dir = try std.fmt.allocPrint(self.ctx.allocator, "{s}/.asyuvi", .{home});
        // defer self.ctx.allocator.free(asyuvi_dir);
        // try archive.extractTarGz(self.ctx.allocator, archive_path, asyuvi_dir);
        // std.debug.print("✓ asYuvi 安装完成\n", .{});
    }

    /// 创建和启动 Lima VM
    pub fn startLimaVM(self: *Installer) !void {
        if (self.ctx.platform.os != .darwin) {
            return;
        }

        std.debug.print("\n=== 启动 Lima VM ===\n", .{});

        const home = std.posix.getenv("HOME") orelse return error.HomeNotSet;
        const limactl = try std.fmt.allocPrint(self.ctx.allocator, "{s}/.lima/bin/limactl", .{home});
        defer self.ctx.allocator.free(limactl);

        // 检查 limactl 是否存在
        if (!archive.fileExists(limactl)) {
            std.debug.print("错误: limactl 未找到，请先安装 Lima\n", .{});
            return error.LimaNotInstalled;
        }

        // 检查 VM 是否已存在
        const check_result = std.process.Child.run(.{
            .allocator = self.ctx.allocator,
            .argv = &[_][]const u8{ limactl, "list", "-q" },
        }) catch {
            std.debug.print("无法检查 Lima VM 状态\n", .{});
            return;
        };
        defer self.ctx.allocator.free(check_result.stdout);
        defer self.ctx.allocator.free(check_result.stderr);

        if (std.mem.indexOf(u8, check_result.stdout, "asYuvi") != null) {
            std.debug.print("asYuvi VM 已存在\n", .{});
            return;
        }

        std.debug.print("提示: 需要手动创建和启动 Lima VM\n", .{});
        std.debug.print("运行: limactl start ~/.asyuvi/vm/asYuvi.yaml\n", .{});
    }

    fn checkLimaInstalled(self: *Installer) bool {
        const home = std.posix.getenv("HOME") orelse return false;
        const limactl_path = std.fmt.allocPrint(
            self.ctx.allocator,
            "{s}/.lima/bin/limactl",
            .{home},
        ) catch return false;
        defer self.ctx.allocator.free(limactl_path);

        return archive.fileExists(limactl_path);
    }
};
