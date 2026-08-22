# 🎛️ CueBox

**现场表演音效 Cue 播放器** —— 面向舞台演出、剧场、Live 现场的多轨音效播放与编排工具。

CueBox 让你像操作节目单一样管理音效:提前编排好一条条"Cue"（音效点），演出时一键触发，支持多轨叠加、波形可视化编辑与即时切换，为现场演出提供稳定可靠的声音控制。

> ⚡ 一套代码，多端运行 —— 基于 [Flutter](https://flutter.dev) 构建，支持 macOS、Windows、iOS、Android。

---

## ✨ 功能特性

- 🎵 **多轨音效播放** —— 基于 `just_audio` 引擎，支持多路音效同时播放与独立控制
- 📊 **波形可视化** —— 音频波形展示与缓存，直观预览每条 Cue 的内容
- 📁 **多素材文件夹** —— 素材库可添加多个文件夹统一管理，再次打开自动定位到最后一次导入音频的目录
- ✂️ **Cue 编辑** —— 拖拽/裁剪音频片段，精准设定起止点（音频槽位编辑器）
- 📋 **演出编排** —— 以"Show"为单位组织演出，管理 Cue 列表与触发顺序
- 🛒 **快速触发面板** —— 类 Cart 面板，演出中一键点选触发
- 🎨 **双主题** —— 深色（舞台暗光）、浅色（Apple 玻璃质感），可随时切换并记忆选择
  - 🌑 **深色「舞台暗光」**：越黑越有纵深感的蓝黑渐变、冷色氛围光与柔和辉光，适合剧院/演出现场的暗场操作
  - 🪟 **浅色「Liquid Glass」**：透出渐变底色的白色玻璃卡片、蓝紫柔光折射带、高光描边与 Apple 系统色，清爽但更有层次
- 📱 **跨平台** —— macOS / Windows / iOS / Android 一套代码全覆盖

---

## 🖥️ 支持的平台

| 平台 | 状态 | 产物 |
|---|---|---|
| 🍎 macOS | ✅ | `.app`（免安装，拖出即用） |
| 🪟 Windows | ✅ | 便携版目录（双击 `cuebox.exe` 运行） |
| 📱 iOS | ✅ | 签名 IPA（需 Apple 开发者证书） |
| 🤖 Android | ✅ | `APK` 安装包 |

---

## 🚀 本地开发

### 环境要求

- [Flutter SDK](https://docs.flutter.dev/get-started/install)（Channel stable）
- **macOS 构建**：完整版 [Xcode](https://developer.apple.com/xcode/) + CocoaPods
- **Windows 构建**：Visual Studio 2022（勾选"使用 C++ 的桌面开发"）

### 运行

```bash
# 克隆仓库
git clone https://github.com/Tiw1590/cuebox.git
cd cuebox

# 拉取依赖
flutter pub get

# 在指定平台运行（任选）
flutter run -d macos     # macOS
flutter run -d windows   # Windows
flutter run -d chrome    # Web（如已启用）
flutter run             # 默认设备
```

### 一键构建（本地）

项目内置了平台构建脚本，产出**免安装**的便携版本：

```bash
# macOS —— 构建后自动打开产物目录
./build_macos.sh

# Windows —— 在 cmd 中执行
build_windows.bat
```

---

## 🤖 云端自动构建（GitHub Actions）

项目内置 GitHub Actions 流水线（`.github/workflows/build.yml`），推送到 `main` 分支即自动触发，**云端并行构建全部平台**，产物可在 Actions 页面下载。

### 日常开发流程

```bash
# 修改代码后
git add -A
git commit -m "你的改动说明"
git push          # 自动触发多平台构建
```

### 发布正式版本

打版本标签即可触发构建：

```bash
git tag v1.0.0
git push origin v1.0.0
```

查看构建进度与下载产物：

- **Actions 页面**：<https://github.com/Tiw1590/cuebox/actions>
- 每个平台任务完成后会生成对应安装包，可直接下载分发
  - `cuebox-android-apk` —— Android APK
  - `cuebox-ios-unsigned` —— iOS（未签名 .app）
  - `cuebox-macos` —— macOS .app
  - `cuebox-windows` —— Windows 便携版

---

## 🗂️ 项目结构

```
lib/
├── main.dart                    # 入口
├── app.dart                     # 应用根组件
├── core/                        # 核心基础层
│   ├── audio/                   # 音频会话配置
│   ├── platform/                # 平台相关（媒体访问 / SAF 通道 / 波形缓存）
│   └── widgets/                 # 通用组件（波形、编辑器、主题等）
└── features/                    # 业务功能模块
    ├── home/                    # 主界面外壳
    ├── cue/                     # Cue 列表与控制
    ├── show/                    # 演出编排与数据模型
    ├── media/                   # 媒体库
    ├── playback/                # 播放引擎
    ├── cart/                    # 快速触发面板
    └── settings/                # 设置
```

### 技术栈

- **状态管理**：`flutter_riverpod`
- **音频播放**：`just_audio` / `audio_session`
- **本地存储**：`shared_preferences` / `path_provider`
- **平台适配**：`just_audio_windows`

---

## 📄 License

本项目为私有项目，保留所有权利。未经授权请勿用于商业用途。
