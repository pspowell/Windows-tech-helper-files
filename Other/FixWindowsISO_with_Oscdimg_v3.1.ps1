<#
.SYNOPSIS
  Fix a Windows ISO by removing sources\appraiserres.dll; ensure oscdimg.exe is available
  (copy to System32), uninstall ADK immediately after copying (Option A), rebuild the ISO, and clean up.

.NOTES
  - Requires Administrator.
  - Uses only PowerShell operators (-and, -or). No Unicode punctuation.
  - Uses WINGET to install the ADK Deployment Tools first (handles architecture correctly).
  - If winget isn't present, script will instruct the user to install ADK manually (no flaky bootstrapper).
#>

[CmdletBinding()]
param(
  [string]$IsoPath,
  [string]$OutputIsoPath
)

function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $pr = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Re-launching elevated..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    [Diagnostics.Process]::Start($psi) | Out-Null
    exit
  }
}

function Get-ADKInstallRoot {
  $keys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots"
  )
  foreach ($k in $keys) {
    try {
      $v = (Get-ItemProperty -Path $k -ErrorAction Stop).KitsRoot10
      if ($v) { return $v }
    } catch {}
  }
  return $null
}

function Find-OscdimgCandidatePaths {
  $candidates = New-Object System.Collections.Generic.List[string]
  $kits = Get-ADKInstallRoot
  if ($kits) {
    $candidates.Add((Join-Path $kits "Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"))
    $candidates.Add((Join-Path $kits "Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe"))
    $candidates.Add((Join-Path $kits "Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\oscdimg.exe"))
  }
  $candidates.Add("C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe")
  $candidates.Add("C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe")
  $candidates.Add("C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\oscdimg.exe")
  $candidates.Add("C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe")
  $candidates.Add("C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe")
  $candidates.Add("C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\Oscdimg\oscdimg.exe")
  return $candidates
}

function Get-ADKUninstallCommands {
  $roots = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
  )
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($r in $roots) {
    try {
      Get-ChildItem $r -ErrorAction Stop | ForEach-Object {
        try {
          $p = Get-ItemProperty $_.PsPath -ErrorAction Stop
          $name = "$($p.DisplayName)"
          $u = "$($p.UninstallString)"
          if ($name -and $u) {
            if ($name -like "*Windows Assessment and Deployment Kit*" -or $name -like "*Windows ADK*" -or $name -like "*Windows PE add-on*") {
              $out.Add($u.Trim('"'))
            }
          }
        } catch {}
      }
    } catch {}
  }
  return $out
}

function Parse-UninstallString {
  param([string]$S)
  $exe = $null; $args = ""
  if (-not $S) { return @{Exe=$null; Args=""} }
  $S = $S.Trim()
  if ($S.StartsWith('"')) {
    $idx = $S.IndexOf('"',1)
    if ($idx -gt 0) {
      $exe = $S.Substring(1,$idx-1)
      if ($S.Length -gt ($idx+1)) { $args = $S.Substring($idx+1).Trim() }
    } else { $exe = $S.Trim('"') }
  } else {
    $sp = $S.IndexOf(' ')
    if ($sp -gt 0) { $exe = $S.Substring(0,$sp); $args = $S.Substring($sp+1).Trim() } else { $exe = $S }
  }
  return @{Exe=$exe; Args=$args}
}

function Invoke-SilentUninstall {
  param([string]$UninstallString)
  if (-not $UninstallString) { return $false }
  if ($UninstallString -match "(?i)msiexec(\.exe)?") {
    if ($UninstallString -match "\{[0-9A-F\-]{36}\}") {
      $prod = $Matches[0]
      Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $prod /qn /norestart" -Wait -WindowStyle Hidden | Out-Null
      return $true
    } else {
      $rest = ($UninstallString -replace "(?i)^\s*msiexec(\.exe)?\s*", "").Trim()
      if ($rest -notmatch "(?i)(/quiet|/qn)") { $rest += " /qn" }
      if ($rest -notmatch "(?i)(/norestart)") { $rest += " /norestart" }
      Start-Process -FilePath "msiexec.exe" -ArgumentList $rest -Wait -WindowStyle Hidden | Out-Null
      return $true
    }
  } else {
    $p = Parse-UninstallString -S $UninstallString
    if (-not $p.Exe) { return $false }
    $args = $p.Args
    if ($args -and ($args -notmatch "(?i)(/quiet|/qn)")) { $args += " /quiet" }
    if ($args -notmatch "(?i)(/norestart)") { $args += " /norestart" }
    try {
      Start-Process -FilePath $p.Exe -ArgumentList $args -Wait -WindowStyle Hidden | Out-Null
      return $true
    } catch { return $false }
  }
}

