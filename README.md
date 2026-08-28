# Toolbag

A collection of PowerShell utilities and scripts for Windows development environment management.

## New machine setup

```powershell
git clone https://github.com/bojordan/Toolbag.git C:\src\Repos\Toolbag
cd C:\src\Repos\Toolbag
.\Bootstrap.ps1                            # write the stub profile(s)
.\Bootstrap.ps1 -InstallDeps               # also install posh-git / oh-my-posh / gsudo / Beyond Compare
.\Bootstrap.ps1 -ConfigureWindowsTerminal  # duplicated tabs/panes inherit the current directory
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
- Imports all utility scripts (windowing, machine_setup, helpers, visualstudio, node)
- Adds existing dev-tool directories to PATH (Git, .NET, npm, VS Code, JRE) - missing ones are skipped
- Sets Beyond Compare as default comparison tool when installed
- Conditionally `cd`s to the repos root only when the shell started in a Windows-default directory, so a pane duplicated into a specific directory keeps it (see [Opening new tabs and panes in the current directory](#opening-new-tabs-and-panes-in-the-current-directory))

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
- `Format-RepoName` - Abbreviates dotted repo names so long namespace prefixes don't eat the tab (`foo.bar.bat.thing` -> `f.b.b.thing`)
- `Update-RepoTitle` - Sets the terminal title to the current git repo's name, prefixed with the git-branch glyph
- `Update-TerminalCwd` - Emits the OSC `9;9` escape sequence to tell Windows Terminal the current directory. See [Opening new tabs and panes in the current directory](#opening-new-tabs-and-panes-in-the-current-directory)
- `Test-StartedInDefaultDirectory` - Reports whether the shell was launched into a Windows-default directory (user profile, system folder, `WindowsApps`) rather than a deliberately chosen one. Used by `profile.ps1` to decide whether the auto-`cd` to the repos root is appropriate
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

### [node.ps1](PowerShell/node.ps1)
Per-directory Node.js version switching via [fnm](https://github.com/Schniz/fnm).

Install with `winget install Schniz.fnm`, then `fnm install --lts`. If `fnm`
isn't on PATH the script silently no-ops, so machines without it are unaffected.

**Features:**
- `Update-FnmNodeVersion` - Applies the Node version declared by the current
  directory tree; `profile.ps1` calls it at startup and from
  `LocationChangedAction`, so it fires for `cd`, `Set-Location`, `pushd`, and
  `popd` alike
- Deliberately avoids fnm's own `--use-on-cd` hook, which installs an AllScope
  alias over `cd` — that misses the other navigation commands and collides with
  this profile's existing `LocationChangedAction`
- Uses `--version-file-strategy recursive`, so a single `.nvmrc` at a repo root
  also covers nested projects (e.g. `src/Foo/ClientApp`)
- Walks up for `.nvmrc`, `.node-version`, or `package.json` before shelling out,
  keeping `fnm` off the hot path for unrelated directory changes
- Falls back to `fnm use default` when leaving a pinned tree, so a shell doesn't
  silently retain a previous repo's Node version

### [private.ps1](PowerShell/private.ps1)
A small, **tracked** loader for work-specific (or otherwise private) profile
functions. `profile.ps1` dot-sources it near the end of startup when present.

**Persistence strategy — peer repo, not a gitignored file:**
The actual private functions no longer live in this file (the older strategy
kept them in a gitignored `private.ps1`). Instead they live in a separate
**peer repository** cloned side-by-side with this one. The loader:

1. Resolves the repos root as the parent of this repo's directory.
2. Finds a sibling directory matching `Toolbag_*` (excluding `Toolbag`
   itself), so no specific peer repo name is hardcoded here.
3. Dot-sources `<peer>\ps\profile.private.ps1` from that peer if it exists.

If no peer repo is found (or the file is missing), it silently no-ops, so a
fresh clone of just this repo works without any private functions. Because
`private.ps1` contains only generic resolution logic and no secrets, it is
safe to track and publish.

To use it, clone your private peer repo beside this one, e.g.:

```text
C:\src\Repos\Toolbag\          # this repo (public)
C:\src\Repos\Toolbag_work\     # peer repo with ps\profile.private.ps1
```

## Opening new tabs and panes in the current directory

By default, `alt+shift+-` (duplicate pane down), `alt+shift+d`, and `ctrl+shift+d`
(duplicate tab) all open in the profile's configured `startingDirectory` — not
in the directory the current pane is sitting in. Getting the inherit-the-CWD
behaviour requires **three** cooperating pieces, only two of which live in this
repo.

### Why Windows needs a shell-side opt-in

On Linux and macOS, a terminal emulator can read a child process's CWD straight
from the OS. On Windows that's unreliable, and for PowerShell it's actively
wrong: **PowerShell does not change its process working directory as you `cd`
around.** `Set-Location` updates PowerShell's own location stack, but the
`pwsh.exe` process CWD stays wherever it was launched. So if Windows Terminal
duplicated the OS-reported CWD it would nearly always land in the wrong place.

The workaround is a shell-side announcement. The shell emits an
[OSC](https://en.wikipedia.org/wiki/ANSI_escape_code#OSC_(Operating_System_Command))
escape sequence — the ConEmu-originated `9;9` "SetCwd" sequence — and the
terminal records the path against that pane:

```text
ESC ] 9 ; 9 ; "C:\src\Repos\Toolbag" ESC \
```

Terminals that don't understand `9;9` ignore it, so emitting it unconditionally
is safe (conhost, VS Code's terminal, CI logs, and SSH sessions are unaffected).

### Piece 1 — Windows Terminal `settings.json` (NOT in this repo)

This is per-machine state living outside the repo, at:

```text
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

