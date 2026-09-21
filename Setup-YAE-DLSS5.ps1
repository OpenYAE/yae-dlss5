[CmdletBinding()]
param(
    [string] $GameDir,
    [string] $DependenciesDir = (Join-Path $PSScriptRoot 'THIRD-PARTY-FILES-HERE'),
    [switch] $LaunchGame
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$lumeniteUrl = 'https://codeload.github.com/umar-afzaal/LumeniteFX/zip/refs/heads/mainline'
$dlssUrl = 'https://raw.githubusercontent.com/NVIDIA/DLSS/main/lib/Windows_x86_64/rel/nvngx_dlss.dll'
$dlssNrUrl = 'https://github.com/RankFTW/rhi-repo/releases/download/dlssnr-310.8.0/nvngx_dlssnr_310.8.0.zip'
$dlssNrArchiveSha256 = '388C0A7912E15EC911B9C9E11A692142B11FE387DDF2B637D8C358138FFFB3AC'
$dlssNrDllSha256 = 'E16BCF15E16E13F527491CDF7845B2FE6521A738D8F7C9C721866A8496E1FC8E'
$tempRoot = $null

function Get-Sha256([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-NvidiaRuntime([string] $Path, [string] $ExpectedProduct) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    $version = (Get-Item -LiteralPath $Path).VersionInfo
    return ($signature.Status -eq 'Valid' -and
            $signature.SignerCertificate -and
            $signature.SignerCertificate.Subject -match 'NVIDIA Corporation' -and
            [string]$version.ProductName -match $ExpectedProduct)
}

function Preserve-InvalidFile([string] $Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $preserved = "$Path.invalid-$stamp"
        Move-Item -LiteralPath $Path -Destination $preserved -Force
        Write-Warning "Invalid existing file was preserved as: $preserved"
    }
}

function Download-Atomic([string] $Uri, [string] $Destination, [string] $Label) {
    $partial = "$Destination.download"
    if (Test-Path -LiteralPath $partial -PathType Leaf) {
        Remove-Item -LiteralPath $partial -Force
    }
    Write-Host "Downloading $Label ..."
    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $partial
    Move-Item -LiteralPath $partial -Destination $Destination -Force
    Write-Host "Downloaded $Label."
}

function Select-GameFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = 'Select the You Are Empty folder that contains YOU_ARE_EMPTY.exe'
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'Game-folder selection was cancelled.'
    }
    return $dialog.SelectedPath
}

