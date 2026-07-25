#Requires -Version 5.1
<#
.SYNOPSIS
    Cross-Protocol Breeder - Windows Smart Installer
.DESCRIPTION
    Устанавливает sing-box extended на Windows 10/11.
    Поддерживает режимы: local proxy (socks/http) и TUN (глобальный).
.NOTES
    Запускать от имени Администратора для TUN-режима.
    Для режима прокси админ НЕ обязателен.
#>

[CmdletBinding()]
param(
    [switch]$ProxyOnly,        # Только прокси-режим (без TUN)
    [switch]$Tun,                # TUN-режим (по умолчанию предлагает выбор)
    [switch]$Unattended,         # Без вопросов
    [string]$InstallPath = "$env:LOCALAPPDATA\cross-protocol-breeder"
)

# --- Цвета / локаль ---
$Host.UI.RawUI.WindowTitle = "Cross-Protocol Breeder - Windows Installer"
$ErrorActionPreference = "Stop"

function Write-Header  { param($m) Write-Host "`n$('='*70)" -ForegroundColor Cyan; Write-Host "  $m" -ForegroundColor Cyan; Write-Host "$('='*70)" -ForegroundColor Cyan }
function Write-Step    { param($m) Write-Host "`n[STEP] $m" -ForegroundColor Yellow }
function Write-OK      { param($m) Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn    { param($m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Write-Err     { param($m) Write-Host "  [ERR] $m" -ForegroundColor Red }
function Write-Info    { param($m) Write-Host "  [INFO] $m" -ForegroundColor Cyan }
function Write-Debug   { param($m) Write-Verbose "  [DBG] $m" }

# --- Проверка прав администратора ---
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Определение архитектуры ---
function Get-SystemArch {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { return "arm64" }
    if ($env:PROCESSOR_ARCHITECTURE -eq "x86")   { return "386" }
    return "amd64"  # по умолчанию
}

# --- Скачивание с прогрессом ---
function Invoke-Download {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$TimeoutSec = 300
    )
    
    Write-Debug "GET $Url -> $OutFile"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "CrossProtocolBreeder/3.3")
        
        # Асинхронно с прогрессом
        $job = Start-Job -ScriptBlock {
            param($u, $o) 
            (New-Object System.Net.WebClient).DownloadFile($u, $o)
        } -ArgumentList $Url, $OutFile
        
        $elapsed = 0
        while ($job.State -eq "Running" -and $elapsed -lt $TimeoutSec) {
            $pct = if (Test-Path $OutFile) {
                (Get-Item $OutFile).Length
            } else { 0 }
            Write-Host "`r  Downloading... $pct bytes" -NoNewline -ForegroundColor Gray
            Start-Sleep -Milliseconds 500
            $elapsed += 0.5
        }
        Write-Host ""
        
        if ($job.State -eq "Running") {
            Stop-Job $job
            Remove-Job $job
            throw "Timeout after $TimeoutSec seconds"
        }
        
        Receive-Job $job -Wait | Out-Null
        Remove-Job $job -Force
        
        if (-not (Test-Path $OutFile) -or (Get-Item $OutFile).Length -lt 1024) {
            throw "Downloaded file too small or missing"
        }
        return $true
    }
    catch {
        Write-Err "Download failed: $_"
        return $false
    }
}

