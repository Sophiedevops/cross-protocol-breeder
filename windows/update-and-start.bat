@echo off
chcp 65001 >NUL

set "MODE=%~1"
if "%MODE%"=="" set "MODE=proxy"

set "SB_DIR=%~dp0"
cd /d "%SB_DIR%"

echo.
echo ============================================================
echo   Cross-Protocol Breeder - Update and Start [%MODE%]
echo ============================================================
echo.

echo [1/4] Stopping old instance...
call "%SB_DIR%stop.bat" >NUL

echo [2/4] Updating hybrid configs...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SB_DIR%update_hybrid.ps1"
if errorlevel 1 echo   [WARN] update_hybrid.ps1 failed

echo.
echo [3/4] Generating client links...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SB_DIR%gen_links.ps1"
if errorlevel 1 echo   [WARN] gen_links.ps1 failed

echo.
echo [4/4] Starting sing-box...
if /i "%MODE%"=="tun" (
    call "%SB_DIR%start-tun.bat"
) else (
    call "%SB_DIR%start-proxy.bat"
)

echo.
echo [OK] Done
pause
