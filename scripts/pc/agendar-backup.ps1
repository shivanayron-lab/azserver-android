# Schedules baixar-backup.ps1 in Windows: daily at -At and 5 minutes after logon; if the PC
# was off at that time, it runs as soon as it is back (StartWhenAvailable). No admin needed.
#   agendar-backup.ps1 -Url https://<fixed address> -Token <backup.token> [-Dir pasta] [-At 18:00] [-Name "AZS - Backup"]
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Token,
    [string]$Dir = (Join-Path $PSScriptRoot 'backups'),
    [string]$At = '18:00',
    [string]$Name = 'AZS - Backup do servidor Android'
)
$script = Join-Path $PSScriptRoot 'baixar-backup.ps1'
$arg = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Url `"$Url`" -Token `"$Token`" -Dir `"$Dir`""
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
$t1 = New-ScheduledTaskTrigger -Daily -At $At
$t2 = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$t2.Delay = 'PT5M'
$s = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -RunOnlyIfNetworkAvailable
Register-ScheduledTask -TaskName $Name -Action $a -Trigger $t1, $t2 -Settings $s -Force `
    -Description "Baixa o backup criptografado do servidor Android para $Dir" | Out-Null
Start-ScheduledTask -TaskName $Name
Write-Output "Tarefa '$Name' criada e executada uma vez. Histórico: $Dir\backup.log"
