# Toolbag

A collection of PowerShell utilities and scripts for Windows development environment management.

## New machine setup

```powershell
git clone https://github.com/bojordan/Toolbag.git C:\src\Repos\Toolbag
cd C:\src\Repos\Toolbag
.\Bootstrap.ps1                   # write the stub profile(s)
.\Bootstrap.ps1 -InstallDeps      # also install posh-git / oh-my-posh / gsudo / Beyond Compare
```

That writes a tiny stub profile to your real `$PROFILE.CurrentUserAllHosts`
(both pwsh and Windows PowerShell by default) which dot-sources
`PowerShell/profile.ps1` from this repo. Open a new pwsh window.

The repo can be cloned anywhere; the bootstrap bakes the resolved path into
the stub. Use `-WhatIf` first if you want to preview, `-Force` to replace an
existing non-stub profile (a `.bak` is kept), and `-RestoreDocuments` if this
machine has the legacy Documents-Known-Folder redirect (see below).

### Why a stub instead of redirecting Documents?

The repo's older `Set-PowerShellProfileDirectory` function pointed the
Windows Documents Known Folder at this repo. That worked but had three
recurring problems:

1. Bootstrapping was chicken-and-egg - the function that does the redirect
   lives inside the profile that the redirect makes loadable.
2. Enterprise OneDrive Known Folder Move (DevBox default) silently
   competes with the redirect and wins on a fresh machine.
3. Every app that writes to Documents (Office, Visual Studio, IIS Express,
   `desktop.ini`, ...) ends up in the repo working tree.

The stub-profile pattern keeps Documents at the Windows default and only
puts a 5-line file there.

## PowerShell Scripts

### [profile.ps1](PowerShell/profile.ps1)
Main PowerShell profile that loads all other scripts and configures the shell environment.

**Features:**
- Lazy-loads posh-git via `PowerShell.OnIdle` event for instant shell startup (skipped if posh-git isn't installed)
- Startup timing diagnostics showing per-section load times
- Sets up directory colors
- Discovers `reposPath` and `toolsPath` from a list of candidates and falls back to the repo's own parent so a fresh DevBox still works
- Imports all utility scripts (windowing, machine_setup, helpers, visualstudio)
- Adds existing dev-tool directories to PATH (Git, .NET, npm, VS Code, JRE) - missing ones are skipped
- Sets Beyond Compare as default comparison tool when installed

### [helpers.ps1](PowerShell/helpers.ps1)
General-purpose utility functions for common development tasks.

**Functions:**
- `which` - Finds the full path of a command
- `Set-Title` - Changes the PowerShell window title
- `Convert-MessageBody` - Decodes base64-encoded message bodies
- `ConvertFrom-UnixTime` / `ConvertTo-UnixTime` - Unix timestamp conversion utilities
- `Get-GitRemote` - Retrieves the origin URL for a git repository
- `Get-GitBranchList` - Lists git branches sorted by most recent commit with details
- `Get-AssemblyVersion` - Extracts version information from .NET assemblies
- `Decode-Clipboard` / `Decode-Text` - Base64 decoding utilities
- `Decode-Jwt` - Decodes and pretty-prints JWT tokens (header and payload)

### [windowing.ps1](PowerShell/windowing.ps1)
Window management utilities using Windows API calls.

**Functions:**
- `Stop-Display` - Turns off the display; defers C# interop compilation to first use (aliases: `DisplayOff`, `off`, `MonOff`)
- `Gather-AllWindows` - Arranges all open windows in a cascading pattern
- `Get-AllWindows` - Retrieves all processes with visible windows
- `Set-Window` - Comprehensive window positioning and sizing utility with support for:
  - Setting window position (X, Y coordinates)
  - Setting window size (Width, Height)
  - Working with processes by name or ID
  - Pipeline support for batch operations

### [machine_setup.ps1](PowerShell/machine_setup.ps1)
System configuration functions for setting up a Windows development machine.

**Functions:**
- `Set-MouseWheelInverted` - Inverts mouse wheel scrolling direction (alias: `FlipFlopWheel`)
- `Set-CapsLockMappedToControl` - Remaps CapsLock key to Control via registry
- `Set-PowerShellProfileDirectory` - **Legacy.** Configures custom PowerShell profile location by redirecting the Documents Known Folder. Prefer the stub-profile pattern installed by `Bootstrap.ps1` instead.

### [Take-OwnershipRecursively.ps1](PowerShell/Take-OwnershipRecursively.ps1)
Recovers ownership and access on folder trees where some subdirectories deny
the current user. Run from an **elevated** PowerShell session, against a
folder tree you legitimately need to recover (e.g. files left behind by an
old user account, a broken uninstall, or a roaming profile).

For each folder it can't enumerate due to `UnauthorizedAccessException`, it:
1. Calls `takeown.exe /A /F` to make the local Administrators group the owner.
2. Adds `FullControl` ACEs (with `ContainerInherit, ObjectInherit`) for both
   `NT AUTHORITY\SYSTEM` and the supplied `<MyDomain>\<MyAdmin>` principal.
3. Recurses into the now-accessible folder to repeat as needed.

Logs the entire run via `Start-Transcript`.

```powershell
# Elevated pwsh, running as MYDOMAIN\myadmin
.\Take-OwnershipRecursively.ps1 `
    -Folder   'D:\OldProfile' `
    -MyDomain 'MYDOMAIN' `
    -MyAdmin  'myadmin' `
    -LogFile  "$env:TEMP\takeown-$(Get-Date -f yyyyMMdd-HHmmss).log"
```

> Be deliberate: this script grants broad permissions and changes ownership.
> Do not point it at system directories like `C:\Windows` or `C:\Program Files`.

### [visualstudio.ps1](PowerShell/visualstudio.ps1)
Visual Studio integration and shortcuts.

**Features:**
- Lazy-loads Visual Studio Developer Shell via lightweight proxy stubs (`msbuild`, `cl`, `devenv`, `nmake`, etc.) — the dev shell is loaded on first use, not at startup
- `Enter-VS` - Manually loads the VS Developer Shell (supports VS 2026 Insiders or Enterprise)
- `code` - Launches VS Code with medium integrity from admin console (requires gsudo)
- `sln` - Smart solution file launcher that:
  - Prioritizes .slnx files over .sln files
  - Searches current directory and subdirectories
  - Opens the first matching solution file

## Usage

To use these scripts on a new machine, run [`Bootstrap.ps1`](Bootstrap.ps1)
from the repo root. That installs a stub profile that dot-sources
`PowerShell/profile.ps1`. See the **New machine setup** section above for
details.
