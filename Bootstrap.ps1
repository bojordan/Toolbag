<#
.SYNOPSIS
    Bootstrap this Toolbag repo on a new Windows machine (e.g. DevBox).

.DESCRIPTION
    Installs a small "stub" profile into the real PowerShell profile location(s)
    that dot-sources this repo's profile.ps1. This avoids hijacking the Windows
    Documents Known Folder, which is the historical mechanism in this repo and
    causes problems on DevBox (OneDrive Known Folder Move, repo pollution from
    apps that write to Documents, manual registry edit required to bootstrap).

    By default this script:
      * Discovers where the real Documents folder lives (handles OneDrive KFM).
      * Writes a stub profile.ps1 (CurrentUserAllHosts) for the requested
        PowerShell edition(s) that dot-sources <repo>/PowerShell/profile.ps1.
      * Does NOT touch the Documents Known Folder registry value.
      * Does NOT install dependencies (use -InstallDeps for that).

.PARAMETER Edition
    Which PowerShell edition(s) to install the stub profile for.
        Core    - PowerShell 7+ (pwsh)               [Documents\PowerShell]
        Desktop - Windows PowerShell 5.1 (powershell)[Documents\WindowsPowerShell]
        Both    - both editions (default)

.PARAMETER InstallDeps
    Also install the soft dependencies the profile uses:
      posh-git           (PSGallery)
      oh-my-posh         (winget: JanDeDobbeleer.OhMyPosh)
      gsudo              (winget: gerardog.gsudo)
      Beyond Compare 4   (winget: ScooterSoftware.BeyondCompare4)
    Anything that is already present is skipped.

.PARAMETER RestoreDocuments
    On a machine where this repo has been used the legacy way (Documents Known
    Folder redirected to the repo via HKCU\...\User Shell Folders\Personal),
    restore Documents to the Windows default ($env:USERPROFILE\Documents or
    the OneDrive KFM location, whichever is currently expected). This affects
    only the registry value; it does not move any files.

.PARAMETER DocumentsPath
    Override the detected real Documents path. Useful if you want the stubs
    placed somewhere specific (rare).

.PARAMETER Force
    Overwrite an existing stub profile even if it points somewhere else.

.PARAMETER WhatIf
    Show what would happen without making changes.

.EXAMPLE
    .\Bootstrap.ps1
    Install the stub profile for both pwsh and Windows PowerShell. No deps.

.EXAMPLE
    .\Bootstrap.ps1 -InstallDeps
    Install stubs and the optional dependencies via winget / PSGallery.

.EXAMPLE
    .\Bootstrap.ps1 -Edition Core -InstallDeps
    pwsh-only setup with deps.

.EXAMPLE
    .\Bootstrap.ps1 -RestoreDocuments
    Stop redirecting Documents to this repo (legacy machine cleanup).
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Core', 'Desktop', 'Both')]
    [string] $Edition = 'Both',

    [switch] $InstallDeps,

    [switch] $RestoreDocuments,

    [string] $DocumentsPath,

    [switch] $Force
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve repo root + the profile we want stubs to dot-source
# ---------------------------------------------------------------------------
$RepoRoot      = $PSScriptRoot
$RepoProfile   = Join-Path $RepoRoot 'PowerShell\profile.ps1'

if (-not (Test-Path $RepoProfile)) {
    throw "Cannot find repo profile at '$RepoProfile'. Run Bootstrap.ps1 from the repo root."
}

Write-Host ""
Write-Host "Toolbag bootstrap" -ForegroundColor Cyan
Write-Host "  Repo root:    $RepoRoot"
Write-Host "  Repo profile: $RepoProfile"
Write-Host ""

# ---------------------------------------------------------------------------
# Detect the *real* Documents folder, ignoring any legacy redirect that
# already points at this repo. Prefer OneDrive KFM if active; otherwise
# fall back to the local profile path.
# ---------------------------------------------------------------------------
function Get-RealDocumentsPath {
    param([string] $Override)

    if ($Override) { return $Override }

    # OneDrive Known Folder Move: enterprise DevBoxes commonly enforce this.
    foreach ($od in @($env:OneDriveCommercial, $env:OneDrive)) {
        if ($od -and (Test-Path (Join-Path $od 'Documents'))) {
            return (Join-Path $od 'Documents')
        }
    }

    # Default local Documents.
    return (Join-Path $env:USERPROFILE 'Documents')
}

$DocsRoot = Get-RealDocumentsPath -Override $DocumentsPath
Write-Host "  Documents:    $DocsRoot" -ForegroundColor DarkGray

# Warn if the *current* registry redirect points at this repo - that's the
# legacy setup and the user probably wants -RestoreDocuments at some point.
$personal = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name Personal -ErrorAction SilentlyContinue).Personal
if ($personal -and ($personal -ieq $RepoRoot)) {
    Write-Warning "Documents Known Folder is currently redirected to this repo ($personal)."
    Write-Warning "The new stub-profile pattern does not need that redirect. Re-run with -RestoreDocuments to undo it."
}

# ---------------------------------------------------------------------------
# Compute the stub profile target(s)
# ---------------------------------------------------------------------------
$targets = @()
switch ($Edition) {
    'Core'    { $targets += (Join-Path $DocsRoot 'PowerShell\profile.ps1') }
    'Desktop' { $targets += (Join-Path $DocsRoot 'WindowsPowerShell\profile.ps1') }
    'Both'    {
        $targets += (Join-Path $DocsRoot 'PowerShell\profile.ps1')
        $targets += (Join-Path $DocsRoot 'WindowsPowerShell\profile.ps1')
    }
}

