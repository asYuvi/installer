# asYuvi 安装器实现计划

**版本**: v1.0
**日期**: 2026-01-17
**状态**: Planning

---

## 概述

本文档描述如何从当前的安装方案迁移到新的基于 Zig 的 TUI 安装器架构。

### 当前状况

```
packaging/
├── download-site/           (下载站点，已独立)
├── installer/              (现有安装器，bash+TUI)
│   └── install.sh          (macOS shell 安装脚本)
├── dist/                   (发布脚本)
│   └── build-release.sh
└── vm/                     (VM 镜像构建)
    └── images/
        ├── build-minimal.sh
        ├── build-full.sh
        └── ...
```

### 目标状况

```
packaging/
├── docs/                   (架构文档)
│   ├── installer-architecture.md
│   ├── README.md
│   └── implementation-plan.md (本文档)
│
├── installer/              (新 Zig 安装器)
│   ├── src/
│   │   ├── main.zig
│   │   ├── orchestrator.zig
│   │   └── ...
│   ├── embed/
│   │   └── manifest.json
│   └── build.zig
│
├── manifest/               (执行列表定义)
│   ├── v1.0.0.json
│   └── latest.json
│
└── scripts/                (构建脚本)
    ├── build-installer.sh
    └── release.sh
```

---

## 迁移策略

### Phase 0: 准备 (完成)

- [x] 备份 packaging 目录
- [x] 创建架构设计文档
- [x] 评估现有实现

### Phase 1: 项目初始化 (第 1 周)

#### 1.1 Zig 项目搭建

```bash
# 创建 Zig 项目
cd packaging/installer
zig init-exe

# 创建目录结构
mkdir -p src/{utils}
mkdir -p embed
mkdir -p keys
mkdir -p tests/{unit,integration,e2e}
```

#### 1.2 设置 build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "asyuvi-installer",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // 静态链接
    exe.linkage = .static;
    exe.strip = true;

    // 嵌入 manifest
    exe.addAnonymousModule("manifest", .{
        .source_file = .{ .path = "embed/manifest.json" },
    });

    b.installArtifact(exe);

    // 测试
    const tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
