
@echo off
chcp 65001
echo ========================================
echo 🦞 OpenClaw 24小时员工 启动脚本
echo ========================================
echo.
echo [1/3] 检查 Ollama...
tasklist /FI "IMAGENAME eq ollama.exe" 2>NUL | find /I /N "ollama.exe">NUL
if "%ERRORLEVEL%"=="0" (
    echo ✅ Ollama 已在运行
) else (
    echo 🚀 启动 Ollama...
    start "" ollama serve
    timeout /t 5 /nobreak
)

echo.
echo [2/3] 启动 OpenClaw 网关...
echo.
echo ========================================
echo ⚠️  重要提示：
echo    请勿关闭此窗口！
echo    关闭窗口 = 停止24小时员工下班
echo ========================================
echo.
echo [3/3] 正在启动...
echo.

C:\Users\1\.openclaw\gateway.cmd

pause