function Test-Command {
  param([string]$Name)
  try { $null = Get-Command $Name -ErrorAction Stop; return $true } catch { return $false }
}

function Ensure-Oscdimg {
  $cmd = Get-Command oscdimg.exe -ErrorAction SilentlyContinue
  if ($cmd) { Write-Host "Found oscdimg.exe in PATH at $($cmd.Source)"; return $cmd.Source }

  $sys32 = Join-Path $env:SystemRoot "System32\oscdimg.exe"
  if (Test-Path $sys32) { Write-Host "Found oscdimg.exe at $sys32"; return $sys32 }

  foreach ($p in Find-OscdimgCandidatePaths) {
    if (Test-Path $p) {
      Write-Host "Found oscdimg.exe at $p"
      try { Copy-Item -Path $p -Destination $sys32 -Force; Write-Host "Copied oscdimg.exe to $sys32" -ForegroundColor Green } catch { Write-Warning $_.Exception.Message }
      if (Test-Path $sys32) {
        # Option A: uninstall ADK now
        $unins = Get-ADKUninstallCommands
        foreach ($u in $unins) { Invoke-SilentUninstall $u | Out-Null }
        return $sys32
      } else {
        return $p
      }
    }
  }

  # Install via Winget first (handles architecture automatically)
  if (Test-Command -Name "winget") {
    Write-Host "Installing Windows ADK (Deployment Tools) via winget..." -ForegroundColor Yellow
    $adkId = "Microsoft.WindowsADK"
    $peId  = "Microsoft.WindowsADK.PEAddon"  # may or may not exist; ignore failures
    try {
      Start-Process -FilePath "winget" -ArgumentList @("install","-e","--id", $adkId,"--accept-package-agreements","--accept-source-agreements","--silent") -Wait -NoNewWindow | Out-Null
    } catch { Write-Warning "winget install for ADK failed: $($_.Exception.Message)" }

    # Re-scan
    foreach ($p in Find-OscdimgCandidatePaths) {
      if (Test-Path $p) {
        try { Copy-Item -Path $p -Destination $sys32 -Force; Write-Host "Copied oscdimg.exe to $sys32" -ForegroundColor Green } catch { Write-Warning "Could not copy to System32. Using $p" }
        # Uninstall via winget if possible
        try { Start-Process -FilePath "winget" -ArgumentList @("uninstall","-e","--id", $adkId,"--silent") -Wait -NoNewWindow | Out-Null } catch {}
        try { Start-Process -FilePath "winget" -ArgumentList @("uninstall","-e","--id", $peId,"--silent")  -Wait -NoNewWindow | Out-Null } catch {}
        if (Test-Path $sys32) { return $sys32 } else { return $p }
      }
    }

    # Try PE add-on too (some builds place tools under that)
    try { Start-Process -FilePath "winget" -ArgumentList @("install","-e","--id", $peId,"--accept-package-agreements","--accept-source-agreements","--silent") -Wait -NoNewWindow | Out-Null } catch {}
    foreach ($p in Find-OscdimgCandidatePaths) {
      if (Test-Path $p) {
        try { Copy-Item -Path $p -Destination $sys32 -Force; Write-Host "Copied oscdimg.exe to $sys32" -ForegroundColor Green } catch { Write-Warning "Could not copy to System32. Using $p" }
        try { Start-Process -FilePath "winget" -ArgumentList @("uninstall","-e","--id", $adkId,"--silent") -Wait -NoNewWindow | Out-Null } catch {}
        try { Start-Process -FilePath "winget" -ArgumentList @("uninstall","-e","--id", $peId,"--silent")  -Wait -NoNewWindow | Out-Null } catch {}
        if (Test-Path $sys32) { return $sys32 } else { return $p }
      }
    }

    Write-Error "Winget installed ADK but oscdimg.exe not found in expected paths."
    return $null
  }

  Write-Error "oscdimg.exe not found and winget is unavailable. Please install 'Windows ADK (Deployment Tools)' then re-run."
  return $null
}

