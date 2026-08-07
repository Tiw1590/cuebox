@echo off
chcp 65001 >nul
cd /d "%~dp0"

where flutter >nul 2>nul
if errorlevel 1 (
  echo [错误] 未找到 Flutter 命令，请先安装 Flutter SDK 并加入 PATH。
  pause
  exit /b 1
)

echo 以调试模式运行（可热重载）...
call flutter run -d windows
pause