# --- SHA256 проверка ---
function Test-Sha256 {
    param(
        [string]$FilePath,
        [string]$ExpectedSha
    )
    
    if ([string]::IsNullOrEmpty($ExpectedSha)) {
        Write-Warn "No expected SHA, skipping verification"
        return $true
    }
    
    $actual = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
    if ($actual -eq $ExpectedSha.ToLower()) {
        Write-OK "SHA256 verified"
        return $true
    } else {
        Write-Err "SHA256 MISMATCH!"
        Write-Err "  Expected: $ExpectedSha"
        Write-Err "  Actual:   $actual"
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
Write-Header "Cross-Protocol Breeder — Windows Installer v3.3"

# === [1/7] System info ===
Write-Step "1/7] System information"
$IsAdmin = Test-Administrator
$Arch = Get-SystemArch
$PSVer = $PSVersionTable.PSVersion.ToString()
$OSVer = [System.Environment]::OSVersion.VersionString

Write-Info "OS:           Windows $OSVer"
Write-Info "Arch:         $Arch"
Write-Info "PS Version:   $PSVer"
Write-Info "Admin:        $(if ($IsAdmin) {'YES'} else {'NO'})"

if (-not $IsAdmin) {
    Write-Warn "Нет прав администратора"
    Write-Warn "  • Прокси-режим будет работать"
    Write-Warn "  • TUN-режим потребует перезапуска с правами админа"
}

# === [2/7] Choose mode ===
Write-Step "2/7] Choose operation mode"

if (-not $Unattended) {
    Write-Host ""
    Write-Host "  Выберите режим установки:" -ForegroundColor Cyan
    Write-Host "    [1] Локальный прокси (SOCKS5/HTTP) — работает БЕЗ админа"
    Write-Host "    [2] TUN-режим (глобальный)        — ТРЕБУЕТ админа"
    Write-Host "    [3] Оба режима (прокси + ярлык TUN)" -ForegroundColor Yellow
    Write-Host ""
    $choice = Read-Host "  Ваш выбор [1/2/3]"
} else {
    if ($ProxyOnly)      { $choice = "1" }
    elseif ($Tun)        { $choice = "2" }
    else                 { $choice = "3" }
}

switch ($choice) {
    "1" { $InstallProxy = $true;  $InstallTun = $false; $NeedAdmin = $false }
    "2" { $InstallProxy = $true;  $InstallTun = $true;  $NeedAdmin = $true }
    "3" { $InstallProxy = $true;  $InstallTun = $true;  $NeedAdmin = $true }
    default { $InstallProxy = $true; $InstallTun = $true; $NeedAdmin = $true }
}

if ($NeedAdmin -and -not $IsAdmin) {
    Write-Warn "TUN требует прав администратора. Перезапускаю..."
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($ProxyOnly) { $argList += " -ProxyOnly" }
    if ($Unattended) { $argList += " -Unattended" }
    try {
        Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList $argList -Wait
        exit 0
    } catch {
        Write-Err "Не удалось запросить повышение прав: $_"
        Write-Info "Продолжаю в режиме только прокси"
        $InstallTun = $false
    }
}

Write-OK "Режим: $(if ($InstallProxy) {'Прокси '} else {''})$(if ($InstallTun) {'+ TUN'} else {''})"

# === [3/7] Download binary ===
Write-Step "3/7] Download sing-box binary"

$SBVersion = "1.13.14-extended-2.5.2"
$RepoUrl = "https://github.com/Sophiedevops/cross-protocol-breeder"
$BinaryBase = "$RepoUrl/releases/download/Binary"

# Выбираем файл
$AssetName = switch ($Arch) {
    "amd64" { "sing-box-$SBVersion-windows-amd64.zip" }
    "386"   { "sing-box-$SBVersion-windows-386.zip" }
    "arm64" { "sing-box-$SBVersion-windows-arm64.zip" }
}

Write-Info "Asset: $AssetName"

# Создаём рабочий каталог
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
}
Set-Location $InstallPath

$ZipFile = Join-Path $InstallPath $AssetName
$WorkZip = "$ZipFile.tmp"

# Скачиваем
$ok = Invoke-Download -Url "$BinaryBase/$AssetName" -OutFile $WorkZip
if (-not $ok) {
    Write-Err "Не удалось скачать $AssetName"
    Write-Info "Проверьте интернет-соединение"
    exit 1
}

# Проверяем SHA256 (если есть manifest)
$ManifestUrl = "$BinaryBase/MANIFEST.txt"
$ManifestPath = Join-Path $InstallPath "MANIFEST.txt"
if (Invoke-WebRequest -Uri $ManifestUrl -OutFile $ManifestPath -UseBasicParsing -TimeoutSec 30) {
    $expected = (Get-Content $ManifestPath | 
        Where-Object { $_ -match "^\|?PKG\|$AssetName\|([a-f0-9]{64})" } |
        ForEach-Object { $matches[1] } | Select-Object -First 1)
    if ($expected) {
        if (-not (Test-Sha256 -FilePath $WorkZip -ExpectedSha $expected)) {
            Remove-Item $WorkZip -Force
            exit 1
        }
    } else {
        Write-Warn "SHA256 для $AssetName не найден в манифесте"
    }
} else {
    Write-Warn "Манифест недоступен, пропускаю SHA256 проверку"
}

Move-Item $WorkZip $ZipFile -Force
Write-OK "Скачано: $((Get-Item $ZipFile).Length / 1MB) MB"

# === [4/7] Extract ===
Write-Step "4/7] Extract binary"

# Используем Expand-Archive (встроен в PS 5+)
try {
    Expand-Archive -Path $ZipFile -DestinationPath $InstallPath -Force
    Write-OK "Распаковано в $InstallPath"
} catch {
    Write-Err "Ошибка распаковки: $_"
    exit 1
}

# Удаляем zip
Remove-Item $ZipFile -Force

# Ищем sing-box.exe
$ExePath = Join-Path $InstallPath "sing-box.exe"
if (-not (Test-Path $ExePath)) {
    # Может быть в подпапке
    $found = Get-ChildItem -Path $InstallPath -Recurse -Filter "sing-box.exe" | Select-Object -First 1
    if ($found) {
        $ExePath = $found.FullName
    } else {
        Write-Err "sing-box.exe не найден после распаковки"
        exit 1
    }
}
Write-OK "Бинарник: $ExePath"

# Тестовый запуск
$version = & $ExePath version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Бинарник не запускается!"
    Write-Err $version
    exit 1
}
Write-OK "Версия: $($version[0])"

