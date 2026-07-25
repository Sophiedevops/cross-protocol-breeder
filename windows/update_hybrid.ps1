<#
.SYNOPSIS
    Сборка гибридных цепочек для sing-box
#>

[CmdletBinding()]
param(
    [string]$SbDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
Set-Location $SbDir

function OK   { param($m) Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Err  { param($m) Write-Host "  [ERR] $m" -ForegroundColor Red; exit 1 }
function Info { param($m) Write-Host "  [INFO] $m" -ForegroundColor Cyan }

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  Cross-Protocol Breeder - Hybrid Chain Builder" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$Exe = Join-Path $SbDir "sing-box.exe"
$ConfigFile = Join-Path $SbDir "conf3_final.json"
$Chain6 = Join-Path $SbDir "conf_chain6.json"

if (-not (Test-Path $Exe))         { Err "sing-box.exe not found" }
if (-not (Test-Path $ConfigFile))  { Err "conf3_final.json not found" }

Write-Host "`n[STEP 1/3] Loading base config" -ForegroundColor Yellow
$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
OK "Loaded $ConfigFile"

Write-Host "`n[STEP 2/3] Building conf_chain6.json" -ForegroundColor Yellow

# Формируем гибридную цепочку
$chain6 = [ordered]@{
    inbounds = $config.inbounds
    outbounds = @(
        @{
            type = "selector"
            tag = "proxy"
            outbounds = @("auto", "direct")
            default = "auto"
        }
        @{
            type = "urltest"
            tag = "auto"
            outbounds = @("proxy-out-1", "proxy-out-2", "proxy-out-3")
            url = "http://www.gstatic.com/generate_204"
            interval = "3m"
            tolerance = 50
        }
        @{
            type = "vmess"
            tag = "proxy-out-1"
            server = "example.com"
            server_port = 443
            uuid = "00000000-0000-0000-0000-000000000000"
            security = "auto"
            alter_id = 0
            tls = @{ enabled = $true; server_name = "example.com" }
        }
        @{
            type = "shadowsocks"
            tag = "proxy-out-2"
            server = "example.com"
            server_port = 8388
            method = "chacha20-ietf-poly1305"
            password = "password"
        }
        @{
            type = "hysteria2"
            tag = "proxy-out-3"
            server = "example.com"
            server_port = 443
            password = "password"
            tls = @{ enabled = $true; server_name = "example.com" }
        }
        @{
            type = "direct"
            tag = "direct"
        }
    )
    route = @{
        final = "proxy"
        rules = @(
            @{ ip_cidr = @("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8"); outbound = "direct" }
        )
    }
}

$chain6 | ConvertTo-Json -Depth 30 | Set-Content $Chain6 -Encoding UTF8
OK "Saved $Chain6"

Write-Host "`n[STEP 3/3] Validating config" -ForegroundColor Yellow
$checkOut = & $Exe check -c $Chain6 2>&1
if ($LASTEXITCODE -ne 0) {
    Err "Config validation failed: $checkOut"
}
OK "Config is valid"

Write-Host "`n[OK] Done! Now run gen_links.ps1" -ForegroundColor Green
