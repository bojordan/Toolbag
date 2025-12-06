# Set-VsVars 2026
$insiders2026 = "C:\Program Files\Microsoft Visual Studio\18\Insiders\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
$enterprise2026 = "C:\Program Files\Microsoft Visual Studio\18\Enterprise\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"

if (Test-Path $insiders2026) {
    Import-Module $insiders2026
    Enter-VsDevShell -VsInstallPath 'C:\Program Files\Microsoft Visual Studio\18\Insiders\'
} elseif (Test-Path $enterprise2026) {
    Import-Module $enterprise2026
    Enter-VsDevShell -VsInstallPath 'C:\Program Files\Microsoft Visual Studio\18\Enterprise\'
}

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