A recorded CWD is only *consulted* when the profile has no starting directory of
its own. An explicit `startingDirectory` always wins, so it must be cleared:

```jsonc
"profiles": {
    "defaults": {
        // null = "inherit the pane's CWD when one was reported,
        //         otherwise fall back to %USERPROFILE%"
        "startingDirectory": null
    }
}
```

Notes that matter here:

- **`null`, not `""` or omitted.** Omitting the key leaves the built-in default
  in place; `null` is the explicit "no starting directory" signal.
- **`defaults` does not override per-profile settings.** Any profile in
  `profiles.list` that sets its own `startingDirectory` keeps it and will keep
  ignoring the CWD. On this machine that meant clearing it on the hand-rolled
  pwsh profile (which had `%USERPROFILE%`); the two Anaconda profiles still pin
  `C:\Users\<user>` and are deliberately left alone.
- **Only duplicate-mode actions consume the CWD.** Confirmed against WT
  `1.24.11911.0` defaults: `alt+shift+-` is `Terminal.DuplicatePaneDown`
  (`splitPane` with `"splitMode": "duplicate"`), and `alt+shift+d` is the
  `split: auto` variant bound in this machine's `settings.json`. A plain
  `newTab` opens a fresh profile and intentionally starts at
  `startingDirectory`.
- Non-PowerShell profiles (Command Prompt, Git Bash, WSL) each need their own
  prompt-side emit before they inherit anything; only the PowerShell side is
  wired up here.

Because this file is machine-local and not tracked, it can't ship with the
repo — but `Bootstrap.ps1` can write it for you:

```powershell
.\Bootstrap.ps1 -ConfigureWindowsTerminal
.\Bootstrap.ps1 -ConfigureWindowsTerminal -WhatIf   # preview the exact changes
```

That switch:

- Finds `settings.json` for Stable and Preview installs, falling back to the
  unpackaged path only when no packaged install exists. (Third-party
  installers — Anaconda in particular — drop profile fragments at the
  unpackaged path even on machines that only run the Store build; rewriting
  that dead file would be pointless.)
- Sets `profiles.defaults.startingDirectory` to `null`.
- Clears `startingDirectory` on profiles that launch a **bare** PowerShell.
  The check deliberately requires the commandline to be *nothing but* the
  executable: Anaconda's "PowerShell Prompt" embeds `powershell.exe` in a
  longer conda-activation commandline, and a naive match on the exe name
  would wrongly claim it.
- Leaves every other profile alone and reports it, since cmd, WSL, and
  Anaconda prompts each need their own prompt-side emit anyway.
