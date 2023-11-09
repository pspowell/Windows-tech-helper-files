# IMAGE_BACKUP.BAT
This batch file is meant to easily create a system image of the boot drive and all other essential partitions and data needed to successfully boot the computer.  

**NOTE**
This utility only backs up the partitions needed to boot the system.  In most situations, that is everything, but if the boot disk has been split or extra storage has been added (Drive D: for example), that drive will not be backed up.

## USAGE
1. Plug in your backup media
2. Copy the image backup.bat file to the backup media drive
3. Open a command prompt as administrator on the backup media drive and execute the script image_backup.bat.
 ```
    D:\>image_backup.bat
wbadmin 1.0 - Backup command-line tool
(C) Copyright Microsoft Corporation. All rights reserved.

Retrieving volume information...
This will back up SYSTEM(EFI System Partition) (100.00 MB),Windows(C:) to D:.
The backup operation to D: is starting.
Creating a shadow copy of the volumes specified for backup...
Creating a shadow copy of the volumes specified for backup...
Creating a backup of volume SYSTEM(EFI System Partition) (100.00 MB), copied (0%).
Creating a backup of volume SYSTEM(EFI System Partition) (100.00 MB), copied (100%).
The backup of volume SYSTEM(EFI System Partition) (100.00 MB) completed successfully.
Creating a backup of volume Windows(C:), copied (0%).
Creating a backup of volume Windows(C:), copied (5%).
Creating a backup of volume Windows(C:), copied (10%).
.
.
.
Creating a backup of volume Windows(C:), copied (100%).
The backup of volume Windows(C:) completed successfully.
Summary of the backup operation:
------------------

The backup operation successfully completed.
The backup of volume SYSTEM(EFI System Partition) (100.00 MB) completed successfully.
The backup of volume Windows(C:) completed successfully.
Log of files successfully backed up:
C:\Windows\Logs\WindowsBackup\Backup-05-04-2023_16-20-11.log

A subdirectory or file D:\windowsimagebackup\FarmPC\Drivers already exists.

Deployment Image Servicing and Management tool
Version: 10.0.19041.844

Image Version: 10.0.19045.2604

Exporting 1 of 8 - oem0.inf: The driver package successfully exported.
Exporting 2 of 8 - oem1.inf: The driver package successfully exported.
Exporting 3 of 8 - oem2.inf: The driver package successfully exported.
Exporting 4 of 8 - oem3.inf: The driver package successfully exported.
Exporting 5 of 8 - oem4.inf: The driver package successfully exported.
Exporting 6 of 8 - oem5.inf: The driver package successfully exported.
Exporting 7 of 8 - oem6.inf: The driver package successfully exported.
Exporting 8 of 8 - oem7.inf: The driver package successfully exported.
The operation completed successfully.

D:\>
```

## WHAT IT DOES
In these examples, the backup drive is D: and the computername is LENOVO
### **Executes WBADMIN**
Executes the WBADMIN utility to back up just drive C and essential boot partitions.  A directory *WindowsImageBackup\your_computername* is created on the backup drive
`wbadmin start backup -backupTarget:D: -include:C: -allCritical -quiet"`   
#### **Resets permissions on WINDOWSIMAGEBACKUP**
Since WBADMIN creates a directory on the backup drive which is protected, this script executes a few commands to unprotect the backup so it can be more easily viewed.   
`takeown /F D:\windowsimagebackup /a /r /d y > nul `   
`icacls D:\windowsimagebackup /reset /T > nul`  
#### **Exports special drivers to the backup directory**
All special drivers not typically shipped with Windows are exported to *WindowsImageBackup\your_computername\Drivers*  
`dism /online /export-driver /destination:D:\windowsimagebackup\LENOVO\Drivers`  
#### **If it exists, the product key is exported as well**
`wmic path softwarelicensingservice get OA3xOriginalProductKey>D:\windowsimagebackup\LENOVO\ProductKey.txt`  


