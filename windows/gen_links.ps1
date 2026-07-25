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

$Exe = Join-Path $SbDir "sing-box.exe"
$ConfigPath = Join-Path $SbDir "conf_chain6.json"
$OutFile = Join-Path $SbDir "clients.txt"

if (-not (Test-Path $ConfigPath)) {
    Write-Host "[ERR] conf_chain6.json not found. Run update_hybrid.ps1 first." -ForegroundColor Red
    exit 1
}

# LAN IP
$lanIP = "127.0.0.1"
try {
    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notmatch "^(127\.|169\.254\.|0\.0\.0\.0$)" }
    if ($ips) { $lanIP = $ips[0].IPAddress }
} catch { }

Write-Host "`nDetected LAN IP: $lanIP" -ForegroundColor Cyan

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$lines = New-Object System.Collections.Generic.List[string]

$lines.Add("================================================================")
$lines.Add("  Cross-Protocol Breeder - Client Links")
$lines.Add("  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("  Server:    $lanIP")
$lines.Add("================================================================")
$lines.Add("")

foreach ($ib in $config.inbounds) {
    $tag = $ib.tag
    $port = $ib.listen_port
    $type = $ib.type
    
    switch ($type) {
        "mixed" {
            $lines.Add("--- Mixed (SOCKS+HTTP) [$tag] ---")
            $lines.Add("socks5://$lanIP`:$port#$tag")
            $lines.Add("http://$lanIP`:$port#$tag")
            $lines.Add("")
        }
        "socks" {
            $lines.Add("--- SOCKS5 [$tag] ---")
            $lines.Add("socks5://$lanIP`:$port#$tag")
            $lines.Add("")
        }
        "http" {
            $lines.Add("--- HTTP [$tag] ---")
            $lines.Add("http://$lanIP`:$port#$tag")
            $lines.Add("")
        }
        "shadowsocks" {
            $method = $ib.method
            $pass = $ib.password
            $userinfo = [Convert]::ToBase64String(
                [Text.Encoding]::UTF8.GetBytes("$method`:$pass")
            ).TrimEnd('=')
            $lines.Add("--- Shadowsocks [$tag] ---")
            $lines.Add("ss://$userinfo@$lanIP`:$port#$tag")
            $lines.Add("")
        }
        "hysteria2" {
            $pass = $ib.users[0].password
            $lines.Add("--- Hysteria 2 [$tag] ---")
            $lines.Add("hy2://$pass@$lanIP`:$port?insecure=1#$tag")
            $lines.Add("")
        }
        "vless" {
            $uuid = $ib.users[0].uuid
            $lines.Add("--- VLESS [$tag] ---")
            $lines.Add("vless://$uuid@$lanIP`:$port?security=none#$tag")
            $lines.Add("")
        }
        default {
            $lines.Add("--- $type [$tag] port $port ---")
            $lines.Add("")
        }
    }
}

$lines | Out-File -FilePath $OutFile -Encoding UTF8

Write-Host "`nLinks saved to: $OutFile" -ForegroundColor Green
Write-Host ""
Get-Content $OutFile
