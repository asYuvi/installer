const std = @import("std");

pub const DownloadOptions = struct {
    url: []const u8,
    dest_path: []const u8,
    expected_sha256: ?[]const u8 = null,
    show_progress: bool = true,
};

pub const DownloadProgress = struct {
    downloaded: u64,
    total: u64,

    pub fn percentage(self: DownloadProgress) f64 {
        if (self.total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.downloaded)) / @as(f64, @floatFromInt(self.total)) * 100.0;
    }
};

pub const Downloader = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Downloader {
        return .{ .allocator = allocator };
    }

    /// 下载文件（使用 curl 简化实现）
    pub fn download(self: *Downloader, options: DownloadOptions) !void {
        std.debug.print("开始下载: {s}\n", .{options.url});
        std.debug.print("目标路径: {s}\n", .{options.dest_path});

        // 创建目标目录
        const dest_dir = std.fs.path.dirname(options.dest_path) orelse ".";
        try std.fs.cwd().makePath(dest_dir);

        // 使用 curl 下载
        const result = try std.process.Child.run(.{
            .allocator = self.allocator,
            .argv = &[_][]const u8{
                "curl",
                "-L", // 跟随重定向
                "-o",
                options.dest_path,
                if (options.show_progress) "-#" else "-s",
                options.url,
            },
        });
        defer self.allocator.free(result.stdout);
        defer self.allocator.free(result.stderr);

        if (result.term.Exited != 0) {
            std.debug.print("下载失败: {s}\n", .{result.stderr});
            return error.DownloadFailed;
        }

        std.debug.print("✓ 下载完成\n", .{});

        // 验证 SHA256
        if (options.expected_sha256) |expected| {
            try self.verifySha256(options.dest_path, expected);
        }
    }

    /// 计算文件的 SHA256
    pub fn calculateSha256(self: *Downloader, file_path: []const u8) ![32]u8 {
        _ = self;
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        var buffer: [8192]u8 = undefined;

        while (true) {
            const bytes_read = try file.read(&buffer);
            if (bytes_read == 0) break;
            hasher.update(buffer[0..bytes_read]);
        }

        var hash: [32]u8 = undefined;
        hasher.final(&hash);
        return hash;
    }

    /// 验证 SHA256
    pub fn verifySha256(self: *Downloader, file_path: []const u8, expected_hex: []const u8) !void {
        std.debug.print("验证 SHA256...\n", .{});

        const actual_hash = try self.calculateSha256(file_path);

        // 将期望的十六进制字符串转换为字节
        if (expected_hex.len != 64) {
            return error.InvalidSha256;
        }

        var expected_hash: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected_hash, expected_hex);

        // 比较哈希
        if (!std.mem.eql(u8, &actual_hash, &expected_hash)) {
            std.debug.print("✗ SHA256 校验失败!\n", .{});
            std.debug.print("期望: {s}\n", .{expected_hex});
            // 将实际哈希转换为十六进制字符串
            var actual_hex_buf: [64]u8 = undefined;
            for (actual_hash, 0..) |b, i| {
                _ = std.fmt.bufPrint(actual_hex_buf[i * 2 .. i * 2 + 2], "{x:0>2}", .{b}) catch unreachable;
            }
            std.debug.print("实际: {s}\n", .{actual_hex_buf});
            return error.Sha256Mismatch;
        }

        std.debug.print("✓ SHA256 校验通过\n", .{});
    }
};

test "download progress calculation" {
    const progress = DownloadProgress{
        .downloaded = 500,
        .total = 1000,
    };
    try std.testing.expectEqual(@as(f64, 50.0), progress.percentage());
}
