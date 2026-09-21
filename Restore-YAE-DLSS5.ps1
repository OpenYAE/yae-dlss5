[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $GameDir,

    [string] $BackupDir,

    [switch] $ConfirmRestore
)

$ErrorActionPreference = 'Stop'

function Get-Sha256([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {
    throw "Game folder does not exist: $GameDir"
}
$GameDir = (Resolve-Path -LiteralPath $GameDir).Path

if (-not $BackupDir) {
    $backupRoot = Join-Path $GameDir '_DLSS5-Backups'
    $latest = Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction Stop |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "No backup was found under $backupRoot" }
    $BackupDir = $latest.FullName
}
elseif (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    throw "Backup folder does not exist: $BackupDir"
}
else {
    $BackupDir = (Resolve-Path -LiteralPath $BackupDir).Path
}

$manifestPath = Join-Path $BackupDir 'install-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Backup manifest is missing: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$changedRoot = Join-Path $BackupDir 'pre-restore-changes'

if (-not $ConfirmRestore) {
    throw 'Restore removes files added by the package and restores saved originals. Re-run with -ConfirmRestore after checking GameDir and BackupDir.'
}

foreach ($entry in $manifest.Files) {
    $relative = [string]$entry.RelativePath
    $target = Join-Path $GameDir $relative
    $currentHash = Get-Sha256 $target

    if ($currentHash -and $currentHash -ne [string]$entry.InstalledHash) {
        $preserve = Join-Path $changedRoot $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $preserve) | Out-Null
        Move-Item -LiteralPath $target -Destination $preserve -Force
    }

    if ([bool]$entry.HadOriginal) {
        $saved = Join-Path $BackupDir $relative
        if (-not (Test-Path -LiteralPath $saved -PathType Leaf)) {
            throw "Saved original is missing: $saved"
        }
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        Copy-Item -LiteralPath $saved -Destination $target -Force
    }
    elseif (Test-Path -LiteralPath $target -PathType Leaf) {
        Remove-Item -LiteralPath $target -Force
    }
}

$dirList = New-Object 'System.Collections.Generic.List[string]'
foreach ($entry in $manifest.Files) {
    $dir = Split-Path -Parent (Join-Path $GameDir ([string]$entry.RelativePath))
    while ($dir -and $dir -ne $GameDir -and $dir.StartsWith($GameDir, [StringComparison]::OrdinalIgnoreCase)) {
        $dirList.Add($dir)
        $dir = Split-Path -Parent $dir
    }
}
$candidateDirs = @($dirList | Sort-Object Length -Descending -Unique)

foreach ($dir in $candidateDirs) {
    if ($dir -and $dir -ne $GameDir -and (Test-Path -LiteralPath $dir -PathType Container)) {
        if (-not (Get-ChildItem -LiteralPath $dir -Force | Select-Object -First 1)) {
            Remove-Item -LiteralPath $dir -Force
        }
    }
}

Write-Host "Restore complete from $BackupDir"
if (Test-Path -LiteralPath $changedRoot -PathType Container) {
    Write-Host "Files changed after installation were preserved in $changedRoot"
}
