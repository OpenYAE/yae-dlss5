[CmdletBinding()]
param(
    [string] $GameDir,
    [switch] $LaunchGame
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$sourceUrl = 'https://codeload.github.com/Blu2z/yae-dlss5/zip/refs/heads/main'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('YAE-DLSS5-online-' + [Guid]::NewGuid().ToString('N'))

try {
    Write-Host 'You Are Empty - DLSS 5 online installer'
    Write-Host '=========================================' 
    Write-Host ''

    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    $archive = Join-Path $tempRoot 'yae-dlss5-main.zip'
    $extract = Join-Path $tempRoot 'source'

    Write-Host 'Downloading the current installer package from GitHub...'
    Invoke-WebRequest -UseBasicParsing -Uri $sourceUrl -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force

    $setupFiles = @(Get-ChildItem -LiteralPath $extract -Recurse -File -Filter 'Setup-YAE-DLSS5.ps1')
    if ($setupFiles.Count -ne 1) {
        throw "Expected exactly one Setup-YAE-DLSS5.ps1, found $($setupFiles.Count)."
    }

    $setup = $setupFiles[0].FullName
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $setup
    )
    if ($GameDir) {
        $arguments += @('-GameDir', $GameDir)
    }
    if ($LaunchGame) {
        $arguments += '-LaunchGame'
    }

    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "The setup process returned exit code $LASTEXITCODE."
    }

    Write-Host ''
    Write-Host 'Online installation completed successfully.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTemp.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolvedTemp) -like 'YAE-DLSS5-online-*') {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
