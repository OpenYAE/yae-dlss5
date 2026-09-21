[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [string] $GameDir,

    [string] $DependenciesDir = (Join-Path $PSScriptRoot 'THIRD-PARTY-FILES-HERE')
)

$ErrorActionPreference = 'Stop'
$payload = Join-Path $PSScriptRoot 'payload'
$tempRoot = $null

function Get-Sha256([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-NvidiaRuntime([string] $Path, [string] $ExpectedProduct) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required NVIDIA runtime is missing: $Path"
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or
        -not $signature.SignerCertificate -or
        $signature.SignerCertificate.Subject -notmatch 'NVIDIA Corporation') {
        throw "NVIDIA signature validation failed for $Path (status: $($signature.Status))."
    }

    $version = (Get-Item -LiteralPath $Path).VersionInfo
    if ([string]$version.ProductName -notmatch $ExpectedProduct) {
        throw "Unexpected product name in ${Path}: '$($version.ProductName)'."
    }
}

if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'A 64-bit version of Windows is required.'
}
if (-not (Test-Path -LiteralPath $payload -PathType Container)) {
    throw "Payload folder is missing: $payload"
}
if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) {
    throw "Game folder does not exist: $GameDir"
}
if (-not (Test-Path -LiteralPath $DependenciesDir -PathType Container)) {
    throw "Dependency folder does not exist: $DependenciesDir"
}

$GameDir = (Resolve-Path -LiteralPath $GameDir).Path
$DependenciesDir = (Resolve-Path -LiteralPath $DependenciesDir).Path
$gameExe = Join-Path $GameDir 'YOU_ARE_EMPTY.exe'

if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
    throw "YOU_ARE_EMPTY.exe was not found in: $GameDir"
}

$actualExeHash = Get-Sha256 $gameExe

$lumeniteZip = Join-Path $DependenciesDir 'LumeniteFX-mainline.zip'
$nvngxDlss = Join-Path $DependenciesDir 'nvngx_dlss.dll'
$nvngxDlssNr = Join-Path $DependenciesDir 'nvngx_dlssnr.dll'

if (-not (Test-Path -LiteralPath $lumeniteZip -PathType Leaf)) {
    throw "LumeniteFX-mainline.zip is missing from: $DependenciesDir"
}
Assert-NvidiaRuntime -Path $nvngxDlss -ExpectedProduct 'Deep Learning SuperSampling'
Assert-NvidiaRuntime -Path $nvngxDlssNr -ExpectedProduct 'DLSSNR'

$gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
if ($gpuNames.Count -gt 0 -and -not ($gpuNames -match 'NVIDIA GeForce RTX 50')) {
    Write-Warning ('DLSS Neural Rendering in this package was tested on RTX 50-series hardware. Detected: ' + ($gpuNames -join ', '))
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('YAE-DLSS5-' + [Guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    Expand-Archive -LiteralPath $lumeniteZip -DestinationPath $tempRoot -Force

    $kernel = Get-ChildItem -LiteralPath $tempRoot -Recurse -File -Filter 'lumenite_Kernel.fx' |
        Select-Object -First 1
    if (-not $kernel) {
        throw 'The LumeniteFX archive does not contain Shaders\lumenite_Kernel.fx.'
    }

    $shadersDir = $kernel.Directory.FullName
    $lumeniteRoot = Split-Path -Parent $shadersDir
    $lumeniteFiles = @(
        @{ Source = (Join-Path $shadersDir 'lumenite_Kernel.fx'); RelativePath = 'reshade-shaders\Shaders\lumenite_Kernel.fx' },
        @{ Source = (Join-Path $shadersDir 'include\lumenite_ColorManagement.fxh'); RelativePath = 'reshade-shaders\Shaders\include\lumenite_ColorManagement.fxh' },
        @{ Source = (Join-Path $shadersDir 'include\lumenite_Compute.fxh'); RelativePath = 'reshade-shaders\Shaders\include\lumenite_Compute.fxh' },
        @{ Source = (Join-Path $shadersDir 'include\lumenite_Helpers.fxh'); RelativePath = 'reshade-shaders\Shaders\include\lumenite_Helpers.fxh' },
        @{ Source = (Join-Path $shadersDir 'include\lumenite_Projections.fxh'); RelativePath = 'reshade-shaders\Shaders\include\lumenite_Projections.fxh' },
        @{ Source = (Join-Path $lumeniteRoot 'Textures\lumenite_bluenoise256.png'); RelativePath = 'reshade-shaders\Textures\lumenite_bluenoise256.png' }
    )

    foreach ($item in $lumeniteFiles) {
        if (-not (Test-Path -LiteralPath $item.Source -PathType Leaf)) {
            throw "Required LumeniteFX file is missing from the archive: $($item.Source)"
        }
    }

    $payloadRoot = (Resolve-Path -LiteralPath $payload).Path
    $sources = New-Object 'System.Collections.Generic.List[object]'

    foreach ($file in Get-ChildItem -LiteralPath $payloadRoot -Recurse -Force -File | Sort-Object FullName) {
        $sources.Add([pscustomobject]@{
            Source = $file.FullName
            RelativePath = $file.FullName.Substring($payloadRoot.Length + 1)
            Component = 'package'
        })
    }

    $sources.Add([pscustomobject]@{ Source = $nvngxDlss; RelativePath = 'host64\nvngx_dlss.dll'; Component = 'user-supplied NVIDIA runtime' })
    $sources.Add([pscustomobject]@{ Source = $nvngxDlssNr; RelativePath = 'host64\nvngx_dlssnr.dll'; Component = 'user-supplied NVIDIA runtime' })
    foreach ($item in $lumeniteFiles) {
        $sources.Add([pscustomobject]@{ Source = $item.Source; RelativePath = $item.RelativePath; Component = 'user-supplied LumeniteFX' })
    }

    $duplicates = @($sources | Group-Object RelativePath | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) {
        throw ('Duplicate target paths in installation plan: ' + (($duplicates.Name) -join ', '))
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupRoot = Join-Path $GameDir '_DLSS5-Backups'
    $backupDir = Join-Path $backupRoot $stamp

    if (-not $PSCmdlet.ShouldProcess($GameDir, "Install $($sources.Count) DLSS5 pipeline files with backup in $backupDir")) {
        return
    }

    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $records = New-Object 'System.Collections.Generic.List[object]'

    foreach ($entry in $sources) {
        $target = Join-Path $GameDir $entry.RelativePath
        $targetParent = Split-Path -Parent $target
        $hadOriginal = Test-Path -LiteralPath $target -PathType Leaf
        $originalHash = $null

        if ($hadOriginal) {
            $originalHash = Get-Sha256 $target
            $backupTarget = Join-Path $backupDir $entry.RelativePath
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupTarget) | Out-Null
            Copy-Item -LiteralPath $target -Destination $backupTarget -Force
        }

        New-Item -ItemType Directory -Force -Path $targetParent | Out-Null
        Copy-Item -LiteralPath $entry.Source -Destination $target -Force

        $records.Add([pscustomobject]@{
            RelativePath = $entry.RelativePath
            Component = $entry.Component
            HadOriginal = $hadOriginal
            OriginalHash = $originalHash
            InstalledHash = Get-Sha256 $target
        })
    }

    $manifest = [pscustomobject]@{
        CreatedAt = (Get-Date).ToString('o')
        GameDir = $GameDir
        GameExeSha256 = $actualExeHash
        BackupDir = $backupDir
        Files = $records
    }
    $manifestPath = Join-Path $backupDir 'install-manifest.json'
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Restore-YAE-DLSS5.ps1') -Destination (Join-Path $backupDir 'Restore-YAE-DLSS5.ps1') -Force

    Write-Host "Installed $($records.Count) files."
    Write-Host "Backup and manifest: $backupDir"
    Write-Host 'No registry, driver, Defender, Vulkan-layer, or system-directory changes were made.'

    $verify = Join-Path $GameDir 'Verify-DLSS5Feeder.ps1'
    if (Test-Path -LiteralPath $verify -PathType Leaf) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $verify -GamePath $GameDir -Exe 'YOU_ARE_EMPTY.exe' -NoPause
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The verifier returned exit code $LASTEXITCODE. Read its report before launching the game."
        }
    }
}
finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot -PathType Container)) {
        $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        if ($resolvedTemp.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $resolvedTemp) -like 'YAE-DLSS5-*') {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
}
