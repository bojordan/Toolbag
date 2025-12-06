Write-Host "Loading profile... $($PSCommandPath)" -ForegroundColor Yellow

Import-Module posh-git
$GitPromptSettings.WindowTitle = $false
$GitPromptSettings.DefaultPromptPath.ForegroundColor = [ConsoleColor]::Green #0x98c379
$GitPromptSettings.DefaultPromptWriteStatusFirst = $true
$GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`n'
$GitPromptSettings.DefaultPromptSuffix = '$(">" * ($nestedPromptLevel + 1)) '

# Set directory color to blue without blackground
$PSStyle.FileInfo.Directory = "`e[94m"

Set-Alias becomp 'C:\Program Files\Beyond Compare 4\BComp.exe'
Set-Alias beyondcompare becomp 

# Define paths
$reposPath = 'D:\src\Repos'
if (!(Test-Path $reposPath)) {
    $reposPath = 'C:\src\Repos'
}
if (!(Test-Path $reposPath)) {
    Write-Warning "Unable to locate $($reposPath)"
}

$toolsPath = 'D:\tools'
if (!(Test-Path $toolsPath)) {
    $toolsPath = 'C:\workspace\tools'
}
if (!(Test-Path $toolsPath)) {
    Write-Warning "Unable to locate $($toolsPath)"
}

. $PSScriptRoot/windowing.ps1
. $PSScriptRoot/machine_setup.ps1
. $PSScriptRoot/helpers.ps1
. $PSScriptRoot/visualstudio.ps1
if (Test-Path "$PSScriptRoot/private.ps1") {
    . $PSScriptRoot/private.ps1
}

$env:path += ";$toolsPath\;$toolsPath\jre1.8.0_121\bin"
$env:path += ";C:\Program Files\Git\usr\bin"
$env:path += ";$reposPath\Toolbag\ps"
$env:path += ";$env:USERPROFILE\.dotnet\tools"
$env:path += ";$env:USERPROFILE\AppData\Roaming\npm"
$env:path += ";$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code"

Set-Location $reposPath
