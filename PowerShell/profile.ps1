$_profileSw = [System.Diagnostics.Stopwatch]::StartNew()
$_profileTimings = [System.Collections.Generic.List[string]]::new()
Write-Host "Loading profile... $($PSCommandPath)" -ForegroundColor Yellow

# oh-my-posh --init --shell pwsh --config "$PSScriptRoot/ohmyposhv3-v2.json" | Invoke-Expression

# Lazy-load posh-git: defers import until the shell is idle (after the first
# prompt is displayed), so startup feels instant. The git prompt appears on
# the second prompt refresh. Skips silently if posh-git isn't installed
# (run Bootstrap.ps1 -InstallDeps from the repo root).
$_sectionSw = [System.Diagnostics.Stopwatch]::StartNew()
if (Get-Module posh-git -ListAvailable) {
    Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        Import-Module posh-git -Global
        $global:GitPromptSettings.WindowTitle = $false
        $global:GitPromptSettings.DefaultPromptPath.ForegroundColor = [ConsoleColor]::Green
        $global:GitPromptSettings.DefaultPromptWriteStatusFirst = $true
        $global:GitPromptSettings.DefaultPromptBeforeSuffix.Text = '`n'
        $global:GitPromptSettings.DefaultPromptSuffix = '$(">" * ($nestedPromptLevel + 1)) '
    } | Out-Null
}
$_profileTimings.Add("  posh-git(defer): $($_sectionSw.ElapsedMilliseconds)ms")

# Set directory color to blue without blackground
$PSStyle.FileInfo.Directory = "`e[94m"

$_bcompPath = 'C:\Program Files\Beyond Compare 4\BComp.exe'
if (Test-Path $_bcompPath) {
    Set-Alias becomp $_bcompPath
    Set-Alias beyondcompare becomp
}
Remove-Variable _bcompPath -ErrorAction SilentlyContinue

# Define paths. The first hit wins; the last entry is a derived fallback so
# that the repo always knows where it lives even on a fresh DevBox where
# neither D:\ nor C:\src\Repos exists yet (the repo's own parent is the
# repos root).
$_sectionSw.Restart()
$_repoParent = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$reposPath = @('D:\src\Repos', 'C:\src\Repos', $_repoParent) |
    Where-Object { $_ -and (Test-Path $_) } |
    Select-Object -First 1
if (-not $reposPath) {
    Write-Warning "Unable to locate a repos root (tried D:\src\Repos, C:\src\Repos, $_repoParent)"
}

$toolsPath = @('D:\tools', 'C:\workspace\tools') |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
# Tools path is optional; only warn at -Verbose to avoid noise on minimal machines.
if (-not $toolsPath) {
    Write-Verbose "No tools path found (D:\tools or C:\workspace\tools)"
}
Remove-Variable _repoParent -ErrorAction SilentlyContinue
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
if (Test-Path "$PSScriptRoot/private.ps1") {
    . $PSScriptRoot/private.ps1
}
$_profileTimings.Add("  workspecific:    $($_sectionSw.ElapsedMilliseconds)ms")

# Append PATH entries that actually exist on this machine. Anything missing
# (e.g. JRE on a fresh DevBox) is silently skipped instead of polluting PATH.
$_pathCandidates = @(
    $toolsPath
    if ($toolsPath) { Join-Path $toolsPath 'jre1.8.0_121\bin' }
    'C:\Program Files\Git\usr\bin'
    if ($reposPath) { Join-Path $reposPath 'Toolbag\ps' }
    Join-Path $env:USERPROFILE '.dotnet\tools'
    Join-Path $env:USERPROFILE 'AppData\Roaming\npm'
    Join-Path $env:USERPROFILE 'AppData\Local\Programs\Microsoft VS Code'
)
foreach ($p in $_pathCandidates) {
    if ($p -and (Test-Path $p) -and ($env:path -notlike "*$p*")) {
        $env:path += ";$p"
    }
}
Remove-Variable _pathCandidates -ErrorAction SilentlyContinue

if ((-not ($env:TERM_PROGRAM -eq 'vscode')) -and $reposPath -and (Test-Path $reposPath)) {
    Set-Location $reposPath
}

Write-Host "Profile loaded in $($_profileSw.ElapsedMilliseconds)ms" -ForegroundColor Cyan
$_profileTimings | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
Remove-Variable _profileSw, _sectionSw, _profileTimings
