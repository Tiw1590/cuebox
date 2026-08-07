#!/bin/bash
# CueBox macOS 一键构建（本地测试版，免安装）
set -e
cd "$(dirname "$0")"

echo "=========================================="
echo "  CueBox macOS 一键构建"
echo "=========================================="
echo

if ! command -v flutter >/dev/null 2>&1; then
  echo "[错误] 未找到 Flutter 命令，请先安装 Flutter SDK。"
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "[错误] 未找到完整 Xcode。"
  echo "请先到 App Store 安装 Xcode，然后执行："
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -runFirstLaunch"
  exit 1
fi

echo "[1/2] 拉取依赖..."
flutter pub get

echo "[2/2] 构建 Release 版..."
flutter build macos --release

echo
echo "=========================================="
echo "  构建完成！App 位置："
echo "  build/macos/Build/Products/Release/CueBox.app"
echo "  双击 CueBox.app 即可运行（免安装）。"
echo "=========================================="
open "build/macos/Build/Products/Release"
