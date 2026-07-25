@echo off
REM Запуск sing-box в TUN-режиме (глобальный прокси всей системы)
REM ТРЕБУЕТ прав администратора!

setlocal
set "SB_DIR=%~dp0"
set "SB_EXE=%SB_DIR%sing-box.exe"
set "CONFIG=%SB_DIR%conf3_final.json"
set "CONFIG_HYBRID=%SB_DIR%conf_chain6.json"

cd /d "%SB_DIR%"

REM Проверяем права админа
net session >NUL 2>&1
if errorlevel 1 (
    echo [ERR] TUN mode requires Administrator privileges!
    echo [INFO] Right-click and "Run as administrator"
    pause
    exit /b 1
)

if not exist "%SB_EXE%" (
    echo [ERR] sing-box.exe not found
    pause
    exit /b 1
)

REM TUN-конфиг (динамически создаём если нет)
set "TUN_CONFIG=%SB_DIR%conf_tun.json"
if not exist "%TUN_CONFIG%" (
    echo [INFO] Creating TUN config...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SB_DIR%generate_tun_config.ps1"
    if errorlevel 1 (
        echo [ERR] Failed to create TUN config
        pause
        exit /b 1
    )
)

echo.
echo ============================================================
echo   Starting sing-box in TUN mode (GLOBAL)
echo   ALL system traffic will be routed through proxy
echo ============================================================
echo.
echo   To use: just keep this window open
echo   To stop: close this window or run stop.bat
echo.

tasklist /FI "IMAGENAME eq sing-box.exe" 2>NUL | find /I /N "sing-box.exe">NUL
if not errorlevel 1 (
    echo [WARN] sing-box is already running. Stopping...
    taskkill /F /IM sing-box.exe >NUL 2>&1
    timeout /t 2 >NUL
)

"%SB_EXE%" run -c "%TUN_CONFIG%"

echo.
echo [INFO] sing-box stopped
pause
