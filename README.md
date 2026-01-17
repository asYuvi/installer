# asYuvi Installer

本地化 AI Agent 执行平台的安装器。

## 特性

- ✅ **轻量化**: 二进制 < 5MB，静态链接，零依赖
- ✅ **智能化**: 自动网络检测、代理配置、镜像源选择
- ✅ **灵活性**: Manifest 可在线更新，无需重新发布
- ✅ **跨平台**: macOS, Linux, Windows (WSL2)

## 快速开始

### 安装

```bash
# 下载并运行安装器
curl -fsSL https://asyuvi.com/install.sh | bash

# 或者直接下载二进制
wget https://github.com/xbits/asYuvi/releases/latest/download/asyuvi-installer-darwin-arm64
chmod +x asyuvi-installer-darwin-arm64
./asyuvi-installer-darwin-arm64 install
```

### 使用

```bash
# 全新安装
asyuvi-installer install

# 升级到最新版本
asyuvi-installer upgrade

# 诊断系统状态
asyuvi-installer diagnose

# 检查更新
asyuvi-installer version-check

# 查看帮助
asyuvi-installer --help
```

## 开发

### 环境要求

- Zig 0.12+ 编译器
- Git

### 构建

```bash
# Debug 模式
zig build

# Release 模式
zig build -Doptimize=ReleaseSafe

# 运行
zig build run -- install

# 测试
zig build test
```

### 项目结构

```
asYuvi.installer/
├── src/              # 源代码
│   ├── main.zig         # 程序入口
│   ├── orchestrator.zig # 核心编排器
│   ├── manifest.zig     # Manifest 管理
│   ├── platform.zig     # 平台检测
│   ├── network.zig      # 网络管理
│   ├── installer.zig    # 安装引擎
│   └── utils/           # 工具函数
├── embed/            # 嵌入资源
│   └── manifest.json    # 默认 manifest
├── manifest/         # Manifest 定义
│   └── v1.0.0.json
├── docs/             # 文档
│   ├── installer-architecture.md
│   └── implementation-plan.md
├── tests/            # 测试
│   ├── unit/
│   ├── integration/
│   └── e2e/
└── build.zig         # 构建配置
```

## 架构

详见 [docs/installer-architecture.md](docs/installer-architecture.md)

## 许可证

与 asYuvi 主项目相同