function Get-IsoLabel {
  param([string]$IsoPath)
  try {
    $m = Mount-DiskImage -ImagePath $IsoPath -StorageType ISO -PassThru -ErrorAction Stop
    try {
      $vol = ($m | Get-Volume)
      if ($vol -is [System.Array]) { $vol = $vol | Select-Object -First 1 }
      $label = $null
      if ($vol) { $label = $vol.FileSystemLabel }
      if (-not $label) { $label = [IO.Path]::GetFileNameWithoutExtension($IsoPath) }
    } finally {
      Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
    }
  } catch {
    Write-Warning "Could not read ISO label. Using file name stem."
    $label = [IO.Path]::GetFileNameWithoutExtension($IsoPath)
  }
  $label = [string]$label
  if (-not $label) { $label = "WIN11_NO_TPM" }
  $label = ($label -replace '[^A-Za-z0-9_-]','_')
  if ($label.Length -gt 32) { $label = $label.Substring(0,32) }
  return $label
}

function Select-IsoIfNeeded {
  param([string]$IsoPath)
  if ($IsoPath -and (Test-Path $IsoPath)) { return (Resolve-Path $IsoPath).Path }
  Add-Type -AssemblyName System.Windows.Forms
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Filter = "ISO files (*.iso)|*.iso|All files (*.*)|*.*"
  $dlg.Title = "Select a Windows ISO"
  if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.FileName }
  throw "No ISO selected."
}

function Expand-Iso {
  param([string]$IsoPath,[string]$WorkDir)
  New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
  Write-Host "Mounting ISO..."
  $m = Mount-DiskImage -ImagePath $IsoPath -StorageType ISO -PassThru
  try {
    $letter = ($m | Get-Volume).DriveLetter
    if (-not $letter) { throw "Failed to get mounted drive letter." }
    $src = "$($letter):"
    Write-Host "Copying files from $src to $WorkDir ..."
    robocopy "$src\" "$WorkDir\" /MIR | Out-Null
  } finally {
    Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
  }
}

function Remove-AppraiserRes {
  param([string]$WorkDir)
  $f = Join-Path $WorkDir "sources\appraiserres.dll"
  if (Test-Path $f) { Remove-Item -Force $f; Write-Host "Removed: sources\appraiserres.dll" -ForegroundColor Green } else { Write-Host "appraiserres.dll not found (already absent)" -ForegroundColor DarkYellow }
}

