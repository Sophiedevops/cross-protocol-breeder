@echo off
chcp 65001 >NUL
setlocal

set "SB_DIR=%~dp0"
cd /d "%SB_DIR%"

set "EXE=%SB_DIR%sing-box.exe"
set "CFG_HYBRID=%SB_DIR%conf_chain6.json"
set "CFG_BASE=%SB_DIR%conf3_final.json"

if not exist "%EXE%" (
    echo [ERR] sing-box.exe not found
    pause
    exit /b 1
)

REM Выбираем конфиг
if exist "%CFG_HYBRID%" (
    set "CFG=%CFG_HYBRID%"
) else (
    set "CFG=%CFG_BASE%"
    echo [WARN] conf_chain6.json not found, using conf3_final.json
    echo [INFO] Run update_hybrid.ps1 first to build hybrid config
)

REM Останавливаем старый процесс
taskkill /F /IM sing-box.exe 2>NUL
timeout /t 1 >NUL

echo.
echo ============================================================
echo   sing-box PROXY mode
echo   SOCKS5: 127.0.0.1:20184
echo   HTTP:   127.0.0.1:20181
echo ============================================================
echo.

"%EXE%" run -c "%CFG%"

echo.
echo [INFO] sing-box stopped
pause

