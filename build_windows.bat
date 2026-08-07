@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ==========================================
echo   CueBox Windows 一键构建（免安装便携版）
echo ==========================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo [错误] 未找到 Flutter 命令。
  echo 请先安装 Flutter SDK 并加入 PATH：
  echo   https://docs.flutter.dev/get-started/install/windows
  echo 另外需要 Visual Studio 2022，勾选“使用 C++ 的桌面开发”。
  pause
  exit /b 1
)

echo [1/2] 拉取依赖...
call flutter pub get
if errorlevel 1 (
  echo [错误] 依赖拉取失败。
  pause
  exit /b 1
)

echo [2/2] 构建 Release 版...
call flutter build windows --release
if errorlevel 1 (
  echo [错误] 构建失败，请把上方日志发给我。
  pause
  exit /b 1
)

echo.
echo ==========================================
echo   构建完成！便携版位置：
echo   build\windows\x64\runner\Release\
echo.
echo   把整个 Release 文件夹拷到任何 Windows 电脑，
echo   双击 cuebox.exe 即可运行，无需安装。
echo ==========================================
explorer "build\windows\x64\runner\Release"
pause
