# Lazy VS Dev Shell: instead of loading the full developer environment at
# startup (~2-5s), create lightweight proxy stubs for common VS tools.
# The first invocation of any stub loads the dev shell, removes all stubs,
# and re-invokes the real command transparently.

$global:_vsDevShellLoaded = $false

function global:Enter-VS {
    if ($global:_vsDevShellLoaded) { Write-Host 'VS Dev Shell already loaded.' -ForegroundColor DarkGray; return }
    $global:_vsDevShellLoaded = $true

    $insiders2026 = "C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
    $enterprise2026 = "C:\Program Files\Microsoft Visual Studio\18\Enterprise\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"

    if (Test-Path $insiders2026) {
        Import-Module $insiders2026
        Enter-VsDevShell -VsInstallPath 'C:\Program Files\Microsoft Visual Studio\18\Insiders\'
    } elseif (Test-Path $enterprise2026) {
        Import-Module $enterprise2026
        Enter-VsDevShell -VsInstallPath 'C:\Program Files\Microsoft Visual Studio\18\Enterprise\'
    } else {
        Write-Warning 'No Visual Studio installation found.'
        $global:_vsDevShellLoaded = $false
        return
    }

    # Remove all proxy stubs now that the real tools are on PATH
    foreach ($t in @('msbuild','cl','link','lib','devenv','nmake','dumpbin','editbin','rc')) {
        if (Test-Path "function:global:$t") { Remove-Item "function:global:$t" }
    }
    Write-Host 'VS Dev Shell loaded.' -ForegroundColor Green
}

# Proxy stubs: calling any of these triggers Enter-VS, then runs the real tool
foreach ($_vsToolName in @('msbuild','cl','link','lib','devenv','nmake','dumpbin','editbin','rc')) {
    $sb = [scriptblock]::Create(@"
        Enter-VS
        `$exe = Get-Command '$_vsToolName' -CommandType Application -ErrorAction SilentlyContinue
        if (`$exe) { & `$exe @args } else { Write-Warning "'$_vsToolName' not found after loading VS Dev Shell." }
"@)
    Set-Item "function:global:$_vsToolName" $sb
}
Remove-Variable _vsToolName, sb -ErrorAction SilentlyContinue

# Launch non-admin VS Code from Administrator console.
# Get gsudo: choco install gsudo
function code { gsudo --integrity medium code $args }

function sln {
    # Get all solution files in current directory
    $slnxFiles = @(Get-ChildItem *.slnx -ErrorAction SilentlyContinue)
    $slnFiles = @(Get-ChildItem *.sln -ErrorAction SilentlyContinue)
    
    # Prioritize .slnx files if found
    if ($slnxFiles.Count -gt 0) {
        & $slnxFiles[0].FullName
        return
    }
    
    # Otherwise use .sln files
    if ($slnFiles.Count -eq 0) {
        # Check subdirectories
        $subSlnxFiles = @(Get-ChildItem *\*.slnx -ErrorAction SilentlyContinue)
        $subSlnFiles = @(Get-ChildItem *\*.sln -ErrorAction SilentlyContinue)
        
        if ($subSlnxFiles.Count -gt 0) {
            & $subSlnxFiles[0].FullName
        }
        elseif ($subSlnFiles.Count -gt 0) {
            & $subSlnFiles[0].FullName
        }
    }
    else {
        & $slnFiles[0].FullName
    }
}
