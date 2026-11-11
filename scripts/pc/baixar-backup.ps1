# Downloads the newest encrypted backup of the Android server and keeps the last N.
#   baixar-backup.ps1 -Url https://<fixed address> -Token <backup.token> [-Dir pasta] [-Keep 30]
# Schedule it with agendar-backup.ps1. The files stay encrypted (see references/05-backup.md).
param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Token,
    [string]$Dir = (Join-Path $PSScriptRoot 'backups'),
    [int]$Keep = 30
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Force $Dir | Out-Null
$Log = Join-Path $Dir 'backup.log'
function Log($msg) { Add-Content -Path $Log -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg) -Encoding UTF8 }

try {
    $h = @{ 'X-Backup-Token' = $Token }
    $base = $Url.TrimEnd('/') + '/_backup'
    $info = Invoke-RestMethod -Uri "$base/latest.json" -Headers $h -TimeoutSec 60
    if (-not $info.name) { Log 'nenhum backup no aparelho ainda'; exit 0 }
    $dest = Join-Path $Dir $info.name
    if (Test-Path $dest) { Log "já tenho $($info.name)"; exit 0 }

    $tmp = "$dest.part"
    Invoke-WebRequest -Uri "$base/latest.enc" -Headers $h -OutFile $tmp -TimeoutSec 600 -UseBasicParsing
    $sha = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()
    if ($sha -ne $info.sha256) { Remove-Item $tmp; throw 'arquivo corrompido (sha256 não confere)' }
    Move-Item $tmp $dest
    Get-ChildItem $Dir -Filter 'backup-*.tar.gz.enc' | Sort-Object Name -Descending |
        Select-Object -Skip $Keep | Remove-Item
    Log "ok $($info.name) ($($info.size) bytes, de $($info.date) UTC)"
}
catch {
    Log "ERRO: $($_.Exception.Message)"
    exit 1
}
