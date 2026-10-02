@echo off
chcp 65001 >nul
title AI 生图工作台 · 本地代理
cd /d "%~dp0"

rem 一键启动：起本地静态+转发服务，再开浏览器。
rem 注意：python server.py 是阻塞式运行，start 开浏览器必须在其之前调用
rem （python 毫秒级就绪，浏览器打开需 1-2 秒，服务实际先就绪；
rem   万一页面先于服务加载，页面每 30 秒自动重探、也可点设置栏「重探」）。

where python >nul 2>nul
if %errorlevel%==0 (
    start "" http://127.0.0.1:8765
    python server.py
    goto :stopped
)

where py >nul 2>nul
if %errorlevel%==0 (
    start "" http://127.0.0.1:8765
    py server.py
    goto :stopped
)

echo [错误] 未找到 python / py 命令。
echo 请先安装 Python 3（安装时勾选 "Add python.exe to PATH"）后重试：
echo   https://www.python.org/downloads/
pause
exit /b 1

:stopped
echo.
echo 本地服务已停止（窗口可直接关闭）。
pause
