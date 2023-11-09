# Set the path to the VHD file
$vhdPath = "C:\Path\To\VHD\File.vhd"

# Mount the VHD file as a virtual disk
Mount-DiskImage -ImagePath $vhdPath

# Get the drive letter of the mounted virtual disk
$driveLetter = (Get-DiskImage $vhdPath).AttachedDrive

# Get the computer name of the mounted virtual disk
$computerName = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" | Select-Object -ExpandProperty ComputerName

# Dismount the virtual disk
Dismount-DiskImage -ImagePath $vhdPath

# Output the computer name
Write-Host "Computer name of the offline VHD file: $computerName"