#Add New Markdown to right-click context menu
if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Classes\.md") -ne $true) {  New-Item "HKLM:\SOFTWARE\Classes\.md" -force -ea SilentlyContinue };
if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Classes\.md\ShellNew") -ne $true) {  New-Item "HKLM:\SOFTWARE\Classes\.md\ShellNew" -force -ea SilentlyContinue };
if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Classes\markdown") -ne $true) {  New-Item "HKLM:\SOFTWARE\Classes\markdown" -force -ea SilentlyContinue };
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Classes\.md' -Name '(default)' -Value 'markdown' -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Classes\.md\ShellNew' -Name 'NullFile' -Value '' -PropertyType String -Force -ea SilentlyContinue;
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Classes\markdown' -Name '(default)' -Value 'README' -PropertyType String -Force -ea SilentlyContinue;

#Add New Powershell to right-click context menu
if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Classes\.ps1\ShellNew") -ne $true) {  New-Item "HKLM:\SOFTWARE\Classes\.ps1\ShellNew" -force -ea SilentlyContinue };
New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Classes\.ps1\ShellNew' -Name 'NullFile' -Value '' -PropertyType String -Force -ea SilentlyContinue;
