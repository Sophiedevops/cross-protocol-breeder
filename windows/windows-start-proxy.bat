@echo off
REM Запуск sing-box в режиме прокси (SOCKS5/HTTP)
REM Не требует прав администратора

setlocal
set "SB_DIR=%~dp0"
set "SB_EXE=%SB_DIR%sing-box.exe"
set "CONFIG=%SB_DIR%conf3_final.json"
set "CONFIG_HYBRID=%SB_DIR%conf_chain6.json"

cd /d "%SB_DIR%"

if not exist "%SB_EXE%" (
    echo [ERR] sing-box.exe not found
    pause
    exit /b 1
)

REM Используем гибридный конфиг если есть, иначе базовый
if exist "%CONFIG_HYBRID%" (
    set "CFG=%CONFIG_HYBRID%"
    echo [INFO] Using hybrid config: conf_chain6.json
) else (
    set "CFG=%CONFIG%"
    echo [INFO] Using base config: conf3_final.json
    echo [INFO] (Run update_hybrid.ps1 to generate hybrid config)
)

echo.
echo ============================================================
echo   Starting sing-box in PROXY mode
echo   SOCKS5: 127.0.0.1:20184
echo   HTTP:   127.0.0.1:20181
echo   Mixed:  127.0.0.1:20185
echo ============================================================
echo.
echo   To use: configure your browser/app to use these proxies
echo   To stop: close this window or run stop.bat
echo.

REM Проверяем, не запущен ли уже
tasklist /FI "IMAGENAME eq sing-box.exe" 2>NUL | find /I /N "sing-box.exe">NUL
if not errorlevel 1 (
    echo [WARN] sing-box is already running. Stopping old instance...
    taskkill /F /IM sing-box.exe >NUL 2>&1
    timeout /t 2 >NUL
)

"%SB_EXE%" run -c "%CFG%"

echo.
echo [INFO] sing-box stopped
pause
