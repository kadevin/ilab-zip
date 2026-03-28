<div align="center">

# 如压 · iLab-zip

**🗜️ 免费开源的 macOS 原生压缩/解压工具 | Free & Open-Source Archive Manager for macOS**

[![Build](https://github.com/kadevin/ilab-zip/actions/workflows/build.yml/badge.svg)](https://github.com/kadevin/ilab-zip/actions)
[![License: LGPL v2.1](https://img.shields.io/badge/License-LGPL_v2.1-blue.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/Platform-macOS_13%2B-brightgreen.svg)]()
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)]()

[English](#english) · [中文](#中文)

</div>

---

<a name="中文"></a>

## 🇨🇳 简介

**如压**是一款基于 [7-Zip](https://www.7-zip.org) 引擎的 macOS 原生压缩/解压缩客户端，使用 Swift + SwiftUI 构建。

市面上大部分 macOS 图形化解压缩工具（如 BetterZip、Archiver、WinZip）均为收费软件或共享软件。**如压致力于提供一个完全免费、开源的替代方案**，让每一位 Mac 用户都能享有强大的压缩/解压能力。

### ✨ 功能特性

- 🗂️ **WinRAR 风格浏览器** — 双栏文件浏览，左侧目录树 + 右侧文件列表
- 📦 **广泛格式支持** — 7z、ZIP、RAR、TAR、GZ、BZ2、XZ、ISO、DMG、CAB、ARJ、LZH、WIM 等
- 🔐 **AES-256 加密** — 支持创建/解压加密压缩包，内置密码库（AES-256-GCM 本地加密存储）
- 📂 **Finder 集成** — 右键菜单快速压缩/解压
- 🌐 **多语言支持** — 中文 / English
- 💾 **分卷压缩** — 支持自定义分卷大小
- 🎨 **macOS 原生体验** — SwiftUI 构建，支持 Liquid Glass 设计
- 🆓 **完全免费** — 无广告、无内购、永久免费

### 📋 支持格式

| 操作 | 格式 |
|------|------|
| **压缩 & 解压** | 7z, ZIP |
| **仅解压** | RAR, TAR, GZ, BZ2, XZ, ISO, DMG, CAB, ARJ, LZH, WIM, Z, CPIO, RPM, DEB, NSIS, VHD, FAT, NTFS, HFS |

### 🚀 安装

#### 从 Release 下载

前往 [Releases](https://github.com/kadevin/ilab-zip/releases) 页面下载最新的 `.dmg` 安装包。

#### 从源码编译

```bash
# 前置条件：Xcode 26+, xcodegen
brew install xcodegen

# 克隆仓库
git clone https://github.com/kadevin/ilab-zip.git
cd iLab-zip

# 生成 Xcode 项目
xcodegen generate

# 打开 Xcode 编译
open iLab-zip.xcodeproj
```

### 🏗️ 项目结构

```
iLab-zip/
├── iLab-zip/                   # 主应用源码
│   ├── App/                    # 应用入口 & AppDelegate
│   ├── Engine/                 # 7-Zip 引擎封装
│   ├── UI/                     # SwiftUI 视图
│   │   ├── ArchiveWindow/      # 主浏览窗口
│   │   ├── Compression/        # 压缩配置面板
│   │   ├── Preferences/        # 偏好设置
│   │   └── Progress/           # 进度窗口
│   ├── Vault/                  # 密码库（GRDB + CryptoKit）
│   ├── Localization/           # 国际化资源
│   └── Resources/              # 7zz 二进制 & 资源文件
├── iLab-zipFinderExtension/    # Finder 右键菜单扩展
├── iLab-zipXPC/                # XPC Service（扩展通信）
├── iLab-zipTests/              # 单元测试
├── iLab-zipUITests/            # UI 测试
└── project.yml                 # XcodeGen 项目定义
```

---

<a name="english"></a>

## 🇺🇸 English

**iLab-zip** (如压) is a **free and open-source** native macOS archive manager powered by the [7-Zip](https://www.7-zip.org) engine, built with Swift and SwiftUI.

Most GUI archive tools for macOS — such as BetterZip, Archiver, and WinZip — are either paid or shareware. **iLab-zip aims to be a completely free, open-source alternative**, providing powerful compression and extraction capabilities to every Mac user.

### ✨ Features

- 🗂️ **WinRAR-style File Browser** — Dual-pane layout with directory tree & file list
- 📦 **Extensive Format Support** — 7z, ZIP, RAR, TAR, GZ, BZ2, XZ, ISO, DMG, CAB, and 15+ more
- 🔐 **AES-256 Encryption** — Create/extract encrypted archives with built-in password vault
- 📂 **Finder Integration** — Right-click context menu for quick compress/extract
- 🌐 **Multilingual** — Chinese / English
- 💾 **Split Archives** — Create multi-volume archives with custom sizes
- 🎨 **Native macOS Experience** — Built with SwiftUI, supports Liquid Glass design
- 🆓 **Completely Free** — No ads, no in-app purchases, free forever

### 📋 Supported Formats

| Operation | Formats |
|-----------|---------|
| **Compress & Extract** | 7z, ZIP |
| **Extract Only** | RAR, TAR, GZ, BZ2, XZ, ISO, DMG, CAB, ARJ, LZH, WIM, Z, CPIO, RPM, DEB, NSIS, VHD, FAT, NTFS, HFS |

### 🚀 Installation

#### Download from Releases

Visit the [Releases](https://github.com/kadevin/ilab-zip/releases) page to download the latest `.dmg`.

#### Build from Source

```bash
# Prerequisites: Xcode 26+, xcodegen
brew install xcodegen

# Clone the repository
git clone https://github.com/kadevin/ilab-zip.git
cd iLab-zip

# Generate Xcode project
xcodegen generate

# Open in Xcode and build
open iLab-zip.xcodeproj
```

---

## 🙏 致谢 | Acknowledgements

- **[7-Zip](https://www.7-zip.org)** — 由 **Igor Pavlov** 开发的卓越开源压缩引擎，本项目核心压缩/解压能力均由 7-Zip 提供。感谢 Igor Pavlov 对开源社区的伟大贡献！
  > *The core compression/extraction engine is powered by 7-Zip, an outstanding open-source project created by Igor Pavlov. We are deeply grateful for his contributions to the open-source community.*
- **[GRDB.swift](https://github.com/groue/GRDB.swift)** — 优雅的 Swift SQLite 工具库，用于密码库存储。
- **[Apple SwiftUI](https://developer.apple.com/swiftui/)** — 构建原生 macOS 用户界面。

## 📄 许可证 | License

本项目基于 [LGPL-2.1](LICENSE) 许可证开源。

7-Zip 引擎 (`7zz`) 遵循 [LGPL-2.1](https://www.7-zip.org/license.txt) 许可及 unRAR 限制条款。

This project is licensed under [LGPL-2.1](LICENSE).
The 7-Zip engine (`7zz`) is licensed under [LGPL-2.1](https://www.7-zip.org/license.txt) with unRAR restriction.

---

<div align="center">

**如压** — 让解压缩回归简单与自由 ✨

*iLab-zip — Making archive management simple and free* ✨

</div>
