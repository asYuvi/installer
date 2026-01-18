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

    /// Download file (using curl for simplicity)
    pub fn download(self: *Downloader, options: DownloadOptions) !void {
        std.debug.print("Downloading: {s}\n", .{options.url});
        std.debug.print("Destination: {s}\n", .{options.dest_path});

        // Create destination directory
        const dest_dir = std.fs.path.dirname(options.dest_path) orelse ".";
        try std.fs.cwd().makePath(dest_dir);

        // Use curl to download
        var child = std.process.Child.init(
            &[_][]const u8{
                "curl",
                "-L", // Follow redirects
                "-o",
                options.dest_path,
                if (options.show_progress) "-#" else "-s",
                options.url,
            },
            self.allocator,
        );

        // Inherit stdio to show progress in real-time
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        const term = try child.spawnAndWait();

        if (term.Exited != 0) {
            std.debug.print("Download failed\n", .{});
            return error.DownloadFailed;
        }

        std.debug.print("✓ Download complete\n", .{});

        // Verify SHA256
        if (options.expected_sha256) |expected| {
            try self.verifySha256(options.dest_path, expected);
        }
    }

    /// Calculate file SHA256
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

    /// Verify SHA256
    pub fn verifySha256(self: *Downloader, file_path: []const u8, expected_hex: []const u8) !void {
        std.debug.print("Verifying SHA256...\n", .{});

        const actual_hash = try self.calculateSha256(file_path);

        // Convert expected hex string to bytes
        if (expected_hex.len != 64) {
            return error.InvalidSha256;
        }

        var expected_hash: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected_hash, expected_hex);

        // Compare hashes
        if (!std.mem.eql(u8, &actual_hash, &expected_hash)) {
            std.debug.print("✗ SHA256 verification failed!\n", .{});
            std.debug.print("Expected: {s}\n", .{expected_hex});
            // Convert actual hash to hex string
            var actual_hex_buf: [64]u8 = undefined;
            for (actual_hash, 0..) |b, i| {
                _ = std.fmt.bufPrint(actual_hex_buf[i * 2 .. i * 2 + 2], "{x:0>2}", .{b}) catch unreachable;
            }
            std.debug.print("Actual: {s}\n", .{actual_hex_buf});
            return error.Sha256Mismatch;
        }

        std.debug.print("✓ SHA256 verified\n", .{});
    }
};

test "download progress calculation" {
    const progress = DownloadProgress{
        .downloaded = 500,
        .total = 1000,
    };
    try std.testing.expectEqual(@as(f64, 50.0), progress.percentage());
}
