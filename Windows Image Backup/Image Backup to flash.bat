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
set MYDRIVE=%~d0

rem find hostname
FOR /F "usebackq" %%i IN (`hostname`) DO SET HOST=%%i

rem create a share to fix flash limitation
net share Backup=%MYDRIVE% /GRANT:EVERYONE,FULL /REMARK:"Backup Drive"

rem Perform the Backup
wbadmin start backup -backupTarget:\\%host%\Backup -include:C: -allCritical -quiet

rem Take Ownership
takeown /F %mydrive%\windowsimagebackup /a /r /d y > nul
icacls %MYDRIVE%\windowsimagebackup /reset /T > nul

rem Get Product key
wmic path softwarelicensingservice get OA3xOriginalProductKey>%mydrive%\windowsimagebackup\%HOST%\ProductKey.txt

md %mydrive%\windowsimagebackup\%HOST%\Drivers
dism /online /export-driver /destination:%mydrive%\windowsimagebackup\%HOST%\Drivers
winget export -o %mydrive%\windowsimagebackup\%HOST%\MyApps.json


rem Remove Backup share
net share Backup /DELETE 