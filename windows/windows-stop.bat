@echo off
REM Остановка всех процессов sing-box

echo.
echo [INFO] Stopping sing-box...

taskkill /F /IM sing-box.exe 2>NUL
if errorlevel 1 (
    echo [INFO] No running sing-box processes found
) else (
    echo [OK] sing-box stopped
)

REM Чистим DNS-кеш (на случай если был TUN)
ipconfig /flushdns >NUL 2>&1
echo [OK] DNS cache flushed

echo.
pause
