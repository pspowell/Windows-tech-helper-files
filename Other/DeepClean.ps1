$tempFilesENV = Get-ChildItem "env:\TEMP"
$tempFiles = $tempFilesENV.Value
$windowsTemp = "C:\Windows\Temp\*"
$winDist = "C:\Windows\SoftwareDistribution"
Clear-RecycleBin -Force
Remove-Item -Recure "$tempFiles\*"
Get-Service -Name WUAUSERV | Stop-Service
Remove-Item -Path $winDist -Recurse -Force
Get-Service -Name WUAUSERV | Start-Service
cleanmgr /sagerun:1 /VeryLowDisk /AUTOCLEAN | Out-Null
dism.exe /Online /Cleanup-Image /RestoreHealth
dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
dism.exe /Online /Cleanup-Image /StartComponentCleanup
dism.exe /Online /Cleanup-Image /SPSuperseded
