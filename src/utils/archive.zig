const std = @import("std");

/// 解压 tar.gz 文件
pub fn extractTarGz(allocator: std.mem.Allocator, archive_path: []const u8, dest_dir: []const u8) !void {
    std.debug.print("Extracting: {s} -> {s}\n", .{ archive_path, dest_dir });

    // 创建目标目录
    try std.fs.cwd().makePath(dest_dir);

    // 使用系统 tar 命令解压（简化实现）
    // TODO: 未来可以使用纯 Zig 实现
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "tar",
            "-xzf",
            archive_path,
            "-C",
            dest_dir,
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        std.debug.print("tar extraction failed: {s}\n", .{result.stderr});
        return error.ExtractFailed;
    }

    std.debug.print("✓ Extraction complete\n", .{});
}

/// 创建目录（递归）
pub fn ensureDir(path: []const u8) !void {
    try std.fs.cwd().makePath(path);
}

/// 删除文件或目录
pub fn remove(path: []const u8) !void {
    std.fs.cwd().deleteTree(path) catch |err| {
        if (err == error.FileNotFound) {
            return;
        }
        return err;
    };
}

/// 检查文件是否存在
pub fn fileExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// 展开环境变量（简化版）
pub fn expandPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, path, "$HOME/")) {
        const home = std.posix.getenv("HOME") orelse return error.HomeNotSet;
        return try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, path[6..] });
    }
    if (std.mem.startsWith(u8, path, "~/")) {
        const home = std.posix.getenv("HOME") orelse return error.HomeNotSet;
        return try std.fmt.allocPrint(allocator, "{s}/{s}", .{ home, path[2..] });
    }
    return try allocator.dupe(u8, path);
}
