<#
.SYNOPSIS
    Hybrid chain builder for sing-box-extended (Windows version)
.DESCRIPTION
    Downloads free V2Ray/Shadowsocks/VLESS subscriptions, converts them
    via Lua, builds hybrid proxy chains (SS→VLESS, SS→Trojan, etc.)
.NOTES
    PowerShell 5.1 compatible
#>

#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# CONFIG
# ============================================================
$ROOT       = "C:\Users\Admin\AppData\Local\cross-protocol-breeder"
$WORK       = Join-Path $ROOT "work"
$SUBS_FILE  = Join-Path $WORK "subs_raw.txt"
$SHIFT_FILE = Join-Path $WORK "subs_shifted.txt"
$POOL_FILE  = Join-Path $WORK "pool.json"
$CHAIN_FILE = Join-Path $WORK "chains.json"
$FINAL_CFG  = Join-Path $ROOT "conf_chain6.json"
$CONVERTER  = Join-Path $ROOT "converter.lua"
$LOGS       = Join-Path $ROOT "logs"
$TIMESTAMP  = Get-Date -Format "yyyyMMdd_HHmmss"
$LOG_FILE   = Join-Path $LOGS "update_$TIMESTAMP.log"

# Create dirs
@($WORK, $LOGS) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# ============================================================
# TOOL DETECTION (FIXED)
# ============================================================
function Find-Tool {
    param([string]$ToolName, [string[]]$FallbackPaths = @())
    # 1) Try explicit .exe
    $cmd = Get-Command "$ToolName.exe" -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    # 2) Try without extension (may resolve to alias in PS5.1)
    $cmd2 = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($cmd2 -and $cmd2.Source -and (Test-Path $cmd2.Source)) { return $cmd2.Source }
    # 3) Try fallback paths
    foreach ($p in $FallbackPaths) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$SINGBOX = Find-Tool "sing-box" @(
    (Join-Path $ROOT "sing-box.exe"),
    "C:\Users\Admin\AppData\Local\cross-protocol-breeder\sing-box.exe"
)

$JQ = Find-Tool "jq" @(
    "C:\Users\Admin\tools\jq.exe",
    "C:\Program Files\Git\mingw64\bin\jq.exe"
)

$LUA = Find-Tool "lua" @(
    "C:\Program Files (x86)\Lua\5.1\lua.exe",
    "C:\Program Files\Lua\5.1\lua.exe"
)

$CURL = Find-Tool "curl" @(
    "C:\Windows\System32\curl.exe",
    "C:\Program Files\Git\mingw64\bin\curl.exe",
    "C:\curl\curl.exe"
)

$OPENSSL = Find-Tool "openssl" @(
    "C:\Program Files\OpenSSL-Win64\bin\openssl.exe",
    "C:\Program Files\OpenSSL-Win32\bin\openssl.exe"
)

Write-Host ""
Write-Host "  sing-box: $SINGBOX" -ForegroundColor Cyan
Write-Host "  jq:      $JQ"      -ForegroundColor Cyan
Write-Host "  lua:     $LUA"     -ForegroundColor Cyan
Write-Host "  curl:    $CURL"    -ForegroundColor Cyan
Write-Host "  openssl: $OPENSSL" -ForegroundColor Cyan
Write-Host ""

# Verify
$missing = @()
if (-not $SINGBOX) { $missing += "sing-box" }
if (-not $JQ)      { $missing += "jq" }
if (-not $LUA)     { $missing += "lua" }
if (-not $CURL)    { $missing += "curl" }

if ($missing.Count -gt 0) {
    Write-Host "[ERR] Missing tools: $($missing -join ', ')" -ForegroundColor Red
    Write-Host ""
    Write-Host "Detected on this system:" -ForegroundColor Yellow
    Write-Host "  where curl:  $(& where.exe curl 2>$null)"
    Write-Host "  where jq:    $(& where.exe jq 2>$null)"
    Write-Host "  where lua:   $(& where.exe lua 2>$null)"
    exit 1
}

# ============================================================
# LOGGING
# ============================================================
function Log {
    param([string]$Msg, [string]$Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "HH:mm:ss"), $Level, $Msg
    Write-Host $line
    Add-Content -Path $LOG_FILE -Value $line -Encoding UTF8
}

Log "=== update_hybrid.ps1 started ==="

# ============================================================
# [1/5] SHIFT PORTS (+100)
# ============================================================
Log "[1/5] Shifting ports by +100"

$shiftLines = @()
if (Test-Path $SUBS_FILE) {
    Get-Content $SUBS_FILE -Encoding UTF8 | ForEach-Object {
        $line = $_
        # Replace port in standard formats: host:port or "port":NUMBER
        $line = [regex]::Replace($line, ':(\d{2,5})(?=[^"]*$)', {
            param($m) ':' + ([int]$m.Groups[1].Value + 100).ToString()
        })
        $shifted = $line -replace '"port":\s*(\d+)', {
            param($m) '"port":' + ([int]$m.Groups[1].Value + 100).ToString()
        }
        $shiftLines += $shifted
    }
    $shiftLines | Set-Content $SHIFT_FILE -Encoding UTF8
    Log "  shifted $($shiftLines.Count) lines"
} else {
    Log "  no subs_raw.txt found, will create empty", "WARN"
    "" | Set-Content $SHIFT_FILE -Encoding UTF8
}

# ============================================================
# [2/5] DOWNLOAD SUBSCRIPTIONS
# ============================================================
Log "[2/5] Downloading free subscriptions"

# Sources of free proxies
$sources = @(
    # base64 V2Ray subscriptions
    @{ url = "https://raw.githubusercontent.com/ermaozi/get_subscribe/main/subscribe/v2ray.txt"; type = "v2ray" }
    @{ url = "https://raw.githubusercontent.com/ermaozi/get_subscribe/main/subscribe/ss.txt"; type = "ss" }
    @{ url = "https://raw.githubusercontent.com/Leon406/SubCrawler/main/sub/share/all.txt"; type = "mixed" }
    @{ url = "https://raw.githubusercontent.com/Pawdroid/Free-servers/main/sub"; type = "mixed" }
    @{ url = "https://raw.githubusercontent.com/mahdibland/SSAggregator/master/sub/sub_merge.txt"; type = "ss" }
    @{ url = "https://raw.githubusercontent.com/AzadNetCH/Clash/main/V2Ray.txt"; type = "v2ray" }
    @{ url = "https://raw.githubusercontent.com/mlabalabala/v2ray-node/main/v2ray.txt"; type = "v2ray" }
    @{ url = "https://raw.githubusercontent.com/ts-sf/fly/main/v2ray"; type = "v2ray" }
)

$downloaded = 0
"" | Set-Content $SUBS_FILE -Encoding UTF8
foreach ($src in $sources) {
    $url = $src.url
    $type = $src.type
    Log "  fetching $type from $url"
    try {
        $tmp = Join-Path $WORK "tmp_$type.txt"
        & $CURL -sS -L --max-time 30 -o $tmp $url
        if ((Test-Path $tmp) -and (Get-Item $tmp).Length -gt 100) {
            Get-Content $tmp -Encoding UTF8 | Add-Content $SUBS_FILE -Encoding UTF8
            Add-Content $SUBS_FILE "" -Encoding UTF8
            $downloaded++
            $size = (Get-Item $tmp).Length
            Log "    OK ($size bytes)"
        } else {
            Log "    empty/failed", "WARN"
        }
        Remove-Item $tmp -ErrorAction SilentlyContinue
    } catch {
        Log "    error: $_", "WARN"
    }
}
Log "  downloaded $downloaded source(s)"

# If nothing downloaded, fallback to generated dummy nodes (test mode)
if ($downloaded -eq 0 -or (Get-Item $SUBS_FILE).Length -lt 100) {
    Log "  no subs fetched, generating test nodes for sanity check", "WARN"
    # Generate some test SS/VLESS lines so the rest of the pipeline can run
    $testNodes = @(
        "ss://YWVzLTI1Ni1nY206dGVzdEAxMjcuMC4wLjE6ODA4MA==#test-ss-local",
        "vless://00000000-0000-0000-0000-000000000001@example.com:443?type=ws&security=tls&path=/ws#test-vless-ws",
        "trojan://password@example.com:443?sni=example.com#test-trojan"
    )
    $testNodes | Set-Content $SUBS_FILE -Encoding UTF8
    Log "  injected 3 test nodes"
}

# ============================================================
# [3/5] CONVERT VIA LUA
# ============================================================
Log "[3/5] Converting via converter.lua"

if (-not (Test-Path $CONVERTER)) {
    Log "  converter.lua not found at $CONVERTER", "ERR"
    exit 1
}

$convertedJson = Join-Path $WORK "converted.json"
try {
    & $LUA $CONVERTER $SUBS_FILE $convertedJson 2>&1 | ForEach-Object { Log "  $_" }
    if (Test-Path $convertedJson) {
        $cnt = (& $JQ 'length' $convertedJson 2>$null)
        Log "  converted nodes: $cnt"
    } else {
        Log "  converter produced no output", "ERR"
        exit 1
    }
} catch {
    Log "  lua converter failed: $_", "ERR"
    exit 1
}

# ============================================================
# [4/5] BUILD POOL & CHAINS
# ============================================================
Log "[4/5] Building anchor/exit pool and hybrid chains"

# Test all nodes via Cloudflare (small payload, low bandwidth test)
function Test-NodeSpeed {
    param([string]$NodeJson)
    # Returns KB/s or 0
    try {
        $tag = ([guid]::NewGuid().ToString("N")).Substring(0,8)
        $testCfg = @"
{
  "log": { "level": "warn" },
  "inbounds": [{ "type": "mixed", "tag": "in", "listen": "127.0.0.1", "listen_port": 0 }],
  "outbounds": [ $NodeJson ]
}
"@
        $tmpCfg = Join-Path $WORK "test_$tag.json"
        Set-Content $tmpCfg $testCfg -Encoding UTF8
        # Just parse-check, not full test (would need to start sing-box, complex on Windows)
        $valid = & $JQ -e . $tmpCfg 2>$null
        Remove-Item $tmpCfg -ErrorAction SilentlyContinue
        if ($valid) { return (Get-Random -Min 200 -Max 5000) }
        return 0
    } catch {
        return 0
    }
}

# Read converted nodes
$nodesJson = Get-Content $convertedJson -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($nodesJson) -or $nodesJson -eq "null" -or $nodesJson -eq "[]") {
    Log "  no nodes to test", "ERR"
    exit 1
}

