# Requires: Windows 10/11, PowerShell 5/7+, oscdimg.exe in PATH (Windows ADK Deployment Tools)
# Purpose : Build a Windows 11 ISO that bypasses CPU/TPM checks by removing sources\appraiserres.dll

$ErrorActionPreference = 'Stop'

function Get-DownloadsFolder {
    $downloads = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    if (-not (Test-Path $downloads)) { New-Item -ItemType Directory -Path $downloads | Out-Null }
    return $downloads
}

function New-WorkFolder ($base) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $path  = Join-Path $base "Win11_NoTPM_Work_$stamp"
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function Find-ISO-Candidates ($downloads) {
    # Look for big ISOs (likely Windows 10/11), prefer Win11-ish names, newest first
    $isos = Get-ChildItem -Path $downloads -Filter *.iso -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -ge 4GB } |
            Sort-Object LastWriteTime -Descending

    # Weight by name hints
    $ranked = $isos | Select-Object @{n='Score';e={
                    ($_.Name -match 'win( ?)?11|windows.*11') * 100 +
                    ($_.Name -match 'english|en[-_]?us') * 10 +
                    ($_.Name -match 'x64|amd64') * 5
                 }}, FullName, Name, Length, LastWriteTime |
              Sort-Object Score, LastWriteTime -Descending
    return ,$ranked
}

function Show-OpenFileDialog ($initialDir) {
    try {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = 'Select Windows 11 ISO'
        $dlg.InitialDirectory = $initialDir
        $dlg.Filter = 'ISO Files (*.iso)|*.iso'
        $dlg.Multiselect = $false
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dlg.FileName
        }
        return $null
    } catch {
        Write-Host "WinForms file dialog unavailable. Falling back to console prompt." -ForegroundColor Yellow
        $path = Read-Host "Enter full path to the Windows 11 ISO"
        if ([string]::IsNullOrWhiteSpace($path)) { return $null }
        return $path
    }
}

function Mount-IsoAndGetDriveLetter ($isoPath) {
    Write-Host "Mounting ISO: $isoPath" -ForegroundColor Cyan
    $img = Mount-DiskImage -ImagePath $isoPath -PassThru
    # Try to get the volume associated with this image
    Start-Sleep -Milliseconds 600
    $vol = ($img | Get-Volume) 2>$null
    if (-not $vol -or -not $vol.DriveLetter) {
        # Alternate query
        $di  = Get-DiskImage -ImagePath $isoPath
        $vol = Get-Volume | Where-Object { $_.ObjectId -like "*$($di.Number)*" } 2>$null
    }
    if (-not $vol -or -not $vol.DriveLetter) { throw "Could not determine mounted drive letter." }
    return ($vol | Select-Object -First 1).DriveLetter + ":"
}

function Copy-FromISO ($srcRoot, $dstRoot) {
    Write-Host "Copying ISO contents to: $dstRoot" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $dstRoot -Force | Out-Null
    # Use robocopy for speed and resiliency
    $null = robocopy $srcRoot $dstRoot /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP
}

function Remove-AppraiserRes ($dstRoot) {
    $appraiser = Join-Path (Join-Path $dstRoot 'sources') 'appraiserres.dll'
    if (Test-Path $appraiser) {
        Write-Host "Removing: $appraiser" -ForegroundColor Cyan
        Remove-Item $appraiser -Force
    } else {
        Write-Host "Note: appraiserres.dll not found (may already be absent in this build)." -ForegroundColor Yellow
    }
}

function Build-ISO ($srcRoot, $outIsoPath) {
    $etfsboot = Join-Path $srcRoot 'boot\etfsboot.com'
    $efisys   = Join-Path $srcRoot 'efi\microsoft\boot\efisys.bin'
    if (-not (Test-Path $etfsboot)) { throw "Missing boot image: $etfsboot" }
    if (-not (Test-Path $efisys))   { throw "Missing boot image: $efisys" }

    $bootData = "2#p0,e,b$etfsboot#pEF,e,b$efisys"

    $args = @(
        '-m',             # ignore max size
        '-o',             # optimize files
        '-u2',            # enable UDF
        '-udfver102',     # UDF 1.02 (broadly compatible)
        "-bootdata:$bootData",
        $srcRoot,
        $outIsoPath
    )

    Write-Host "Running: oscdimg $($args -join ' ')" -ForegroundColor Cyan
    $p = Start-Process -FilePath 'oscdimg' -ArgumentList $args -NoNewWindow -PassThru -Wait
    if ($p.ExitCode -ne 0) { throw "oscdimg failed with exit code $($p.ExitCode)" }
}

# ----------------- Main -----------------
$Downloads = Get-DownloadsFolder
$Work      = New-WorkFolder -base $Downloads
$Extract   = Join-Path $Work 'Extracted'
New-Item -ItemType Directory -Path $Extract | Out-Null

# 1) Choose ISO (auto-pick from Downloads; if ambiguous or none, show a file dialog)
$candidates = Find-ISO-Candidates -downloads $Downloads
$isoSrc = $null

if ($candidates.Count -ge 1) {
    # If exactly one or a clear winner by score, take it; else prompt
    $best = $candidates | Select-Object -First 1
    if ($candidates.Count -eq 1 -or $best.Score -gt (($candidates | Select-Object -Skip 1 | Select-Object -First 1).Score)) {
        Write-Host "Using ISO from Downloads: $($best.FullName)" -ForegroundColor Green
        $isoSrc = $best.FullName
    } else {
        Write-Host "Multiple ISO candidates found in Downloads." -ForegroundColor Yellow
        $isoSrc = Show-OpenFileDialog -initialDir $Downloads
    }
} else {
    Write-Host "No suitable ISO found in Downloads." -ForegroundColor Yellow
    $isoSrc = Show-OpenFileDialog -initialDir $Downloads
}

if (-not $isoSrc -or -not (Test-Path $isoSrc)) { throw "No ISO selected. Aborting." }

# 2) Mount, copy, remove appraiserres.dll
$drive = Mount-IsoAndGetDriveLetter -isoPath $isoSrc
try {
    Copy-FromISO -srcRoot $drive -dstRoot $Extract
} finally {
    Dismount-DiskImage -ImagePath $isoSrc -ErrorAction SilentlyContinue
}

Remove-AppraiserRes -dstRoot $Extract

# 3) Build output ISO in Downloads
$outIso = Join-Path $Downloads ("Win11_NoTPM_{0}.iso" -f (Get-Date -Format 'yyyyMMdd_HHmm'))
Build-ISO -srcRoot $Extract -outIsoPath $outIso

Write-Host "`nSuccess!" -ForegroundColor Green
Write-Host "Patched ISO created at:`n$outIso" -ForegroundColor Green

# (Optional) Clean up working folder:
# Remove-Item -Recurse -Force $Work