function Build-Iso {
  param([string]$Oscdimg,[string]$WorkDir,[string]$OutIso,[string]$VolLabel)

  $bios = Join-Path $WorkDir "boot\etfsboot.com"
  $efi1 = Join-Path $WorkDir "efi\microsoft\boot\efisys.bin"
  $efi2 = Join-Path $WorkDir "efi\microsoft\boot\efisys_noprompt.bin"

  Write-Host "Preflight:"
  $biosStatus = if (Test-Path $bios) { "FOUND" } else { "missing" }
  $efi1Status = if (Test-Path $efi1) { "FOUND" } else { "missing" }
  $efi2Status = if (Test-Path $efi2) { "FOUND" } else { "missing" }
  Write-Host ("  BIOS etfsboot.com     : {0}" -f $biosStatus)
  Write-Host ("  UEFI efisys.bin       : {0}" -f $efi1Status)
  Write-Host ("  UEFI efisys_noprompt  : {0}" -f $efi2Status)
  Write-Host ("  Volume label          : {0}" -f $VolLabel)
  Write-Host ("  Output ISO            : {0}" -f $OutIso)

  if (Test-Path $OutIso) {
    Write-Host "Output exists, deleting: $OutIso" -ForegroundColor DarkYellow
    Remove-Item -Force $OutIso
  }

  # Build strategies (most complete first). Always pass SOURCE then DESTINATION.
  $strategies = @()

  if ((Test-Path $bios) -and (Test-Path $efi1)) {
    $boot = "-bootdata:2#p0,e,b`"$bios`"#pEF,e,b`"$efi1`""
    $strategies += ,@("-m","-o","-u2","-udfver102","-l$VolLabel",$boot,"$WorkDir","$OutIso")
  }
  if ((Test-Path $bios) -and (Test-Path $efi2)) {
    $boot = "-bootdata:2#p0,e,b`"$bios`"#pEF,e,b`"$efi2`""
    $strategies += ,@("-m","-o","-u2","-udfver102","-l$VolLabel",$boot,"$WorkDir","$OutIso")
  }
  if (Test-Path $efi1) {
    $boot = "-bootdata:1#pEF,e,b`"$efi1`""
    $strategies += ,@("-m","-o","-u2","-udfver102","-l$VolLabel",$boot,"$WorkDir","$OutIso")
  }
  if (Test-Path $efi2) {
    $boot = "-bootdata:1#pEF,e,b`"$efi2`""
    $strategies += ,@("-m","-o","-u2","-udfver102","-l$VolLabel",$boot,"$WorkDir","$OutIso")
  }
  if (Test-Path $bios) {
    $strategies += ,@("-m","-o","-u2","-udfver102","-l$VolLabel","-b",$bios,"$WorkDir","$OutIso")
  }
  # last resort: non-bootable ISO (still useful to inspect)
  $strategies += ,@("-m","-o","-u2","-udfver102","-l$VolLabel","$WorkDir","$OutIso")

  $logRoot = Join-Path $env:TEMP ("Oscdimg-Logs-" + [Guid]::NewGuid())
  New-Item -ItemType Directory -Force -Path $logRoot | Out-Null

  $attempt = 0
  foreach ($args in $strategies) {
    $attempt++
    $cmdLine = "`"$Oscdimg`" " + ($args -join " ")
    Write-Host ("Attempt {0}: {1}" -f $attempt, $cmdLine)

    $outFile = Join-Path $logRoot ("attempt{0}_stdout.txt" -f $attempt)
    $errFile = Join-Path $logRoot ("attempt{0}_stderr.txt" -f $attempt)
    $cmdFile = Join-Path $logRoot ("attempt{0}_command.txt" -f $attempt)

    $proc = Start-Process -FilePath $Oscdimg -ArgumentList $args -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru -Wait -NoNewWindow
    $ec = $proc.ExitCode
    $cmdLine | Out-File -FilePath $cmdFile -Encoding UTF8

    if ($ec -eq 0) {
      Write-Host ("Build succeeded. Logs at: {0}" -f $logRoot) -ForegroundColor DarkGray
      return
    } else {
      Write-Warning ("oscdimg exit code {0} on attempt {1} - see {2}" -f $ec, $attempt, $errFile)
    }
  }

  Write-Host ("Logs are in: {0}" -f $logRoot) -ForegroundColor Yellow
  throw "All oscdimg strategies failed. See logs."
}

# ---- MAIN ----
try {
  Assert-Admin

  $osc = Ensure-Oscdimg
  if (-not $osc) { throw "oscdimg.exe not available." }

  $IsoPath = Select-IsoIfNeeded -IsoPath $IsoPath
  $IsoPath = (Resolve-Path $IsoPath).Path
  $label = Get-IsoLabel -IsoPath $IsoPath

  if (-not $OutputIsoPath) {
    $dir = Split-Path -Parent $IsoPath
    $name = [IO.Path]::GetFileNameWithoutExtension($IsoPath) + "-NoTPM.iso"
    $OutputIsoPath = Join-Path $dir $name
  }

  $work = Join-Path $env:TEMP ("WinISO-Fix-" + [Guid]::NewGuid())
  Expand-Iso -IsoPath $IsoPath -WorkDir $work
  Remove-AppraiserRes -WorkDir $work
  Build-Iso -Oscdimg $osc -WorkDir $work -OutIso $OutputIsoPath -VolLabel $label
  Write-Host "Successfully created: $OutputIsoPath" -ForegroundColor Green
}
catch {
  Write-Error $_
}
finally {
  if ($work -and (Test-Path $work)) {
    try { Remove-Item -Recurse -Force -Path $work } catch {}
  }
}
