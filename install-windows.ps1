<#
.SYNOPSIS
    Cross-Protocol Breeder - Windows Smart Installer
.DESCRIPTION
    Installs sing-box extended on Windows 10/11.
    Supports proxy (socks/http) and TUN (global) modes.
.NOTES
    Compatible with PowerShell 5.1 and later.
    All comments in English to avoid encoding issues.
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\cross-protocol-breeder",
    [switch]$ProxyOnly,
    [switch]$TunOnly,
    [switch]$Unattended
)

# --- Force consistent encoding ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# --- Constants ---
$SB_VERSION = "1.13.14-extended-2.5.2"
$REPO_RAW = "https://raw.githubusercontent.com/Sophiedevops/cross-protocol-breeder/main"
$BINARY_BASE = "https://github.com/Sophiedevops/cross-protocol-breeder/releases/download/Binary"
$MANIFEST_URL = "$BINARY_BASE/MANIFEST.txt"

# --- Color helpers ---
function Write-Line  { param($m) Write-Host ("=" * 70) -ForegroundColor Cyan; Write-Host ("  " + $m) -ForegroundColor Cyan; Write-Host ("=" * 70) -ForegroundColor Cyan }
function Write-Step  { param($m) Write-Host ""; Write-Host ("[STEP] " + $m) -ForegroundColor Yellow }
function Write-OK    { param($m) Write-Host ("  [OK] " + $m) -ForegroundColor Green }
function Write-Warn  { param($m) Write-Host ("  [WARN] " + $m) -ForegroundColor Yellow }
function Write-Err   { param($m) Write-Host ("  [ERR] " + $m) -ForegroundColor Red }
function Write-Info  { param($m) Write-Host ("  [INFO] " + $m) -ForegroundColor Cyan }

# --- Admin check ---
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Architecture ---
function Get-SystemArch {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { return "arm64" }
    if ($env:PROCESSOR_ARCHITECTURE -eq "x86")   { return "386" }
    return "amd64"
}

# --- Download with progress ---
function Invoke-SafeDownload {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$TimeoutSec = 300
    )

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "CrossProtocolBreeder/3.3")

        $job = Start-Job -ScriptBlock {
            param($u, $o)
            (New-Object System.Net.WebClient).DownloadFile($u, $o)
        } -ArgumentList $Url, $OutFile

        $elapsed = 0
        while (($job.State -eq "Running") -and ($elapsed -lt $TimeoutSec)) {
            $pct = 0
            if (Test-Path $OutFile) { $pct = (Get-Item $OutFile).Length }
            Write-Host ("`r  Downloading... {0:N0} bytes" -f $pct) -NoNewline -ForegroundColor Gray
            Start-Sleep -Milliseconds 500
            $elapsed = $elapsed + 0.5
        }
        Write-Host ""

        if ($job.State -eq "Running") {
            Stop-Job $job -PassThru | Remove-Job -Force
            throw "Timeout after $TimeoutSec seconds"
        }

        Receive-Job $job -Wait | Out-Null
        Remove-Job $job -Force

        if ((-not (Test-Path $OutFile)) -or ((Get-Item $OutFile).Length -lt 1024)) {
            throw "File too small or missing"
        }
        return $true
    }
    catch {
        return $false
    }
}

