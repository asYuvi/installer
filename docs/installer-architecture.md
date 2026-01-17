# asYuvi 安装器架构设计

**版本**: v2.0
**日期**: 2026-01-17
**语言**: Zig
**类型**: TUI (Terminal User Interface)

---

## 目录

1. [概述](#概述)
2. [设计目标](#设计目标)
3. [系统架构](#系统架构)
4. [核心组件](#核心组件)
5. [执行列表 (Manifest)](#执行列表-manifest)
6. [API 设计](#api-设计)
7. [执行流程](#执行流程)
8. [网络策略](#网络策略)
9. [升级策略](#升级策略)
10. [数据结构](#数据结构)
11. [错误处理](#错误处理)
12. [技术选型](#技术选型)
13. [文件结构](#文件结构)
14. [实现路线图](#实现路线图)

---

## 概述

asYuvi 安装器是一个轻量级、独立的 TUI 程序，负责：
- 检查 asYuvi 和组件更新
- 下载和安装 asYuvi 及其依赖（Lima、Alpine 镜像）
- 配置运行环境（VM、网络代理、软件源）
- 启动和诊断 asYuvi 主程序

### 核心理念

**轻量化分发**:
- 在 asYuvi.com 上只托管小的安装器 (<5MB) 和执行列表 (<100KB)
- 利用第三方存储（GitHub Releases, CDN, Alpine Mirrors）下载大文件
- 减少自有服务器带宽和存储成本

**灵活性**:
- 执行列表可在线更新，无需重新发布安装器
- 支持多种下载源（GitHub, CDN, 镜像站）
- 支持网络代理和国内镜像源

---

## 设计目标

### 功能目标

1. **自举安装** - 一个命令完成所有安装
2. **版本管理** - 检测、提示、升级已安装的组件
3. **网络适应** - 自动检测和配置网络环境（代理、镜像源）
4. **诊断能力** - 检测和修复常见安装问题
5. **用户友好** - 清晰的 TUI 界面和进度提示

### 技术目标

1. **体积小** - 编译后 < 5MB
2. **零依赖** - 静态链接，无需外部依赖
3. **跨平台** - macOS (ARM64, x86_64), Linux (x86_64, ARM64), Windows (WSL2)
4. **可维护** - 清晰的代码结构，易于扩展

### 性能目标

1. **启动快** - < 100ms 启动时间
2. **下载快** - 并发下载，断点续传
3. **安装快** - 并行安装步骤

---

## 系统架构

### 高层架构

```
┌─────────────────────────────────────────────────────────────┐
│                    asYuvi Installer (Zig)                   │
│                         (~5MB binary)                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   TUI Layer  │  │  CLI Parser  │  │  Diagnostics │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │             │
│  ┌──────▼──────────────────▼──────────────────▼───────┐   │
│  │              Core Orchestrator                      │   │
│  │  (State Machine, Task Scheduler, Event Bus)        │   │
│  └──────┬───────────┬───────────┬───────────┬─────────┘   │
│         │           │           │           │              │
│  ┌──────▼──────┐ ┌──▼──────┐ ┌──▼──────┐ ┌──▼──────┐     │
│  │  Manifest   │ │Network  │ │Installer│ │Platform │     │
│  │  Manager    │ │Manager  │ │Engine   │ │Adapter  │     │
│  └─────────────┘ └─────────┘ └─────────┘ └─────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼────┐          ┌─────▼─────┐        ┌─────▼─────┐
   │asYuvi.com│          │GitHub API │        │ CDN/Mirror│
   │ Manifest │          │ Releases  │        │  Servers  │
   └─────────┘          └───────────┘        └───────────┘
```

### 组件层次

```
Layer 1: 用户界面层
  - TUI (Terminal User Interface)
  - CLI (Command Line Interface)

Layer 2: 业务逻辑层
  - Core Orchestrator (核心编排器)
  - Manifest Manager (执行列表管理)
  - Network Manager (网络管理)
  - Installer Engine (安装引擎)

Layer 3: 平台适配层
  - Platform Adapter (macOS/Linux/Windows)
  - VM Manager (Lima/Podman/WSL2)
  - Package Manager (APK/YUM/APT)

Layer 4: 基础设施层
  - HTTP Client (下载器)
  - File System (文件系统)
  - Process Manager (进程管理)
```

---

## 核心组件

### 1. Core Orchestrator (核心编排器)

**职责**:
- 管理安装器生命周期和状态机
- 调度任务执行
- 处理事件和通知

**状态机**:
```
[Initializing] → [CheckingManifest] → [UpdatingManifest?]
                        ↓
             [CheckingInstallation]
                        ↓
          ┌─────────────┴─────────────┐
          │                           │
    [NeedInstall]              [NeedUpgrade]
          │                           │
          └──────────┬─────────────────┘
                     ↓
              [DownloadingDeps]
                     ↓
              [InstallingDeps]
                     ↓
              [ConfiguringVM]
                     ↓
              [InstallingAsYuvi]
                     ↓
           [Ready] → [LaunchApp]
```

**接口**:
```zig
pub const Orchestrator = struct {
    state: State,
    manifest: *Manifest,
    network: *NetworkManager,
    installer: *InstallerEngine,

    pub fn init(allocator: Allocator) !*Orchestrator;
    pub fn run(self: *Orchestrator) !void;
    pub fn checkForUpdates(self: *Orchestrator) !UpdateInfo;
    pub fn installOrUpgrade(self: *Orchestrator) !void;
    pub fn launchApp(self: *Orchestrator) !void;
    pub fn diagnose(self: *Orchestrator) !DiagnosticReport;
};
```

### 2. Manifest Manager (执行列表管理)

**职责**:
- 加载内嵌的默认执行列表
- 从服务器获取最新执行列表
- 验证执行列表签名和完整性
- 解析和缓存执行列表

**执行列表版本控制**:
```
本地: v1.0.0 (嵌入二进制)
远程: v1.1.0 (https://api.asyuvi.com/manifest/latest)
```

**接口**:
```zig
pub const ManifestManager = struct {
    embedded: Manifest,      // 编译时嵌入
    cached: ?Manifest,       // 缓存的远程版本
    config: ManifestConfig,

    pub fn loadEmbedded(self: *ManifestManager) !Manifest;
    pub fn fetchRemote(self: *ManifestManager) !Manifest;
    pub fn getCurrent(self: *ManifestManager) !Manifest;
    pub fn verifySignature(manifest: Manifest) !bool;
    pub fn updateCache(self: *ManifestManager, manifest: Manifest) !void;
};
```

### 3. Network Manager (网络管理)

**职责**:
- 检测网络连接性
- 自动发现和配置代理
- 选择最优下载源（CDN、镜像站）
- 实现下载（并发、断点续传、校验）

**网络策略**:
```
1. 连接性检测
   - Ping asYuvi.com API
   - Ping GitHub API
   - Ping Alpine Mirrors

2. 代理发现
   - 读取环境变量 (HTTP_PROXY, HTTPS_PROXY)
   - macOS: 读取系统代理设置
   - 提示用户手动配置

3. 源选择
   - 国际: GitHub Releases, dl-cdn.alpinelinux.org
   - 中国: ghproxy.com, mirrors.tuna.tsinghua.edu.cn
```

**接口**:
```zig
pub const NetworkManager = struct {
    proxy: ?ProxyConfig,
    mirrors: []MirrorConfig,

    pub fn detectConnectivity(self: *NetworkManager) !ConnectivityInfo;
    pub fn configureProxy(self: *NetworkManager) !void;
    pub fn selectBestMirror(self: *NetworkManager, region: Region) !Mirror;
    pub fn download(self: *NetworkManager, url: []const u8, dest: []const u8) !void;
    pub fn downloadParallel(self: *NetworkManager, tasks: []DownloadTask) !void;
};
```

### 4. Installer Engine (安装引擎)

**职责**:
- 执行安装步骤
- 管理依赖关系
- 处理平台差异
- 回滚失败的安装

**安装步骤**:
```
Step 1: 检测平台 (macOS/Linux/Windows)
Step 2: 检测已安装组件
Step 3: 下载依赖包
  - Lima (macOS)
  - Alpine minimal 镜像
  - asYuvi 软件包
Step 4: 安装 Lima (如果需要)
Step 5: 创建 VM
  - 启动 Alpine VM
  - 配置网络和代理
Step 6: 在 VM 内安装软件
  - 配置 APK 镜像源
  - 安装 Node.js, Python, Chromium
  - 测试安装
Step 7: 安装 asYuvi 应用
Step 8: 配置和验证
```

**接口**:
```zig
pub const InstallerEngine = struct {
    platform: Platform,
    steps: []InstallStep,

    pub fn detectPlatform() !Platform;
    pub fn checkInstalled() !InstalledComponents;
    pub fn installComponent(self: *InstallerEngine, component: Component) !void;
    pub fn rollback(self: *InstallerEngine, step: InstallStep) !void;
    pub fn verify(self: *InstallerEngine) !VerificationResult;
};
```

### 5. Platform Adapter (平台适配)

**职责**:
- 抽象平台差异
- 调用平台特定 API
- 管理 VM 生命周期

**支持平台**:
- **macOS**: Lima (VZ framework)
- **Linux**: Podman 或原生
- **Windows**: WSL2

**接口**:
```zig
pub const PlatformAdapter = struct {
    os: OS,
    arch: Arch,

    pub fn getHomeDir() ![]const u8;
    pub fn getConfigDir() ![]const u8;
    pub fn createVM(config: VMConfig) !VM;
    pub fn startVM(vm: *VM) !void;
    pub fn execInVM(vm: *VM, cmd: []const u8) !ExecResult;
    pub fn stopVM(vm: *VM) !void;
};
```

### 6. TUI Layer (用户界面)

**职责**:
- 显示安装进度
- 处理用户交互
- 展示错误和诊断信息

**界面设计**:
```
┌─────────────────────────────────────────────────────────┐
│  asYuvi Installer v2.0.0                                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Status: Downloading dependencies (3/5)                │
│                                                         │
│  [██████████████░░░░░░░░░░] 60% Lima 2.0.3 (12.3/20MB) │
│  [████████████████████████] 100% Alpine minimal (128MB)│
│  [░░░░░░░░░░░░░░░░░░░░░░░░]   0% asYuvi 0.12.1         │
│                                                         │
│  Network: Using proxy http://127.0.0.1:7890            │
│  Mirror: mirrors.tuna.tsinghua.edu.cn (China)          │
│                                                         │
│  ⓘ Tip: Press 'q' to cancel, 'd' for diagnostics      │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  [Continue]  [Cancel]  [Diagnostics]                   │
└─────────────────────────────────────────────────────────┘
```

**库选择**: `zig-tui` 或 `vaxis`

---

## 执行列表 (Manifest)

### Manifest 结构

执行列表是一个 JSON 文件，定义了安装过程的所有细节。

**示例**:
```json
{
  "version": "1.1.0",
  "schema_version": "2.0",
  "created_at": "2026-01-17T12:00:00Z",
  "signature": "base64-encoded-signature",

  "installer": {
    "min_version": "2.0.0",
    "recommended_version": "2.0.1"
  },

  "asyuvi": {
    "version": "0.12.1",
    "release_date": "2026-01-17",
    "changelog_url": "https://github.com/xbits/asYuvi/releases/tag/v0.12.1",

    "artifacts": {
      "macos_arm64": {
        "url": "https://github.com/xbits/asYuvi/releases/download/v0.12.1/asYuvi-0.12.1-darwin-arm64.tar.gz",
        "mirrors": [
          "https://ghproxy.com/https://github.com/xbits/asYuvi/releases/download/v0.12.1/asYuvi-0.12.1-darwin-arm64.tar.gz"
        ],
        "size": 52428800,
        "sha256": "abc123...",
        "install_path": "$HOME/.asyuvi/bin"
      }
    }
  },

  "dependencies": {
    "lima": {
      "version": "2.0.3",
      "required_on": ["darwin"],

      "artifacts": {
        "darwin_arm64": {
          "url": "https://github.com/lima-vm/lima/releases/download/v2.0.3/lima-2.0.3-Darwin-arm64.tar.gz",
          "size": 23068672,
          "sha256": "22aee997..."
        }
      }
    },

    "alpine_vm": {
      "version": "3.23.2",
      "variant": "minimal",
      "required_on": ["darwin", "linux"],

      "artifacts": {
        "arm64": {
          "url": "https://cdn.asyuvi.com/releases/v0.12.1/asyuvi-alpine-arm64-0.12.0-minimal-20260117.tar.gz",
          "mirrors": [
            "https://mirrors.tuna.tsinghua.edu.cn/asyuvi/releases/v0.12.1/asyuvi-alpine-arm64-0.12.0-minimal-20260117.tar.gz"
          ],
          "size": 134096813,
          "sha256": "c29cf0e7..."
        }
      },

      "post_install": {
        "steps": [
          {
            "type": "apk_install",
            "packages": ["nodejs", "python3", "py3-pip", "chromium-headless-shell"],
            "mirrors": [
              {
                "region": "global",
                "main": "https://dl-cdn.alpinelinux.org/alpine/v3.23/main",
                "community": "https://dl-cdn.alpinelinux.org/alpine/v3.23/community"
              },
              {
                "region": "cn",
                "main": "https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.23/main",
                "community": "https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.23/community"
              }
            ]
          },
          {
            "type": "verify",
            "commands": [
              "node --version",
              "python3 --version",
              "chromium-headless-shell --version"
            ]
          }
        ]
      }
    }
  },

  "network": {
    "mirrors": [
      {
        "id": "github_global",
        "region": "global",
        "base_url": "https://github.com",
        "test_url": "https://api.github.com"
      },
      {
        "id": "github_cn_proxy",
        "region": "cn",
        "base_url": "https://ghproxy.com/https://github.com",
        "test_url": "https://ghproxy.com"
      },
      {
        "id": "alpine_global",
        "region": "global",
        "base_url": "https://dl-cdn.alpinelinux.org",
        "test_url": "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/latest-releases.yaml"
      },
      {
        "id": "alpine_cn_tuna",
        "region": "cn",
        "base_url": "https://mirrors.tuna.tsinghua.edu.cn",
        "test_url": "https://mirrors.tuna.tsinghua.edu.cn/alpine/"
      }
    ],

    "connectivity_tests": [
      {
        "name": "GitHub API",
        "url": "https://api.github.com",
        "timeout_ms": 5000
      },
      {
        "name": "asYuvi API",
        "url": "https://api.asyuvi.com/health",
        "timeout_ms": 3000
      }
    ]
  },

  "diagnostics": {
    "checks": [
      {
        "id": "platform_support",
        "description": "Check if platform is supported",
        "command": "uname -s -m"
      },
      {
        "id": "lima_installed",
        "description": "Check if Lima is installed",
        "command": "which limactl"
      },
      {
        "id": "vm_status",
        "description": "Check VM status",
        "command": "limactl list"
      }
    ]
  }
}
```

### Manifest 签名验证

**目的**: 防止中间人攻击和篡改

**方案**: Ed25519 签名
1. asYuvi 私钥签名 Manifest
2. 公钥嵌入安装器二进制
3. 下载后验证签名

**实现**:
```zig
const signature = try base64Decode(manifest.signature);
const message = try json.stringify(manifest without signature);
const publicKey = @embedFile("keys/asyuvi-public.key");

if (!ed25519.verify(signature, message, publicKey)) {
    return error.InvalidManifestSignature;
}
```

### Manifest 更新机制

```
1. 启动时检查
   GET https://api.asyuvi.com/manifest/latest
   If-None-Match: <etag-of-cached-manifest>

2. 比较版本
   Remote: 1.1.0
   Local:  1.0.0
   → 需要更新

3. 下载新 Manifest
   GET https://api.asyuvi.com/manifest/1.1.0
   验证签名
   缓存到 ~/.asyuvi/installer/manifest.json

4. 使用新 Manifest
   优先使用缓存的 Manifest
   如果网络失败，回退到嵌入的 Manifest
```

---

## API 设计

### 安装器 HTTP API

asYuvi.com 提供的 API 端点：

#### 1. 获取最新 Manifest

```
GET /api/v1/manifest/latest
Accept: application/json

Response:
{
  "version": "1.1.0",
  "url": "https://api.asyuvi.com/api/v1/manifest/1.1.0",
  "etag": "W/\"abc123\"",
  "size": 45678,
  "sha256": "def456..."
}
```

#### 2. 下载 Manifest

```
GET /api/v1/manifest/{version}
Accept: application/json

Response: <manifest-json>
```

#### 3. 健康检查

```
GET /api/v1/health

Response:
{
  "status": "ok",
  "version": "1.0.0",
  "timestamp": "2026-01-17T12:00:00Z"
}
```

#### 4. 检查更新

```
GET /api/v1/updates/check?current_version={version}&platform={platform}

Response:
{
  "has_update": true,
  "latest_version": "0.12.1",
  "current_version": "0.11.0",
  "release_notes": "https://github.com/xbits/asYuvi/releases/tag/v0.12.1",
  "required": false,
  "recommended": true
}
```

#### 5. 上报安装统计 (可选)

```
POST /api/v1/telemetry/install
Content-Type: application/json

{
  "installer_version": "2.0.0",
  "asyuvi_version": "0.12.1",
  "platform": "darwin-arm64",
  "success": true,
  "duration_ms": 123456,
  "error": null
}

Response: 204 No Content
```

---

## 执行流程

### 全新安装流程

```
┌─────────────────────────────────────────────────────────┐
│ 1. 启动安装器                                           │
│    - 显示欢迎界面                                       │
│    - 解析命令行参数                                     │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 2. 加载 Manifest                                        │
│    - 加载嵌入的默认 Manifest                            │
│    - 尝试获取最新 Manifest                              │
│    - 验证签名                                           │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 3. 检测网络环境                                         │
│    - 检测连接性 (GitHub, asYuvi API)                   │
│    - 发现代理配置                                       │
│    - 选择下载镜像 (global/cn)                           │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 4. 检测已安装组件                                       │
│    - Lima: not installed                                │
│    - Alpine VM: not exist                               │
│    - asYuvi: not installed                              │
│    → 需要全新安装                                       │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 5. 下载依赖                                             │
│    - Lima 2.0.3 (from GitHub/ghproxy)                   │
│    - Alpine minimal (from CDN/mirrors.tuna)             │
│    - asYuvi 0.12.1 (from GitHub/ghproxy)                │
│    并发下载,显示进度                                    │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 6. 安装 Lima (macOS)                                    │
│    - 解压到 ~/.lima/bin                                 │
│    - 添加到 PATH                                        │
│    - 验证: limactl --version                            │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 7. 创建和配置 VM                                        │
│    - 解压 Alpine 镜像                                   │
│    - 创建 Lima VM 配置                                  │
│    - 启动 VM: limactl start                             │
│    - 等待 SSH 就绪                                      │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 8. 配置 VM 内软件源                                     │
│    - 检测网络 (在 VM 内 ping 8.8.8.8)                  │
│    - 如果不通: 配置主机代理转发                         │
│    - 配置 APK 镜像源 (global/cn)                        │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 9. 在 VM 内安装软件                                     │
│    SSH 执行:                                            │
│    - apk update                                         │
│    - apk add nodejs python3 chromium-headless-shell     │
│    - 验证安装: node --version, etc.                     │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 10. 安装 asYuvi 应用                                    │
│    - 解压到 ~/.asyuvi                                   │
│    - 创建配置文件                                       │
│    - 创建启动脚本                                       │
│    - 添加到 PATH                                        │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 11. 验证安装                                            │
│    - 运行诊断检查                                       │
│    - 测试 asYuvi 启动                                   │
│    - 生成安装报告                                       │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 12. 完成                                                │
│    - 显示成功消息                                       │
│    - 提示下一步操作                                     │
│    - 询问是否启动 asYuvi                                │
└─────────────────────────────────────────────────────────┘
```

### 升级流程

```
┌─────────────────────────────────────────────────────────┐
│ 1. 检测已安装版本                                       │
│    - Lima: 2.0.3 (latest)                               │
│    - asYuvi: 0.11.0 (outdated, latest: 0.12.1)          │
└────────────────┬────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────┐
│ 2. 提示用户升级                                         │
│    ┌───────────────────────────────────────────────┐   │
│    │ New version available!                        │   │
│    │                                               │   │
│    │ Current: asYuvi 0.11.0                        │   │
│    │ Latest:  asYuvi 0.12.1                        │   │
│    │                                               │   │
│    │ Release notes:                                │   │
│    │ - Dual image strategy (minimal + full)       │   │
│    │ - Optimized image size (-25%)                │   │
│    │                                               │   │
│    │ [Upgrade] [Skip] [View Full Notes]           │   │
│    └───────────────────────────────────────────────┘   │
└────────────────┬────────────────────────────────────────┘
                 │
            [Skip]│[Upgrade]
                 │
    ┌────────────┴────────────┐
    │                         │
┌───▼───┐               ┌────▼────────────────────────────┐
│ Launch│               │ 3. 下载新版本                   │
│ asYuvi│               │    - asYuvi 0.12.1 (50MB)       │
└───────┘               └────┬────────────────────────────┘
                             │
                   ┌─────────▼────────────────────────────┐
                   │ 4. 备份当前版本                      │
                   │    - mv ~/.asyuvi ~/.asyuvi.backup   │
                   └─────────┬────────────────────────────┘
                             │
                   ┌─────────▼────────────────────────────┐
                   │ 5. 安装新版本                        │
                   │    - 解压到 ~/.asyuvi                │
                   └─────────┬────────────────────────────┘
                             │
                   ┌─────────▼────────────────────────────┐
                   │ 6. 验证                              │
                   │    - asyuvi --version                │
                   │    - 如果失败, 回滚到备份            │
                   └─────────┬────────────────────────────┘
                             │
                   ┌─────────▼────────────────────────────┐
                   │ 7. 完成                              │
                   │    - 删除备份                        │
                   │    - 启动 asYuvi                     │
                   └──────────────────────────────────────┘
```

### 诊断流程

```
用户执行: asyuvi-installer diagnose

┌─────────────────────────────────────────────────────────┐
│ asYuvi Diagnostics                                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ [✓] Platform: macOS 14.0 (arm64) - Supported           │
│ [✓] Lima: 2.0.3 installed at /Users/user/.lima/bin     │
│ [✓] VM: asYuvi running (uptime: 2h 15m)                │
│ [✓] asYuvi: 0.12.1 installed at /Users/user/.asyuvi    │
│                                                         │
│ [✗] Network: Cannot reach GitHub                       │
│     → Proxy detected: http://127.0.0.1:7890            │
│     → Testing... Failed                                │
│     → Suggestion: Check proxy settings                 │
│                                                         │
│ [!] VM Software: chromium-headless-shell not found     │
│     → Suggestion: Run 'asyuvi-installer repair'        │
│                                                         │
│ [Generate Report] [Repair] [Close]                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 网络策略

### 连接性检测

```
1. 测试 asYuvi API
   URL: https://api.asyuvi.com/health
   Timeout: 3s
   如果成功 → 网络正常

2. 测试 GitHub API
   URL: https://api.github.com
   Timeout: 5s
   如果失败 → 可能需要代理或镜像

3. 测试 Alpine 镜像
   URL: https://dl-cdn.alpinelinux.org
   Timeout: 5s
```

### 代理配置

**自动发现**:
```zig
fn detectProxy() ?ProxyConfig {
    // 1. 环境变量
    if (std.os.getenv("HTTPS_PROXY")) |proxy| {
        return parseProxy(proxy);
    }

    // 2. macOS 系统设置
    if (builtin.os.tag == .macos) {
        // 调用 scutil --proxy
        const result = exec("scutil", &[_][]const u8{"--proxy"});
        return parseSystemProxy(result.stdout);
    }

    // 3. 用户配置文件
    if (readConfigFile("~/.asyuvi/proxy.conf")) |conf| {
        return conf.proxy;
    }

    return null;
}
```

**手动配置**:
```
用户可以通过 TUI 或配置文件设置:

~/.asyuvi/config.toml:
[network]
proxy = "http://127.0.0.1:7890"
timeout = 30
retry = 3

[mirrors]
prefer_region = "cn"  # or "global"
```

### 镜像源选择

**策略**:
```
1. 检测用户地区
   - IP 地理位置 (通过 API)
   - 用户配置

2. 选择对应镜像
   China:
     GitHub → ghproxy.com
     Alpine → mirrors.tuna.tsinghua.edu.cn

   Global:
     GitHub → github.com
     Alpine → dl-cdn.alpinelinux.org

3. 回退机制
   如果主镜像失败，尝试备用镜像
   mirrors = [primary, fallback1, fallback2]
```

**APK 镜像源配置**:
```bash
# Global
/etc/apk/repositories:
https://dl-cdn.alpinelinux.org/alpine/v3.23/main
https://dl-cdn.alpinelinux.org/alpine/v3.23/community

# China
/etc/apk/repositories:
https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.23/main
https://mirrors.tuna.tsinghua.edu.cn/alpine/v3.23/community
```

### 下载实现

**特性**:
- 并发下载多个文件
- 断点续传
- 进度回调
- 校验和验证

**实现**:
```zig
pub const Downloader = struct {
    http_client: std.http.Client,
    max_concurrent: usize = 3,

    pub fn downloadFile(
        self: *Downloader,
        url: []const u8,
        dest: []const u8,
        expected_sha256: ?[]const u8,
        progress_cb: ?*const fn(u64, u64) void,
    ) !void {
        // 1. 检查是否已部分下载
        const resume_offset = try getResumeOffset(dest);

        // 2. 发送 HTTP 请求
        var req = try self.http_client.request(.GET, url, .{});
        if (resume_offset > 0) {
            try req.headers.append("Range",
                try std.fmt.allocPrint(allocator, "bytes={d}-", .{resume_offset}));
        }

        // 3. 下载到临时文件
        const temp_file = try std.fs.createFileAbsolute(dest ++ ".tmp", .{});
        defer temp_file.close();

        var downloaded: u64 = resume_offset;
        const total_size = try getTotalSize(req);

        while (true) {
            const chunk = try req.read(buffer[0..]);
            if (chunk.len == 0) break;

            try temp_file.writeAll(chunk);
            downloaded += chunk.len;

            if (progress_cb) |cb| {
                cb(downloaded, total_size);
            }
        }

        // 4. 验证校验和
        if (expected_sha256) |expected| {
            const actual = try sha256File(dest ++ ".tmp");
            if (!std.mem.eql(u8, actual, expected)) {
                return error.ChecksumMismatch;
            }
        }

        // 5. 重命名到最终位置
        try std.fs.renameAbsolute(dest ++ ".tmp", dest);
    }

    pub fn downloadParallel(
        self: *Downloader,
        tasks: []DownloadTask,
    ) !void {
        var pool = try ThreadPool.init(self.max_concurrent);
        defer pool.deinit();

        for (tasks) |task| {
            try pool.spawn(downloadWorker, .{self, task});
        }

        try pool.wait();
    }
};
```

---

## 升级策略

### 版本检测

```
本地版本获取:
1. 读取 ~/.asyuvi/VERSION 文件
2. 或执行 asyuvi --version

远程版本获取:
1. GET https://api.asyuvi.com/api/v1/updates/check?current={version}
2. 或读取 GitHub latest release
```

### 升级策略

**策略类型**:

1. **可选升级** (Recommended)
   - 有新功能和改进
   - 用户可以选择跳过
   - 下次启动再次提示

2. **必需升级** (Required)
   - 安全漏洞修复
   - 重大 Bug 修复
   - API 不兼容
   - 强制升级，不允许跳过

3. **自动升级** (Auto)
   - 用户配置允许自动升级
   - 后台静默下载
   - 下次启动时安装

**实现**:
```zig
pub const UpdateInfo = struct {
    has_update: bool,
    latest_version: []const u8,
    current_version: []const u8,
    required: bool,
    recommended: bool,
    release_notes_url: []const u8,
    download_url: []const u8,
    size: u64,
    sha256: []const u8,
};

pub fn checkForUpdates(current: []const u8) !UpdateInfo {
    const url = try std.fmt.allocPrint(
        allocator,
        "https://api.asyuvi.com/api/v1/updates/check?current_version={s}&platform={s}",
        .{current, getPlatform()}
    );

    const response = try http.get(url);
    return try json.parse(UpdateInfo, response.body);
}

pub fn performUpgrade(info: UpdateInfo) !void {
    // 1. 下载新版本
    try downloadWithProgress(info.download_url, "/tmp/asyuvi-new.tar.gz");

    // 2. 验证校验和
    try verifySha256("/tmp/asyuvi-new.tar.gz", info.sha256);

    // 3. 备份当前版本
    try backupCurrent();

    // 4. 安装新版本
    try installNew("/tmp/asyuvi-new.tar.gz");

    // 5. 验证新版本
    if (!try verifyInstallation()) {
        try rollback();
        return error.UpgradeFailed;
    }

    // 6. 清理备份
    try cleanupBackup();
}
```

### 回滚机制

```
升级失败时自动回滚:

1. 保留备份
   ~/.asyuvi.backup-{timestamp}/

2. 验证失败
   - 新版本无法启动
   - 关键功能损坏

3. 执行回滚
   - 删除新版本
   - 恢复备份
   - 验证恢复成功

4. 上报失败
   POST /api/v1/telemetry/upgrade-failed
   { version, error, platform }
```

---

## 数据结构

### 核心数据结构 (Zig)

```zig
// 平台信息
pub const Platform = struct {
    os: OS,
    arch: Arch,

    pub const OS = enum {
        darwin,
        linux,
        windows,
    };

    pub const Arch = enum {
        x86_64,
        aarch64,
    };

    pub fn toString(self: Platform) []const u8 {
        return switch (self.os) {
            .darwin => switch (self.arch) {
                .aarch64 => "darwin-arm64",
                .x86_64 => "darwin-x86_64",
            },
            .linux => switch (self.arch) {
                .aarch64 => "linux-arm64",
                .x86_64 => "linux-x86_64",
            },
            .windows => "windows-wsl2",
        };
    }
};

// 组件信息
pub const Component = struct {
    name: []const u8,
    version: []const u8,
    installed: bool,
    up_to_date: bool,
    install_path: ?[]const u8,
};

// 下载任务
pub const DownloadTask = struct {
    url: []const u8,
    dest: []const u8,
    size: u64,
    sha256: []const u8,
    mirrors: [][]const u8,
    priority: u8 = 0,
};

// 安装步骤
pub const InstallStep = struct {
    id: []const u8,
    description: []const u8,
    type: StepType,
    required: bool,
    rollback: ?*const fn() anyerror!void,

    pub const StepType = enum {
        download,
        extract,
        install,
        configure,
        verify,
    };
};

// 网络配置
pub const NetworkConfig = struct {
    proxy: ?ProxyConfig,
    timeout_ms: u32 = 30000,
    retry_count: u3 = 3,
    prefer_region: Region = .auto,

    pub const Region = enum {
        auto,
        global,
        cn,
    };
};

pub const ProxyConfig = struct {
    protocol: Protocol,
    host: []const u8,
    port: u16,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,

    pub const Protocol = enum {
        http,
        https,
        socks5,
    };
};

// 镜像配置
pub const MirrorConfig = struct {
    id: []const u8,
    region: []const u8,
    base_url: []const u8,
    test_url: []const u8,
    priority: u8 = 0,
};

// VM 配置
pub const VMConfig = struct {
    name: []const u8,
    image_path: []const u8,
    cpus: u8 = 4,
    memory_mb: u32 = 4096,
    disk_gb: u32 = 30,
    mounts: []Mount,

    pub const Mount = struct {
        host_path: []const u8,
        guest_path: []const u8,
        writable: bool = false,
    };
};

// 诊断结果
pub const DiagnosticReport = struct {
    checks: []CheckResult,
    overall_status: Status,
    timestamp: i64,

    pub const CheckResult = struct {
        id: []const u8,
        name: []const u8,
        status: Status,
        message: []const u8,
        suggestion: ?[]const u8,
    };

    pub const Status = enum {
        ok,
        warning,
        error,
    };
};
```

---

## 错误处理

### 错误类型

```zig
pub const InstallerError = error{
    // 网络错误
    NetworkUnavailable,
    DownloadFailed,
    ChecksumMismatch,
    ProxyConnectionFailed,

    // 平台错误
    UnsupportedPlatform,
    UnsupportedArchitecture,
    InsufficientPermissions,

    // Manifest 错误
    ManifestNotFound,
    ManifestParseError,
    ManifestSignatureInvalid,
    ManifestVersionMismatch,

    // 安装错误
    DependencyNotFound,
    InstallationFailed,
    VMCreationFailed,
    VMStartFailed,
    SoftwareInstallFailed,

    // 验证错误
    VerificationFailed,
    HealthCheckFailed,

    // 升级错误
    BackupFailed,
    RollbackFailed,
    UpgradeAborted,
};
```

### 错误处理策略

```
1. 网络错误
   - 自动重试 (最多 3 次)
   - 切换镜像源
   - 提示用户检查网络/代理

2. 安装错误
   - 记录详细日志
   - 尝试回滚
   - 生成诊断报告

3. 用户错误
   - 显示友好的错误消息
   - 提供解决建议
   - 链接到文档

4. 系统错误
   - 捕获 panic
   - 保存崩溃报告
   - 提示用户提交 issue
```

### 日志记录

```zig
pub const Logger = struct {
    file: std.fs.File,
    level: Level = .info,

    pub const Level = enum {
        debug,
        info,
        warn,
        err,
    };

    pub fn init(path: []const u8) !Logger {
        const file = try std.fs.createFileAbsolute(path, .{});
        return Logger{ .file = file };
    }

    pub fn log(
        self: *Logger,
        comptime level: Level,
        comptime fmt: []const u8,
        args: anytype,
    ) void {
        const timestamp = std.time.timestamp();
        const level_str = switch (level) {
            .debug => "DEBUG",
            .info => "INFO ",
            .warn => "WARN ",
            .err => "ERROR",
        };

        const msg = std.fmt.allocPrint(
            allocator,
            "[{d}] {s} " ++ fmt ++ "\n",
            .{timestamp, level_str} ++ args,
        ) catch return;

        self.file.writeAll(msg) catch return;
    }
};

// 使用
var logger = try Logger.init("~/.asyuvi/installer.log");
logger.log(.info, "Starting installation", .{});
logger.log(.err, "Download failed: {s}", .{url});
```

---

## 技术选型

### 为什么选择 Zig?

**优势**:
1. **体积小**: 静态链接，无运行时，编译后 < 5MB
2. **性能高**: 接近 C 的性能，零开销抽象
3. **跨平台**: 一次编写，多平台编译
4. **易于集成**: 可以调用 C 库，与系统交互容易
5. **内存安全**: 编译时检查，减少运行时错误
6. **嵌入资源**: 可以用 `@embedFile` 嵌入 Manifest

**劣势**:
1. **生态较新**: 库不如 Go/Rust 丰富
2. **学习曲线**: 语法和概念需要学习
3. **工具链**: 调试和分析工具较少

**对比其他语言**:

| 特性 | Zig | Go | Rust | C |
|------|-----|----|----|---|
| 二进制大小 | 小 (~5MB) | 中 (~10MB) | 小 (~5MB) | 很小 (~2MB) |
| 编译速度 | 快 | 快 | 慢 | 很快 |
| 运行性能 | 高 | 中 | 高 | 很高 |
| 内存安全 | 编译时 | 运行时GC | 编译时 | 无 |
| 跨平台 | 优秀 | 优秀 | 优秀 | 需手动 |
| 生态成熟度 | 低 | 高 | 高 | 很高 |
| 开发效率 | 中 | 高 | 中 | 低 |

**结论**: Zig 在体积、性能和跨平台方面都符合需求，虽然生态较新，但对于安装器这种相对独立的程序是合适的选择。

### 依赖库选择

```
核心库:
- std (Zig 标准库) - 必需
- zig-cli - 命令行参数解析 (可选，可自己实现)
- vaxis - TUI 库 (推荐)
- zig-network - HTTP 客户端增强 (可选)

第三方依赖:
- lima (运行时依赖) - VM 管理
- tar, gzip (系统工具) - 解压缩
```

### 构建配置

```zig
// build.zig
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

    // 嵌入资源
    exe.addAnonymousModule("manifest", .{
        .source_file = .{ .path = "embed/manifest.json" },
    });
    exe.addAnonymousModule("public_key", .{
        .source_file = .{ .path = "keys/public.key" },
    });

    // 优化
    exe.strip = true; // 移除调试符号
    exe.single_threaded = false; // 多线程

    b.installArtifact(exe);
}
```

---

## 文件结构

### 项目结构

```
packaging/
├── docs/
│   ├── installer-architecture.md     (本文档)
│   ├── api-reference.md              (API 文档)
│   └── user-guide.md                 (用户指南)
│
├── installer/                        (Zig 安装器)
│   ├── src/
│   │   ├── main.zig                  (入口)
│   │   ├── orchestrator.zig          (核心编排器)
│   │   ├── manifest.zig              (Manifest 管理)
│   │   ├── network.zig               (网络管理)
│   │   ├── installer.zig             (安装引擎)
│   │   ├── platform.zig              (平台适配)
│   │   ├── tui.zig                   (TUI 界面)
│   │   ├── diagnostics.zig           (诊断)
│   │   └── utils/
│   │       ├── http.zig              (HTTP 客户端)
│   │       ├── hash.zig              (哈希和签名)
│   │       ├── archive.zig           (压缩解压)
│   │       └── process.zig           (进程管理)
│   │
│   ├── embed/
│   │   └── manifest.json             (默认 Manifest)
│   │
│   ├── keys/
│   │   ├── private.key               (签名私钥，不提交)
│   │   └── public.key                (验证公钥)
│   │
│   ├── build.zig                     (构建脚本)
│   ├── build.zig.zon                 (依赖声明)
│   └── README.md
│
├── manifest/                         (Manifest 定义)
│   ├── schema.json                   (JSON Schema)
│   ├── v1.0.0.json                   (版本 1.0.0)
│   ├── v1.1.0.json                   (版本 1.1.0)
│   └── latest.json -> v1.1.0.json    (软链接)
│
├── scripts/                          (构建和发布脚本)
│   ├── build-installer.sh            (构建安装器)
│   ├── sign-manifest.sh              (签名 Manifest)
│   ├── release.sh                    (发布流程)
│   └── test-installer.sh             (测试脚本)
│
└── tests/                            (测试)
    ├── unit/                         (单元测试)
    ├── integration/                  (集成测试)
    └── e2e/                          (端到端测试)
```

### 安装后文件结构

```
~/.asyuvi/
├── bin/
│   ├── asyuvi                        (主程序)
│   └── asyuvi-installer              (安装器副本)
│
├── config/
│   ├── config.toml                   (配置文件)
│   └── proxy.conf                    (代理配置)
│
├── installer/
│   ├── manifest.json                 (缓存的 Manifest)
│   └── manifest.json.sig             (签名)
│
├── logs/
│   ├── installer.log                 (安装器日志)
│   └── asyuvi.log                    (应用日志)
│
├── cache/
│   └── downloads/                    (下载缓存)
│       ├── lima-2.0.3.tar.gz
│       ├── alpine-minimal.tar.gz
│       └── asyuvi-0.12.1.tar.gz
│
└── VERSION                           (版本文件)
```

---

## 实现路线图

### Phase 1: MVP (2-3 周)

**目标**: 实现基本安装功能

**任务**:
1. ✅ 架构设计文档
2. ⏸️ Zig 项目初始化
   - 设置 build.zig
   - 创建基本文件结构
3. ⏸️ 核心组件实现
   - Platform 检测
   - Manifest 加载 (嵌入式)
   - HTTP 下载器
4. ⏸️ 安装流程
   - 下载 Lima
   - 下载 Alpine 镜像
   - 安装和验证
5. ⏸️ 基本 CLI
   - 命令行参数解析
   - 进度显示
6. ⏸️ 测试
   - macOS ARM64 测试
   - 集成测试

**交付**:
- 可以在 macOS ARM64 上完成全新安装
- 命令行进度显示
- 基本错误处理

### Phase 2: 增强 (2-3 周)

**目标**: TUI 界面和网络优化

**任务**:
1. ⏸️ TUI 实现
   - 使用 vaxis 库
   - 进度条、菜单
   - 错误对话框
2. ⏸️ 网络优化
   - 代理检测和配置
   - 镜像源选择
   - 并发下载
   - 断点续传
3. ⏸️ Manifest 远程更新
   - API 实现
   - 签名验证
   - 缓存管理
4. ⏸️ 诊断功能
   - 系统检查
   - 生成报告
5. ⏸️ 跨平台
   - macOS x86_64 支持
   - Linux 初步支持

**交付**:
- 友好的 TUI 界面
- 网络适应能力 (代理、镜像)
- 支持 macOS (ARM64 + x86_64)

### Phase 3: 完善 (2 周)

**目标**: 升级、回滚和 Windows 支持

**任务**:
1. ⏸️ 升级功能
   - 版本检测
   - 升级流程
   - 回滚机制
2. ⏸️ Windows/WSL2 支持
   - 平台适配
   - WSL2 检测和配置
3. ⏸️ Linux 完整支持
   - Podman 集成
   - 各发行版测试
4. ⏸️ 文档
   - 用户指南
   - API 文档
   - 故障排查

**交付**:
- 完整的升级系统
- 支持 macOS, Linux, Windows
- 完善的文档

### Phase 4: 优化和发布 (1-2 周)

**目标**: 性能优化和生产发布

**任务**:
1. ⏸️ 性能优化
   - 减小二进制体积
   - 加快启动速度
   - 优化下载并发
2. ⏸️ 安全加固
   - Manifest 签名验证
   - HTTPS 证书验证
   - 输入验证
3. ⏸️ 遥测 (可选)
   - 匿名使用统计
   - 崩溃报告
4. ⏸️ 发布准备
   - CI/CD 配置
   - 发布脚本
   - 版本管理

**交付**:
- 生产就绪的安装器
- < 5MB 二进制大小
- 完整的 CI/CD 流程

---

## 附录

### A. Manifest JSON Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "asYuvi Installer Manifest",
  "type": "object",
  "required": ["version", "schema_version", "asyuvi", "dependencies"],
  "properties": {
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$"
    },
    "schema_version": {
      "type": "string"
    },
    "created_at": {
      "type": "string",
      "format": "date-time"
    },
    "signature": {
      "type": "string"
    },
    "asyuvi": {
      "type": "object",
      "required": ["version", "artifacts"],
      "properties": {
        "version": {"type": "string"},
        "release_date": {"type": "string"},
        "changelog_url": {"type": "string"},
        "artifacts": {
          "type": "object",
          "patternProperties": {
            "^.*$": {
              "type": "object",
              "required": ["url", "size", "sha256"],
              "properties": {
                "url": {"type": "string"},
                "mirrors": {"type": "array", "items": {"type": "string"}},
                "size": {"type": "integer"},
                "sha256": {"type": "string"},
                "install_path": {"type": "string"}
              }
            }
          }
        }
      }
    },
    "dependencies": {
      "type": "object"
    },
    "network": {
      "type": "object"
    },
    "diagnostics": {
      "type": "object"
    }
  }
}
```

### B. API 端点完整列表

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/v1/health` | GET | 健康检查 |
| `/api/v1/manifest/latest` | GET | 获取最新 Manifest 元数据 |
| `/api/v1/manifest/{version}` | GET | 下载指定版本 Manifest |
| `/api/v1/updates/check` | GET | 检查更新 |
| `/api/v1/telemetry/install` | POST | 上报安装统计 |
| `/api/v1/telemetry/upgrade` | POST | 上报升级统计 |
| `/api/v1/telemetry/error` | POST | 上报错误 |

### C. 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `ASYUVI_INSTALLER_DEBUG` | 启用调试模式 | `1` |
| `ASYUVI_INSTALLER_PROXY` | 强制使用代理 | `http://127.0.0.1:7890` |
| `ASYUVI_INSTALLER_MIRROR` | 强制使用镜像 | `cn` or `global` |
| `ASYUVI_INSTALLER_MANIFEST_URL` | 自定义 Manifest URL | `https://...` |
| `ASYUVI_INSTALLER_NO_TUI` | 禁用 TUI，使用纯 CLI | `1` |
| `ASYUVI_INSTALLER_SKIP_VERIFY` | 跳过签名验证 (不推荐) | `1` |

### D. 配置文件示例

```toml
# ~/.asyuvi/config.toml

[installer]
auto_update = true
check_interval_hours = 24

[network]
proxy = "http://127.0.0.1:7890"
timeout_seconds = 30
retry_count = 3
prefer_region = "cn"  # cn, global, auto

[mirrors]
github = "https://ghproxy.com/https://github.com"
alpine = "https://mirrors.tuna.tsinghua.edu.cn"

[vm]
cpus = 4
memory_mb = 4096
disk_gb = 30

[diagnostics]
enable_telemetry = false
log_level = "info"  # debug, info, warn, error
```

---

## 总结

本架构设计提供了一个全面的 asYuvi 安装器方案，基于 Zig 实现，具有以下特点：

**核心优势**:
1. ✅ 轻量化 - 二进制 < 5MB
2. ✅ 灵活性 - 执行列表可在线更新
3. ✅ 智能化 - 自动检测网络环境和配置
4. ✅ 跨平台 - macOS, Linux, Windows 统一实现
5. ✅ 用户友好 - TUI 界面，清晰的进度和错误提示

**技术亮点**:
1. 状态机驱动的安装流程
2. 并发下载和断点续传
3. 自动代理检测和镜像源选择
4. Manifest 签名验证
5. 完善的错误处理和回滚机制

**下一步行动**:
1. 审阅和完善本架构文档
2. 开始 Phase 1 (MVP) 实现
3. 在实现过程中持续迭代和优化

---

**文档版本**: v2.0
**最后更新**: 2026-01-17
**维护者**: asYuvi Team
