@echo off
chcp 65001 >NUL
setlocal

set "SB_DIR=%~dp0"
cd /d "%SB_DIR%"

REM Проверяем админа
net session >NUL 2>&1
if errorlevel 1 (
    echo [ERR] TUN requires Administrator privileges!
    echo [INFO] Right-click - Run as administrator
    pause
    exit /b 1
)

set "EXE=%SB_DIR%sing-box.exe"
set "TUN_CFG=%SB_DIR%conf_tun.json"

if not exist "%EXE%" (
    echo [ERR] sing-box.exe not found
    pause
    exit /b 1
)

REM Генерируем TUN-конфиг если нет
if not exist "%TUN_CFG%" (
    echo [INFO] Creating TUN config...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SB_DIR%generate_tun_config.ps1"
    if errorlevel 1 (
        echo [ERR] Failed to create TUN config
        pause
        exit /b 1
    )
)

taskkill /F /IM sing-box.exe 2>NUL
timeout /t 1 >NUL

echo.
echo ============================================================
echo   sing-box TUN mode (GLOBAL proxy)
echo   All system traffic will be routed through proxy
echo ============================================================
echo.

"%EXE%" run -c "%TUN_CFG%"

echo.
echo [INFO] sing-box stopped
pause
