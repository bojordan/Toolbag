$_profileSw = [System.Diagnostics.Stopwatch]::StartNew()
$_profileTimings = [System.Collections.Generic.List[string]]::new()
Write-Host "Loading profile... $($PSCommandPath)" -ForegroundColor Yellow

# oh-my-posh --init --shell pwsh --config "$PSScriptRoot/ohmyposhv3-v2.json" | Invoke-Expression

# Lazy-load posh-git: defers import until the shell is idle (after the first
# prompt is displayed), so startup feels instant. The git prompt appears on
# the second prompt refresh.
$_sectionSw = [System.Diagnostics.Stopwatch]::StartNew()
Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Import-Module posh-git -Global
    $global:GitPromptSettings.WindowTitle = $false
    $global:GitPromptSettings.DefaultPromptPath.ForegroundColor = [ConsoleColor]::Green
    $global:GitPromptSettings.DefaultPromptWriteStatusFirst = $true
    $global:GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`n'
    $global:GitPromptSettings.DefaultPromptSuffix = '$(">" * ($nestedPromptLevel + 1)) '
} | Out-Null
$_profileTimings.Add("  posh-git(defer): $($_sectionSw.ElapsedMilliseconds)ms")

# Set directory color to blue without blackground
$PSStyle.FileInfo.Directory = "`e[94m"

Set-Alias becomp 'C:\Program Files\Beyond Compare 4\BComp.exe'
Set-Alias beyondcompare becomp 

# Define paths
$_sectionSw.Restart()
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
$_profileTimings.Add("  path probing:    $($_sectionSw.ElapsedMilliseconds)ms")

$_sectionSw.Restart()
. $PSScriptRoot/windowing.ps1
$_profileTimings.Add("  windowing.ps1:   $($_sectionSw.ElapsedMilliseconds)ms")

$_sectionSw.Restart()
. $PSScriptRoot/machine_setup.ps1
$_profileTimings.Add("  machine_setup:   $($_sectionSw.ElapsedMilliseconds)ms")

$_sectionSw.Restart()
. $PSScriptRoot/helpers.ps1
$_profileTimings.Add("  helpers.ps1:     $($_sectionSw.ElapsedMilliseconds)ms")

$_sectionSw.Restart()
. $PSScriptRoot/visualstudio.ps1
$_profileTimings.Add("  visualstudio:    $($_sectionSw.ElapsedMilliseconds)ms")

$_sectionSw.Restart()
if (Test-Path "$PSScriptRoot/workspecific.ps1") {
    . $PSScriptRoot/workspecific.ps1
}
$_profileTimings.Add("  workspecific:    $($_sectionSw.ElapsedMilliseconds)ms")

$env:path += ";$toolsPath\;$toolsPath\jre1.8.0_121\bin"
$env:path += ";C:\Program Files\Git\usr\bin"
$env:path += ";$reposPath\Toolbag\ps"
$env:path += ";$env:USERPROFILE\.dotnet\tools"
$env:path += ";$env:USERPROFILE\AppData\Roaming\npm"
$env:path += ";$env:USERPROFILE\AppData\Local\Programs\Microsoft VS Code"

Set-Location $reposPath

Write-Host "Profile loaded in $($_profileSw.ElapsedMilliseconds)ms" -ForegroundColor Cyan
$_profileTimings | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
Remove-Variable _profileSw, _sectionSw, _profileTimings
