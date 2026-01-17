const std = @import("std");
const builtin = @import("builtin");

pub const OS = enum {
    darwin,
    linux,
    windows,
    unknown,
};

pub const Arch = enum {
    arm64,
    x86_64,
    unknown,
};

pub const Platform = struct {
    os: OS,
    arch: Arch,

    pub fn detect() !Platform {
        const os = switch (builtin.os.tag) {
            .macos => OS.darwin,
            .linux => OS.linux,
            .windows => OS.windows,
            else => OS.unknown,
        };

        const arch = switch (builtin.cpu.arch) {
            .aarch64 => Arch.arm64,
            .x86_64 => Arch.x86_64,
            else => Arch.unknown,
        };

        return Platform{
            .os = os,
            .arch = arch,
        };
    }

    pub fn isSupported(self: Platform) bool {
        return self.os != .unknown and self.arch != .unknown;
    }

    pub fn getIdentifier(self: Platform) []const u8 {
        return switch (self.os) {
            .darwin => switch (self.arch) {
                .arm64 => "darwin_arm64",
                .x86_64 => "darwin_x86_64",
                else => "unknown",
            },
            .linux => switch (self.arch) {
                .arm64 => "linux_arm64",
                .x86_64 => "linux_x86_64",
                else => "unknown",
            },
            .windows => "windows_x86_64",
            else => "unknown",
        };
    }
};

test "platform detection" {
    const plat = try Platform.detect();
    try std.testing.expect(plat.isSupported());
}
