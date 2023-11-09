@echo off
net stop wuauserv
net stop cryptSvc
net stop bits
net stop msiserver

echo Deleting SoftwareDistribution folder...
rd /s /q C:\Windows\SoftwareDistribution

echo Creating new SoftwareDistribution folder...
mkdir C:\Windows\SoftwareDistribution

echo Restarting Windows Update service...
net start wuauserv
net start cryptSvc
net start bits
net start msiserver

echo SoftwareDistribution folder has been flushed successfully.

