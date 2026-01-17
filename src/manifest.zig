const std = @import("std");
const build_options = @import("build_options");

/// 下载文件的信息
pub const Artifact = struct {
    url: []const u8,
    mirrors: []const []const u8,
    size: u64,
    sha256: []const u8,
    install_path: []const u8,
};

/// 依赖项
pub const Dependency = struct {
    version: []const u8,
    required_on: []const []const u8,
    description: []const u8,
    artifacts: std.json.Value, // 动态解析
};

/// asYuvi 主程序信息
pub const AsYuviInfo = struct {
    version: []const u8,
    release_date: []const u8,
    changelog_url: []const u8,
    artifacts: std.json.Value, // 动态解析
};

/// 安装器版本要求
pub const InstallerInfo = struct {
    min_version: []const u8,
    recommended_version: []const u8,
};

/// 完整的 Manifest 结构
pub const ManifestData = struct {
    version: []const u8,
    schema_version: []const u8,
    created_at: []const u8,
    signature: []const u8,
    installer: InstallerInfo,
    asyuvi: AsYuviInfo,
    dependencies: std.json.Value, // 动态解析

    pub fn getArtifact(self: *const ManifestData, allocator: std.mem.Allocator, platform_id: []const u8, component: []const u8) !?Artifact {
        _ = allocator;
        _ = platform_id;
        _ = component;
        _ = self;
        // TODO: 实现从 JSON Value 中提取 Artifact
        return null;
    }
};

pub const Manifest = struct {
    allocator: std.mem.Allocator,
    version: []const u8,
    raw_json: []const u8,
    parsed: ?std.json.Parsed(ManifestData),

    pub fn loadEmbedded(allocator: std.mem.Allocator) !Manifest {
        const embedded = build_options.embedded_manifest;
        const json_copy = try allocator.dupe(u8, embedded);

        return Manifest{
            .allocator = allocator,
            .version = "1.0.0",
            .raw_json = json_copy,
            .parsed = null,
        };
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Manifest {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB max

        return Manifest{
            .allocator = allocator,
            .version = "unknown",
            .raw_json = content,
            .parsed = null,
        };
    }

    pub fn parse(self: *Manifest) !void {
        self.parsed = try std.json.parseFromSlice(
            ManifestData,
            self.allocator,
            self.raw_json,
            .{ .ignore_unknown_fields = true },
        );
    }

    pub fn getData(self: *Manifest) !*const ManifestData {
        if (self.parsed == null) {
            try self.parse();
        }
        return &self.parsed.?.value;
    }

    pub fn deinit(self: *Manifest) void {
        if (self.parsed) |p| {
            p.deinit();
        }
        self.allocator.free(self.raw_json);
    }
};

test "load embedded manifest" {
    const allocator = std.testing.allocator;
    var manifest = try Manifest.loadEmbedded(allocator);
    defer manifest.deinit();

    try std.testing.expect(manifest.raw_json.len > 0);
}

test "parse manifest" {
    const allocator = std.testing.allocator;
    var manifest = try Manifest.loadEmbedded(allocator);
    defer manifest.deinit();

    try manifest.parse();
    const data = try manifest.getData();
    try std.testing.expect(data.version.len > 0);
}
