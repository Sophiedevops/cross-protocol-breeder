@echo off
REM install-windows.bat — качает и запускает install-windows.ps1
set "PS_URL=https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main/install-windows.ps1"
set "PS_FILE=%TEMP%\install-windows.ps1"

echo Downloading installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "(New-Object Net.WebClient).DownloadFile('%PS_URL%', '%PS_FILE%')"
if errorlevel 1 (
    echo [ERR] Download failed
    pause
    exit /b 1
)

echo Running installer...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_FILE%" %*