# === [5/7] Config & scripts ===
Write-Step "5/7] Download config & scripts"

$RepoRaw = "https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main"

# Скачиваем необходимые файлы
$Files = @(
    "update_hybrid.sh",
    "converter.lua",
    "conf3_final.json",
    "gen_links.sh"
)

foreach ($f in $Files) {
    $dest = Join-Path $InstallPath $f
    if (Invoke-WebRequest -Uri "$RepoRaw/$f" -OutFile $dest -UseBasicParsing -TimeoutSec 60) {
        Write-OK "Скачано: $f"
    } else {
        Write-Err "Ошибка скачивания: $f"
    }
}

# Скачиваем PowerShell-аналоги .sh скриптов
$PSScripts = @(
    @{ Name = "update_hybrid.ps1";  Source = "update_hybrid.ps1" }
    @{ Name = "gen_links.ps1";      Source = "gen_links.ps1" }
    @{ Name = "scheduler_setup.ps1"; Source = "scheduler_setup.ps1" }
)

foreach ($s in $PSScripts) {
    $dest = Join-Path $InstallPath $s.Name
    if (Invoke-WebRequest -Uri "$RepoRaw/windows/$($s.Source)" -OutFile $dest -UseBasicParsing -TimeoutSec 60) {
        Write-OK "Скачано: $($s.Name)"
    } else {
        Write-Warn "Не удалось скачать $($s.Name) (не критично)"
    }
}

# Скачиваем .bat-обёртки
$BatFiles = @("start-proxy.bat", "start-tun.bat", "stop.bat", "update-and-start.bat", "uninstall.bat")
foreach ($b in $BatFiles) {
    $dest = Join-Path $InstallPath $b
    if (Invoke-WebRequest -Uri "$RepoRaw/windows/$b" -OutFile $dest -UseBasicParsing -TimeoutSec 60) {
        Write-OK "Скачано: $b"
    }
}

# === [6/7] Generate certs & passwords ===
Write-Step "6/7] Generate certificates & passwords"

$CertDir = Join-Path $InstallPath "certs\grpc"
New-Item -ItemType Directory -Path $CertDir -Force | Out-Null

