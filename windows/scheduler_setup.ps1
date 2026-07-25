<#
.SYNOPSIS
    Добавление задачи в планировщик Windows
#>

[CmdletBinding()]
param(
    [string]$SbDir = $PSScriptRoot,
    [string]$Time = "04:00",
    [string]$Mode = "proxy"
)

$ErrorActionPreference = "Stop"

$UpdateScript = Join-Path $SbDir "update-and-start.bat"
$TaskName = "CrossProtocolBreeder.Update"

# Удаляем старую
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[INFO] Removed old task" -ForegroundColor Cyan
}

# Создаём новую
$Action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"$UpdateScript`" $Mode"

$Trigger = New-ScheduledTaskTrigger -Daily -At $Time

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Description "Cross-Protocol Breeder auto-update (daily at $Time)" `
        -RunLevel Highest `
        -ErrorAction Stop
    Write-Host "[OK] Task created: $TaskName (daily at $Time, mode=$Mode)" -ForegroundColor Green
} catch {
    Write-Host "[ERR] Failed: $_" -ForegroundColor Red
    exit 1
}
