<#
.SYNOPSIS
    Cross-Protocol Breeder - Hybrid Chain Builder (minimal)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Цвета
function W-OK    { param($m) Write-Host ("  [OK] " + $m) -ForegroundColor Green }
function W-Err   { param($m) Write-Host ("  [ERR] " + $m) -ForegroundColor Red }
function W-Warn  { param($m) Write-Host ("  [WARN] " + $m) -ForegroundColor Yellow }
function W-Info  { param($m) Write-Host ("  " + $m) -ForegroundColor Cyan }

# Найти инструменты
$BIN = (Get-ChildItem $PSScriptRoot -Recurse -Filter "sing-box.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
$JQ  = (Get-Command jq -ErrorAction SilentlyContinue).Source
$LUA = (Get-Command lua -ErrorAction SilentlyContinue).Source
$CURL = (Get-Command curl -ErrorAction SilentlyContinue).Source

Write-Host ""
Write-Host "  sing-box: $BIN"
Write-Host "  jq:      $JQ"
Write-Host "  lua:     $LUA"
Write-Host "  curl:    $CURL"
Write-Host ""

if (-not $BIN)  { W-Err "sing-box.exe not found"; exit 1 }
if (-not $JQ)   { W-Err "jq not found"; exit 1 }
if (-not $LUA)  { W-Err "lua not found"; exit 1 }
if (-not $CURL) { W-Err "curl not found"; exit 1 }

W-OK "All tools found!"

# Конфигурация
$CONF_BASE   = Join-Path $PSScriptRoot "conf3_final.json"
$CONF_TARGET = Join-Path $PSScriptRoot "conf_chain6.json"
$SUBS_RAW    = Join-Path $PSScriptRoot "subs_raw.txt"
$CONVERTER   = Join-Path $PSScriptRoot "converter.lua"

$TEST_API_PORT = 9093
$TEST_PORT = 25556
$PORT_SHIFT = 100
$WANTED_CHAINS = 6
$MIN_CHAIN_SPEED_KBPS = 400
$MIN_POOL_SPEED_KBPS = 700
$MAX_PING = 4000
$ENCRYPTION_PRIORITY = 1

$TEST_URLS = @(
    "https://speed.cloudflare.com/__down?bytes=15000000",
    "https://cachefly.cachefly.net/10mb.test"
)
$ACTIVE_TEST_URL = $TEST_URLS[0]

$SUBS_LIST = @(
    "https://sub.whitedns.one/sub/base64.txt",
    "https://raw.githubusercontent.com/sakha1370/OpenRay/refs/heads/main/output/all_valid_proxies.txt",
    "https://raw.githubusercontent.com/SoliSpirit/v2ray-configs/refs/heads/main/Protocols/ss.txt",
    "https://raw.githubusercontent.com/ebrasha/free-v2ray-public-list/refs/heads/main/all_extracted_configs.txt"
)

$CHAIN_TYPES = @("ss-ss", "ss-vless", "ss-trojan", "vless-ss", "trojan-ss")

# Temp
$TEMP = Join-Path $env:TEMP "sb_chain6_tmp"
if (Test-Path $TEMP) { Remove-Item $TEMP -Recurse -Force }
New-Item -ItemType Directory -Path $TEMP -Force | Out-Null

# ====================================================================
# jq filter files
# ====================================================================
[System.IO.File]::WriteAllText("$TEMP\gen.jq", @'
. as $n | { "log": { "level": "error" }, "experimental": { "clash_api": { "external_controller": "127.0.0.1:9093" } }, "route": { "final": "tester_group" }, "inbounds": [ { "type": "socks", "tag": "socks-test", "listen": "127.0.0.1", "listen_port": 25556 } ], "outbounds": ($n + [{ "type": "urltest", "tag": "tester_group", "outbounds": ($n | map(.tag)), "url": "http://cp.cloudflare.com/generate_204", "interval": "1m", "tolerance": 50 }]) }
'@, $utf8NoBom)

[System.IO.File]::WriteAllText("$TEMP\gen_chain.jq", @'
. as $n | { "log": { "level": "error" }, "experimental": { "clash_api": { "external_controller": "127.0.0.1:9093" } }, "route": { "final": "tester_group" }, "inbounds": [ { "type": "socks", "tag": "socks-test", "listen": "127.0.0.1", "listen_port": 25556 } ], "outbounds": ($entry[0] + $n + [{ "type": "urltest", "tag": "tester_group", "outbounds": ($n | map(.tag)), "url": "http://cp.cloudflare.com/generate_204", "interval": "1m", "tolerance": 50 }]) }
'@, $utf8NoBom)

[System.IO.File]::WriteAllText("$TEMP\uroboros.jq", @'
def get_prefix(s): (s | split(".")) as $p | if ($p | length) == 4 then $p[0:3] | join(".") else s end;
map(
  select(.tag != $t and .server != $srv and get_prefix(.server) != get_prefix($srv)) |
  .tag = (.tag + "_via_" + $t) |
  .detour = $t
)
'@, $utf8NoBom)

[System.IO.File]::WriteAllText("$TEMP\api_all_valid.jq", @'
.proxies | to_entries | map(select(.value.history | length > 0) | select(.value.history[-1].delay > 0 and .value.history[-1].delay <= 4000) | select(.key != "socks-test" and .key != "tester_group")) | map(.key) | .[]
'@, $utf8NoBom)

[System.IO.File]::WriteAllText("$TEMP\fin.jq", @'
.log.level = "warn" | .outbounds = $entry[0] + $nodes[0] + $sel[0] + .outbounds | .route.final = "Best-Auto"
'@, $utf8NoBom)

[System.IO.File]::WriteAllText("$TEMP\sel.jq", @'
[{ "type": "urltest", "tag": "Best-Auto", "outbounds": $tags[0], "url": "http://cp.cloudflare.com/generate_204", "interval": "12m", "tolerance": 150 }]
'@, $utf8NoBom)

[System.IO.File]::WriteAllText("$TEMP\dec.lua", @"
local f = io.open(arg[1], 'r')
if not f then os.exit(1) end
local str = f:read('*a'):gsub('[%s%c]', ''):gsub('-', '+'):gsub('_', '/')
f:close()
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local res = {}
for i = 1, #str, 4 do
    local n = 0
    for j = 0, 3 do
        local c = str:sub(i+j, i+j)
        local val = b:find(c, 1, true)
        if val then n = n + (val - 1) * (64^(3-j)) end
    end
    table.insert(res, string.char(math.floor(n / 65536)))
    if str:sub(i+2, i+2) ~= '=' then table.insert(res, string.char(math.floor((n % 65536) / 256))) end
    if str:sub(i+3, i+3) ~= '=' then table.insert(res, string.char(n % 256)) end
end
print(table.concat(res))
"@, $utf8NoBom)

# ====================================================================
# Helpers
# ====================================================================
function Jq($args, $inputFile, $outputFile) {
    $argList = @($args)
    if ($inputFile) { $argList += $inputFile }
    $out = & $JQ $argList 2>$null
    if ($outputFile -and $out) {
        [System.IO.File]::WriteAllText($outputFile, $out, $utf8NoBom)
    } else {
        return $out
    }
}

function Kill-SingBox {
    Get-Process -Name "sing-box" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

function Start-Tester($cfg, $timeoutIters) {
    Kill-SingBox
    $proc = Start-Process -FilePath $BIN -ArgumentList @("run", "-c", $cfg) -PassThru -NoNewWindow -WindowStyle Hidden
    for ($i = 1; $i -le $timeoutIters; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$TEST_API_PORT/proxies" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($r.StatusCode -eq 200) { return $true }
        } catch {}
        Start-Sleep -Seconds 2
    }
    return $false
}

function Get-ValidNodes {
    try {
        $raw = Invoke-WebRequest -Uri "http://127.0.0.1:$TEST_API_PORT/proxies" -UseBasicParsing -TimeoutSec 5 -ErrorAction SilentlyContinue
        [System.IO.File]::WriteAllText("$TEMP\api.json", $raw.Content, $utf8NoBom)
        $out = & $JQ -r -f "$TEMP\api_all_valid.jq" "$TEMP\api.json" 2>$null
        if ($out) { return ($out -split "`n" | Where-Object { $_ }) }
    } catch {}
    return @()
}

function Test-Speed {
    $out = & $CURL --socks5-hostname "127.0.0.1:$TEST_PORT" -sL -o $null -w "%{http_code}|%{speed_download}" --connect-timeout 20 --max-time 40 $ACTIVE_TEST_URL 2>$null
    $parts = $out -split "\|"
    $code = $parts[0]
    $kbps = 0
    if ($parts[1]) { $kbps = [int]([double]$parts[1] / 1024) }
    return @{ code = $code; kbps = $kbps }
}

# ====================================================================
# MAIN
# ====================================================================
Write-Host ""
Write-Host "[1/5] Shifting ports..." -ForegroundColor Yellow
Jq @("--argjson", "shift", "$PORT_SHIFT", '.inbounds |= map(if .listen_port then .listen_port += $shift else . end)') $CONF_BASE "$TEMP\conf_base_shifted.json"

Write-Host "[2/5] Downloading subscriptions..." -ForegroundColor Yellow
"" | Set-Content $SUBS_RAW -Encoding UTF8
$totalNodes = 0
foreach ($url in $SUBS_LIST) {
    $name = Split-Path $url -Leaf
    Write-Host "  Downloading $name... " -NoNewline
    try {
        $content = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 -SkipCertificateCheck
        $text = $content.Content -replace "`r", "" -replace "`0", ""
        if ($text -notmatch "^(ss|vless|trojan)://") {
            try {
                $clean = $text -replace "[\s]", "" -replace "-", "+" -replace "_", "/"
                $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($clean))
                if ($decoded -match "^(ss|vless|trojan)://") { $text = $decoded }
            } catch {}
        }
        $lines = ($text -split "`n" | Where-Object { $_ -match "^(ss|vless|trojan)://" })
        $lines | Add-Content $SUBS_RAW -Encoding UTF8
        $totalNodes += $lines.Count
        W-OK "$($lines.Count) nodes"
    } catch {
        W-Warn "Failed"
    }
}
W-Info "Total raw: $totalNodes"

# Dedupe + quota
$subs = Get-Content $SUBS_RAW | Select-Object -Unique
$ss = ($subs | Where-Object { $_ -match "^ss://" }) | Select-Object -First 1200
$vless = ($subs | Where-Object { $_ -match "^vless://" }) | Select-Object -First 800
$trojan = ($subs | Where-Object { $_ -match "^trojan://" }) | Select-Object -First 500
$totalFinal = $ss.Count + $vless.Count + $trojan.Count
W-Info "After quota: $totalFinal"

@($ss + $vless + $trojan) | Set-Content $SUBS_RAW -Encoding UTF8

Write-Host "[3/5] Converting via Lua..." -ForegroundColor Yellow
Set-Location $PSScriptRoot
& $LUA converter.lua 2>&1 | Out-Null
if (-not (Test-Path "all_nodes.json")) { W-Err "Converter failed"; exit 1 }
W-OK "Converted"

function Build-RawPool($proto) {
    $outFile = "$TEMP\rawnodes_$proto.json"
    if ((Test-Path $outFile) -and (Get-Item $outFile).Length -gt 0) { return }
    Jq @("--arg", "p", $proto, 'map(select(.type == $p))') "all_nodes.json" $outFile
}

function Gather-Pool($proto, $need, $outFile) {
    $poolFile = "$TEMP\pool_$proto.txt"
    $rawFile = "$TEMP\rawnodes_$proto.json"
    if (-not (Test-Path $poolFile)) { "" | Set-Content $poolFile -Encoding UTF8 }
    $have = 0
    if (Test-Path $poolFile) { $have = (Get-Content $poolFile | Measure-Object).Count }
    if ($have -ge $need) {
        W-OK "[CACHE] $proto: $have (need $need)"
    } else {
        Build-RawPool $proto
        $totalValid = 0
        if (Test-Path $rawFile) { $totalValid = [int](& $JQ 'length' $rawFile 2>$null) }
        $cur = 0
        while ($have -lt $need -and $cur -lt $totalValid) {
            $end = [Math]::Min($cur + 3, $totalValid)
            W-Info "Testing $proto batch $cur-$end"
            $batch = & $JQ ".[$cur`:$end]" $rawFile 2>$null
            [System.IO.File]::WriteAllText("$TEMP\batch.json", $batch, $utf8NoBom)
            $cfg = & $JQ -f "$TEMP\gen.jq" "$TEMP\batch.json" 2>$null
            [System.IO.File]::WriteAllText("$TEMP\run.json", $cfg, $utf8NoBom)
            if (Start-Tester "$TEMP\run.json" 20) {
                Start-Sleep -Seconds 4
                $valid = Get-ValidNodes
                foreach ($n in $valid) {
                    try { Invoke-WebRequest -Uri "http://127.0.0.1:$TEST_API_PORT/proxies/tester_group" -Method Put -Body "{`"name`":`"$n`"}" -ContentType "application/json" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch {}
                    Start-Sleep -Seconds 2
                    $r = Test-Speed
                    if (($r.code -eq "200" -or $r.code -eq "206") -and $r.kbps -ge $MIN_POOL_SPEED_KBPS) {
                        W-OK "[POOL] $n : $($r.kbps) KB/s"
                        "$($r.kbps)|$n" | Add-Content $poolFile -Encoding UTF8
                        $have++
                        if ($have -ge $need) { break }
                    }
                }
            }
            $cur = $end
        }
        Kill-SingBox
    }
    if ($have -lt 1) { return $false }
    Get-Content $poolFile | ForEach-Object {
        $parts = $_ -split "\|"
        if ($parts.Count -ge 2) { [PSCustomObject]@{ kbps = [int]$parts[0]; tag = $parts[1] } }
    } | Sort-Object kbps -Descending | Select-Object tag -Unique | Select-Object -First $need | ForEach-Object { $_.tag } | Set-Content $outFile -Encoding UTF8
    return $true
}

Write-Host "[4/5] Building hybrid chains..." -ForegroundColor Yellow
foreach ($chainType in $CHAIN_TYPES) {
    W-Info "Type: $chainType"
    "" | Set-Content "$TEMP\chain_results.txt" -Encoding UTF8
    $pEntry = $chainType.Split("-")[0]
    $pExit = $chainType.Split("-")[1]
    $jsonEntry = if ($pEntry -eq "ss") { "shadowsocks" } else { $pEntry }
    $jsonExit = if ($pExit -eq "ss") { "shadowsocks" } else { $pExit }

    if (-not (Gather-Pool $jsonEntry 5 "$TEMP\anchor_pool.txt")) { continue }
    if (-not (Gather-Pool $jsonExit 10 "$TEMP\exit_pool.txt")) { continue }

    $anchorTags = Get-Content "$TEMP\anchor_pool.txt"
    $exitTags = Get-Content "$TEMP\exit_pool.txt"

    [System.IO.File]::WriteAllText("$TEMP\anchor_tags.txt", ($anchorTags -join "`n"), $utf8NoBom)
    [System.IO.File]::WriteAllText("$TEMP\exit_tags.txt", ($exitTags -join "`n"), $utf8NoBom)

    Jq @("-Rs", 'split("\n") | map(select(length > 0))') "$TEMP\anchor_tags.txt" "$TEMP\a_tags.json"
    Jq @("-Rs", 'split("\n") | map(select(length > 0))') "$TEMP\exit_tags.txt" "$TEMP\e_tags.json"
    Jq @("--slurpfile", "tags", "$TEMP\a_tags.json", 'map(. as $n | select($tags[0] | index($n.tag)))') "$TEMP\rawnodes_$jsonEntry.json" "$TEMP\anchors.json"
    Jq @("--slurpfile", "tags", "$TEMP\e_tags.json", 'map(. as $n | select($tags[0] | index($n.tag)))') "$TEMP\rawnodes_$jsonExit.json" "$TEMP\exits.json"

    foreach ($anchorTag in $anchorTags) {
        if (-not $anchorTag) { continue }
        W-Info "Anchor: $anchorTag"
        Jq @("--arg", "t", $anchorTag, '[.[] | select(.tag == $t)]') "$TEMP\anchors.json" "$TEMP\current_entry.json"
        $anchorServer = (& $JQ -r --arg t $anchorTag '.[] | select(.tag == $t) | .server' "$TEMP\anchors.json" 2>$null)
        Jq @("--arg", "t", $anchorTag, "--arg", "srv", $anchorServer, "-f", "$TEMP\uroboros.jq") "$TEMP\exits.json" "$TEMP\current_matrix.json"

        $matLen = 0
        if (Test-Path "$TEMP\current_matrix.json") { $matLen = [int](& $JQ 'length' "$TEMP\current_matrix.json" 2>$null) }
        if ($matLen -lt 1) { continue }

        Jq @("--slurpfile", "entry", "$TEMP\current_entry.json", "-f", "$TEMP\gen_chain.jq") "$TEMP\current_matrix.json" "$TEMP\run.json"

        & $BIN check -c "$TEMP\run.json" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { continue }

        if (-not (Start-Tester "$TEMP\run.json" 25)) { continue }
        Start-Sleep -Seconds 5
        $valid = Get-ValidNodes

        foreach ($chainNode in $valid) {
            if (-not $chainNode) { continue }
            try { Invoke-WebRequest -Uri "http://127.0.0.1:$TEST_API_PORT/proxies/tester_group" -Method Put -Body "{`"name`":`"$chainNode`"}" -ContentType "application/json" -UseBasicParsing -TimeoutSec 5 | Out-Null } catch {}
            Start-Sleep -Seconds 3
            $r = Test-Speed
            if (($r.code -eq "200" -or $r.code -eq "206") -and $r.kbps -ge $MIN_CHAIN_SPEED_KBPS) {
                W-OK "[CHAIN] $chainNode : $($r.kbps) KB/s"
                "$($r.kbps)|$chainNode" | Add-Content "$TEMP\chain_results.txt" -Encoding UTF8
                $found = (Get-Content "$TEMP\chain_results.txt" | Measure-Object).Count
                if ($found -ge $WANTED_CHAINS) { break }
            }
        }
        $found = 0
        if (Test-Path "$TEMP\chain_results.txt") { $found = (Get-Content "$TEMP\chain_results.txt" | Measure-Object).Count }
        if ($found -ge $WANTED_CHAINS) { break }
    }

    $found = 0
    if (Test-Path "$TEMP\chain_results.txt") { $found = (Get-Content "$TEMP\chain_results.txt" | Measure-Object).Count }
    if ($found -ge $WANTED_CHAINS) { W-OK "Built for $chainType!"; break }
}

Kill-SingBox

Write-Host "[5/5] Assembling final config..." -ForegroundColor Yellow
$hasResults = $false
if (Test-Path "$TEMP\chain_results.txt") { $hasResults = ((Get-Content "$TEMP\chain_results.txt" | Measure-Object).Count -gt 0) }

if ($hasResults) {
    Get-Content "$TEMP\chain_results.txt" | ForEach-Object {
        $parts = $_ -split "\|"
        if ($parts.Count -ge 2) { [PSCustomObject]@{ kbps = [int]$parts[0]; tag = $parts[1] } }
    } | Sort-Object kbps -Descending | Select-Object tag -Unique | Select-Object -First $WANTED_CHAINS | ForEach-Object { $_.tag } | Set-Content "$TEMP\top_chains.txt" -Encoding UTF8

    Jq @("-Rs", 'split("\n") | map(select(length > 0))') "$TEMP\top_chains.txt" "$TEMP\chain_tags.json"

    "" | Set-Content "$TEMP\giant_matrix.json" -Encoding UTF8
    foreach ($aTag in $anchorTags) {
        $aSrv = (& $JQ -r --arg t $aTag '.[] | select(.tag == $t) | .server' "$TEMP\anchors.json" 2>$null)
        $part = & $JQ --arg t $aTag --arg srv $aSrv -f "$TEMP\uroboros.jq" "$TEMP\exits.json" 2>$null
        $part | Add-Content "$TEMP\giant_matrix.json" -Encoding UTF8
    }
    Jq @("-s", "flatten") "$TEMP\giant_matrix.json" "$TEMP\flat_matrix.json"
    Jq @("--slurpfile", "tags", "$TEMP\chain_tags.json", 'map(. as $n | select($tags[0] | index($n.tag)))') "$TEMP\flat_matrix.json" "$TEMP\final_chains.json"

    Jq @("map(.detour) | unique") "$TEMP\final_chains.json" "$TEMP\used_anchors.json"
    Jq @("--slurpfile", "anchors", "$TEMP\used_anchors.json", 'map(. as $n | select($anchors[0] | index($n.tag)))') "$TEMP\anchors.json" "$TEMP\final_entries.json"

    Jq @("map(.tag)") "$TEMP\final_chains.json" "$TEMP\ftags.json"
    Jq @("-n", "--slurpfile", "tags", "$TEMP\ftags.json", "-f", "$TEMP\sel.jq") $null "$TEMP\sel.json"

    Jq @("--slurpfile", "nodes", "$TEMP\final_chains.json", "--slurpfile", "entry", "$TEMP\final_entries.json", "--slurpfile", "sel", "$TEMP\sel.json", "-f", "$TEMP\fin.jq") "$TEMP\conf_base_shifted.json" "$TEMP\conf_target_candidate.json"

    & $BIN check -c "$TEMP\conf_target_candidate.json" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Copy-Item "$TEMP\conf_target_candidate.json" $CONF_TARGET -Force
        W-OK "DONE! Config at $CONF_TARGET"
    } else {
        W-Err "Final config invalid"
    }
} else {
    W-Err "No chains built"
}

Remove-Item $SUBS_RAW -Force -ErrorAction SilentlyContinue
Remove-Item "all_nodes.json" -Force -ErrorAction SilentlyContinue