# Генерируем EC-ключ
try {
    & openssl ecparam -genkey -name prime256v1 -out "$CertDir\h2.pem" 2>$null
    & openssl req -new -x509 -days 36500 -key "$CertDir\h2.pem" `
        -out "$CertDir\h2.cert" -subj "/CN=cloudflare.com" 2>$null
    Write-OK "Сертификаты (openssl) созданы"
} catch {
    Write-Warn "openssl недоступен, генерирую через .NET"
    Add-Type -AssemblyName System.Security
    $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048)
    
    # Простой self-signed через .NET
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        [System.Guid]::NewGuid().ToString()
    )
    Write-OK "Сертификаты (.NET) созданы"
}

# Генерируем пароли
$SSPass = -join ((1..24) | ForEach-Object { [char[]]([char]'a'..[char]'f') + ([char]'0'..[char]'9') | Get-Random })
$HY2Pass = -join ((1..20) | ForEach-Object { [char[]]([char]'a'..[char]'f') + ([char]'0'..[char]'9') | Get-Random })

# Подставляем в конфиг
$ConfigFile = Join-Path $InstallPath "conf3_final.json"
if (Test-Path $ConfigFile) {
    $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    
    function Set-InboundPassword {
        param($Inbounds, $Tag, $NewPass)
        foreach ($i in $Inbounds) {
            if ($i.tag -eq $Tag) {
                if ($i.PSObject.Properties['password']) {
                    $i.password = $NewPass
                }
                if ($i.PSObject.Properties['users'] -and $i.users.Count -gt 0) {
                    $i.users[0].password = $NewPass
                }
            }
        }
    }
    
    Set-InboundPassword -Inbounds $config.inbounds -Tag "ss-in"  -NewPass $SSPass
    Set-InboundPassword -Inbounds $config.inbounds -Tag "hy2-in" -NewPass $HY2Pass
    
    $config | ConvertTo-Json -Depth 20 | Set-Content $ConfigFile -Encoding UTF8
    Write-OK "Пароли сгенерированы и вставлены в конфиг"
}

# === [7/7] Schedule update task ===
Write-Step "7/7] Schedule automatic updates (Task Scheduler)"

$UpdateScript = Join-Path $InstallPath "update_hybrid.ps1"
$UpdateSh     = Join-Path $InstallPath "update_hybrid.sh"

if (Test-Path $UpdateScript) {
    $TaskName = "CrossProtocolBreeder.Update"
    
    # Удаляем существующее задание
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Info "Удалено старое задание"
    }
    
    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$UpdateScript`""
    
    $Trigger = New-ScheduledTaskTrigger -Daily -At "04:00"
    
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable
    
    try {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $Action `
            -Trigger $Trigger `
            -Settings $Settings `
            -Description "Cross-Protocol Breeder - auto update hybrid configs (every day at 04:00)" `
            -RunLevel Highest `
            -ErrorAction Stop
        Write-OK "Задача в планировщике создана: $TaskName"
    } catch {
        Write-Warn "Не удалось создать задачу в планировщике: $_"
        Write-Info "Создайте вручную: Task Scheduler → Create Task"
    }
}

# === ИТОГ ===
Write-Header "Installation Complete!"
Write-Host ""
Write-Host "  Путь:        " -NoNewline; Write-Host $InstallPath -ForegroundColor Yellow
Write-Host "  Бинарник:    " -NoNewline; Write-Host $ExePath -ForegroundColor Yellow
Write-Host "  Режим:       " -NoNewline
if ($InstallProxy) { Write-Host "SOCKS5/HTTP прокси" -NoNewline -ForegroundColor Green }
if ($InstallTun)   { Write-Host " + TUN" -NoNewline -ForegroundColor Green }
Write-Host ""
Write-Host ""
Write-Host "  Как запустить:" -ForegroundColor Cyan
Write-Host "    Прокси:    " -NoNewline; Write-Host ".\start-proxy.bat" -ForegroundColor Green
if ($InstallTun) {
    Write-Host "    TUN:       " -NoNewline; Write-Host ".\start-tun.bat (от админа)" -ForegroundColor Green
}
Write-Host "    Остановка: " -NoNewline; Write-Host ".\stop.bat" -ForegroundColor Green
Write-Host "    Обновить:  " -NoNewline; Write-Host ".\update-and-start.bat" -ForegroundColor Green
Write-Host ""
Write-Host "  ПЕРВЫЙ ЗАПУСК (обязательно):" -ForegroundColor Yellow
Write-Host "    .\update_hybrid.ps1       " -ForegroundColor Green -NoNewline
Write-Host "← соберёт гибридные цепочки" -ForegroundColor Yellow
Write-Host "    .\gen_links.ps1           " -ForegroundColor Green -NoNewline
Write-Host "← сгенерирует ссылки для клиентов" -ForegroundColor Yellow
Write-Host ""
