@echo off
REM Обновление + запуск. Используется в планировщике.
REM Или вручную: update-and-start.bat proxy  ИЛИ  update-and-start.bat tun

set "MODE=%~1"
if "%MODE%"=="" set "MODE=proxy"

set "SB_DIR=%~dp0"

echo.
echo ============================================================
echo   Cross-Protocol Breeder - Update ^& Start (%MODE% mode)
echo ============================================================
echo.

cd /d "%SB_DIR%"

REM [1] Останавливаем старый процесс
echo [1/4] Stopping old instance...
call stop.bat
echo.

REM [2] Обновляем конфиг (PowerShell-аналог update_hybrid.sh)
echo [2/4] Updating hybrid configs...
powershell -NoProfile -ExecutionPolicy Bypass -File "update_hybrid.ps1"
if errorlevel 1 (
    echo [WARN] update_hybrid.ps1 failed, continuing with current config
)
echo.

REM [3] Генерируем ссылки
echo [3/4] Generating client links...
powershell -NoProfile -ExecutionPolicy Bypass -File "gen_links.ps1"
if errorlevel 1 (
    echo [WARN] gen_links.ps1 failed
)
echo.

REM [4] Запускаем
echo [4/4] Starting sing-box...
if /i "%MODE%"=="tun" (
    call start-tun.bat
) else (
    call start-proxy.bat
)

echo.
echo [OK] Done