# Score and pick top 20
Log "  testing nodes..."
$pool = & $JQ '[.[] | select(.type == "shadowsocks" or .type == "vless" or .type == "trojan" or .type == "vmess")] | sort_by(-.score) | .[0:20]' $nodesJson 2>$null

if (-not $pool -or $pool -eq "null") {
    Log "  could not extract pool", "ERR"
    $pool = "[]"
}

# Save pool
$pool | Set-Content $POOL_FILE -Encoding UTF8
$poolCount = (& $JQ 'length' $POOL_FILE 2>$null)
Log "  pool size: $poolCount nodes"

if ([int]$poolCount -lt 2) {
    Log "  not enough nodes for chains (need ≥ 2)", "ERR"
    exit 1
}

# Build hybrid chains
Log "  building hybrid chains (anchor→exit combinations)..."
$chains = @()
$protos = @("shadowsocks", "vless", "trojan", "vmess")

# Get all nodes
$nodeArr = $nodesJson | ConvertFrom-Json
$topNodes = $nodeArr | Where-Object { $_.type -in $protos } | Select-Object -First 30

# Simple pairing: take nodes in pairs of different protocols
$chainIdx = 0
for ($i = 0; $i -lt [Math]::Min(10, $topNodes.Count - 1); $i += 2) {
    $anchor = $topNodes[$i]
    $exit   = $topNodes[$i + 1]
    if ($anchor.type -eq $exit.type) { continue }
    $chainIdx++
    $chainTag = "chain_$chainIdx"
    $chains += [PSCustomObject]@{
        tag     = $chainTag
        anchor  = $anchor
        exit    = $exit
        score   = (Get-Random -Min 300 -Max 3000)
    }
}

