# 版本说明

## 1.1.0 - Finder 集成稳定性更新

本次更新重点修复 Finder 右键菜单扩展的稳定性和安全边界，降低 Finder 卡死、加载错误扩展副本、以及路径泄露的风险。

### 主要变化

- Finder 右键菜单不再监控系统根目录 `/`，改为默认监控桌面、文稿、下载、外置卷和共享目录。
- 新增偏好设置里的“Finder 右键目录”，可添加自定义 Finder 菜单生效目录。
- 自定义目录写入 `~/Library/Application Support/iLab-zip/FinderSyncConfig.json`，配置缺失、损坏或不可读时会回退到默认目录。
- Finder 扩展与主 App 的交接改为 UUID + 命名 pasteboard，不再把文件路径和目标路径直接放进 URL Scheme。
- Finder 扩展日志改为摘要输出，避免在系统日志里记录完整文件路径。
- 打开主 App 失败时会记录失败结果，避免静默失败。
- 移除 Finder 扩展的 App Group 权限要求，未签名本地构建也能使用当前实现。

### 验证

- `xcodebuild test -project iLab-zip.xcodeproj -scheme iLab-zip -destination 'platform=macOS,arch=arm64' -only-testing:iLab-zipTests`
- `xcodebuild build -project iLab-zip.xcodeproj -scheme iLab-zip -configuration Release -destination 'platform=macOS,arch=arm64'`
- 本机安装到 `/Applications/如压.app` 后，已确认 Finder Sync 插件注册只保留应用目录中的一个副本。

### 已知限制

无签名构建无法使用 App Group 作为强可靠共享配置通道。当前版本使用普通配置文件作为无签名 fallback；如果 macOS sandbox 在特定环境下拒绝 Finder 扩展读取该文件，扩展会安全回退到默认目录。
