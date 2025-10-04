<# 
.SYNOPSIS
    Fetch oscdimg.exe from Microsoft (via WinGet or the official ADK), copy it to C:\Tools\Oscdimg, then clean up.

.DESCRIPTION
    - Installs Windows ADK (Deployment Tools) from Microsoft: tries WinGet first, falls back to the official ADK bootstrapper.
    - Copies oscdimg.exe (amd64 and x86 if present) to a permanent tools folder.
    - Optionally adds that folder to the user's PATH (commented).
    - Uninstalls the ADK afterwards so only oscdimg remains.
    Run as Administrator.
#>

#----- Configuration -----
$DestRoot = 'C:\Tools\Oscdimg'
$TempRoot = Join-Path $env:TEMP 'get-oscdimg'
$ErrorActionPreference = 'Stop'

# Official Microsoft ADK bootstrapper fwlink (kept here so you always pull from Microsoft).
# If it ever changes, grab the current link from Microsoft's ADK page.
$AdkFwLink = 'https://go.microsoft.com/fwlink/?linkid=2289980'  # Known Windows ADK link as of late 2024

#----- Helpers -----
function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw "This script must be run as Administrator."
    }
}

function Test-WinGet {
    try {
        $null = winget --version 2>$null
        return $true
    } catch { 
        return $false 
    }
}

function Path-Ensure {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { 
        New-Item -ItemType Directory -Path $Dir | Out-Null 
    }
}

function Copy-Oscdimg {
    param(
        [Parameter(Mandatory=$true)][string]$AdkRoot, 
        [Parameter(Mandatory=$true)][string]$Dest
    )

    $paths = @(
        (Join-Path $AdkRoot 'Deployment Tools\amd64\Oscdimg\oscdimg.exe'),
        (Join-Path $AdkRoot 'Deployment Tools\x86\Oscdimg\oscdimg.exe')
    )
    $candidates = $paths | Where-Object { Test-Path $_ }

    if (-not $candidates -or $candidates.Count -eq 0) {
        throw "Couldn't find oscdimg.exe under '$AdkRoot'."
    }

    Path-Ensure $Dest
    foreach ($exe in $candidates) {
        $arch = (Split-Path (Split-Path $exe -Parent) -Leaf) # amd64 or x86
        $target = Join-Path $Dest ("oscdimg_{0}.exe" -f $arch)
        Copy-Item $exe $target -Force
    }

    # Also copy as generic name if amd64 exists
    $amd64Exe = Join-Path $Dest 'oscdimg_amd64.exe'
    if (Test-Path $amd64Exe) {
        Copy-Item $amd64Exe (Join-Path $Dest 'oscdimg.exe') -Force
    }
}

function Get-ADKInstallRoot {
    # Typical install base for Windows 10/11 ADK
    $root = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit'
    if (Test-Path $root) { 
        return $root 
    }
    return $null
}

function Uninstall-ADK {
    # Prefer WinGet uninstall if available, else try the ADK's Uninstall.exe
    if (Test-WinGet) {
        try {
            winget uninstall -e --id Microsoft.WindowsADK --silent --accept-source-agreements --accept-package-agreements | Out-Null
            return
        } catch { 
            Write-Verbose "winget uninstall failed: $($_.Exception.Message)"
        }
    }

    $adkRoot = Get-ADKInstallRoot
    if ($adkRoot) {
        $uninst = Join-Path $adkRoot 'Uninstall.exe'
        if (Test-Path $uninst) {
            Start-Process $uninst -ArgumentList '/quiet' -Wait
        }
    }
}

#----- Main -----
Assert-Admin
Path-Ensure $TempRoot
Write-Host "Working folder: $TempRoot"

$installedVia = $null
$adkRoot = Get-ADKInstallRoot

if (-not $adkRoot) {
    Write-Host "ADK not found; attempting to install minimal components..."

    if (Test-WinGet) {
        Write-Host "Using WinGet to install Microsoft.WindowsADK..."
        winget install -e --id Microsoft.WindowsADK --silent --accept-source-agreements --accept-package-agreements
        Start-Sleep -Seconds 5
        $adkRoot = Get-ADKInstallRoot
        if ($adkRoot) { $installedVia = 'winget' }
    }

    if (-not $adkRoot) {
        Write-Host "Falling back to Microsoft ADK bootstrapper (Deployment Tools only)..."
        $adkSetup = Join-Path $TempRoot 'adksetup.exe'
        Invoke-WebRequest -UseBasicParsing -Uri $AdkFwLink -OutFile $adkSetup

        # Install only Deployment Tools (where oscdimg lives)
        $args = @(
            '/quiet',
            '/norestart',
            '/ceip off',
            '/features', 'OptionId.DeploymentTools'
        )
        Start-Process $adkSetup -ArgumentList $args -Wait -NoNewWindow
        $adkRoot = Get-ADKInstallRoot
        if ($adkRoot) { $installedVia = 'bootstrapper' }
    }

    if (-not $adkRoot) {
        throw "Failed to install the Windows ADK."
    }
} else {
    Write-Host "Found existing ADK at: $adkRoot"
}

# Copy oscdimg to the permanent tools folder
Copy-Oscdimg -AdkRoot $adkRoot -Dest $DestRoot
Write-Host "oscdimg copied to: $DestRoot"
Get-ChildItem $DestRoot -Filter 'oscdimg*.exe' | Select-Object Name,Length,LastWriteTime | Format-Table

# (Optional) Add to PATH for current user
# $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
# if ($userPath -notmatch [Regex]::Escape($DestRoot)) {
#     [Environment]::SetEnvironmentVariable('PATH', "$userPath;$DestRoot", 'User')
#     Write-Host "Added $DestRoot to your user PATH. Restart shells to pick it up."
# }

# If we installed the ADK in this run, uninstall it so only oscdimg remains
if ($installedVia) {
    Write-Host "Cleaning up: uninstalling the Windows ADK ($installedVia)..."
    Uninstall-ADK
}

# Remove temp files
if (Test-Path $TempRoot) { 
    Remove-Item $TempRoot -Recurse -Force 
}

Write-Host ("Done. Try:`n  {0}\oscdimg.exe -?" -f $DestRoot)