# ---------------------------------------------------------------------------
# Stub content: tiny, self-explanatory, idempotent.
# Uses a literal repo path (no $PSScriptRoot magic) so it's unambiguous.
# ---------------------------------------------------------------------------
$stubMarker = '# Toolbag stub profile'
$stubContent = @"
$stubMarker -- managed by Bootstrap.ps1 in https://github.com/bojordan/Toolbag
# Edits here are not version-controlled. Edit '$RepoProfile' instead.
`$ToolbagProfile = '$RepoProfile'
if (Test-Path `$ToolbagProfile) {
    . `$ToolbagProfile
} else {
    Write-Warning "Toolbag profile not found at `$ToolbagProfile. Re-clone https://github.com/bojordan/Toolbag and re-run Bootstrap.ps1."
}
"@

function Install-StubProfile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string] $Path, [string] $Content, [switch] $Force)

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    if (Test-Path $Path) {
        $existing = Get-Content -Raw -LiteralPath $Path
        if ($existing -like "*$stubMarker*") {
            if ($existing -eq $Content) {
                Write-Host "  [=] Stub already current: $Path" -ForegroundColor DarkGray
                return
            }
            if ($PSCmdlet.ShouldProcess($Path, 'Update existing Toolbag stub')) {
                Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
                Write-Host "  [~] Stub updated:        $Path" -ForegroundColor Yellow
            }
            return
        }

        if (-not $Force) {
            Write-Warning "Profile already exists and is NOT a Toolbag stub: $Path"
            Write-Warning "Re-run with -Force to overwrite, or merge by hand."
            return
        }

        $backup = "$Path.bak-$(Get-Date -Format yyyyMMddHHmmss)"
        if ($PSCmdlet.ShouldProcess($Path, "Backup to $backup and replace")) {
            Copy-Item -LiteralPath $Path -Destination $backup
            Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
            Write-Host "  [!] Replaced (backup: $backup): $Path" -ForegroundColor Magenta
        }
        return
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Write new Toolbag stub')) {
        Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
        Write-Host "  [+] Stub installed:      $Path" -ForegroundColor Green
    }
}

Write-Host "Installing stub profile(s)..." -ForegroundColor Cyan
foreach ($t in $targets) {
    Install-StubProfile -Path $t -Content $stubContent -Force:$Force
}

# ---------------------------------------------------------------------------
# Optional: undo the legacy Documents redirect
# ---------------------------------------------------------------------------
if ($RestoreDocuments) {
    Write-Host ""
    Write-Host "Restoring Documents Known Folder to default..." -ForegroundColor Cyan
    if ($PSCmdlet.ShouldProcess($DocsRoot, "Set HKCU User Shell Folders\Personal")) {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
        Set-ItemProperty -Path $key -Name Personal -Value $DocsRoot -Type ExpandString -Force
        # Keep the (cached) Shell Folders value in sync for apps that read it.
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -Name Personal -Value $DocsRoot -Force
        Write-Host "  Documents -> $DocsRoot" -ForegroundColor Green
        Write-Host "  Note: existing files in the old location are NOT moved. Sign out and back in for all apps to pick this up." -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# Optional: install soft dependencies
# ---------------------------------------------------------------------------
if ($InstallDeps) {
    Write-Host ""
    Write-Host "Installing dependencies (use -WhatIf to preview)..." -ForegroundColor Cyan

    # posh-git via PSGallery
    if (Get-Module posh-git -ListAvailable) {
        Write-Host "  [=] posh-git already installed" -ForegroundColor DarkGray
    } elseif ($PSCmdlet.ShouldProcess('posh-git', 'Install-Module from PSGallery')) {
        try {
            if (-not (Get-PSRepository PSGallery -ErrorAction SilentlyContinue)) {
                Register-PSRepository -Default
            }
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
            Install-Module posh-git -Scope CurrentUser -Force -AllowClobber
            Write-Host "  [+] posh-git installed" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to install posh-git: $_"
        }
    }

    # winget-managed tools
    $wingetPkgs = [ordered]@{
        'oh-my-posh'        = 'JanDeDobbeleer.OhMyPosh'
        'gsudo'             = 'gerardog.gsudo'
        'Beyond Compare 4'  = 'ScooterSoftware.BeyondCompare.4'
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget is not available; skipping: $($wingetPkgs.Keys -join ', ')"
    } else {
        foreach ($display in $wingetPkgs.Keys) {
            $id = $wingetPkgs[$display]
            $listed = winget list --id $id --exact --accept-source-agreements 2>$null | Out-String
            if ($listed -match [regex]::Escape($id)) {
                Write-Host "  [=] $display already installed" -ForegroundColor DarkGray
                continue
            }
            if ($PSCmdlet.ShouldProcess($id, 'winget install')) {
                winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [+] $display installed" -ForegroundColor Green
                } else {
                    Write-Warning "winget install $id exited with code $LASTEXITCODE"
                }
            }
        }
    }

    # Things we cannot or should not silently install:
    Write-Host ""
    Write-Host "Manual follow-ups (not auto-installed):" -ForegroundColor Cyan
    Write-Host "  * Visual Studio 2026 (profile expects Insiders or Enterprise at C:\Program Files\Microsoft Visual Studio\18\)"
    Write-Host "  * JRE 1.8 at <toolsPath>\jre1.8.0_121\bin (only if you actually use it)"
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Bootstrap complete." -ForegroundColor Green
Write-Host "Open a new pwsh window to load the stub profile, or run: . `$PROFILE" -ForegroundColor DarkGray
