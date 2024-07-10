@echo off

cd /d "%~dp0"

rem Test for administrator
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo You must be logged in as a member of the Adminstrators group and right-click
    echo this batch file then "Run as Administrator" for the PowerShell script
    echo to execute properly.
    PAUSE
    GOTO :EOF
)

rem Get Drive Letter
set MYDRIVE="h:"

@echo off
setlocal enabledelayedexpansion
for /f "skip=1 delims=" %%a in ('wmic logicaldisk where "DeviceID='C:'" get FreeSpace /format:value') do for /f "delims=" %%b in ("%%a") do set "freespace=%%b"
set "freespace=%freespace:~10%"
set freemb=!freespace:~0,-6!
echo %freemb%
setlocal disabledelayedexpansion

set FILE_PATH="Diskpart_script.txt"
del %FILE_PATH%
echo select disk 0>>%FILE_PATH%
echo create vdisk file='C:\Backup.vhdx' maximum=%freemb% type=expandable>>%FILE_PATH%
echo select vdisk file='C:\Backup.vhdx'>>%FILE_PATH%
echo attach vdisk>>%FILE_PATH%
echo create partition primary>>%FILE_PATH%
echo format fs=ntfs label='Backup' quick>>%FILE_PATH%
echo assign letter=H>>%FILE_PATH%
echo exit>>%FILE_PATH%
diskpart /s "diskpart_script.txt"
del %FILE_PATH%

rem find hostname
FOR /F "usebackq" %%i IN (`hostname`) DO SET HOST=%%i

rem Backup
wbadmin start backup -backupTarget:%MYDRIVE% -include:C: -allCritical -quiet"

rem Take Ownership
takeown /F %mydrive%\windowsimagebackup /a /r /d y > nul
icacls %MYDRIVE%\windowsimagebackup /reset /T > nul

rem Get Product key
wmic path softwarelicensingservice get OA3xOriginalProductKey>%mydrive%\windowsimagebackup\%HOST%\ProductKey.txt

md %mydrive%\windowsimagebackup\%HOST%\Drivers
dism /online /export-driver /destination:%mydrive%\windowsimagebackup\%HOST%\Drivers
winget export -o %mydrive%\windowsimagebackup\%HOST%\MyApps.json

