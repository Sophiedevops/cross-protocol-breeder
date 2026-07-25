@echo off
REM Cross-Protocol Breeder - Windows CMD Installer
REM Использование: install-windows.bat [proxy^|tun^|full]

setlocal EnableDelayedExpansion

color 0A
echo.
echo ================================================================
echo   Cross-Protocol Breeder - Windows CMD Installer v3.3
echo ================================================================
echo.

set "MODE=%~1"
if "%MODE%"=="" set "MODE=full"

set "INSTALL_PATH=%LOCALAPPDATA%\cross-protocol-breeder"
set "SB_VERSION=1.13.14-extended-2.5.2"
set "REPO_BASE=https://github.com/Sophiedevops/cross-protocol-breeder"
set "BINARY_BASE=%REPO_BASE%/releases/download/Binary"
set "RAW_BASE=https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main"

REM Определяем архитектуру
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "ARCH=arm64"
    set "ASSET=sing-box-%SB_VERSION%-windows-arm64.zip"
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    set "ARCH=386"
    set "ASSET=sing-box-%SB_VERSION%-windows-386.zip"
) else (
    set "ARCH=amd64"
    set "ASSET=sing-box-%SB_VERSION%-windows-amd64.zip"
)

echo [INFO] Architecture: %ARCH%
echo [INFO] Install path:  %INSTALL_PATH%
echo [INFO] Mode:          %MODE%
echo.

REM Создаём каталог
if not exist "%INSTALL_PATH%" mkdir "%INSTALL_PATH%"
cd /d "%INSTALL_PATH%"

echo [STEP 1/5] Download sing-box...
echo   URL: %BINARY_BASE%/%ASSET%

REM Используем PowerShell для скачивания (всегда есть)
powershell -NoProfile -Command ^
    "try { (New-Object System.Net.WebClient).DownloadFile('%BINARY_BASE%/%ASSET%', '%ASSET%') } catch { exit 1 }"
if errorlevel 1 (
    echo [ERR] Download failed
    exit /b 1
)
echo [OK] Downloaded

echo.
echo [STEP 2/5] Extract...
powershell -NoProfile -Command "Expand-Archive -Path '%ASSET%' -DestinationPath '.' -Force"
if errorlevel 1 (
    echo [ERR] Extract failed
    exit /b 1
)
del /f /q "%ASSET%"
echo [OK] Extracted

REM Ищем sing-box.exe
set "EXE_PATH="
for /r %%i in (sing-box.exe) do (
    if exist "%%i" (
        set "EXE_PATH=%%i"
        goto :found
    )
)
:found
if "%EXE_PATH%"=="" (
    echo [ERR] sing-box.exe not found
    exit /b 1
)
echo [OK] Binary: %EXE_PATH%

echo.
echo [STEP 3/5] Test binary...
"%EXE_PATH%" version
if errorlevel 1 (
    echo [ERR] Binary doesn't work
    exit /b 1
)
echo [OK] Working

echo.
echo [STEP 4/5] Download scripts & config...
powershell -NoProfile -Command ^
    "$files = @('update_hybrid.sh', 'converter.lua', 'conf3_final.json', 'gen_links.sh'); ^
     foreach ($f in $files) { ^
         try { Invoke-WebRequest -Uri '%RAW_BASE%/' + $f -OutFile $f -UseBasicParsing; Write-Host ('  [OK] ' + $f) } ^
         catch { Write-Host ('  [ERR] ' + $f) } ^
     }"

REM PS-аналоги
powershell -NoProfile -Command ^
    "$files = @('update_hybrid.ps1', 'gen_links.ps1', 'scheduler_setup.ps1'); ^
     foreach ($f in $files) { ^
         try { Invoke-WebRequest -Uri '%RAW_BASE%/windows/' + $f -OutFile $f -UseBasicParsing; Write-Host ('  [OK] ' + $f) } ^
         catch { Write-Host ('  [WARN] ' + $f + ' (optional)') } ^
     }"

echo.
echo [STEP 5/5] Download .bat wrappers...
powershell -NoProfile -Command ^
    "$bats = @('start-proxy.bat', 'start-tun.bat', 'stop.bat', 'update-and-start.bat', 'uninstall.bat'); ^
     foreach ($b in $bats) { ^
         try { Invoke-WebRequest -Uri '%RAW_BASE%/windows/' + $b -OutFile $b -UseBasicParsing; Write-Host ('  [OK] ' + $b) } ^
         catch { Write-Host ('  [WARN] ' + $b) } ^
     }"

echo.
echo ================================================================
echo   Installation Complete!
echo ================================================================
echo.
echo   Path:     %INSTALL_PATH%
echo   Binary:   %EXE_PATH%
echo.
echo   FIRST RUN (required):
echo     powershell -ExecutionPolicy Bypass -File "%INSTALL_PATH%\update_hybrid.ps1"
echo     powershell -ExecutionPolicy Bypass -File "%INSTALL_PATH%\gen_links.ps1"
echo.
echo   Then use:
echo     start-proxy.bat     - запустить как прокси
echo     start-tun.bat       - запустить TUN (нужен админ)
echo     stop.bat            - остановить
echo     update-and-start.bat - обновить и запустить
echo.
pause