function Test-DirectoryWriteAccess([string] $Path) {
    $probe = Join-Path $Path ('.yae-dlss5-write-test-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($probe, 'write test')
        Remove-Item -LiteralPath $probe -Force
        return $true
    }
    catch {
        if (Test-Path -LiteralPath $probe -PathType Leaf) {
            Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

try {
    Write-Host 'You Are Empty - DLSS 5 automatic setup'
    Write-Host '========================================'
    Write-Host ''

    if (-not $GameDir) {
        $localExe = Join-Path $PSScriptRoot 'YOU_ARE_EMPTY.exe'
        if (Test-Path -LiteralPath $localExe -PathType Leaf) {
            $GameDir = $PSScriptRoot
        }
        else {
            $GameDir = Select-GameFolder
        }
    }

    if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {
        throw "Game folder does not exist: $GameDir"
    }
    $GameDir = (Resolve-Path -LiteralPath $GameDir).Path

    $gameExe = Join-Path $GameDir 'YOU_ARE_EMPTY.exe'
    if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
        throw "YOU_ARE_EMPTY.exe was not found in: $GameDir"
    }

    if (-not (Test-DirectoryWriteAccess -Path $GameDir)) {
        if (-not (Test-IsAdministrator)) {
            Write-Host 'The game folder requires administrator access. Requesting UAC elevation...'
            $elevatedArgs = @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-File', ('"' + $PSCommandPath + '"'),
                '-GameDir', ('"' + $GameDir + '"'),
                '-DependenciesDir', ('"' + $DependenciesDir + '"')
            )
            if ($LaunchGame) { $elevatedArgs += '-LaunchGame' }
            $elevated = Start-Process -FilePath 'powershell.exe' -ArgumentList $elevatedArgs -Verb RunAs -Wait -PassThru
            exit $elevated.ExitCode
        }
        throw "The game folder is not writable: $GameDir"
    }

    New-Item -ItemType Directory -Force -Path $DependenciesDir | Out-Null
    $DependenciesDir = (Resolve-Path -LiteralPath $DependenciesDir).Path

    $lumeniteZip = Join-Path $DependenciesDir 'LumeniteFX-mainline.zip'
    $nvngxDlss = Join-Path $DependenciesDir 'nvngx_dlss.dll'
    $nvngxDlssNr = Join-Path $DependenciesDir 'nvngx_dlssnr.dll'

    if (-not (Test-Path -LiteralPath $lumeniteZip -PathType Leaf)) {
        Download-Atomic -Uri $lumeniteUrl -Destination $lumeniteZip -Label 'LumeniteFX from the author repository'
    }
    else {
        Write-Host 'Using existing LumeniteFX-mainline.zip.'
    }

    if (-not (Test-NvidiaRuntime -Path $nvngxDlss -ExpectedProduct 'Deep Learning SuperSampling')) {
        Preserve-InvalidFile -Path $nvngxDlss
        Download-Atomic -Uri $dlssUrl -Destination $nvngxDlss -Label 'nvngx_dlss.dll from NVIDIA/DLSS'
        if (-not (Test-NvidiaRuntime -Path $nvngxDlss -ExpectedProduct 'Deep Learning SuperSampling')) {
            throw 'The downloaded nvngx_dlss.dll failed NVIDIA signature or product-name validation.'
        }
    }
    else {
        Write-Host 'Using existing, NVIDIA-signed nvngx_dlss.dll.'
    }

    if (-not (Test-NvidiaRuntime -Path $nvngxDlssNr -ExpectedProduct 'DLSSNR')) {
        Preserve-InvalidFile -Path $nvngxDlssNr
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('YAE-DLSS5-bootstrap-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
        $nrArchive = Join-Path $tempRoot 'nvngx_dlssnr_310.8.0.zip'
        Download-Atomic -Uri $dlssNrUrl -Destination $nrArchive -Label 'pinned DLSS-NR runtime archive from RankFTW/rhi-repo'

        $archiveHash = Get-Sha256 $nrArchive
        if ($archiveHash -ne $dlssNrArchiveSha256) {
            throw "DLSS-NR archive hash mismatch. Expected $dlssNrArchiveSha256, got $archiveHash."
        }

        $nrExtract = Join-Path $tempRoot 'nr'
        Expand-Archive -LiteralPath $nrArchive -DestinationPath $nrExtract -Force
        $nrSource = Get-ChildItem -LiteralPath $nrExtract -Recurse -File -Filter 'nvngx_dlssnr.dll' |
            Select-Object -First 1
        if (-not $nrSource) {
            throw 'The verified DLSS-NR archive does not contain nvngx_dlssnr.dll.'
        }

        $dllHash = Get-Sha256 $nrSource.FullName
        if ($dllHash -ne $dlssNrDllSha256) {
            throw "DLSS-NR DLL hash mismatch. Expected $dlssNrDllSha256, got $dllHash."
        }
        if (-not (Test-NvidiaRuntime -Path $nrSource.FullName -ExpectedProduct 'DLSSNR')) {
            throw 'The extracted nvngx_dlssnr.dll failed NVIDIA signature or product-name validation.'
        }
        Copy-Item -LiteralPath $nrSource.FullName -Destination $nvngxDlssNr -Force
    }
    else {
        Write-Host 'Using existing, NVIDIA-signed nvngx_dlssnr.dll.'
    }

    $installer = Join-Path $PSScriptRoot 'Install-YAE-DLSS5.ps1'
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
        throw "Installer is missing: $installer"
    }

    Write-Host ''
    Write-Host "Installing into: $GameDir"
    & $installer -GameDir $GameDir -DependenciesDir $DependenciesDir

    Write-Host ''
    Write-Host 'Installation completed. Launch YOU_ARE_EMPTY.exe normally.'
    Write-Host 'Home opens ReShade; Insert opens the host/OptiScaler panel.'

    if ($LaunchGame) {
        Start-Process -FilePath $gameExe -WorkingDirectory $GameDir
    }
}
catch {
    Write-Error $_
    exit 1
}
finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot -PathType Container)) {
        $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTemp.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolvedTemp) -like 'YAE-DLSS5-bootstrap-*') {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
