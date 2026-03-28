# 贡献指南 | Contributing Guide

感谢您对 **如压 (iLab-zip)** 的关注！我们欢迎所有形式的贡献。

Thank you for your interest in **iLab-zip**! We welcome all forms of contributions.

---

## 🐛 报告 Bug | Report a Bug

请通过 [GitHub Issues](https://github.com/kadevin/ilab-zip/issues) 提交，并包含：

- 操作系统版本（macOS version）
- 复现步骤（Steps to reproduce）
- 期望行为 vs 实际行为（Expected vs actual behavior）
- 相关日志或截图（Logs or screenshots）

## 💡 功能建议 | Feature Requests

欢迎在 Issues 中提出功能建议，请描述使用场景和预期效果。

## 🔧 提交代码 | Pull Requests

### 环境准备 | Setup

```bash
# 安装依赖
brew install xcodegen

# 克隆仓库
git clone https://github.com/kadevin/ilab-zip.git
cd iLab-zip

# 生成 Xcode 项目
xcodegen generate

# 打开 Xcode
open iLab-zip.xcodeproj
```

### 开发流程 | Workflow

1. Fork 本仓库
2. 创建特性分支 `git checkout -b feature/your-feature`
3. 提交更改 `git commit -m "Add: your feature description"`
4. 推送分支 `git push origin feature/your-feature`
5. 创建 Pull Request

### 代码规范 | Code Style

- 使用 Swift 标准命名规范
- 保持代码简洁，添加必要注释
- 新功能请附带单元测试
- UI 文本需同时支持中英文（Localization）

## 📄 许可 | License

贡献的代码将遵循项目的 [LGPL-2.1](LICENSE) 许可证。

By contributing, you agree that your contributions will be licensed under the [LGPL-2.1](LICENSE) license.