# --- SHA256 verification ---
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
    }
    else {
        Write-Err "SHA256 MISMATCH!"
        Write-Err ("  Expected: " + $ExpectedSha)
        Write-Err ("  Actual:   " + $actual)
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================
Write-Line "Cross-Protocol Breeder - Windows Installer v3.3"

# === [1/7] System info ===
Write-Step "1/7] System information"
$IsAdmin = Test-Administrator
$Arch = Get-SystemArch

Write-Info ("OS:           Windows " + [System.Environment]::OSVersion.VersionString)
Write-Info ("Arch:         " + $Arch)
Write-Info ("PS Version:   " + $PSVersionTable.PSVersion.ToString())
Write-Info ("Admin:        " + $(if ($IsAdmin) {"YES"} else {"NO"}))

if (-not $IsAdmin) {
    Write-Warn "Not running as Administrator"
    Write-Warn "  - Proxy mode will work"
    Write-Warn "  - TUN mode will require elevation"
}

# === [2/7] Choose mode ===
Write-Step "2/7] Choose operation mode"

$choice = "3"
if ($Unattended) {
    if ($ProxyOnly) { $choice = "1" }
    elseif ($TunOnly) { $choice = "2" }
}
else {
    Write-Host ""
    Write-Host "  Select installation mode:" -ForegroundColor Cyan
    Write-Host "    [1] Local proxy (SOCKS5/HTTP) - works WITHOUT admin"
    Write-Host "    [2] TUN mode (global)         - REQUIRES admin"
    Write-Host "    [3] Both (proxy + TUN shortcut)" -ForegroundColor Yellow
    Write-Host ""
    $choice = Read-Host "  Your choice [1/2/3]"
}

$InstallProxy = $true
$InstallTun = $true
$NeedAdmin = $false

switch ($choice) {
    "1" { $InstallProxy = $true;  $InstallTun = $false; $NeedAdmin = $false }
    "2" { $InstallProxy = $true;  $InstallTun = $true;  $NeedAdmin = $true }
    "3" { $InstallProxy = $true;  $InstallTun = $true;  $NeedAdmin = $true }
    default { $InstallProxy = $true; $InstallTun = $true; $NeedAdmin = $true }
}

if (($NeedAdmin) -and (-not $IsAdmin)) {
    Write-Warn "TUN requires Administrator. Requesting elevation..."
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -InstallDir `"$InstallDir`""
    if ($ProxyOnly)   { $argList = $argList + " -ProxyOnly" }
    if ($TunOnly)     { $argList = $argList + " -TunOnly" }
    if ($Unattended)  { $argList = $argList + " -Unattended" }

    try {
        Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList $argList -Wait
        exit 0
    }
    catch {
        Write-Err ("Failed to elevate: " + $_)
        Write-Info "Continuing in proxy-only mode"
        $InstallTun = $false
    }
}

Write-OK ("Mode: " + $(if ($InstallProxy) {"Proxy "} else {""}) + $(if ($InstallTun) {"+ TUN"} else {""}))

# === [3/7] Download binary ===
Write-Step "3/7] Download sing-box binary"

$AssetName = switch ($Arch) {
    "amd64" { "sing-box-$SB_VERSION-windows-amd64.zip" }
    "386"   { "sing-box-$SB_VERSION-windows-386.zip" }
    "arm64" { "sing-box-$SB_VERSION-windows-arm64.zip" }
}

Write-Info ("Asset: " + $AssetName)

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Set-Location $InstallDir

$ZipFile = Join-Path $InstallDir $AssetName
$WorkZip = $ZipFile + ".tmp"

$ok = Invoke-SafeDownload -Url ("$BINARY_BASE/" + $AssetName) -OutFile $WorkZip
if (-not $ok) {
    Write-Err ("Failed to download " + $AssetName)
    Write-Info "Check internet connection"
    exit 1
}

$ManifestPath = Join-Path $InstallDir "MANIFEST.txt"
try {
    Invoke-WebRequest -Uri $MANIFEST_URL -OutFile $ManifestPath -UseBasicParsing -TimeoutSec 30 | Out-Null

    if (Test-Path $ManifestPath) {
        $expected = $null
        Get-Content $ManifestPath | ForEach-Object {
            if ($_ -match "^\|?PKG\|" + [regex]::Escape($AssetName) + "\|([a-f0-9]{64})") {
                $expected = $matches[1]
            }
        }

        if ($expected) {
            if (-not (Test-Sha256 -FilePath $WorkZip -ExpectedSha $expected)) {
                Remove-Item $WorkZip -Force -ErrorAction SilentlyContinue
                exit 1
            }
        }
        else {
            Write-Warn ("SHA256 for " + $AssetName + " not found in manifest")
        }
    }
}
catch {
    Write-Warn "Manifest unavailable, skipping SHA256 verification"
}

Move-Item $WorkZip $ZipFile -Force
Write-OK ("Downloaded: " + [math]::Round(((Get-Item $ZipFile).Length / 1MB), 2) + " MB")

# === [4/7] Extract ===
Write-Step "4/7] Extract binary"

try {
    Expand-Archive -Path $ZipFile -DestinationPath $InstallDir -Force
    Write-OK ("Extracted to " + $InstallDir)
}
catch {
    Write-Err ("Extraction failed: " + $_)
    exit 1
}

Remove-Item $ZipFile -Force -ErrorAction SilentlyContinue

$ExePath = $null
$found = Get-ChildItem -Path $InstallDir -Recurse -Filter "sing-box.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($found) {
    $ExePath = $found.FullName
}
else {
    Write-Err "sing-box.exe not found after extraction"
    exit 1
}

