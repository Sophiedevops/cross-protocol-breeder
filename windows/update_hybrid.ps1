<#
.SYNOPSIS
    Build hybrid proxy chains for sing-box
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

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  Cross-Protocol Breeder - Hybrid Chain Builder" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# === Find sing-box.exe ===
$Exe = $null
$searchPaths = @(
    (Join-Path $SbDir "sing-box.exe"),
    (Join-Path $SbDir "sing-box-*-amd64\sing-box.exe"),
    (Join-Path $SbDir "sing-box-*-x64\sing-box.exe")
)
foreach ($p in $searchPaths) {
    if ($p -like "*\*") {
        $found = Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $Exe = $found.FullName; break }
    } elseif (Test-Path $p) {
        $Exe = $p; break
    }
}
if (-not $Exe) {
    $found = Get-ChildItem -Path $SbDir -Recurse -Filter "sing-box.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $Exe = $found.FullName }
}
if (-not $Exe) {
    Write-Err "sing-box.exe not found in $SbDir"
    exit 1
}
Write-OK "Found: $Exe"

# === Load base config ===
$ConfigFile = Join-Path $SbDir "conf3_final.json"
$Chain6 = Join-Path $SbDir "conf_chain6.json"
$Chain7 = Join-Path $SbDir "conf_chain7.json"

if (-not (Test-Path $ConfigFile)) {
    Write-Err "conf3_final.json not found"
    exit 1
}

Write-Step "1/4] Loading base config"
try {
    $configRaw = Get-Content $ConfigFile -Raw
    $config = $configRaw | ConvertFrom-Json
    Write-OK "Loaded $ConfigFile"
}
catch {
    Write-Err ("Failed to parse JSON: " + $_)
    exit 1
}

# === Build chain6 (manual JSON, not via ConvertTo-Json) ===
Write-Step "2/4] Building conf_chain6.json"

# Extract inbounds from base config
$inboundsJson = $config.inbounds | ConvertTo-Json -Depth 20 -Compress
if (-not $inboundsJson.StartsWith("[")) {
    $inboundsJson = "[" + $inboundsJson + "]"
}

# Build chain6 config as raw JSON string (PS 5.1 safe)
$chain6Json = @"
{
  "inbounds": $inboundsJson,
  "outbounds": [
    {
      "type": "selector",
      "tag": "proxy",
      "outbounds": ["auto", "direct"],
      "default": "auto"
    },
    {
      "type": "urltest",
      "tag": "auto",
      "outbounds": ["chain-step-1", "chain-step-2", "direct"],
      "url": "http://www.gstatic.com/generate_204",
      "interval": "3m",
      "tolerance": 50
    },
    {
      "type": "vmess",
      "tag": "chain-step-1",
      "server": "example.com",
      "server_port": 443,
      "uuid": "00000000-0000-0000-0000-000000000000",
      "security": "auto",
      "alter_id": 0,
      "tls": {
        "enabled": true,
        "server_name": "example.com"
      }
    },
    {
      "type": "shadowsocks",
      "tag": "chain-step-2",
      "server": "example.com",
      "server_port": 8388,
      "method": "chacha20-ietf-poly1305",
      "password": "CHANGE_ME"
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "proxy",
    "rules": [
      {
        "ip_cidr": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8"],
        "outbound": "direct"
      }
    ]
  }
}
"@

[System.IO.File]::WriteAllText($Chain6, $chain6Json, [System.Text.Encoding]::UTF8)
Write-OK "Saved $Chain6"

# === Build chain7 (different chain) ===
Write-Step "3/4] Building conf_chain7.json"

$chain7Json = @"
{
  "inbounds": $inboundsJson,
  "outbounds": [
    {
      "type": "selector",
      "tag": "proxy",
      "outbounds": ["hysteria2-out", "vmess-out", "direct"],
      "default": "hysteria2-out"
    },
    {
      "type": "hysteria2",
      "tag": "hysteria2-out",
      "server": "example.com",
      "server_port": 443,
      "password": "CHANGE_ME",
      "tls": {
        "enabled": true,
        "server_name": "example.com"
      }
    },
    {
      "type": "vmess",
      "tag": "vmess-out",
      "server": "example.com",
      "server_port": 443,
      "uuid": "00000000-0000-0000-0000-000000000000",
      "security": "auto",
      "alter_id": 0
    },
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "final": "proxy"
  }
}
"@

[System.IO.File]::WriteAllText($Chain7, $chain7Json, [System.Text.Encoding]::UTF8)
Write-OK "Saved $Chain7"

# === Validate ===
Write-Step "4/4] Validating config"

$checkOut = & $Exe check -c $Chain6 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Config validation failed:"
    Write-Host $checkOut
    exit 1
}
Write-OK "conf_chain6.json is valid"

$checkOut2 = & $Exe check -c $Chain7 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warn "conf_chain7.json validation failed (not critical):"
    Write-Host $checkOut2
} else {
    Write-OK "conf_chain7.json is valid"
}

Write-Host "`n[OK] Done!" -ForegroundColor Green
Write-Host "  Next: run gen_links.ps1 to generate client links" -ForegroundColor Cyan
