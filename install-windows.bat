@echo off
REM install-windows.bat - minimal wrapper, only downloads and runs PS1
chcp 65001 >NUL

set "PS_URL=https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install-windows.ps1"
set "PS_FILE=%TEMP%\cross-protocol-breeder-install.ps1"
set "RAW_URL=https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main"
set "INSTALL_DIR=%LOCALAPPDATA%\cross-protocol-breeder"

echo.
echo ================================================================
echo   Cross-Protocol Breeder - Windows Installer
echo ================================================================
echo.

REM Clean previous
if exist "%PS_FILE%" del /f /q "%PS_FILE%"

echo [1/3] Downloading installer script...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { (New-Object System.Net.WebClient).DownloadFile('%PS_URL%', '%PS_FILE%'); exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo [ERR] Failed to download installer
    echo [INFO] Check internet connection
    pause
    exit /b 1
)

if not exist "%PS_FILE%" (
    echo [ERR] Installer file not found after download
    pause
    exit /b 1
)

for %%I in ("%PS_FILE%") do set "SIZE=%%~zI"
echo [OK] Downloaded: %SIZE% bytes

echo.
echo [2/3] Running installer (this may take a few minutes)...
echo.

REM Pass all arguments to PS1
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_FILE%" -InstallDir "%INSTALL_DIR%" %*

set "EXITCODE=%errorlevel%"

echo.
echo [3/3] Done (exit code: %EXITCODE%)
pause
exit /b %EXITCODE%