Write-OK ("Binary: " + $ExePath)

$version = & $ExePath version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Binary does not run!"
    Write-Err $version
    exit 1
}
Write-OK ("Version: " + $version[0])

# === [5/7] Download scripts ===
Write-Step "5/7] Download scripts and configuration"

$ShellFiles = @("update_hybrid.sh", "converter.lua", "conf3_final.json", "gen_links.sh")
foreach ($f in $ShellFiles) {
    $dest = Join-Path $InstallDir $f
    try {
        Invoke-WebRequest -Uri ("$REPO_RAW/" + $f) -OutFile $dest -UseBasicParsing -TimeoutSec 60 | Out-Null
        Write-OK ("Downloaded: " + $f)
    }
    catch {
        Write-Err ("Failed: " + $f)
    }
}

$PSScripts = @("update_hybrid.ps1", "gen_links.ps1", "generate_tun_config.ps1", "scheduler_setup.ps1")
foreach ($f in $PSScripts) {
    $dest = Join-Path $InstallDir $f
    try {
        Invoke-WebRequest -Uri ("$REPO_RAW/windows/" + $f) -OutFile $dest -UseBasicParsing -TimeoutSec 60 | Out-Null
        Write-OK ("Downloaded: " + $f)
    }
    catch {
        Write-Warn ("Not available: " + $f + " (optional)")
    }
}

$BatFiles = @("start-proxy.bat", "start-tun.bat", "stop.bat", "update-and-start.bat", "uninstall.bat")
foreach ($b in $BatFiles) {
    $dest = Join-Path $InstallDir $b
    try {
        Invoke-WebRequest -Uri ("$REPO_RAW/windows/" + $b) -OutFile $dest -UseBasicParsing -TimeoutSec 60 | Out-Null
        Write-OK ("Downloaded: " + $b)
    }
    catch {
        Write-Warn ("Not available: " + $b)
    }
}

# === [6/7] Generate certs and passwords ===
Write-Step "6/7] Generate certificates and passwords"

$CertDir = Join-Path $InstallDir "certs\grpc"
if (-not (Test-Path $CertDir)) {
    New-Item -ItemType Directory -Path $CertDir -Force | Out-Null
}

$opensslAvailable = $false
$opensslCmd = Get-Command openssl -ErrorAction SilentlyContinue
if ($opensslCmd) {
    # Test openssl actually works
    & openssl version 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $opensslAvailable = $true
    }
}

