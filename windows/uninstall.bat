@echo off
REM Полное удаление Cross-Protocol Breeder

echo.
echo ============================================================
echo   Cross-Protocol Breeder - Uninstaller
echo ============================================================
echo.

set "SB_DIR=%~dp0"

echo [1/5] Stopping sing-box...
call stop.bat

echo.
echo [2/5] Removing scheduled task...
schtasks /delete /tn "CrossProtocolBreeder.Update" /f >NUL 2>&1
echo   [OK] Task removed

echo.
echo [3/5] Removing from PATH (user)...
powershell -NoProfile -Command ^
    "$p = [Environment]::GetEnvironmentVariable('Path', 'User'); ^
     $p = ($p -split ';' | Where-Object { $_ -ne '%SB_DIR%' }) -join ';'; ^
     [Environment]::SetEnvironmentVariable('Path', $p, 'User')"
echo   [OK] PATH cleaned

echo.
echo [4/5] Removing firewall rules...
netsh advfirewall firewall delete rule name="Cross-Protocol Breeder" >NUL 2>&1
echo   [OK] Firewall cleaned

echo.
echo [5/5] Removing files...
set "REMOVE_DIR=%SB_DIR%.."
echo   About to remove: %REMOVE_DIR%
set /p "CONFIRM=  Are you sure? (yes/no): "
if /i "%CONFIRM%"=="yes" (
    rmdir /s /q "%REMOVE_DIR%" 2>NUL
    if exist "%REMOVE_DIR%" (
        echo   [WARN] Some files could not be removed. Remove manually: %REMOVE_DIR%
    ) else (
        echo   [OK] Removed: %REMOVE_DIR%
    )
) else (
    echo   [INFO] Cancelled
)

echo.
echo Uninstallation complete.
pause