```

#### 1.3 创建初始 Manifest

参考 installer-architecture.md 的 Manifest 结构，创建 `packaging/manifest/v1.0.0.json`。

内容应包括：
- asYuvi 0.12.1 的下载信息
- Lima 2.0.3 的下载信息
- Alpine minimal 镜像信息
- 网络镜像配置

### Phase 2: 核心功能实现 (第 2-3 周)

#### 2.1 平台检测 (src/platform.zig)

```zig
pub const Platform = struct {
    os: OS,
    arch: Arch,

    pub fn detect() !Platform {
        // 实现平台检测
    }

    pub fn isSupported(self: Platform) bool {
        // 检查是否支持
    }
};
```

**任务**:
- [ ] 实现 macOS 检测
- [ ] 实现 Linux 检测
- [ ] 实现 Windows/WSL2 检测
- [ ] 单元测试

#### 2.2 Manifest 管理 (src/manifest.zig)

```zig
pub const ManifestManager = struct {
    pub fn loadEmbedded() !Manifest {
        const data = @embedFile("manifest");
        return std.json.parse(Manifest, data, .{});
    }

    pub fn fetchRemote(url: []const u8) !Manifest {
        // HTTP GET manifest
        // 验证签名
        // 解析 JSON
    }
};
```

**任务**:
- [ ] JSON 解析
- [ ] 嵌入默认 Manifest
- [ ] HTTP 获取远程 Manifest
- [ ] 签名验证 (Ed25519)
- [ ] 单元测试

#### 2.3 下载器 (src/utils/http.zig)

```zig
pub const Downloader = struct {
    pub fn download(
        url: []const u8,
        dest: []const u8,
        sha256: []const u8,
    ) !void {
        // 实现下载
        // 进度回调
        // 校验和验证
    }

    pub fn downloadWithResume(
        url: []const u8,
        dest: []const u8,
    ) !void {
        // 断点续传
    }
};
```

**任务**:
- [ ] HTTP 下载实现
- [ ] 进度回调
- [ ] 断点续传
- [ ] SHA256 校验
- [ ] 单元测试

#### 2.4 安装引擎 (src/installer.zig)

```zig
pub const InstallerEngine = struct {
    pub fn installLima(artifact: Artifact) !void {
        // 下载 Lima
        // 解压到 ~/.lima/bin
        // 验证
    }

    pub fn installAlpineVM(artifact: Artifact) !void {
        // 下载镜像
        // 创建 VM
        // 配置
    }

    pub fn installAsYuvi(artifact: Artifact) !void {
        // 下载 asYuvi
        // 解压到 ~/.asyuvi
        // 配置
    }
};
```

**任务**:
- [ ] Lima 安装
- [ ] VM 创建和配置
- [ ] asYuvi 安装
- [ ] 验证逻辑
- [ ] 集成测试

### Phase 3: CLI 和 TUI (第 4 周)

#### 3.1 命令行参数 (src/main.zig)

```bash
# 使用示例
asyuvi-installer install           # 全新安装
asyuvi-installer upgrade           # 升级
asyuvi-installer diagnose          # 诊断
asyuvi-installer --help            # 帮助
asyuvi-installer --version         # 版本
```

**任务**:
- [ ] 参数解析
- [ ] 子命令支持
- [ ] 帮助信息

#### 3.2 进度显示 (CLI 版本)

```
Downloading dependencies...
[████████████████░░░░] 75% Lima 2.0.3 (15.3/20MB)
```

**任务**:
- [ ] 进度条实现
- [ ] 多任务进度
- [ ] 终端大小适配

#### 3.3 TUI 界面 (src/tui.zig)

使用 vaxis 库实现。

**任务**:
- [ ] 研究 vaxis 用法
- [ ] 实现主界面布局
- [ ] 进度显示
- [ ] 菜单和按钮
- [ ] 错误对话框

### Phase 4: 网络优化 (第 5 周)

#### 4.1 连接性检测 (src/network.zig)

```zig
pub fn detectConnectivity() !ConnectivityInfo {
    // Ping asYuvi API
    // Ping GitHub
    // Ping Alpine mirrors
}
```

**任务**:
- [ ] HTTP 健康检查
- [ ] 超时处理
- [ ] 并发检测

#### 4.2 代理发现

```zig
pub fn detectProxy() ?ProxyConfig {
    // 环境变量
    // macOS 系统设置
    // 配置文件
}
```

**任务**:
- [ ] 环境变量读取
- [ ] macOS scutil 集成
- [ ] 用户配置

#### 4.3 镜像源选择

```zig
pub fn selectMirror(region: Region) !Mirror {
    // 根据地区选择最优镜像
}
```

**任务**:
- [ ] 地区检测
- [ ] 镜像速度测试
- [ ] 回退机制

### Phase 5: 升级和诊断 (第 6 周)

#### 5.1 版本检测

```zig
pub fn checkForUpdates() !UpdateInfo {
    // 读取本地版本
    // 查询远程版本
    // 比较
}
```

**任务**:
- [ ] 本地版本读取
- [ ] 远程版本查询
- [ ] 版本比较逻辑

#### 5.2 升级流程

```zig
pub fn performUpgrade(info: UpdateInfo) !void {
    // 下载新版本
    // 备份旧版本
    // 安装新版本
    // 验证
    // 清理备份
}
```

**任务**:
- [ ] 下载和验证
- [ ] 备份机制
- [ ] 原子替换
- [ ] 回滚支持

#### 5.3 诊断功能

```zig
pub fn diagnose() !DiagnosticReport {
    // 平台检查
    // Lima 检查
    // VM 检查
    // 网络检查
}
```

**任务**:
- [ ] 各项检查实现
- [ ] 报告生成
- [ ] 修复建议

### Phase 6: 跨平台支持 (第 7-8 周)

#### 6.1 macOS 全平台

- [ ] ARM64 (M1/M2/M3) 测试
- [ ] x86_64 (Intel) 测试
- [ ] macOS 13, 14, 15 测试

#### 6.2 Linux 支持

- [ ] Ubuntu/Debian 支持
- [ ] Fedora/CentOS 支持
- [ ] Podman 集成
- [ ] 原生运行模式

#### 6.3 Windows/WSL2 支持

- [ ] WSL2 检测
- [ ] 路径转换
- [ ] Windows Terminal 兼容

### Phase 7: 测试和文档 (第 9 周)

#### 7.1 测试

```
tests/
├── unit/              # 单元测试
│   ├── platform_test.zig
│   ├── manifest_test.zig
│   └── network_test.zig
├── integration/       # 集成测试
│   ├── install_test.zig
│   └── upgrade_test.zig
└── e2e/              # 端到端测试
    ├── fresh_install.sh
    └── upgrade.sh