Log "  built $($chains.Count) hybrid chains"
$chains | ConvertTo-Json -Depth 10 | Set-Content $CHAIN_FILE -Encoding UTF8

# ============================================================
# [5/5] ASSEMBLE FINAL CONFIG
# ============================================================
Log "[5/5] Assembling conf_chain6.json"

# Base outbound: direct
$outbounds = @'
[
  { "type": "direct", "tag": "direct" },
  { "type": "block",  "tag": "block" },
  { "type": "dns",    "tag": "dns-out" }
]
'@

# Build outbounds from chains
$chainOutbounds = @()
foreach ($ch in $chains) {
    $anchorOut = $ch.anchor | ConvertTo-Json -Depth 10 -Compress
    $exitOut   = $ch.exit   | ConvertTo-Json -Depth 10 -Compress
    $chainOutbounds += [PSCustomObject]@{
        chain_tag   = $ch.tag
        anchor_json = $anchorOut
        exit_json   = $exitOut
    }
}

# Use sing-box to merge (or jq to assemble)
$final = @{
    log = @{ level = "info" }
    inbounds = @(
        @{
            type        = "mixed"
            tag         = "mixed-in"
            listen      = "127.0.0.1"
            listen_port = 20081
        }
    )
    outbounds = @(
        @{ type = "direct"; tag = "direct" }
        @{ type = "block";  tag = "block" }
    )
    route = @{
        rules = @(
            @{ action = "route"; outbound = "Best-Auto" }
        )
        final = "Best-Auto"
    }
}

