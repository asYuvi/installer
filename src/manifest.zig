const std = @import("std");
const build_options = @import("build_options");

pub const Manifest = struct {
    allocator: std.mem.Allocator,
    version: []const u8,
    raw_json: []const u8,

    pub fn loadEmbedded(allocator: std.mem.Allocator) !Manifest {
        const embedded = build_options.embedded_manifest;
        const json_copy = try allocator.dupe(u8, embedded);

        return Manifest{
            .allocator = allocator,
            .version = "1.0.0",
            .raw_json = json_copy,
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
        };
    }

    pub fn deinit(self: *Manifest) void {
        self.allocator.free(self.raw_json);
    }
};

test "load embedded manifest" {
    const allocator = std.testing.allocator;
    var manifest = try Manifest.loadEmbedded(allocator);
    defer manifest.deinit();

    try std.testing.expect(manifest.raw_json.len > 0);
}
