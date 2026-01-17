# asYuvi Installer - 快速开始

**版本**: v2.0.0-alpha
**状态**: Phase 1 完成 ✅
**二进制大小**: 110KB (Release)

---

## 项目概览

asYuvi Installer 是基于 Zig 开发的轻量级、跨平台安装器，用于安装和管理 asYuvi（本地化 AI Agent 执行平台）。

### 核心特性

- ✅ **超轻量**: Release 版本仅 110KB（目标 <5MB，实际仅为目标的 2%）
- ✅ **跨平台**: macOS, Linux, Windows (WSL2)
- ✅ **智能化**: 自动网络检测、代理配置、镜像源选择
- ✅ **灵活性**: Manifest 可在线更新，无需重新发布
- ⏸️ **TUI 界面**: 友好的终端用户界面（开发中）

---

## 快速开始

### 1. 构建

```bash
# 进入项目目录
cd /Users/konghan/Workspace/asYuvi.installer

# Debug 构建（开发用，1.3MB）
zig build

# Release 构建（生产用，110KB）
zig build -Doptimize=ReleaseSafe

# 构建并运行
zig build run -- --help
```

### 2. 使用

```bash
# 查看帮助
./zig-out/bin/asyuvi-installer --help

# 查看版本
./zig-out/bin/asyuvi-installer --version

# 全新安装（当前为演示模式）
./zig-out/bin/asyuvi-installer install

# 检查更新
./zig-out/bin/asyuvi-installer version-check

# 诊断系统
./zig-out/bin/asyuvi-installer diagnose
```

### 3. 测试

```bash
# 运行测试
zig build test

# 运行特定测试
zig test src/platform.zig
```

---

## 项目结构

```
asYuvi.installer/
├── src/                      # 源代码
│   ├── main.zig                # ✅ 程序入口
│   ├── platform.zig            # ✅ 平台检测
│   ├── orchestrator.zig        # ✅ 核心编排器
│   ├── manifest.zig            # ✅ Manifest 管理
│   ├── network.zig             # ⏸️ 网络管理（待实现）
│   ├── installer.zig           # ⏸️ 安装引擎（待实现）
│   └── utils/                  # 工具函数
│
├── docs/                     # 文档
│   ├── installer-architecture.md   # 完整架构设计（35KB+）
│   ├── implementation-plan.md      # 10周实施计划
│   ├── README.md                   # 文档索引
│   └── SUMMARY.md                  # 工作总结
│
├── manifest/                 # Manifest 定义
│   └── v1.0.0.json              # 示例 manifest
│
├── embed/                    # 嵌入资源
│   └── manifest.json            # 默认 manifest（嵌入二进制）
│
├── tests/                    # 测试
│   ├── unit/                    # 单元测试
│   ├── integration/             # 集成测试
│   └── e2e/                     # 端到端测试
│
├── build.zig                 # ✅ 构建配置
├── README.md                 # ✅ 项目文档
├── IMPLEMENTATION-STATUS.md  # ✅ 实施状态
└── QUICKSTART.md            # 本文档
```

---

## 开发流程

### 当前状态：Phase 1 完成 ✅

**已完成**:
- ✅ 项目初始化
- ✅ CLI 框架
- ✅ 平台检测
- ✅ Manifest 骨架
- ✅ 完整文档

**下一步（Phase 2）**:
- 网络管理（HTTP 客户端、下载器）
- 安装引擎（Lima、Alpine VM、asYuvi）
- Manifest 完整解析

### Git 工作流

```bash
# 查看状态
git status

# 提交更改
git add .
git commit -m "feat(module): description"

# 查看日志
git log --oneline

# 当前提交
# df88c2d docs: add implementation status report
# 0720c59 feat(installer): initialize Zig-based installer project
```

---

## 常用命令

### 构建命令

```bash
# Debug 构建
zig build

# Release 构建
zig build -Doptimize=ReleaseSafe

# Small Release (最小体积)
zig build -Doptimize=ReleaseSmall

# Fast Release (最快性能)
zig build -Doptimize=ReleaseFast

# 清理构建
rm -rf zig-cache/ zig-out/
```

### 开发命令

```bash
# 格式化代码
zig fmt src/

# 检查语法
zig ast-check src/main.zig

# 运行程序
zig build run -- install

# 运行测试
zig build test
```

### 查看信息

```bash
# 查看二进制大小
ls -lh zig-out/bin/asyuvi-installer

# 查看依赖
nm zig-out/bin/asyuvi-installer

# 查看文件结构
tree -L 3 -I 'zig-cache|zig-out|.git'
```

---

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Zig 0.15.2 |
| 构建系统 | Zig Build System |
| TUI 库 | vaxis (计划中) |
| HTTP 客户端 | std.http (计划中) |
| JSON 解析 | std.json |
| 加密签名 | Ed25519 (计划中) |

---

## 参考文档

### 核心文档
- [installer-architecture.md](docs/installer-architecture.md) - 完整架构设计
- [implementation-plan.md](docs/implementation-plan.md) - 10周实施计划
- [IMPLEMENTATION-STATUS.md](IMPLEMENTATION-STATUS.md) - 当前状态

### 外部资源
- [Zig 官方文档](https://ziglang.org/documentation/master/)
- [Zig 学习资源](https://github.com/ziglang/zig/wiki/Community)
- [vaxis TUI 库](https://github.com/rockorager/vaxis)

---

## 常见问题

### Q: 为什么选择 Zig？
A:
- 轻量化：生成的二进制非常小（110KB）
- 零依赖：静态链接，无需运行时
- 跨平台：一次编写，交叉编译到多个平台
- 性能：接近 C 的性能
- 现代化：内存安全、错误处理、编译时计算

### Q: 为什么 macOS 上不用静态链接？
A: macOS 不支持完全静态链接系统 libc。当前使用动态链接，未来可能考虑 musl 或其他方案。

### Q: 二进制大小能进一步减小吗？
A: 当前 110KB 已经非常小。使用 `-Doptimize=ReleaseSmall` 和 `strip` 可能进一步减小，但已经满足需求。

### Q: 下一步开发什么？
A: 按照 implementation-plan.md：
- Phase 2: 网络管理和下载功能
- Phase 3: TUI 界面
- Phase 4: 完整安装流程

---

## 贡献指南

### 代码风格
- 使用 `zig fmt` 格式化
- 函数名使用 camelCase
- 类型名使用 PascalCase
- 常量使用 UPPER_CASE

### 提交规范
```
<type>(<scope>): <subject>

[optional body]
```

类型：
- feat: 新功能
- fix: 修复
- docs: 文档
- refactor: 重构
- test: 测试
- chore: 构建/工具

---

**创建时间**: 2026-01-17
**最后更新**: 2026-01-17
**项目主页**: /Users/konghan/Workspace/asYuvi.installer/