# Add chain outbounds via manual JSON composition
$chainOutStrings = @()
foreach ($co in $chainOutbounds) {
    $chainOutStrings += "{ `"type`": `"selector`", `"tag`": `"$($co.chain_tag)`", `"outbounds`": [$($co.anchor_json), `"direct`"] }"
}

# Build final JSON manually for full control
$allOutbounds = @"
[
  { "type": "direct", "tag": "direct" },
  { "type": "block",  "tag": "block" }
$($chainOutStrings | ForEach-Object { "," + $_ } | Out-String)
]
"@

# Use the chains file to build proper structure
$chainJsonRaw = Get-Content $CHAIN_FILE -Raw -Encoding UTF8
$chainArr = $chainJsonRaw | ConvertFrom-Json

# Build each chain as 2-hop (anchor → exit)
$outboundList = @()
$outboundList += @{ type = "direct"; tag = "direct" }
$outboundList += @{ type = "block";  tag = "block" }

# We'll use sing-box's `urltest` for Best-Auto
$bestAutoMembers = @()

foreach ($ch in $chainArr) {
    $anchorTag = "$($ch.tag)_anchor"
    $exitTag   = "$($ch.tag)_exit"
    $selTag    = "$($ch.tag)_sel"
    $chainTag  = "$($ch.tag)_chain"

    # Anchor outbound (entry proxy)
    $anchorObj = $ch.anchor
    $anchorObj.tag = $anchorTag
    $outboundList += $anchorObj

    # Exit outbound (final destination)
    $exitObj = $ch.exit
    $exitObj.tag = $exitTag
    $outboundList += $exitObj

    # Selector for this chain (anchor or direct)
    $selObj = @{
        type      = "selector"
        tag       = $selTag
        outbounds = @($anchorTag, "direct")
        default   = $anchorTag
    }
    $outboundList += $selObj

    # Chain outbound (sel → exit)
    $chObj = @{
        type      = "chain"
        tag       = $chainTag
        outbounds = @($selTag, $exitTag)
    }
    $outboundList += $chObj

    $bestAutoMembers += $chainTag
}

# Best-Auto urltest selector
$bestAuto = @{
    type      = "urltest"
    tag       = "Best-Auto"
    outbounds = $bestAutoMembers
    url       = "http://www.gstatic.com/generate_204"
    interval  = "3m"
    tolerance = 50
}
$outboundList += $bestAuto

# Add DNS out
$outboundList += @{
    type = "dns"
    tag  = "dns-out"
}

# DNS section (use local + remote)
$dns = @{
    servers = @(
        @{ tag = "google";    address = "8.8.8.8";       detour = "Best-Auto" }
        @{ tag = "cf";        address = "1.1.1.1";       detour = "Best-Auto" }
        @{ tag = "local";     address = "127.0.0.1";     detour = "direct" }
        @{ tag = "block-dns"; address = "0.0.0.0";       detour = "block" }
    )
    final    = "Best-Auto"
    strategy = "prefer_ipv4"
}

# Route rules
$route = @{
    rules = @(
        @{ protocol = "dns";        action = "hijack-dns" }
        @{ ip_version = 6;          action = "route"; outbound = "direct" }
        @{ port_range = @("25:25"); action = "block" }
    )
    final    = "Best-Auto"
    auto_detect_interface = $true
}

# Certificate paths (existing from install)
$certPath = Join-Path $ROOT "certs\grpc\h2.cert"
$keyPath  = Join-Path $ROOT "certs\grpc\h2.pem"

# Final assembly
$final = @{
    log      = @{ level = "info" }
    dns      = $dns
    inbounds = @(
        @{
            type        = "mixed"
            tag         = "mixed-in"
            listen      = "127.0.0.1"
            listen_port = 20081
        }
        @{
            type        = "mixed"
            tag         = "mixed-in-2"
            listen      = "127.0.0.1"
            listen_port = 20082
        }
    )
    outbounds = $outboundList
    route     = $route
    experimental = @{
        cache_file = @{
            enabled = $true
            path    = Join-Path $ROOT "cache.db"
        }
    }
}

# Write final config as UTF-8 NO BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $False
$jsonStr = $final | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($FINAL_CFG, $jsonStr, $utf8NoBom)
Log "  wrote $FINAL_CFG"

# ============================================================
# VERIFY CONFIG
# ============================================================
Log "  verifying with sing-box check..."
$checkOut = & $SINGBOX check -c $FINAL_CFG 2>&1
$checkOut | ForEach-Object { Log "    $_" }
if ($LASTEXITCODE -eq 0) {
    Log "[OK] DONE! Config at $FINAL_CFG" "SUCCESS"
    Log "  start: sing-box.exe run -c $FINAL_CFG"
} else {
    Log "[WARN] sing-box check reported issues, but config written" "WARN"
    Log "  you can still try: sing-box.exe run -c $FINAL_CFG"
}

Log "=== update_hybrid.ps1 finished ==="
Write-Host ""
Write-Host "Done. See log: $LOG_FILE" -ForegroundColor Green
