## Splitting your C Drive into two partitions

There are several utilities and scripts available to split the C drive into two partitions and move the user profile to the second partition. Here are some options:

EaseUS Partition Master: This is a third-party utility that allows you to split your C drive into two partitions without losing any data. You can then use the built-in feature to move your user profile to the new partition.

Windows built-in Disk Management tool: You can use the built-in Disk Management tool in Windows to create a new partition on your C drive, then move your user profile to the new partition using the mklink command in Command Prompt.

Sysprep: Sysprep is a built-in tool in Windows that allows you to prepare a Windows installation for cloning or imaging. Using Sysprep, you can create an unattended installation file that includes instructions to split the C drive into two partitions and move the user profile to the new partition.

Script: You can also create a custom script to split your C drive into two partitions and move your user profile to the new partition. This would require some technical knowledge and experience with scripting.

Regardless of which method you choose, it's important to backup your data before making any changes to your partition setup.

### Using mklink

To move the user profile to a different partition using mklink, you can follow these steps:

Create a new partition on your hard drive using the Disk Management tool in Windows.

Open Command Prompt as an administrator.

Type the following command to move the user profile to the new partition:

``` cmd
robocopy C:\Users D:\Users /mir /xj /copyall /sl
```

This command will copy all the user profile data from the C:\Users folder to the D:\Users folder while preserving all file attributes and symbolic links.

Type the following command to create a symbolic link to the new user profile location:

``` mathematica
mklink /j C:\Users D:\Users
```

This command will create a symbolic link named "Users" in the C:\ drive that points to the new user profile location at D:\Users.

Restart your computer to ensure that the changes take effect.

Note that moving the user profile to a different partition can be a complex process and should be done with caution. Be sure to backup all important data before making any changes to your system.

### Using SysPrep

To use Sysprep to move the user profile to a different partition, you can follow these steps:

Create a new partition on your hard drive using the Disk Management tool in Windows.

Open File Explorer and navigate to the C:\Windows\System32\Sysprep folder.

Right-click on the Sysprep.exe file and select "Run as administrator" to launch the System Preparation tool.

In the System Preparation Tool window, select the "Enter System Out-of-Box Experience (OOBE)" option and check the "Generalize" and "Shutdown" options.

Click on the "OK" button to start the Sysprep process. This will prepare your system for imaging or cloning.

Once the system has shut down, boot into Windows using a bootable media or a WinPE (Windows Preinstallation Environment) disk.

Open Command Prompt as an administrator and type the following command to move the user profile to the new partition:

``` bash
robocopy C:\Users D:\Users /mir /xj /copyall /sl
```

This command will copy all the user profile data from the C:\Users folder to the D:\Users folder while preserving all file attributes and symbolic links.

Type the following command to create a symbolic link to the new user profile location:

``` mathematica
mklink /j C:\Users D:\Users
```

This command will create a symbolic link named "Users" in the C:\ drive that points to the new user profile location at D:\Users.

Exit Command Prompt and restart your computer to ensure that the changes take effect.

Note that using Sysprep to move the user profile to a different partition is an advanced procedure and should be done with caution. Be sure to backup all important data before making any changes to your system.

### Using a custom script

To move the user profile to a different partition using a custom script, you can follow these steps:

Create a new partition on your hard drive using the Disk Management tool in Windows.

Open Notepad or any other text editor and create a new file.

Type or paste the following commands into the file:

``` bash
@echo off
robocopy C:\Users D:\Users /mir /xj /copyall /sl
rmdir /S /Q C:\Users
mklink /j C:\Users D:\Users
```

This script will use the robocopy command to copy all the user profile data from the C:\Users folder to the D:\Users folder, then delete the original C:\Users folder and create a symbolic link named "Users" in the C:\ drive that points to the new user profile location at D:\Users.

Save the file with a .bat extension, such as "move_user_profile.bat".

Right-click on the file and select "Run as administrator" to execute the script.

Restart your computer to ensure that the changes take effect.

Note that using a custom script to move the user profile to a different partition requires some technical knowledge and experience with scripting. Be sure to backup all important data before making any changes to your system.

### Use EaseUS Partition Master

To move the user profile to a different partition using EaseUS Partition Master, you can follow these steps:

Open EaseUS Partition Master and select the C drive.

Click on the "Resize/Move" button in the toolbar.

In the Resize/Move window, drag the left slider to the right to shrink the C drive partition and create unallocated space on the hard drive.

Right-click on the unallocated space and select "Create".

In the Create Partition window, select the file system and partition label for the new partition, and adjust the partition size as needed.

Click on the "OK" button to create the new partition.

Right-click on the C drive partition and select "Migrate OS to SSD/HDD".

In the Migrate OS window, select the new partition as the destination drive, and adjust the partition size as needed.

Click on the "Next" button to proceed with the migration process.

In the Summary window, review the migration settings and click on the "Proceed" button to start the migration process.

Wait for the migration process to complete.

Restart your computer to ensure that the changes take effect.

Note that using EaseUS Partition Master to move the user profile to a different partition requires some technical knowledge and experience with partition management software. Be sure to backup all important data before making any changes to your system.
