# asYuvi 安装器文档

## 文档索引

### 设计文档

1. **[installer-architecture.md](./installer-architecture.md)** - 核心架构设计
   - 系统架构和组件设计
   - 执行列表 (Manifest) 规范
   - API 设计
   - 执行流程
   - 网络策略和升级策略
   - 数据结构和错误处理
   - 技术选型和实现路线图

### 开发文档 (待创建)

2. **api-reference.md** - API 参考
   - HTTP API 详细说明
   - Zig API 文档
   - Manifest Schema

3. **development-guide.md** - 开发指南
   - 环境搭建
   - 编译和调试
   - 测试
   - 贡献指南

### 用户文档 (待创建)

4. **user-guide.md** - 用户指南
   - 安装步骤
   - 配置说明
   - 常见问题
   - 故障排查

5. **migration-guide.md** - 迁移指南
   - 从旧版本迁移
   - 配置迁移

## 快速开始

### 架构概览

```
asYuvi 安装器 = 轻量级 Zig TUI 程序
  ↓
功能: 检查更新 + 下载 + 安装 + 启动 + 诊断
  ↓
策略: 小安装器 + 可更新执行列表 + 第三方存储
  ↓
目标: < 5MB 独立程序，零依赖，跨平台
```

### 核心特性

- **轻量化**: 二进制 < 5MB，静态链接，无外部依赖
- **智能化**: 自动检测网络环境，配置代理和镜像源
- **灵活性**: 执行列表可在线更新，无需重新发布安装器
- **可靠性**: 签名验证、断点续传、回滚机制
- **跨平台**: macOS, Linux, Windows (WSL2)

### 当前状态

- ✅ 架构设计完成
- ⏸️ MVP 开发中
- ⏸️ 待发布

## 贡献

欢迎贡献！请查看 [development-guide.md](./development-guide.md) (待创建)

## 许可证

与 asYuvi 主项目相同
