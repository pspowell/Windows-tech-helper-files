# Specify the URL for downloading Disk2VHD
$downloadUrl = "https://download.sysinternals.com/files/Disk2vhd.zip"
$outputPath = "$env:USERPROFILE\Downloads\Disk2vhd.zip"
$extractPath = "$env:USERPROFILE\Downloads\Disk2vhd"

# Download# Specify the URL for downloading Disk2VHD
$downloadUrl = "https://download.sysinternals.com/files/Disk2vhd.zip"
$outputPath = "$env:USERPROFILE\Downloads\Disk2vhd.zip"
$extractPath = "$env:USERPROFILE\Downloads\Disk2vhd"

# Download Disk2VHD zip file
Write-Output "Downloading Disk2VHD..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath

# Create a directory to extract the zip file
Write-Output "Extracting Disk2VHD..."
New-Item -ItemType Directory -Force -Path $extractPath | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($outputPath, $extractPath)

# Specify the path where Disk2VHD is located
$disk2vhdPath = "$env:USERPROFILE\Downloads\Disk2vhd"

# Check if the system is 64-bit
if ([Environment]::Is64BitOperatingSystem) {
    Write-Output "This is a 64-bit system."
    $exePath = Join-Path $disk2vhdPath "Disk2vhd64.exe"
} else {
    Write-Output "This is not a 64-bit system."
    $exePath = Join-Path $disk2vhdPath "Disk2vhd.exe"
}

# Check if the executable exists
if (Test-Path $exePath) {
    Write-Output "Running the appropriate version of Disk2VHD..."
    Start-Process -FilePath $exePath -NoNewWindow -Wait
} else {
    Write-Output "Executable not found. Please ensure Disk2VHD is downloaded and extracted correctly."
}
