@echo off
chcp 65001 >NUL
setlocal

echo.
echo [INFO] Stopping sing-box...
taskkill /F /IM sing-box.exe 2>NUL
if errorlevel 1 (
    echo [INFO] No running processes
) else (
    echo [OK] Stopped
)

ipconfig /flushdns >NUL 2>&1
echo [OK] DNS cache flushed
echo.
pause
