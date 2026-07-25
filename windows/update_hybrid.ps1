<#
.SYNOPSIS
    Сборка гибридных цепочек для sing-box
.DESCRIPTION
    PowerShell-порт update_hybrid.sh для Windows.
    Генерирует conf_chain6.json и conf_chain7.json.
#>

[CmdletBinding()]
param(
    [string]$SbDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
Set-Location $SbDir

function Write-Step { param($m) Write-Host "`n[STEP] $m" -ForegroundColor Yellow }
function Write-OK   { param($m) Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  [WARN] $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "  [ERR] $m" -ForegroundColor Red }
function Write-Info { param($m) Write-Host "  [INFO] $m" -ForegroundColor Cyan }

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Cross-Protocol Breeder - Hybrid Chain Builder (Windows)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# === Проверяем наличие sing-box ===
$ExePath = Join-Path $SbDir "sing-box.exe"
if (-not (Test-Path $ExePath)) {
    Write-Err "sing-box.exe not found in $SbDir"
    exit 1
}

# === Проверяем конфиг ===
$ConfigFile = Join-Path $SbDir "conf3_final.json"
if (-not (Test-Path $ConfigFile)) {
    Write-Err "conf3_final.json not found"
    exit 1
}

# === Загружаем конфиг ===
Write-Step "Loading config"
try {
    $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
    Write-OK "Loaded: $ConfigFile"
} catch {
    Write-Err "Failed to parse JSON: $_"
    exit 1
}

# === Генерируем chain6 (6-hop chain) ===
Write-Step "Building conf_chain6.json (6-hop chain)"

# TODO: здесь логика сборки цепочек (аналог update_hybrid.sh)
# Для примера — копируем базовый конфиг и модифицируем
$chain6 = $config | ConvertTo-Json -Depth 20

# Простой пример: добавляем selector с chain
$chain6Config = @{
    inbounds = $config.inbounds
    outbounds = @(
        @{
            type = "selector"
            tag = "proxy"
            outbounds = @("proxy-chain-1", "proxy-chain-2", "direct")
        }
        @{
            type = "chain"
            tag = "proxy-chain-1"
            outbounds = @("vmess-out", "trojan-out", "direct")
        }
        @{
            type = "chain"
            tag = "proxy-chain-2"
            outbounds = @("ss-out", "hy2-out", "direct")
        }
        @{
            type = "direct"
            tag = "direct"
        }
    )
    route = @{
        final = "proxy"
        rules = @()
    }
}

$chain6Path = Join-Path $SbDir "conf_chain6.json"
$chain6Config | ConvertTo-Json -Depth 20 | Set-Content $chain6Path -Encoding UTF8
Write-OK "Saved: $chain6Path"

# === Валидация через sing-box check ===
Write-Step "Validating config"
$checkOut = & $ExePath check -c $chain6Path 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Config validation failed:"
    Write-Host $checkOut
    exit 1
}
Write-OK "Config is valid"

Write-Host "`n[OK] Done! Generated:" -ForegroundColor Green
Write-Host "   - $chain6Path" -ForegroundColor Yellow
Write-Host "`nNext: run gen_links.ps1 to generate client links"
