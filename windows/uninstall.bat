@echo off
chcp 65001 >NUL
setlocal

set "SB_DIR=%~dp0"
cd /d "%SB_DIR%"

echo.
echo ============================================================
echo   Cross-Protocol Breeder - Uninstaller
echo ============================================================
echo.

echo [1/5] Stopping sing-box...
taskkill /F /IM sing-box.exe 2>NUL
echo   [OK]

echo [2/5] Removing scheduled task...
schtasks /delete /tn "CrossProtocolBreeder.Update" /f >NUL 2>&1
echo   [OK]

echo [3/5] Removing firewall rules...
netsh advfirewall firewall delete rule name="Cross-Protocol Breeder" >NUL 2>&1
echo   [OK]

echo [4/5] Removing from PATH...
powershell -NoProfile -Command ^
    "$env:Path = ($env:Path -split ';' | Where-Object { $_ -ne '%SB_DIR%' }) -join ';'; [Environment]::SetEnvironmentVariable('Path', $env:Path, 'User')"
echo   [OK]

echo [5/5] Removing files...
set /p "CONFIRM=  Remove folder %SB_DIR%? (yes/no): "
if /i "%CONFIRM%"=="yes" (
    cd /d "%TEMP%"
    rmdir /s /q "%SB_DIR%" 2>NUL
    if exist "%SB_DIR%" (
        echo   [WARN] Some files locked. Close sing-box and try again.
    ) else (
        echo   [OK] Removed
    )
) else (
    echo   [INFO] Cancelled
)

echo.
echo Done.
pause
