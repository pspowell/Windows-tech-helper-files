#CREATE A full backup set on the entered drive letter

do {
    $driveLetter = Read-Host "Please enter the backup drive letter only"
    if ($DriveLetter.Length -eq 1 -and $driveLetter -match "^[d-hD-H]$") {
        Write-Output "Valid input: $input"
        $valid = $true
    } else {
        Write-Output "Invalid input. Please try again."
        $valid = $false
    }
} while (-not $valid)

# Display the input
Write-Host "You entered: $DriveLetter"
$hst=hostname
$filePath = "${DriveLetter}:\Image_Backup.bat"
$stream = [System.IO.StreamWriter]::new($filePath)
$stream.Write("@echo off`r`ncd /d %~dp0`r`nwbadmin start backup -backupTarget:${DriveLetter}: -include:C: -allCritical -quiet`r`ntakeown /F ${DriveLetter}:\windowsimagebackup /a /r /d y > nul`r`nicacls ${DriveLetter}:\windowsimagebackup /reset /T > nul`r`nmd ${DriveLetter}:\windowsimagebackup\$hst\Drivers`r`ndism /online /export-driver /destination:${DriveLetter}:\windowsimagebackup\$hst\Drivers`r`nwinget export -o ${DriveLetter}:\windowsimagebackup\$hst\MyApps.json`r`nwmic path softwarelicensingservice get OA3xOriginalProductKey>${DriveLetter}:\windowsimagebackup\$hst\ProductKey.txt")
$stream.Close()
# Display a paragraph of text
Write-Host "`r`nThe backup script has been created at ${driveletter}\Image_Backup.bat`r`n`r`nTo execute the script change to the ${driveletter}: drive, right-click on the script, and select 'Run as Administrator'`r`n"

# Wait for user input
$userInput = Read-Host "Hit <Enter> to exit"