<#
.SYNOPSIS
    Генерация TUN-конфига из conf3_final.json
#>

[CmdletBinding()]
param(
    [string]$SbDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
Set-Location $SbDir

$Base = Join-Path $SbDir "conf3_final.json"
$Tun  = Join-Path $SbDir "conf_tun.json"

if (-not (Test-Path $Base)) {
    Write-Host "[ERR] conf3_final.json not found" -ForegroundColor Red
    exit 1
}

$config = Get-Content $Base -Raw | ConvertFrom-Json

# Берём существующие outbounds и оборачиваем в TUN inbound
$outbounds = $config.outbounds
if (-not $outbounds) { $outbounds = @(@{ type = "direct"; tag = "direct" }) }

$tunConfig = [ordered]@{
    inbounds = @(
        @{
            type = "tun"
            tag = "tun-in"
            inet4_address = "172.19.0.1/30"
            inet6_address = "fdfe:dcba:9876::1/126"
            auto_route = $true
            strict_route = $true
            stack = "gvisor"
            mtu = 9000
        }
        # Оставляем оригинальные inbound'ы тоже
        $config.inbounds
    )
    outbounds = $outbounds
    route = @{
        final = $outbounds[0].tag
        auto_detect_interface = $true
    }
}

$tunConfig | ConvertTo-Json -Depth 30 | Set-Content $Tun -Encoding UTF8
Write-Host "[OK] TUN config created: $Tun" -ForegroundColor Green
