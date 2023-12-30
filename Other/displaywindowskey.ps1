function ConvertToKey($Key) {
    $KeyOffset = 52
    $i = 28
    $Chars = "BCDFGHJKMPQRTVWXY2346789"
    do {
        $Cur = 0
        $x = 14
        do {
            $Cur = $Cur * 256
            $Cur = $Key[$x + $KeyOffset] + $Cur
            $Key[$x + $KeyOffset] = [math]::Floor($Cur / 24) -band 255
            $Cur = $Cur % 24
            $x = $x - 1
        } while ($x -ge 0)
        $i = $i - 1
        $KeyOutput = $Chars[$Cur] + $KeyOutput
        if ((29 - $i) % 6 -eq 0 -and $i -ne -1) {
            $i = $i - 1
            $KeyOutput = "-" + $KeyOutput
        }
    } while ($i -ge 0)
    return $KeyOutput
}

$WshShell = New-Object -ComObject WScript.Shell
$Key = $WshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DigitalProductId")
Write-Host (ConvertToKey($Key))