- Is idempotent, writes a timestamped `.bak` before changing anything, warns
  if the file contains comments (JSON round-tripping drops them), and honours
  `-WhatIf`.

### Piece 2 — emitting the sequence (`windowing.ps1`)

```powershell
function Update-TerminalCwd {
    $loc = $ExecutionContext.SessionState.Path.CurrentLocation
    if ($loc.Provider.Name -eq 'FileSystem') {
        [Console]::Write("`e]9;9;`"$($loc.ProviderPath)`"`e\")
    }
}
```

- The `FileSystem` provider guard matters because PowerShell locations are not
  always filesystem paths — inside `HKLM:\` or a `Cert:\` drive there is no
  directory to hand over, and reporting one would be nonsense.
- `ProviderPath` is used rather than `Path` so that PSDrive locations resolve to
  a real `C:\...` path that Windows Terminal can actually launch into.

**This repo deliberately does not follow the official docs' approach.** The
Microsoft tutorial says to emit the sequence from a custom `prompt` function.
That would collide head-on with this profile's lazy-loaded **posh-git**, which
installs its own `prompt`, and it would re-emit on every prompt redraw
(including every bare <kbd>Enter</kbd>). Instead the emit is hooked to
`LocationChangedAction` in `profile.ps1`, alongside the existing
`Update-RepoTitle` call:

```powershell
$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction = {
    param($old, $new)
    Update-RepoTitle
    Update-TerminalCwd
    ...
}
Update-RepoTitle
Update-TerminalCwd
```

`LocationChangedAction` fires on `cd`, `Set-Location`, `pushd`, and `popd`, so
the terminal is notified exactly once per actual directory change. The two bare
calls after the hook cover the starting directory, since no change event fires
for it.

### Piece 3 — not clobbering the inherited directory (`profile.ps1`)

This is the step that's easy to miss. The profile has always ended with an
unconditional jump to the repos root:

```powershell
Set-Location $reposPath   # old behaviour
```

That runs in the *new* pane too, so even with pieces 1 and 2 working perfectly
the pane would land in `C:\src\Repos` a fraction of a second later. The jump is
now conditional:

```powershell
if (Test-StartedInDefaultDirectory) {
    Set-Location $reposPath
}
```

`Test-StartedInDefaultDirectory` treats `%USERPROFILE%`, anything under
`%SystemRoot%`, and `WindowsApps` as "nobody asked for a directory" — the
directories Windows hands out when a shell is launched with no opinion — and
everything else as deliberate. So the convenience `cd` still happens for a
cold-start terminal, while a duplicated pane, `wt -d <path>`, or Explorer's
"Open in Terminal" is left where it was put.

### Verifying

```powershell
# 1. The sequence is emitted (ESC shown as <ESC>):
pwsh -NoLogo -Command 'Update-TerminalCwd' | ForEach-Object { $_ -replace "`e","<ESC>" }
#    -> <ESC>]9;9;"C:\src\Repos\Toolbag"<ESC>\

# 2. A deliberate directory survives profile load:
cd C:\src\Repos\Toolbag; pwsh -NoLogo -Command '(Get-Location).Path'
#    -> C:\src\Repos\Toolbag

# 3. A default directory still jumps to the repos root:
cd $env:USERPROFILE; pwsh -NoLogo -Command '(Get-Location).Path'
#    -> C:\src\Repos
```

Then open a **new** Windows Terminal window — existing panes are still running
the old profile — `cd` somewhere, and press `alt+shift+-`.

### Troubleshooting

| Symptom | Cause |
| --- | --- |
| New pane opens in `%USERPROFILE%` | The profile in `profiles.list` still has its own `startingDirectory`; `defaults` doesn't override it |
| New pane opens in the repos root | `Test-StartedInDefaultDirectory` misfired, or the pane is running a pre-change profile |
| Nothing inherits at all | Testing with `newTab` instead of a duplicate action, or the shell isn't running this profile |
| Works in pwsh, not in cmd/Git Bash | Those profiles need their own prompt-side `9;9` emit |



To use these scripts on a new machine, run [`Bootstrap.ps1`](Bootstrap.ps1)
from the repo root. That installs a stub profile that dot-sources
`PowerShell/profile.ps1`. See the **New machine setup** section above for
details.
