#CREATE A dynamic vhdx on C with maximum size equal to the free space on drive C

$driveLetter = "H" # Change this to the desired drive letter for the mounted volume
$size=[Math]::Truncate((Get-PSDrive C).Free/1000000000)*1000
$scriptpath="$psscriptroot\tmp.txt"
$filePath = "C:\BACKUP.vhdx" # Change this to the desired path and name for the VHD file
$stream = [System.IO.StreamWriter]::new($scriptpath)
$stream.Write("create vdisk file=""$filepath"" maximum=$size type=expandable`r`nselect vdisk file=""$filepath""`r`nattach vdisk`r`ncreate partition primary`r`nformat fs=NTFS label=""Backup"" quick`r`nassign letter=$driveletter`r`n")
$stream.Close()
$cmdline="echo hi&&diskpart /s ""$scriptpath"""
echo $cmdline
cmd /c $cmdline
del $scriptpath
h:
$hst=hostname
$filePath = "H:\backup.bat"
$stream = [System.IO.StreamWriter]::new($filePath)
$stream.Write("@echo off`r`ncd /d %~dp0`r`nwbadmin start backup -backupTarget:H: -include:C: -allCritical -quiet`r`ntakeown /F H:\windowsimagebackup /a /r /d y > nul`r`nicacls H:\windowsimagebackup /reset /T > nul`r`nwinget export -o H:\windowsimagebackup\$hst\MyApps.json`r`nwmic path softwarelicensingservice get OA3xOriginalProductKey>H:\windowsimagebackup\$hst\ProductKey.txt")
$stream.Close()
cmd /c "H:\backup.bat" /q
$backuppath='H:\windowsimagebackup\'+$hst+'\Drivers'
Export-WindowsDriver -Online -Destination $backuppath
$filePath = "C:\BACKUP.vhdx"
Dismount-DiskImage -ImagePath $filepath
