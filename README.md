# Toolbag

A collection of PowerShell utilities and scripts for Windows development environment management.

## PowerShell Scripts

### [profile.ps1](PowerShell/profile.ps1)
Main PowerShell profile that loads all other scripts and configures the shell environment.

**Features:**
- Configures posh-git with custom prompt settings
- Sets up directory colors
- Defines repository and tools paths with fallback locations
- Imports all utility scripts (windowing, machine_setup, helpers, visualstudio)
- Configures PATH environment with common development tools (Git, .NET, npm, VS Code)
- Sets Beyond Compare as default comparison tool

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
- `Stop-Display` - Turns off the display (aliases: `DisplayOff`, `off`, `MonOff`)
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
- `Set-PowerShellProfileDirectory` - Configures custom PowerShell profile location

### [visualstudio.ps1](PowerShell/visualstudio.ps1)
Visual Studio integration and shortcuts.

**Features:**
- Auto-loads Visual Studio Developer Shell (supports VS 2026 Insiders or Enterprise)
- `code` - Launches VS Code with medium integrity from admin console (requires gsudo)
- `sln` - Smart solution file launcher that:
  - Prioritizes .slnx files over .sln files
  - Searches current directory and subdirectories
  - Opens the first matching solution file

## Usage

To use these scripts, dot-source `profile.ps1` in your PowerShell profile or set it as your profile. Or, use `Set-PowerShellProfileDirectory` to point to the root of this repo.
