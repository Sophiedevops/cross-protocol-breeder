<#
.SYNOPSIS
    Генерация ссылок для клиентов
#>

[CmdletBinding()]
param(
    [string]$SbDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
Set-Location $SbDir

$ExePath = Join-Path $SbDir "sing-box.exe"
$ConfigPath = Join-Path $SbDir "conf_chain6.json"
$OutputFile = Join-Path $SbDir "clients.txt"

if (-not (Test-Path $ConfigPath)) {
    Write-Host "[ERR] conf_chain6.json not found. Run update_hybrid.ps1 first." -ForegroundColor Red
    exit 1
}

# Получаем LAN IP
function Get-LanIP {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }
    if ($ips) { return $ips[0].IPAddress }
    
    # Fallback
    $ipconfig = ipconfig | Out-String
    $match = [regex]::Match($ipconfig, "IPv4.*?:\s*(\d+\.\d+\.\d+\.\d+)")
    if ($match.Success) { return $match.Groups[1].Value }
    return "127.0.0.1"
}

$lanIP = Get-LanIP
Write-Host "`nDetected LAN IP: $lanIP" -ForegroundColor Cyan

# Загружаем конфиг
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

$links = @()
$links += "================================================================"
$links += "  Cross-Protocol Breeder - Client Links"
$links += "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$links += "================================================================"
$links += ""

foreach ($ib in $config.inbounds) {
    $tag = $ib.tag
    $port = $ib.listen_port
    
    switch ($ib.type) {
        "mixed" {
            $links += "--- Mixed (SOCKS+HTTP) [$tag] ---"
            $links += "socks5://$lanIP`:$port#$tag"
            $links += "http://$lanIP`:$port#$tag"
            $links += ""
        }
        "socks" {
            $links += "--- SOCKS5 [$tag] ---"
            $links += "socks5://$lanIP`:$port#$tag"
            $links += ""
        }
        "http" {
            $links += "--- HTTP [$tag] ---"
            $links += "http://$lanIP`:$port#$tag"
            $links += ""
        }
        "shadowsocks" {
            $method = $ib.method
            $pass = $ib.password
            $ssUri = "ss://$("{0}:" -f [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$method`:$pass")))@$lanIP`:$port#$tag"
            $links += "--- Shadowsocks [$tag] ---"
            $links += $ssUri
            $links += ""
        }
        "hysteria2" {
            $pass = $ib.users[0].password
            $hyUri = "hy2://$pass@$lanIP`:$port?insecure=1#$tag"
            $links += "--- Hysteria 2 [$tag] ---"
            $links += $hyUri
            $links += ""
        }
        "vless" {
            $uuid = $ib.users[0].uuid
            $vlessUri = "vless://$uuid@$lanIP`:$port?security=none#$tag"
            $links += "--- VLESS [$tag] ---"
            $links += $vlessUri
            $links += ""
        }
    }
}

$links | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "`nLinks saved to: $OutputFile" -ForegroundColor Green
Write-Host ""
Get-Content $OutputFile