if ($opensslAvailable) {
    & openssl ecparam -genkey -name prime256v1 -out (Join-Path $CertDir "h2.pem") 2>$null
    if ($LASTEXITCODE -eq 0) {
        & openssl req -new -x509 -days 36500 -key (Join-Path $CertDir "h2.pem") `
            -out (Join-Path $CertDir "h2.cert") -subj "/CN=cloudflare.com" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Certificates generated (openssl)"
        }
        else {
            Write-Warn "openssl failed, using .NET fallback"
            $opensslAvailable = $false
        }
    }
    else {
        Write-Warn "openssl failed, using .NET fallback"
        $opensslAvailable = $false
    }
}

if (-not $opensslAvailable) {
    Write-Warn "Using .NET fallback (RSACryptoServiceProvider)"

    Add-Type -AssemblyName System.Security

    # Use legacy RSACryptoServiceProvider (works on ALL Windows versions 7+)
    $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048)

    # Export private key as PEM
    $privKeyBytes = $rsa.ExportCspBlob($true)
    $b64 = [Convert]::ToBase64String($privKeyBytes, [Base64FormattingOptions]::InsertLineBreaks)

    $pemLines = @("-----BEGIN RSA PRIVATE KEY-----")
    for ($i = 0; $i -lt $b64.Length; $i += 64) {
        $end = [Math]::Min($i + 64, $b64.Length)
        $pemLines += $b64.Substring($i, $end - $i)
    }
    $pemLines += "-----END RSA PRIVATE KEY-----"

    [System.IO.File]::WriteAllText((Join-Path $CertDir "h2.pem"), ($pemLines -join "`n"))

    # Generate self-signed certificate
    $req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest(
        "CN=cloudflare.com",
        $rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $cert = $req.CreateSelfSigned(
        [DateTimeOffset]::Now.AddDays(-1),
        [DateTimeOffset]::Now.AddDays(36500)
    )
    [System.IO.File]::WriteAllBytes((Join-Path $CertDir "h2.cert"), $cert.Export("Cert"))

    # Cleanup
    $rsa.Dispose()

    Write-OK "Certificates generated (.NET, RSACryptoServiceProvider)"
}

# Generate passwords
$SSPass = -join ((1..24) | ForEach-Object { Get-Random -InputObject ([char[]]([char]'a'..[char]'f') + [char]'0'..[char]'9') })
$HY2Pass = -join ((1..20) | ForEach-Object { Get-Random -InputObject ([char[]]([char]'a'..[char]'f') + [char]'0'..[char]'9') })

# Inject passwords into config
$ConfigFile = Join-Path $InstallDir "conf3_final.json"
if (Test-Path $ConfigFile) {
    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

        foreach ($i in $config.inbounds) {
            if ($i.tag -eq "ss-in") {
                if ($i.PSObject.Properties["password"]) {
                    $i.password = $SSPass
                }
            }
            if ($i.tag -eq "hy2-in") {
                if (($i.PSObject.Properties["users"]) -and ($i.users.Count -gt 0)) {
                    $i.users[0].password = $HY2Pass
                }
            }
        }

        $config | ConvertTo-Json -Depth 20 | Set-Content $ConfigFile -Encoding UTF8
        Write-OK "Passwords injected into config"
    }
    catch {
        Write-Warn ("Could not update config: " + $_)
    }
}

# === [7/7] Create scheduled task ===
Write-Step "7/7] Create scheduled task for auto-update"

$UpdateBat = Join-Path $InstallDir "update-and-start.bat"
$TaskName = "CrossProtocolBreeder.Update"

if (Test-Path $UpdateBat) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Info "Removed old scheduled task"
    }

    $Action = New-ScheduledTaskAction `
        -Execute "cmd.exe" `
        -Argument ("/c `"" + $UpdateBat + "`" proxy")

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
            -Description "Cross-Protocol Breeder auto-update (daily at 04:00)" `
            -RunLevel Highest `
            -ErrorAction Stop | Out-Null

        Write-OK ("Scheduled task created: " + $TaskName)
    }
    catch {
        Write-Warn ("Could not create scheduled task: " + $_)
        Write-Info "Create manually: Task Scheduler - Create Task"
    }
}
else {
    Write-Warn "update-and-start.bat not found, skipping scheduler setup"
}

# === FINAL ===
Write-Line "Installation Complete!"

Write-Host ""
Write-Host ("  Path:        " + $InstallDir) -ForegroundColor Yellow
Write-Host ("  Binary:      " + $ExePath) -ForegroundColor Yellow
Write-Host ("  Mode:        " + $(if ($InstallProxy) {"Proxy "} else {""}) + $(if ($InstallTun) {"+ TUN"} else {""})) -ForegroundColor Yellow
Write-Host ""
Write-Host "  How to use:" -ForegroundColor Cyan
Write-Host ("    Proxy:     .\start-proxy.bat") -ForegroundColor Green
if ($InstallTun) {
    Write-Host ("    TUN:       .\start-tun.bat (run as admin)") -ForegroundColor Green
}
Write-Host ("    Stop:      .\stop.bat") -ForegroundColor Green
Write-Host ("    Update:    .\update-and-start.bat") -ForegroundColor Green
Write-Host ""
Write-Host "  FIRST RUN (required):" -ForegroundColor Yellow
Write-Host ("    .\update_hybrid.ps1     builds hybrid chains") -ForegroundColor Green
Write-Host ("    .\gen_links.ps1         generates client links") -ForegroundColor Green
Write-Host ""