```

**任务**:
- [ ] 单元测试覆盖率 > 80%
- [ ] 集成测试
- [ ] E2E 测试 (自动化)
- [ ] 性能测试

#### 7.2 文档

- [ ] API 参考文档
- [ ] 开发指南
- [ ] 用户指南
- [ ] 故障排查

### Phase 8: 发布准备 (第 10 周)

#### 8.1 CI/CD

```yaml
# .github/workflows/build.yml
name: Build Installer
on: [push, pull_request]
jobs:
  build:
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest]
        arch: [x86_64, aarch64]
    steps:
      - uses: actions/checkout@v3
      - uses: goto-bus-stop/setup-zig@v2
      - run: zig build -Doptimize=ReleaseSafe
      - run: zig build test
```

**任务**:
- [ ] GitHub Actions 配置
- [ ] 多平台构建
- [ ] 自动测试
- [ ] 发布自动化

#### 8.2 发布脚本

```bash
# packaging/scripts/release.sh
VERSION=$1

# 构建所有平台
build_all_platforms

# 生成 manifest
generate_manifest

# 签名 manifest
sign_manifest

# 上传到 GitHub Releases
upload_to_github

# 部署到 CDN
deploy_to_cdn
```

**任务**:
- [ ] 构建脚本
- [ ] 签名脚本
- [ ] 上传脚本
- [ ] 部署脚本

---

## 里程碑

### M1: MVP (Week 3)

**目标**: 可以在 macOS ARM64 上完成全新安装

**交付**:
- ✅ Zig 项目初始化
- ✅ Manifest 加载
- ✅ 基本下载功能
- ✅ Lima 安装
- ✅ VM 创建
- ✅ asYuvi 安装
- ✅ CLI 进度显示

### M2: 增强 (Week 6)

**目标**: TUI 界面和网络优化

**交付**:
- ✅ TUI 界面
- ✅ 代理检测
- ✅ 镜像源选择
- ✅ 并发下载
- ✅ macOS x86_64 支持

### M3: 完整功能 (Week 8)

**目标**: 升级、诊断、跨平台

**交付**:
- ✅ 升级功能
- ✅ 诊断功能
- ✅ Linux 支持
- ✅ Windows/WSL2 支持

### M4: 发布 (Week 10)

**目标**: 生产就绪

**交付**:
- ✅ 完整测试
- ✅ 完善文档
- ✅ CI/CD
- ✅ 第一个正式版本

---

## 风险和缓解

### 风险 1: Zig 生态不成熟

**影响**: 可能缺少必要的库

**缓解**:
- 优先使用 std 库
- 必要时调用 C 库
- 自己实现简单功能

### 风险 2: 跨平台兼容性

**影响**: 不同平台表现不一致

**缓解**:
- 早期在多平台测试
- 使用 CI 持续测试
- 平台适配层抽象

### 风险 3: 网络环境复杂

**影响**: 下载失败率高

**缓解**:
- 多镜像源
- 断点续传
- 详细的错误信息和建议

### 风险 4: 时间估计不准

**影响**: 延期

**缓解**:
- 分阶段交付
- MVP 优先
- 持续集成和测试

---

## 资源需求

### 人力

- 1 名 Zig 开发者 (全职 10 周)
- 1 名测试工程师 (兼职，第 7-10 周)
- 1 名技术文档工程师 (兼职，第 9-10 周)

### 基础设施

- GitHub Actions (CI/CD)
- CDN 存储 (manifest 和小文件)
- 测试机器 (macOS, Linux, Windows)

### 工具

- Zig 0.12+ 编译器
- vaxis TUI 库
- Git, GitHub
- 测试框架 (Zig 内置)

---

## 下一步行动

### 立即行动 (本周)

1. [ ] 审阅架构文档
2. [ ] 确认技术选型
3. [ ] 准备开发环境
4. [ ] 创建 GitHub 项目看板

### 短期行动 (下周)

1. [ ] 开始 Phase 1 实现
2. [ ] 创建初始 Manifest
3. [ ] 设置 CI/CD
4. [ ] 编写第一个测试

### 中期目标 (1 个月)

1. [ ] 完成 MVP (M1)
2. [ ] 在 macOS 上测试
3. [ ] 收集早期反馈
4. [ ] 调整计划

---

## 参考

- [installer-architecture.md](./installer-architecture.md) - 架构设计
- [Zig Documentation](https://ziglang.org/documentation/master/)
- [vaxis TUI Library](https://github.com/rockorager/vaxis)
- [Lima Documentation](https://lima-vm.io/)

---

**文档版本**: v1.0
**最后更新**: 2026-01-17
**状态**: Active Planning
